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

Al terminar esta sesión, el ejecutor rechazó nuevas llamadas WSL por un límite
temporal de uso. Esto impide reanudar los objetos parciales y lanzar
pmbootstrap, pero no aporta evidencia de un fallo del DTS/kernel. Se detiene el
trabajo remoto de forma explícita y no se intenta eludir el control mediante
otra vía de ejecución.

## 2026-07-17 — sesión 3: build completa y bundle mainline v0

La usuaria autorizó reintentar las ejecuciones WSL. Se reanudó el mismo árbol
en `/root/pmos-gts9u/`; no se tocó la tablet ni se seleccionó ninguna unidad
física.

### Kernel y DTB

- Terminó la compilación directa de Linux 7.2-rc3. `Image.gz` mide 19.837.293
  bytes y el DTB X910 115.616 bytes. Se verificaron como built-in simpledrm,
  SD/MMC/SDHCI MSM, ext4, gadget/configfs/NCM, UART Qualcomm, GT9916 y
  ramoops/pstore.
- El DTB decompilado conserva el framebuffer 2960×1848 en `0xb8000000`, la
  reserva splash, el carveout ADSP, ramoops, SDHC2, Goodix, UART7 y USB2
  peripheral experimental.
- El APK completo `linux-samsung-gts9uwifi-mainline` terminó en 3.215,9 s.
  Su release instalada es `7.2.0-rc3` y los módulos exponen el mismo vermagic.
- `zinstall` no deja un gzip Android en `/boot/vmlinuz`, sino un EFI zboot de
  19.767.808 bytes. Su cabecera `MZ/zimg` señala un payload gzip de 19.706.845
  bytes, SHA-256 `0237f8a0930fe85dd46256ffd7e723f11078b8439d70a8c093e12f0b4760f35c`;
  al descomprimir produce un `Image` ARM64 válido de 57.344.000 bytes. El
  generador extrae ese payload para no mezclar kernel y módulos de builds
  distintas.

### pmbootstrap y rootfs

- Se instaló `kpartx` en Ubuntu-24.04 y el flujo loop/mount de pmbootstrap
  funcionó pese a que WSL no está soportado oficialmente.
- Los primeros intentos del device APK fallaron sucesivamente por un
  mantenedor no válido, ausencia de `android-tools` y falta de page size para
  mkbootimg. Se corrigieron a un RFC822 válido, dependencia explícita y
  `deviceinfo_flash_pagesize="4096"`.
- Una rootfs de una sola partición produjo un initramfs de aproximadamente
  15,15 MiB, mayor que `init_boot`, y pmbootstrap no permite
  `initramfs-extra` con `--single-partition`. Se activó
  `deviceinfo_create_initfs_extra="true"` y se generó una imagen GPT estándar
  de dos particiones.
- Imagen final: 4.634.705.920 bytes, SHA-256
  `103fe9980b7322b2fe2878bd6cf191cabe7152f4d31561623be1a9f0b36ef3b4`.
  La partición 1 es ext2 `pmOS_boot` de unos 487 MiB y la 2 ext4 `pmOS_root`
  de unos 3,8 GiB.
- El initramfs final mide 2.133.928 bytes (SHA-256 `ba13b0d...`) y
  `initramfs-extra` 13.014.943 bytes (SHA-256 `b581bbe6...`). La rootfs incluye
  edge, systemd, XFCE4/LightDM, NetworkManager, OpenSSH, `xfce4-terminal`,
  usuario `phablet`, contraseña `<DEV_PASSWORD>` y hostname `gts9u`.

### Boot chain y artefactos

- Se construyeron `boot`, `init_boot`, `vendor_boot`, `dtbo` y `vbmeta` con
  sus tamaños completos de partición. El kernel procede del zboot del package,
  el initramfs de la rootfs y el DTB del mismo package.
- Se eliminaron dos fuentes de no determinismo: AVB usa un salt derivado del
  SHA-256 previo al footer y el CPIO vendor vacío usa timestamp cero con
  `--reproducible`. Dos generaciones consecutivas dieron hashes idénticos.
- Validación correcta: hashes internos, Android header v4, offsets Samsung,
  comparaciones byte a byte, DTBO de dos selectores, AVB y tamaños. Hashes de
  imágenes: `boot dfe592dc...`, `init_boot 36ed30f9...`,
  `vendor_boot 13bf87cb...`, `dtbo 9f2dc02e...`, `vbmeta f489966f...`.
- Imagen SD comprimida final:
  `postmarketos-edge-xfce-mainline-v0-sm-x910-sd.img.zst`, SHA-256
  `592deff221c271b03a6830d2b7dc89497e327151951ceac043f4ebadb8c0b237`.
