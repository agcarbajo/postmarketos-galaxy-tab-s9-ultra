# Port de postmarketOS para Samsung Galaxy Tab S9 Ultra Wi-Fi

> Documento vivo del proyecto. Debe actualizarse con cada avance, fallo,
> decisión de arquitectura y artefacto generado.
>
> Última actualización: 2026-07-17.

## Objetivo

Conseguir un Linux orientado al escritorio en la Samsung Galaxy Tab S9 Ultra
Wi-Fi (SM-X910, `gts9uwifi`, Qualcomm SM8550/kalama), con postmarketOS como
entorno de bring-up. El objetivo inmediato es arrancar un escritorio ligero,
mostrar correctamente la imagen y disponer de SSH. El objetivo de largo plazo
es un stack Linux convencional con DRM/KMS, Mesa/Turnip y la mayor
compatibilidad posible con software de escritorio ARM64, FEX y Proton.

Ubuntu Touch queda congelado como baseline de referencia en `../port/`; este
proyecto no modifica sus fuentes ni artefactos. Desde 2026-07-18 la usuaria no
requiere conservar la instalación física de UT: se prioriza evitar un brick y
mantener TWRP/Download Mode/Odin, no preservar su boot chain o userdata.

## Estrategia

Se adopta una estrategia **mainline-first**. El kernel upstream, DRM/KMS y
Mesa/Turnip serán la única base de ejecución del nuevo port. El kernel Samsung
5.15.153 funcional no se adaptará como etapa intermedia: se usará como
referencia documental para reconstruir el hardware de la placa (panel, DTBO,
GPIO, reguladores, táctil, firmware y secuencias de alimentación).

Esta decisión puede retrasar la primera salida gráfica, pero evita construir un
segundo sistema atrapado en KGSL/libhybris. Los hitos se aceptan en este orden:

1. kernel mainline arrancando con consola/logs;
2. almacenamiento y rootfs en microSD;
3. red y SSH, inicialmente incluso sin pantalla;
4. DRM/DSI, panel y táctil;
5. escritorio ligero y Turnip;
6. resto del hardware.

La opción preferida de prueba es conservar el sistema en la microSD y cambiar
el mínimo de particiones internas. Antes de afirmar que esto es posible hay que
verificar que el controlador de la microSD y el filesystem elegido estén
integrados en el kernel o disponibles en el initramfs. En Samsung normalmente
no existe `fastboot boot`; no se asumirá que hay arranque temporal hasta
demostrarlo en este dispositivo.

## Estado actual

| Componente | Estado |
|---|---|
| Workspace y documentación | ✅ Inicializados |
| Baseline Ubuntu Touch | 📚 Fuentes intactas; boot físico ya reemplazado en la prueba mainline |
| Identidad y boot chain SM-X910 | ✅ Inventariadas desde firmware X910XXS5CYG1 |
| Kernel downstream 5.15.153 | 📚 Sólo referencia de hardware; no será la base pmOS |
| Kernel mainline SM8550 | ✅ Linux 7.2-rc3 compilado y empaquetado; kernel/DTB y símbolos tempranos validados |
| DTS `gts9uwifi` | 🟡 Framebuffer, SD, UART, ramoops, USB2 experimental y GT9916 descritos y compilados; falta validar en la tablet |
| Acceso temprano a microSD | 🟡 Driver/pines/rails confirmados y built-in; falta el primer boot físico |
| Paquetes pmaports | ✅ Device y kernel APK construidos; rootfs usa el mismo kernel empaquetado |
| Rootfs postmarketOS | ✅ Imagen GPT ext2/ext4 construida y validada estáticamente |
| Escritorio | 🟡 XFCE4/LightDM instalados y habilitados; falta primer arranque físico |
| SSH | 🟡 OpenSSH habilitado; falta que USB NCM o una red funcionen en hardware |
| Bundle Android v4 | ✅ Cinco imágenes reproducibles, AVB/headers/offsets/DTBO validados |
| Restauración Ubuntu Touch | ✅ ZIP boot-only v8/DTBO stock generado y validado |
| Imagen/paquete de prueba | 🟡 v0.1 corrige `vbmeta` RO observado en TWRP; primer boot pendiente |

## Reto en curso

