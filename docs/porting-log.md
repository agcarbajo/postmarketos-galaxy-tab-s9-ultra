# Registro del port postmarketOS para gts9uwifi

## 2026-07-17 — sesión 1: inicio y elección de arquitectura

- Leídos por completo `../port/README.md` y `../port/docs/porting-log.md`, junto
  con los inventarios de firmware y compatibilidad de fuentes.
- Ubuntu Touch se declara baseline estable y queda fuera del alcance de cambios.
- Inicialmente se consideró un PoC downstream 5.15.153 para obtener rápidamente
  pantalla/SSH. La usuaria pidió priorizar una base limpia y se cambió a una
  estrategia mainline-first. El kernel Samsung queda sólo como oráculo de
  hardware; no será una etapa de ejecución de postmarketOS.
- Se confirma que TWRP monta la microSD, pero todavía no que el kernel normal
  pueda usarla como raíz temprana.
- El primer acceso WSL desde el sandbox falló con `WSL_E_DISTRO_NOT_FOUND`.
  Fuera del sandbox se confirmaron `Ubuntu`, `Ubuntu-24.04` y
  `docker-desktop`. Los comandos complejos enviados con `bash -lc` también
  fallaron por quoting; a partir de ahora se ejecutarán scripts versionados.
- No se ha construido ni flasheado ningún artefacto.

## 2026-07-17 — sesión 2: auditoría mainline y DTS v0

- Fijados pmbootstrap 3.11.1 (`08213ed7...`), pmaports
  `b7681d0e857d395edfaa6c8e5cd0d89e4315fd3f` y Linux Torvalds v7.2-rc3
  `a13c140cc289c0b7b3770bce5b3ad42ab35074aa` en
  `/root/pmos-gts9u/` sobre `Ubuntu-24.04`.
- El paquete `linux-postmarketos-mainline` de ese pmaports usa el mismo RC y
  trae SM8550, SDHCI MSM, ext4, initramfs, UART y DWC3. Simpledrm y configfs
  USB estaban desactivados/como módulos, por lo que se añadió un fragmento
  X910 con los controladores tempranos built-in.
- Capturado `/sys/firmware/fdt` de la tablet por SSH; el DTB mide 1,120,765
  bytes y tiene SHA-256
  `7f02a5bb18f1ca2ff086e3038780d372463ff82062b5ef029401398b938cac83`.
  La captura recursiva del árbol sysfs se abandonó por timeout.
- Confirmado framebuffer stock `0xb8000000/0x2b00000`, panel 2960×1848,
  SDHC2 con PM8550 GPIO12/L9B/L8B, UART7 y Goodix GT9916 en I2C4.
- Se estudió usar `sm8550-samsung-q5q.dts` como include. Se descartó antes de
  obtener una build porque su MPSS/carveouts pertenecen al Fold5. El DTS v0
  es autónomo e incluye sólo los dtsi del SoC/PMIC.
- El mapa base `sm8550.dtsi` coincide con casi todas las reservas X910. Sólo
  se reemplazó `adspslpi_mem` por el tamaño Samsung `0x59b4000`, y se añadieron
  la reserva exacta `splash_region` y ramoops sobre el carveout Samsung
  `sec_log_buf` de 2 MiB.
- El DTS v0 habilita simple framebuffer, SDHC2, UART7, GT9916 y un intento USB2
  peripheral fijo. Este último es experimental: el repetidor NXP eUSB2 y el
  SM5714 Type-C/PD aún no tienen el soporte necesario upstream.

### Boot chain

- Analizada `dtbo.img` stock sin depender de dtc: header Android DT table de
  32 bytes, dos entradas, page size 4096, campos table id/rev/custom a cero.
  Se confirmaron propiedades raíz exactas de board-id 00 y 03 y sus rangos
  `dtbo-hw_rev`.
- Creados dos overlays no-op que mantienen esos selectores. No se reutiliza la
  DTBO downstream ni se crea una tabla vacía.
- El conjunto mínimo fiable se fija en `boot`, `init_boot`, `vendor_boot`,
  `dtbo` y `vbmeta`; la raíz va en SD. Recovery/TWRP conserva DTB/DTBO propios.
- `build-android-v4-bundle.sh` reproduce header v4, offsets conocidos, AVB
  footer y tamaños de partición, pero aún no se ha ejecutado porque faltan el
  kernel final y el initramfs pmOS.
- Se generó por adelantado el ZIP de vuelta atrás
  `restore-ubuntu-touch-v8-boot-sm-x910.zip`: toma boot/init/vendor/vbmeta de
  la build UT v8, DTBO del firmware X910XXS5CYG1, rellena cada miembro al
  tamaño completo de partición y no incluye `super`. SHA-256 del ZIP:
  `240599697c20c500cb180b31771f008401b1274a744ac3f81f15f5fd5b1dfcbe`.
  CRC, permiso 0755 del instalador y hashes internos fueron validados.

### Intentos de compilación

1. El primer intento falló al aplicar `add-gts9uwifi-dtb.patch`: el fichero
   contenía los dos caracteres `\\t` en vez de un tabulador. Corregido.
2. El siguiente intento heredó como cwd la ruta Windows con espacios y fue
   cortado por el timeout corto; se fuerza ahora `cd /root/pmos-gts9u`.
3. La compilación completa con el target `modules` superó diez minutos y el
   runner la terminó. No llegó a exportar artefactos. El script directo pide
   ahora sólo `Image.gz` y el DTB; el package pmOS compilará módulos después.

No se ha flasheado ni escrito ninguna microSD. La tarjeta presente de 238.3 GB
está al 96 % y queda expresamente fuera de alcance.

La documentación pmbootstrap actual todavía declara WSL no soportado por los
loop devices. El kernel se compila correctamente en WSL2, pero falta comprobar
la fase `pmbootstrap install`; si ésta falla por loop/mount se usará una VM o
contenedor Linux privilegiado, sin modificar la arquitectura del port.