- ZIP de prueba TWRP final:
  `postmarketos-edge-xfce-mainline-v0-sm-x910-twrp.zip`, SHA-256
  `7af75c71dcb451e0cc1400a6275c2a01908894e1bde9a34f9b85f34702837bc3`.
  CRC, permisos, tamaños y manifests interno/externo pasaron. El instalador
  resuelve de forma segura particiones con o sin sufijo y no toca `super` ni
  datos.
- Se regeneró y volvió a validar el rollback
  `restore-ubuntu-touch-v8-boot-sm-x910.zip`, SHA-256
  `fd1d31a5fb77c3586171601e438bc7aa7b439fd7e4981d05f1d0aa0f209234f3`.
- Una regeneración del ZIP cambió el hash aunque las imágenes no cambiaron:
  `writestr()` estaba fechando dos entradas con la hora actual. Se fijó
  1980-01-01 para todos los miembros y se comprobó que dos ZIP mainline y dos
  rollback independientes son idénticos byte a byte.
- Se añadió `docs/testing-mainline-v0.md`. El bundle queda listo para una
  prueba manual con microSD sacrificable, pero **todavía no está validado por
  un arranque físico**. Wi-Fi no está descrito en el DTS v0 y USB NCM depende
  del repetidor NXP/SM5714 todavía no soportado; no se promete SSH en este
  primer intento.

## 2026-07-18 — sesión 4: primer flash y corrección de vbmeta RO

- Analizado `../logs/recovery.log` tras dos intentos de instalar el ZIP v0.
  TWRP reconoció correctamente la primera partición de la nueva microSD como
  ext2 en `/dev/block/mmcblk1p1`, con unos 454 MiB.
- En ambos intentos se escribieron completos y sin error `boot` (96 MiB),
  `init_boot` (8 MiB), `vendor_boot` (96 MiB) y `dtbo` (16 MiB). El instalador
  terminó con error únicamente al abrir `/dev/block/by-name/vbmeta`.
- ADB confirmó que el symlink era correcto y resolvía a `/dev/block/sde15`.
  La partición mide 131072 bytes, no 65536, y el kernel de TWRP la marca RO.
  `blockdev --setrw` devuelve éxito pero el flag permanece en 1; no se intenta
  eludir la protección escribiendo por otro nodo.
- Se extrajo la partición actual completa. `avbtool` confirmó `Algorithm:
  NONE`, `Flags: 2`, sin descriptores. Los intentos fallidos no la modificaron
  y su contenido ya es apto para arrancar imágenes custom sin verificación.
- Causa raíz: el instalador trataba toda partición existente como escribible y
  consideraba fatal el `dd` de `vbmeta`. La instalación no falló por el ZIP,
  SD, kernel ni las otras imágenes.
- El instalador v0.1 hace un preflight antes de cualquier escritura: comprueba
  tamaño de 128 KiB, flag RO y los cuatro bytes big-endian de AVB flags en el
  offset 120. Si `vbmeta` es RO sólo continúa cuando son `00000002`, conserva
  la partición y escribe las otras cuatro. Si es RW, instala el nuevo vbmeta.
- Todos los generadores y validadores usan ahora el tamaño físico 131072. El
  nuevo ZIP es
  `postmarketos-edge-xfce-mainline-v0.1-sm-x910-twrp.zip`, SHA-256
  `aaef2bb5079d9357338ae173737f9e94cca83c20c0f6d07d2466ccddc8c6aca0`.
  Bundle Android, AVB, tamaños, CRC, permisos, hashes y zstd volvieron a pasar.
- El ZIP v0.1 se copió por ADB a `/sdcard/` mientras la tablet seguía en TWRP
  y se verificó allí el mismo SHA-256. No se flasheó ni se reinició la tablet.
- El rollback se regeneró con el tamaño corregido, SHA-256
  `eee755c73105ce55311e63eb4a8a50dff42ca6338b1930c017825c510a563e06`.
  La usuaria indica que no necesita conservar la instalación UT; se mantiene
  sólo como comodidad. La prioridad de seguridad sigue siendo conservar TWRP,
  Download Mode/Odin, bootloader y particiones de calibración, no el estado de
  `super`/userdata.

## 2026-07-18 — sesión 5: rechazo del DTB por ABL y bundle v0.2

- La usuaria flasheó v0.1 y reinició. La tablet mostró el splash Samsung con
  información RPMB/secure boot y código de barras, y después volvió a TWRP.
  No era un panic ni una consola del kernel: era Odin lanzado por ABL.
- Desde TWRP se recogió un diagnóstico de sólo lectura en
  `work/mainline-first-boot-twrp-20260718.txt`. `pstore` estaba montado pero
  vacío. `/proc/last_kmsg`, de 2 MiB, sí conservaba el log completo de XBL/ABL.