Realizar el primer arranque físico controlado de mainline v0.1:

- escribir la imagen ya generada en una microSD sacrificable de 8 GB o más;
- flashear manualmente desde TWRP el ZIP v0.1: escribe cuatro particiones boot
  y conserva `vbmeta` si está RO pero ya tiene AVB flags 2;
- distinguir si ABL acepta el kernel, si monta `pmOS_root` desde `sdhc_2`, si
  simpledrm conserva el framebuffer y si aparece USB NCM/SSH;
- si falla, volver a TWRP y recuperar ramoops/pstore antes de modificar DTS o
  cmdline; restaurar Ubuntu Touch es opcional;
- si arranca, priorizar red estable y después DRM/DSI nativo para el panel
  dual-DSI, táctil y Turnip.

El DTS v0 no incluye DRM/DSI nativo. Mantiene el scanout del bootloader y usa
simpledrm para separar el primer arranque del futuro driver dual-DSI del panel.

No se flasheará la tablet automáticamente. Todo artefacto debe validarse
estáticamente y acompañarse de instrucciones de restauración antes de pedir una
prueba física.

## Hechos de hardware y firmware confirmados

- Modelo: Samsung SM-X910; codename Android `gts9uwifi`.
- SoC: Qualcomm SM8550/kalama; GPU Adreno 740.
- Dispositivo no A/B.
- Firmware base disponible: X910XXS5CYG1, One UI 7 / Android 15 userspace,
  kernel Samsung 5.15.153 con KMI Android 13.
- Boot image header v4. Particiones relevantes:
  - `boot`: 96 MiB;
  - `init_boot`: 8 MiB;
  - `vendor_boot`: 96 MiB;
  - `dtbo`: 16 MiB, overlay stock `board-id,03`;
  - `recovery`: 104.5 MiB;
  - `super`: 11,744,051,200 bytes.
- Panel: `GTS9U_ANA38407_AMSA46AS02`.
- Táctil: Goodix Berlin/GT9916 (confirmado en el FDT vivo).
- WLAN: Qualcomm Kiwi v2.
- TWRP 3.7.1_12-0 monta una microSD de 238 GB como `/external_sd`.
- Esa tarjeta actual está en exFAT, al 96 % y contiene datos: no se usará para
  pruebas destructivas. Hace falta otra microSD.
- Linux mainline identifica la ranura como `sdhc_2`; el DT vivo confirma
  detección PM8550 GPIO12, VMMC L9B y VQMMC L8B.
- El táctil es Goodix GT9916 en I2C4 `0x5d`, con driver Berlin upstream.
- La X910 usa repetidor NXP eUSB2 y controlador Type-C/PD SM5714, no el diseño
  PMIC GLINK de las placas Qualcomm de referencia.
- El port UT demuestra que el kernel downstream, los blobs stock y la DTBO
  pueden proporcionar pantalla, GPU, táctil, Wi-Fi, audio y sensores.

## Reglas de seguridad

- La usuaria flashea manualmente; las herramientas de build nunca escriben en
  la tablet.
- No tocar bootloader, PIT, EFS, persist, modem ni calibraciones.
- No escribir `super` para el bring-up si puede evitarse.
- Conservar siempre las imágenes stock y hashes antes de generar derivados.
- No reutilizar imágenes X710: panel, táctil, WLAN y overlays no son
  intercambiables con el SM-X910.
- Cada procedimiento de prueba debe incluir vuelta atrás mediante TWRP/Odin.

## Estructura del proyecto

```text
PostmarketOS/
├── README.md                  # este documento vivo
├── docs/
│   ├── porting-log.md         # historial detallado por sesiones
│   ├── upstream-audit.md      # soporte mainline/pmOS y fuentes reutilizables
│   ├── boot-strategy.md       # boot chain, microSD, riesgos y recuperación
│   └── testing-mainline-v0.md # procedimiento manual de prueba y rollback
├── configs/                   # cmdline, bootconfig y fuentes DTBO no-op
├── pmaports/                  # device/kernel packages locales de pmbootstrap
├── scripts/                   # build, empaquetado y validación reproducible
├── sources/                   # repos/clones necesarios o manifiestos fijados
├── work/                      # temporales, logs y scripts de entorno
└── artifacts/                 # imágenes finales, hashes e instrucciones
```