- Secuencia determinante del log: ABL reconoce Hyp, fija memoria en
  `0x80000000`, descomprime el kernel en 364 ms, registra `No match found for
  Soc Dtb type`, luego `Error: Appended Soc Device Tree blob not found` y
  finalmente `Launching odin`. Linux nunca llegó a ejecutarse, por lo que no
  hay todavía evidencia sobre SD, initramfs, simpledrm o USB.
- Se compararon las imágenes v0.1 con el rollback UT funcional. Ambos kernels
  son payloads ARM64 gzip válidos; el kernel UT no contiene un FDT appended
  detectable, de modo que el texto de ABL es un fallback genérico y no prueba
  que Samsung exija adjuntar el DTB al kernel. UT arranca usando el DTB de
  `vendor_boot`.
- El FDT vivo downstream tiene en la raíz `qcom,kalama-mtp`, `qcom,kalama`,
  `qcom,mtp`; `qcom,msm-id = <0x218 0x20000 0x207 0x20000 0x207 0x10000
  0x218 0x10000>`; y `qcom,board-id = <0x10008 0x03>`. El DTB mainline v0.1
  sólo tenía `samsung,gts9uwifi`, `qcom,sm8550` y carecía de ambos IDs.
- Causa raíz: ABL filtra el DTB base de `vendor_boot` usando esos metadatos
  downstream antes de arrancar Linux. Al no encontrar coincidencia, buscó un
  DTB appended inexistente y abrió Odin.
- El DTS mainline conserva sus compatibles upstream pero antepone exactamente
  los tres compatibles Qualcomm y añade los IDs del FDT vivo. Se incrementó
  `pkgrel` y se añadió una validación que extrae el DTB desde `vendor_boot` y
  exige los tres valores exactos.
- La recompilación incremental produjo un DTB de 115.742 bytes, SHA-256
  `571d04dc585702a04db219a78666f07509ccdbe641417a861e6e9d8b869f949a`.
  Para aislar esta hipótesis, v0.2 conserva el payload del kernel empaquetado
  (y por tanto su correspondencia con los módulos de la SD) y sustituye sólo
  el DTB en `vendor_boot`; no usa el `Image.gz` de la build directa.
- Nuevo `vendor_boot.img`: SHA-256
  `3ddf6ddbbb02fc4d687145ba74e52c3085373aff9c919bf56e9248bb4514c9e9`.
  El resto de imágenes no cambió. Todos los headers Android v4, offsets, AVB,
  tamaños, DTBO, comparaciones byte a byte, selectores de ABL, CRC, modos,
  manifests y el stream zstd pasaron.
- Artefacto listo:
  `postmarketos-edge-xfce-mainline-v0.2-sm-x910-twrp.zip`, SHA-256
  `9288af69c694fdc84b7b1f9694265152c5f7959a880d338f98b2e3d106c0f65c`,
  21.850.752 bytes. Se copió a `/sdcard/` y se verificó allí el mismo hash.
  La tablet permanece en TWRP y el asistente no lo ha flasheado.

## 2026-07-18 — sesión 6: fallo ufdt de v0.2 y bundle v0.3

- Tras flashear v0.2, la tablet volvió a mostrar Odin. Se regresó a TWRP y se
  capturó inmediatamente `/proc/last_kmsg` en
  `work/mainline-v02-last-kmsg-20260718.txt`; mide 4.245.076 bytes. `pstore`
  continúa vacío porque tampoco en esta ocasión se ejecutó Linux.
- El log contiene dos intentos v0.2 idénticos. En ambos desapareció el error
  v0.1 `No match found for Soc Dtb type`: ABL descomprime el kernel y ejecuta
  `FindBestMatch GetBoardRev = 5, DtSubType = 3`. Esto valida físicamente los
  compatibles e IDs añadidos en v0.2.
- La nueva secuencia de fallo es `ApplyOverlay: ufdt apply overlay failed`,
  `Error: Dtb overlay failed`, `Root Node is not found at BoardDtb`, y más
  tarde `ERROR: Invalid device tree header`, `Device Tree update failed` y
  `Launching odin`. El fallo sigue dentro de ABL, antes de entrar en Linux.
- Se extrajeron las dos entradas de la DTBO stock: miden 814.799 y 813.811
  bytes y son overlays completos Samsung. No se pueden reutilizar sobre el DTB
  mainline porque contienen cientos de fixups a símbolos/nodos downstream.
  La entrada no-op v0.2 es estructuralmente válida y `fdtoverlay` la aplica
  correctamente sobre el DTB v0.2.
- Se compiló desde la fuente oficial de Android una utilidad local basada en
  `ufdt_apply_overlay`; también aplicó correctamente el no-op v0.2. La
  incompatibilidad observada es por tanto específica del camino/fork ufdt de
  Samsung ABL, no un FDT mal formado según libfdt/libufdt estándar.