Los firmware e imágenes grandes no se duplican: se referencian desde
`../port/firmware-extracted/` y desde la carpeta oficial de firmware situada al
lado del workspace.

## Entorno de trabajo

- Las distribuciones WSL `Ubuntu` y `Ubuntu-24.04` existen para el usuario de
  Windows, pero no son visibles desde el usuario aislado del sandbox. Las
  invocaciones WSL deben ejecutarse con el contexto autorizado del usuario.
- Los comandos complejos no deben pasarse con `bash -lc` desde PowerShell: las
  comillas y expansiones se deforman. Escribirlos en `work/*.sh` y ejecutar el
  fichero con `bash` dentro de WSL.
- Las builds pesadas se harán en filesystem Linux y en una ruta sin espacios;
  el workspace de Windows contendrá fuentes fijadas, configuración, scripts y
  artefactos finales.
- Entorno fijado: `Ubuntu-24.04`, `/root/pmos-gts9u/`; pmbootstrap 3.11.1,
  pmaports `b7681d0...` y Linux `a13c140cc...` (`v7.2-rc3`).
- En `Ubuntu` (Python 3.10) pmbootstrap actual falla por `tomli/tomllib`; usar
  `Ubuntu-24.04` para este proyecto.
- La documentación oficial de pmbootstrap sigue marcando WSL como no
  soportado por su uso de loop devices. En este WSL2 concreto, tras instalar
  `kpartx`, kernel APK, loop/mount, rootfs y export han funcionado. No se
  extrapola esa observación a otros entornos.

## Lo que ha funcionado

- Reutilización del inventario completo y conocimiento de hardware del port UT.
- Acceso autorizado a las distribuciones WSL reales del usuario.
- Confirmación previa de que TWRP reconoce y monta la microSD.
- Captura del FDT vivo X910 como `work/live-device-tree.dtb` y decompilación a
  DTS; hash SHA-256 del blob: `7f02a5bb18f1ca2ff086e3038780d372463ff82062b5ef029401398b938cac83`.
- Auditoría upstream: SM8550, SDHC2, GT9916, A740 y simpledrm tienen base
  mainline utilizable. Linux 7.2-rc3 coincide con el paquete pmOS actual.
- Inspección binaria local de la DTBO stock: dos entradas y todos sus
  selectores exactos confirmados. Se han creado equivalentes no-op.
- Dependencias de kernel instaladas en `Ubuntu-24.04` y worktree/build fuera de
  la ruta Windows con espacios.
- DTS autónomo X910 y paquetes `device-samsung-gts9uwifi` /
  `linux-samsung-gts9uwifi-mainline` creados con checksums fijados.
- Compilado Linux 7.2-rc3 directo y como APK. El DTB resultante conserva
  framebuffer/splash, reservas, SDHC2, GT9916, UART, USB experimental y
  ramoops; los controladores críticos para root SD y diagnóstico son built-in.
- `pmbootstrap install` funciona en WSL2 con `kpartx`. Se creó una imagen GPT
  de 4.634.705.920 bytes con `pmOS_boot` ext2 y `pmOS_root` ext4, XFCE4,
  systemd, LightDM, NetworkManager y OpenSSH.
- Separar `initramfs-extra` en la partición boot reduce el initramfs de
  15,15 MiB a 2.133.928 bytes; cabe en `init_boot` de 8 MiB con 6.254.680 bytes
  de margen bruto antes del footer AVB.
- El `vmlinuz` instalado por `zinstall` es EFI zboot. Se valida su cabecera y
  se extrae su payload gzip (`0237f8a...`) para Android `boot.img`, garantizando
  que kernel y módulos proceden de la misma compilación y release 7.2.0-rc3.
- Bundle Android v4 regenerado dos veces con hashes idénticos y validado byte a
  byte: headers, offsets, DTB, selectores DTBO, AVB y tamaños correctos.
- La primera instalación física confirmó la SD `pmOS_boot` ext2 y escribió
  correctamente `boot`, `init_boot`, `vendor_boot` y `dtbo`. El ZIP v0 falló
  sólo al intentar escribir `vbmeta`: TWRP expone `/dev/block/sde15` (128 KiB)
  con flag RO. Su contenido seguía intacto y ya tenía AVB `Algorithm: NONE`,
  `Flags: 2`, por lo que no necesita reemplazo para esta prueba.
- Generados y validados los artefactos mainline v0.1: imagen SD comprimida
  `592deff2...` y ZIP TWRP `aaef2bb5...`. El instalador valida `vbmeta` antes
  de escribir nada y lo conserva sólo si el RO existente tiene flags 2.
- Regenerado `artifacts/restore-ubuntu-touch-v8-boot-sm-x910.zip` (SHA-256
  `eee755c73105ce55311e63eb4a8a50dff42ca6338b1930c017825c510a563e06`):
  restaura las cuatro particiones boot escribibles y `vbmeta` si recovery lo
  permite; nunca reescribe `super`. Pasó CRC, modo y hashes internos.

## Lo que no ha funcionado / no repetir

- Ejecutar WSL desde el usuario de sandbox: devuelve
  `WSL_E_DISTRO_NOT_FOUND` aunque las distros sí existen para la usuaria.
- Pasar una línea compleja con paréntesis, `$()` y comillas mediante
  `wsl ... bash -lc`: PowerShell/WSL altera el quoting. Usar scripts.
- Asumir que `fastboot boot` existe por tratarse de un dispositivo Android;
  Samsung suele exponer Download Mode/Odin, no fastboot estándar.
- Capturar recursivamente todo `/sys/firmware/devicetree/base` por SSH tardó
  demasiado y dejó un árbol parcial. `capture-live-fdt.sh`, que obtiene
  `/sys/firmware/fdt`, es la vía correcta.
- Incluir directamente `sm8550-samsung-q5q.dts` fue descartado antes de
  compilar: el Fold5 redefine carveouts MPSS propios. El DTS X910 debe incluir
  `sm8550.dtsi` y sólo trasladar datos contrastados de nuestra placa.
- El primer parche del Makefile contenía los caracteres `\\t` en lugar de un
  tabulador real y no aplicó. Está corregido.
- Una compilación que pedía también todos los módulos excedió los diez minutos
  del runner y fue terminada. El script directo construye ahora sólo
  `Image.gz` y el DTB; los módulos completos quedan para el package pmOS.
- Usar una sola partición rootfs deja un initramfs de unos 15,15 MiB, imposible
  para `init_boot` de 8 MiB. `pmbootstrap` además impide `initramfs-extra` con
  `--single-partition`; la solución validada es la imagen estándar de dos
  particiones, no recortar módulos tempranos necesarios.
- El primer package device falló por mantenedor no RFC822, dependencia ausente
  de `android-tools` y falta de `deviceinfo_flash_pagesize`; están corregidos.
- No usar directamente `/boot/vmlinuz` en Android: `zinstall` genera un wrapper
  EFI zboot. Tampoco mezclar el `Image.gz` de la build directa con módulos del
  APK. El bundle extrae y verifica el payload del zboot empaquetado.
- Los AVB salts aleatorios y un CPIO vacío con timestamps variables hacían
  cambiar los hashes. Los salts derivan ahora del SHA-256 de la imagen y el
  vendor ramdisk vacío usa timestamp cero y `cpio --reproducible`.
- `zipfile.writestr()` añadía la hora actual a dos miembros y cambiaba el SHA
  del ZIP aunque las imágenes fueran idénticas. Todos los miembros usan ahora
  época ZIP fija; dos paquetes mainline y dos rollback resultaron idénticos.
- No asumir que una partición presente bajo `/dev/block/by-name` es escribible.
  En este TWRP `vbmeta` apunta correctamente a `sde15`, pero el kernel la marca
  RO y `blockdev --setrw` no lo cambia. El instalador debe prevalidar el flag RO
  y los bytes AVB flags antes de escribir las demás particiones.

## Referencias locales

- `../port/README.md`: estado final del port Ubuntu Touch.
- `../port/docs/porting-log.md`: investigación y bring-up detallados.
- `../port/docs/sm-x910-x910xxs5cyg1-firmware-inventory.md`: boot chain y
  firmware.
- `../port/docs/source-compatibility-matrix.md`: kernel y módulos Samsung
  probados.
- `../port/sources/samsung-gts9u/`: adaptación downstream funcional.