- Diferencia relevante: el DTB base stock funcional tiene `/__symbols__`; el
  DTB mainline v0.2 no. Aunque el overlay no-op usa `target-path` y no necesita
  fixups con la implementación estándar, la ruta Samsung falla sin esa tabla.
- El parche de Makefile del kernel añade ahora
  `DTC_FLAGS_sm8550-samsung-gts9uwifi := -@`; `pkgrel` sube a 2. El nuevo DTB
  mide 150.407 bytes, SHA-256
  `c0684a774f7a8e99ca19ddae603dcdba3638afecefbda7baad54fcd56731c64c`,
  conserva los selectores ABL exactos y exporta 474 símbolos.
- `fdtoverlay` y la utilidad `ufdt_apply_overlay` oficial aplicaron el overlay
  board03 sobre la nueva base. El validador de bundle exige ahora que el DTB
  extraído de `vendor_boot` contenga `/__symbols__` además de los IDs exactos.
- Bundle v0.3: el kernel empaquetado, initramfs, DTBO, vbmeta y SD no cambian;
  sólo cambia el DTB de `vendor_boot`. El nuevo `vendor_boot.img` tiene SHA-256
  `f12fbc3d4f543438f6b2a01c546e43d0b3ca90535f092aba477b42c711fd1850`.
- ZIP final:
  `postmarketos-edge-xfce-mainline-v0.3-sm-x910-twrp.zip`, 21.856.498 bytes,
  SHA-256
  `0a0d5b0e749c17155a0503e1c6a14e340ea3b9b437a3fbbcfbd77d9219bde240`.
  Pasó todas las validaciones, se reprodujo byte a byte, se copió a
  `/sdcard/` y se verificó allí. La tablet permanece en TWRP; el asistente no
  lo ha flasheado.

## 2026-07-18 — sesión 7: ufdt v0.3 descartado y fallback appended-DTB v0.4

- Tras flashear v0.3, la tablet volvió a Odin. Desde TWRP se capturó
  `work/mainline-v03-last-kmsg-20260718.txt`, de 4.238.058 bytes. `pstore`
  sigue vacío.
- La secuencia es indistinguible de v0.2: ABL descomprime el kernel, selecciona
  correctamente el DTB, tarda unos 10,6 ms y devuelve `ApplyOverlay: ufdt
  apply overlay failed`, `Root Node is not found at BoardDtb`, `Invalid device
  tree header` y `Launching odin`. Los 474 símbolos de v0.3 no cambian el
  comportamiento del fork Samsung; esa hipótesis queda descartada.
- Se recuperó como referencia el flujo Qualcomm ABL/Tianocore del commit
  `2a0c8e9714930333c059b820b857f925d4d3a3dd`. `BootLinux.c` llama a
  `LoadAndValidateDtboImg`: si la magia/tabla DTBO no es válida, omite
  `GetBoardDtb` y `ufdt_apply_overlay` y llama a `DeviceTreeAppended` sobre el
  contenido situado después del gzip. `Decompress.c` devuelve precisamente la
  posición final del miembro gzip como `DtbOffset`.
- Se elige ese fallback en vez de inventar IDs PMIC para forzar un supuesto
  exact-match o seguir alterando un overlay que las implementaciones estándar
  sí aceptan pero Samsung rechaza.
- El generador admite ahora `APPEND_DTB_TO_KERNEL=1`: conserva sin cambios el
  `Image.gz` del package y concatena el DTB raw inmediatamente después. El
  validador separa ambas regiones y las compara byte a byte con sus fuentes.
- `DISABLE_RUNTIME_DTBO=1` genera una imagen con prefijo cero, no una Android
  DT table. Después añade un footer hash AVB correcto y la expande a los
  16.777.216 bytes exactos. El validador exige la magia nula y sigue ejecutando
  `avbtool verify_image`. TWRP lleva recovery DTB/DTBO propios; el rollback
  restaura la DTBO stock si fuese necesario.
- Hashes de las imágenes modificadas: `boot.img`
  `342a2dc8e78267b1463d59fb8f889c456ea47bba899d7c314c9cb18a921aaa64`;
  `dtbo.img`
  `c17418be08365c03a5ce3a220af734b14ec2e6b03c0cbc1ed9721be6f21d3ef3`.
  `vendor_boot`, initramfs, vbmeta, kernel ejecutable y SD no cambian.
- ZIP v0.4:
  `postmarketos-edge-xfce-mainline-v0.4-sm-x910-twrp.zip`, 21.884.702 bytes,
  SHA-256
  `2083daf1ad515b32634a8f5686adc4972064ff8fd03153da0e6654d49f97a679`.
  Pasó headers, AVB, tamaños, comparaciones, CRC, manifests y zstd; se reprodujo
  byte a byte, se copió a `/sdcard/` y se verificó allí. La tablet sigue en
  TWRP y el asistente no lo ha flasheado.
