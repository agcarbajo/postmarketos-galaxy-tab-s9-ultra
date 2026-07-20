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

## 2026-07-18 — sesión 8: Linux ejecuta, fatal NoC y bundle v0.5

- La usuaria flasheó v0.4. Por primera vez aparecieron la consola verbose y el
  logo de Linux; después la tablet se reinició. Esto valida físicamente la ruta
  appended-DTB y demuestra que ABL ya entrega el control al kernel mainline.
- De vuelta en TWRP se recogieron `/proc/last_kmsg`, `/proc/cmdline`, dmesg y
  pstore en `work/v04-linux-crash-20260718/`. Pstore estaba vacío.
  `/proc/last_kmsg` contiene el diagnóstico del siguiente XBL, que registra
  reset por PSHOLD, `restart_reason = 0x5023881` y
  `upload_cause = TZBSP_ERR_FATAL_NOC_ERROR`. La sección con información NoC,
  XPU y SMMU indica que el log TZ está cifrado, por lo que no revela
  maestro/esclavo, dirección o driver causante.
- Se descartó tratarlo como un panic ordinario o un fallo ABL. La salida Linux
  llegó a pantalla y el reset fue solicitado por firmware seguro; todavía no
  hay evidencia de que se montase la raíz de la microSD.
- Se compararon con `fdtget` todos los rangos de `/reserved-memory` del FDT vivo
  y del DTB mainline. El dtsi upstream cubría la mayoría de carveouts Qualcomm,
  pero el DTB v0.4 omitía los que normalmente añade la DTBO Samsung:
  `kaslr`, `uh_heap`, `uh_guest`, `chipinfo`, `sec_xbl_ramdump`, LLCC LPI y los
  rangos altos `sec_debug_pool`, reset info, debug BL, pmsg, debug kinfo, HDM y
  `sec_qcom_rdx`. En RAM alta sólo se había conservado `sec_log_buf` para
  ramoops; aproximadamente 180 MiB protegidos quedaban disponibles para el
  buddy allocator. También el HW-fence upstream era `0x64000` bytes menor que
  el rango X910.
- Hipótesis mínima v0.5: un acceso normal de Linux a esos rangos protegidos
  provoca el fatal NoC. Se añadieron las reservas fijas exactas del FDT vivo,
  todas `no-map` salvo el carveout ramoops, y se amplió HW-fence. No se cambió
  USB, Goodix, SD, cmdline, kernel ejecutable, initramfs ni rootfs, para aislar
  el efecto del mapa de memoria.
- El DTS compila sin errores. DTB final: 152.392 bytes, SHA-256
  `78397ab9c916084a68b37a5b19de2d1cd2619691201552f1ecc60a483ab44cd0`.
  El validador extrae el DTB de `vendor_boot` y exige los 15 rangos exactos,
  además de símbolos y selectores ABL.
- Imágenes modificadas: `boot.img`
  `384cdf879ed81f053cf3aeab4795f1d80b87f21c6692cbd4faeecfb58fe41af6`
  y `vendor_boot.img`
  `80fbd52d4e3d03f37a08d2cf90ce7eda44d94864cb4653151d4680dd4c525e63`.
  `dtbo`, `init_boot`, `vbmeta`, payload gzip y la imagen SD no cambiaron.
- ZIP v0.5:
  `postmarketos-edge-xfce-mainline-v0.5-sm-x910-twrp.zip`, 21.885.945 bytes,
  SHA-256
  `1ae10d4effba444a3d970e9c6a68bd11f9304692a7bffcf309633b9063388314`.
  Pasó AVB, headers v4, offsets, appended-DTB, carveouts, tamaños, CRC, modos,
  manifests y zstd; una segunda generación fue idéntica byte a byte. Se copió
  a `/sdcard/` y se verificó el mismo hash en TWRP. El asistente no lo flasheó.

## 2026-07-18 — sesión 9: vídeo v0.5, LPASS AG NOC y bundle v0.6

- La usuaria probó v0.5 y grabó `C:/Users/agcar/Downloads/20260718_033322.mp4`.
  Linux volvió a mostrar verbose/logo y reinició. Desde TWRP se recogieron
  `work/v05-linux-crash-20260718/last_kmsg`, dmesg, iomem y pstore. El reset es
  de nuevo `TZBSP_ERR_FATAL_NOC_ERROR`, ahora con
  `restart_reason = 0x5023a01`; pstore continúa vacío. Los carveouts v0.5 se
  mantienen por corrección, pero no eran el desencadenante inmediato.
- Se extrajeron fotogramas a 2 fps y capturas originales de los últimos
  segundos. El último frame legible antes de apagarse muestra a `26.772 s` el
  retorno correcto de `7400000.interconnect` y `7430000.interconnect`.
  Según el orden de `sm8550.dtsi`, el siguiente proveedor es
  `lpass_ag_noc: interconnect@7e40000`; no aparece su línea de retorno.
- La hipótesis v0.6 deshabilita únicamente `lpass_ag_noc`. Audio no es necesario
  para el primer rootfs/SSH y los otros dos NOC LPASS quedan activos porque el
  vídeo demuestra que sus probes terminan. Si v0.6 avanza, habrá que reconstruir
  la secuencia de alimentación específica X910 antes de reactivarlo.
- TWRP no expone el ramoops mainline porque recovery arranca con otro DTB y no
  registra ese backend. Se estudió el driver downstream `sec_log_buf`: usa una
  cabecera de 16 bytes (`boot_cnt`, magia `0x4d474f4c`/`LOGM`, `idx`,
  `prev_idx`) y un ring que recovery presenta como `/proc/last_kmsg`.
- Se añadió un driver built-in mínimo
  `SAMSUNG_GTS9UWIFI_SEC_LOG`: mapea el carveout real `0x880200000/2 MiB`,
  inicializa la cabecera compatible, registra una consola con
  `CON_PRINTBUFFER` y conserva el índice circular. El DTB sustituye el backend
  ramoops por `sec-log@880200000` y el nodo `sec-kernel-log`. Así, un próximo
  fatal temprano debería dejar printk recuperable desde TWRP.
- La build directa compiló el nuevo objeto y confirmó la opción, el texto del
  driver y `status = "disabled"` en `7e40000`. Después se reconstruyó mediante
  pmbootstrap el APK completo `linux-samsung-gts9uwifi-mainline-7.2_rc3-r4`,
  la rootfs y los initramfs, evitando mezclar el kernel directo con módulos
  anteriores. Kernel release y vermagic son `7.2.0-rc3`.
- Payload gzip empaquetado: SHA-256
  `34d1de801785b7bdab795f596ccebfd393557d3cd991af97307e40303c25f0a8`.
  DTB empaquetado: SHA-256
  `61b0bc560ad8f62f2aa06cb48bfe20cfdeff62678b8e43655b3434c268528081`.
  Initramfs: 2.134.007 bytes; `initramfs-extra`: 13.014.904 bytes.
- Imagen SD v0.6:
  `postmarketos-edge-xfce-mainline-v0.6-sm-x910-sd.img.zst`, 472.948.641
  bytes, SHA-256
  `6250db18ed8afaad2afd8d98dad376305fccefa0518be806c3cf08af0791939e`.
  Descomprimida mide 4.634.705.920 bytes y tiene SHA-256
  `62704236c7faa4b819a19751eefb32dfdafbf6151ce834738ac5a4d3d191a759`.
- ZIP TWRP v0.6:
  `postmarketos-edge-xfce-mainline-v0.6-sm-x910-twrp.zip`, 21.883.967 bytes,
  SHA-256
  `0890bbe1160aa5b03d40963209ae2a5193d7857531ee2518f0adbaf522d31a9a`.
  Bundle, AVB, DTB/status, consola persistente, tamaños, CRC, manifests y zstd
  pasaron. ZIP e imagen SD se reprodujeron byte a byte. El ZIP se copió y
  verificó en `/sdcard`; el asistente no flasheó nada.

## 2026-07-18 — sesión 10: `last_kmsg` mainline completo y traza pre-probe v0.7

- La usuaria probó v0.6 y la tablet volvió a reiniciarse. Se recogieron desde
  TWRP `last_kmsg`, cmdline, dmesg, iomem e índice pstore en
  `work/v06-linux-crash-20260718/`. El reset sigue siendo
  `TZBSP_ERR_FATAL_NOC_ERROR`, con `restart_reason = 0x58238a1`.
- La consola Samsung `LOGM` introducida en v0.6 funcionó: `/proc/last_kmsg`
  mide 453.717 bytes y contiene el printk mainline completo, desde la versión
  del kernel hasta el instante exacto anterior al firmware/XBL siguiente.
  Pstore continúa vacío, pero ya no es necesario y no harán falta vídeos en
  pruebas normales mientras se conserve este backend.
- Deshabilitar `lpass_ag_noc@7e40000` no cambió el punto visible del corte. En
  deferred probe terminan correctamente `7400000.interconnect` a 26,806 s y
  `7430000.interconnect` a 26,813 s; no se registra ningún retorno posterior.
  Por tanto la hipótesis v0.6 queda descartada y el nodo permanece aislado sólo
  por prudencia mientras el audio está fuera del primer hito.
- `8804000.mmc` había devuelto `-EPROBE_DEFER` a 23,698 s. Por el orden del DT
  su reintento después de los proveedores interconnect es el candidato
  principal, pero una línea de retorno no demuestra qué probe empieza después.
- Se añadió `log-probe-entry-before-call.patch`: con `initcall_debug`,
  `really_probe_debug()` imprime `probing <device> with driver <driver>` antes
  de entrar en `->probe()`. La consola persistente escribe esa línea de forma
  síncrona, por lo que debe sobrevivir aunque TrustZone reinicie dentro del
  driver. `pkgrel` queda en 5 y el script de build directo aplica el parche.
- Para reducir desgaste y tiempo de prueba, v0.7 reutiliza el DTB, initramfs,
  release y módulos de la SD v0.6; sólo sustituye el ejecutable built-in del
  kernel. No hay cambios de símbolos, configuración ni ABI de módulos.
- El bundle Android v4 v0.7 pasó hashes internos, tamaños exactos, headers,
  appended-DTB y verificación AVB. ZIP reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.7-probe-trace-sm-x910-twrp.zip`,
  22.012.743 bytes, SHA-256
  `1362e7f9ecf4cedd082af4cbabb963a651215292a7bcd847007978bf5bd3c2be`.
  Se copió a `/sdcard` y su hash remoto coincide. El asistente no lo flasheó.

- El arranque físico v0.7 produjo un `last_kmsg` de 453.927 bytes. La última
  entrada mainline, inmediatamente después del retorno correcto de
  `7430000.interconnect`, es `probing f100000.pinctrl with driver sm8550-tlmm`;
  no aparece su retorno. El siguiente firmware registra
  `restart_reason = 0x5003a01` y `TZBSP_ERR_FATAL_NOC_ERROR`. Se descarta así
  `8804000.mmc` como causante de este reset.
- El primer intento de TLMM a 6,016 s había devuelto `-EPROBE_DEFER`; el fatal
  sucede al reintentarlo cuando ya existe el dominio wakeup/PDC. El FDT vivo
  Samsung describe el TLMM downstream en `0xf000000` y, de forma decisiva,
  marca `qcom,gpios-reserved = <36 37 38 39>`. El desplazamiento de base no es
  por sí mismo un error: el driver mainline parte de `0xf100000` y usa offsets
  por GPIO equivalentes. La reserva segura sí faltaba.
- Se añadió a `&tlmm` la propiedad estándar mainline
  `gpio-reserved-ranges = <36 4>`. Es el equivalente exacto de la X910 y evita
  que gpiolib/irqchip acceda a registros TLMM propiedad de TrustZone. No se
  copiaron GPIO50–51 del Fold5, ausentes en la evidencia de nuestra placa.
- DTB v0.8: SHA-256
  `e3c872e9eae8865d4ff8f5b6871d896ef60261ff73556475e522ac48c298ed66`.
  El kernel instrumentado, initramfs, módulos y SD siguen siendo los de v0.7/
  v0.6; sólo cambia el DTB appended y su copia en vendor_boot.
- ZIP v0.8 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.8-tlmm-reserved-sm-x910-twrp.zip`,
  22.012.795 bytes, SHA-256
  `74607d30076c92cc7fcae787534e26d9ea083a4da60280c551e0a75e87788c92`.
  Se verificó estática y remotamente en `/sdcard`; el asistente no lo flasheó.

## 2026-07-18 — sesión 11: v0.8 supera TrustZone y logger robusto v0.9

- El arranque v0.8 dejó de reiniciarse por firmware. La tablet permaneció en
  una pantalla de kernel panic hasta que la usuaria la reinició manualmente a
  TWRP. La reserva `gpio-reserved-ranges = <36 4>` queda validada físicamente:
  el registro de TLMM ya no dispara el fatal NoC de TrustZone.
- Se recogió `work/v08-linux-panic-20260718/last_kmsg`, pero mide exactamente
  2.097.136 bytes y contiene el ring circular del recovery anterior, no el
  boot mainline. Pstore sigue vacío y TWRP no dispone de `/dev/mem`.
- Causa del fallo de captura: el logger mainline ponía `previous_index` al
  valor antiguo al iniciar y después sólo avanzaba `index`. Un reset fatal
  gestionado por firmware actualizaba la instantánea, como en v0.6/v0.7, pero
  el reinicio manual desde el panic no pasó por esa ruta. Recovery interpretó
  el índice anterior y expuso la sesión vieja.
- `keep-sec-log-previous-index-current.patch` hace avanzar `previous_index`
  junto a `index` en cada escritura. No cambia el formato ni el tamaño del
  ring; permite que `/proc/last_kmsg` conserve el stream mainline tras un
  reinicio manual. `pkgrel` sube a 6.
- Kernel v0.9 `Image.gz`: SHA-256
  `811de097a805e6008795f34803c3877a3505aa96a53624ae8c754664072c6f57`.
  DTB permanece en
  `e3c872e9eae8865d4ff8f5b6871d896ef60261ff73556475e522ac48c298ed66`;
  initramfs, módulos y SD v0.6 no cambian.
- ZIP v0.9 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.9-panic-log-sm-x910-twrp.zip`,
  22.012.505 bytes, SHA-256
  `e7a2d8b3264cc94cdf6863d8abdbbd5c90e6515d1c4577b4f3fd3651fd680375`.
  Se validó y copió a `/sdcard`; el asistente no lo flasheó.
- La primera prueba física de v0.9 volvió a terminar en el mismo panic visible.
  Al recoger `/proc/last_kmsg`, el recovery llevaba 1.026 s arrancado y el
  fichero ocupaba los 2.097.136 bytes máximos. Sólo contenía printk downstream
  del TWRP actual: en esos 17 minutos el recovery había escrito una vuelta
  completa al ring y sobrescrito el boot anterior. Esto no refuta el arreglo
  de índices; impone recuperar el fichero inmediatamente. Se repetirá v0.9 sin
  reflashear ni reescribir la SD.
- La repetición se capturó con sólo 146 s de TWRP, pero tampoco contiene el
  mainline. Entre ambas sesiones aparece `XBL(28, restored from storage)` y
  después arranca directamente el kernel 5.15 Foldiby de recovery. Esto prueba
  que el reinicio forzado desde la pantalla de panic restaura el log antiguo
  persistido por XBL; el contenido mainline se pierde antes de TWRP.
- Se contrastó el formato con el driver Samsung moderno
  `sec_log_buf_main.c`/`sec_log_buf_last_kmsg.c`: recovery copia el ring según
  `idx` durante su probe y sólo después empieza a registrar su propio printk.
  `prev_idx` no selecciona la instantánea en este driver. La estrategia debe
  conservar físicamente la RAM, no seguir ajustando el lector.
- v0.10 cambia sólo cmdline: elimina `initcall_debug`, usa `loglevel=7` y añade
  `panic=10`. Así el log mainline es mucho menor y el kernel reinicia en
  caliente diez segundos después del panic. La usuaria podrá interceptar ese
  reinicio para entrar en TWRP sin el reset forzado que activa la restauración
  de XBL.
- ZIP v0.10 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.10-auto-panic-sm-x910-twrp.zip`,
  22.012.502 bytes, SHA-256
  `47331b9616f68048f381b61d52e9a6e1ff74f3ab35dcb46addae5d39e7ae372a`.
  Se validó y copió a `/sdcard`; el asistente no lo flasheó.

## 2026-07-18 — sesión 12: v0.10, falsa apariencia de panic y canal USB fallido

- La prueba física v0.10 y su repetición no conservaron el printk mainline.
  Las capturas inmediatas `work/v010-linux-panic-warm-20260718/last_kmsg` y
  `work/v010-return-20260718-174922/last_kmsg` miden 2.097.136 bytes, contienen
  `XBL(... restored from storage)` y sólo el ring recovery/XBL antiguo. El
  reinicio automático o normal tampoco proporciona el canal persistente que
  se esperaba; no se seguirá iterando sobre los índices LOGM.
- Se desempaquetó íntegro el initramfs pmOS v0.10. `/init` busca durante 30 s
  la etiqueta `pmOS_boot`, monta esa partición, extrae `initramfs-extra` y pasa
  a `/init_2nd.sh`; no depende de un parámetro `root=` en la cmdline.
- La función `fail_halt_boot()` no llama a panic. Crea un FAT de 32 MiB con
  `pmOS_init.txt`, `dmesg.txt`, `blkid.txt`, `partitions.txt`, cmdline y FDT;
  intenta exponerlo como `PMOS_LOGS`, entra en `debug_shell()` y después
  duerme indefinidamente. Por tanto la pantalla que se describió como kernel
  panic puede ser realmente el error/halt del initramfs y `panic=10` no puede
  reiniciarlo.
- La shell diagnóstica también ofrece ACM `ttyGS0` o telnet sin contraseña en
  `172.16.42.1:23`, con DHCP para el host en `172.16.42.2`.
- Se reutilizó v0.10 sin flashear y se reinició por ADB desde TWRP. Durante más
  de 80 s Windows no detectó el volumen `PMOS_LOGS`, puerto serie, NCM/RNDIS ni
  interfaz en `172.16.42.0/24`. Aparecieron dos dispositivos USB desconocidos
  con error de solicitud de descriptor: el enlace tiene actividad parcial,
  pero el gadget mainline no ofrece aún un canal utilizable.
- Próximo paso: leer una foto fija de la pantalla detenida. Si no contiene el
  error suficiente, construir una v0.11 que muestre un resumen compacto de
  `/pmOS_init.log` y lo copie a `pmOS_boot` cuando la SD sea visible. La primera
  decisión será si `sdhc_2` no enumera o si el fallo ocurre después de montar
  boot/root; no se tocará hardware sin esa evidencia.

## 2026-07-18 — sesión 13: panic transcrito, microSD validada y bundle v0.11

- La foto fija `codex-clipboard-833caf54-71b2-45e3-aea4-305fa3c40946.webp`
  permitió ampliar el final completo. Corrige la hipótesis de la sesión 12:
  v0.10 no llega a `fail_halt_boot()` ni ejecuta `/init`; es un panic real del
  kernel al no poder desempaquetar el initramfs.
- La secuencia exacta visible es `Initramfs unpacking failed: invalid magic at
  start of compressed archive`, `Waiting for root device...`,
  `/dev/root: Can't open blockdev`, `VFS: Cannot open root device "(null)" or
  unknown-block(0,0): error -6` y la petición de una opción `root=`. Sin
  initramfs ejecutable y sin `root=` deliberadamente, el panic es consecuencia
  directa.
- Antes del fallo, el kernel enumera la tarjeta como `mmcblk1` y lista
  `mmcblk1p1`/`mmcblk1p2`. Esto valida por primera vez en hardware mainline
  SDHC2, pinctrl, reguladores, card-detect y el acceso inicial a la microSD.
- Desde TWRP se verificó que `p1` es ext2 `pmOS_boot`, `p2` es ext4
  `pmOS_root`, y recovery monta `p1`. `e2fsck -fn` completa las cinco pasadas
  de boot; el e2fsck antiguo de TWRP no entiende `FEATURE_C12` de root, pero
  su superbloque figura limpio. No se alteró la tarjeta.
- Se extrajo el ramdisk real de `init_boot` v0.10: gzip válido de 2.134.007
  bytes, CPIO válido de 7.168.248 bytes con `/init` y mkinitfs completo. El
  config empaquetado tiene `CONFIG_BLK_DEV_INITRD=y` y todos los `CONFIG_RD_*`,
  así que no se trata de un CPIO truncado ni de omitir el descompresor.
- La comparación con X910XXS5CYG1 muestra que Samsung usa LZ4 legacy, magia
  `02 21 4c 18`, tanto en `init_boot` (1.747.596 bytes) como en el vendor
  ramdisk (13.495.656 bytes). v0.10 combinaba vendor LZ4 con generic gzip; ABL
  entrega esa composición en una forma que mainline rechaza antes de PID 1.
- `build-android-v4-bundle.sh` recomprime ahora por defecto el mismo CPIO pmOS
  a LZ4 legacy. `validate-android-v4-bundle.sh` exige la magia stock, verifica
  LZ4 y compara el stream descomprimido contra el gzip pmOS original. No cambia
  ningún fichero interno del initramfs.
- El LZ4 resultante mide 2.410.662 bytes. `init_boot.img` v0.11 tiene SHA-256
  `bedcad22a49dbf442641dcaf13e3290edd87b221cbca6fb8f47b8f2460c16922`;
  `boot`, `vendor_boot`, `dtbo` y `vbmeta` son idénticos a v0.10.
- ZIP v0.11:
  `postmarketos-edge-xfce-mainline-v0.11-lz4-initramfs-sm-x910-twrp.zip`,
  21.988.029 bytes, SHA-256
  `9cdc1bdd4d6be730a3b64fd66c5413794889f6cc1c0fcc25ea1977604a3713f1`.
  Pasó dos generaciones idénticas, hashes internos, tamaños Android v4, AVB,
  appended-DTB, reservas TLMM/memoria, CRC y comparación íntegra del CPIO. Se
  copió a `/sdcard` y el hash remoto coincide; el asistente no lo flasheó.

## 2026-07-18 — sesión 14: primer login gráfico mainline y bloqueo USB

- La usuaria flasheó v0.11 y confirmó el primer arranque completo. La tablet
  ejecuta el initramfs LZ4, monta `pmOS_boot`/`pmOS_root`, arranca systemd y
  presenta el login de LightDM/XFCE4 para `phablet`. Simpledrm mantiene el
  framebuffer a resolución completa. Se validan así kernel, SD, initramfs,
  rootfs y escritorio ligero en hardware real.
- Buffyboard aparece como teclado en pantalla, pero el Goodix GT9916 todavía
  no produce entrada, de modo que no se puede iniciar sesión localmente.
- Con la tablet viva y conectada se inventariaron PnP, adaptadores, DHCP, ARP,
  ICMP y TCP/22. No aparece ACM, NCM/RNDIS ni una interfaz `172.16.42.0/24`;
  `172.16.42.1` no responde y Windows conserva dos dispositivos desconocidos
  con error al solicitar descriptor. No existe aún un canal SSH.
- La foto anterior del verbose contiene la causa temprana de ese síntoma:
  DWC3 registra `-ETIMEDOUT: failed to initialize core`. El DTS actual habilita
  sólo `usb_1_hsphy`, elimina el superspeed y fuerza peripheral/HS, pero no
  modela el repetidor físico NXP; confiaba experimentalmente en el estado de
  ABL.
- El FDT vivo X910 confirma el repetidor `nxp,eusb2-repeater` en I2C `0x4f`,
  rails `vdd18`/`vdd3`, reset PM8550VS GPIO4 y overrides
  `<0x20 0x06 0x21 0x07 0x63 0x08 0x01 0x0a>`. La PHY eUSB2 stock lo referencia
  como `usb-repeater`.
- En esta primera revisión se creyó que Linux 7.2-rc3 no tenía soporte para el
  NXP I2C y se planteó portar la secuencia Samsung. La auditoría completa de la
  sesión siguiente encontró el driver upstream exacto `phy-nxp-ptn3222`, por
  lo que esta hipótesis queda corregida y no se creará un driver local.
- Al cierre de esa sesión quedaban pendientes los logs persistentes y el
  soporte del repetidor; ambos se investigan y corrigen en la sesión siguiente.

## 2026-07-19 — sesión 15: journal v0.11 y bundle USB/táctil v0.12

- Con la tablet de nuevo en TWRP se montó `/dev/block/mmcblk1p2` como ext4
  `ro,norecovery` en `/tmp/pmos-root`. Se extrajo sin modificar la tarjeta el
  journal persistente de systemd, de 8 MiB, a
  `work/v011-rootfs-logs-20260719/` y se convirtió a texto.
- El journal fija el fallo USB: `dwc3-qcom a600000.usb: DWC3 controller soft
  reset failed`, seguido de `error -ETIMEDOUT: failed to initialize core` y
  fallo de probe `-110`. DWC3 nunca registra el gadget, lo que explica los
  descriptores fallidos del host y la ausencia de NCM/SSH.
- El mismo journal fija el bloqueo del táctil: `a90000.i2c` termina en deferred
  probe con `geni_i2c: Failed to get tx DMA ch`. `CONFIG_QCOM_GPI_DMA` era
  módulo; I2C4 e I2C6 dependen ambos de `gpi_dma1`, así que no podían alcanzar
  Goodix ni el repetidor durante el arranque. Tampoco existía `/dev/input`.
- La revisión completa de Linux 7.2-rc3 encontró
  `drivers/phy/phy-nxp-ptn3222.c` y el binding
  `Documentation/devicetree/bindings/phy/nxp,ptn3222.yaml`. Es exactamente un
  proveedor PHY con `vdd3v3`, `vdd1v8` y reset GPIO, y upstream lo encadena al
  HS PHY mediante `phys`; no hace falta portar el framework Samsung.
- Del FDT stock X910 se trasladaron sólo datos contrastados: PTN3222 en I2C6
  `0x4f`, PM8550B LDO5 a 3.104 V, PM8550B LDO15 a 1.8 V y reset
  PM8550VS-D GPIO4 activo-bajo. `usb_1_hsphy` referencia el repetidor; DWC3
  continúa deliberadamente en peripheral/high-speed.
- El primer DTS de prueba referenció `gpi_dma0`, etiqueta inexistente en el
  `sm8550.dtsi`, y la compilación falló. La inspección de las DMA de I2C4/I2C6
  confirmó que ambas pertenecen a `gpi_dma1`; se eliminó la referencia errónea
  y la siguiente build terminó correctamente.
- El fragmento r7 integra `CONFIG_QCOM_GPI_DMA=y`,
  `CONFIG_PHY_NXP_PTN3222=y`, `CONFIG_INPUT_UINPUT=y` y `CONFIG_UHID=y`.
  `Image.gz` resultante: SHA-256
  `195608d3dcb49c896e48f57510bf65327190be4939c8e1995d119375b803443c`;
  DTB: `6f5fb0944a3438a48c09a8deaec2540c862b4fa11970595c806fb5b1337467ea`;
  config: `e29bca4b34e4137d4341036a7d161ee644a5dcc4f83f8a804b4e1d72242a41d0`.
- El validador Android v4 exige ahora los cuatro built-ins, GPI DMA activo,
  I2C4/I2C6 activos a 400 kHz, PTN3222 con `#phy-cells = 0`, GPIO4
  activo-bajo, phandle enlazado desde la HS PHY y DWC3 peripheral/HS. La
  primera ejecución del validador usó la ruta equivocada `usb@a6f8800` y
  falló de forma segura; el nodo SM8550 real es `usb@a600000` y se corrigió.
- ZIP v0.12:
  `postmarketos-edge-xfce-mainline-v0.12-usb-touch-sm-x910-twrp.zip`,
  22.009.191 bytes, SHA-256
  `bf8067a1eb652b0154b8c8614ce254720a94cce96b428f465371890eb01fa5f2`.
  Dos ejecuciones produjeron exactamente el mismo ZIP. Pasó headers Android
  v4, LZ4 legacy, hashes internos, appended-DTB, AVB y las nuevas aserciones
  de hardware. Se copió a `/sdcard` y `sha256sum` allí coincide. El asistente
  no flasheó ninguna partición.
- Reto inmediato: prueba física v0.12. Si USB enumera, entrar por NCM/SSH y
  comprobar `dmesg`, `ip`, el gadget y `libinput`; en paralelo verificar si el
  GT9916 crea `/dev/input/event*`. Si falla, el journal de la SD permitirá
  separar init del PTN3222, DWC3 y firmware Goodix sin depender de vídeo.

## 2026-07-19 — sesión 16: resultado físico inicial v0.12

- La usuaria flasheó v0.12. El sistema sigue alcanzando LightDM/XFCE mediante
  simpledrm, pero el táctil no responde; por tanto integrar `gpi_dma1` no basta
  por sí solo para exponer el GT9916.
- Con la tablet encendida, Windows no presenta ADB, ACM, NCM/RNDIS ni un nuevo
  adaptador IPv4. Permanecen dos dispositivos USB desconocidos por error de
  descriptor, el mismo síntoma externo de v0.11, y `172.16.42.1:22` no
  responde. El soporte inicial upstream del PTN3222 no ha resuelto por sí solo
  el enlace físico.
- Un barrido concurrente de `<LAN_SUBNET>` encontró SSH en `.138` y `.150`.
  La usuaria confirmó posteriormente que `.138` es otro dispositivo pmOS de
  la red y debe ignorarse; `.150` también es otro equipo. No se obtuvo canal
  remoto atribuible a la tablet.
- Próximo paso obligatorio: volver a TWRP, montar `mmcblk1p2` en sólo lectura
  y extraer el journal de este arranque. Se compararán registro/deferred probe
  de `gpi_dma1`, I2C4/I2C6, PTN3222, DWC3, firmware Goodix y `/dev/input` antes
  de preparar v0.13.

## 2026-07-19 — sesión 17: journal v0.12 y correcciones Goodix/PTN3222 v0.13

- Con la tablet en TWRP se montó `/dev/block/mmcblk1p2` exclusivamente como
  `ro,norecovery` en `/tmp/pmos-root`. Se extrajeron el journal persistente,
  Xorg y los logs de boot/LightDM a `work/v012-rootfs-logs-20260719/`; el
  journal original tiene SHA-256
  `be7e7a159b56d06874a7360310c73d6a42578749a76aaa33cd0aafb53d595794`.
  La partición se desmontó después sin modificar el rootfs.
- El boot v0.12 demuestra que el arreglo GPI DMA funcionó. A 1,628 s aparece
  `Goodix Berlin Capacitive TouchScreen` en
  `a90000.i2c/i2c-4/4-005d/input/input0`. Inmediatamente, cada evento real se
  rechaza con `touch data checksum error`; el fallo ya no es I2C, DMA, probe
  ni firmware.
- `goodix_berlin_core.c` obtiene `point_struct_len` desde `IC_INFO`, pero el
  parser upstream usaba ocho bytes constantes. El driver Samsung GT6936 de
  referencia usa cabecera de ocho, puntos de 16 y checksum sobre
  `event_num * 16 + 2`; también codifica ID/acción y coordenadas en un layout
  distinto. Se creó el parche trazable
  `support-samsung-goodix-16-byte-events.patch`, que selecciona el formato de
  8/16 bytes dinámicamente y mantiene compatibilidad con el upstream normal.
- El primer parche unificado escrito manualmente tenía conteos de hunk
  incorrectos. `git apply --check` lo detectó antes de compilar; se corrigió y
  la versión final aplica limpiamente sobre Linux mainline sin modificar.
- El DT activo stock publica `sec,max_coords = <1848 2960>`, no 1080×2400.
  El DTS r8 usa esas dimensiones y conserva `touchscreen-swapped-x-y`.
  Además se encontró `CONFIG_INPUT_EVDEV=m`: en la build directa sin módulos
  explicaba que no hubiera `/dev/input/event*` aunque existiera `input0`.
  Desde v0.13 `CONFIG_INPUT_EVDEV=y`.
- Para USB, el journal v0.12 muestra la cadena exacta de deferred probe:
  `a600000.usb` espera a `88e3000.phy`, que espera al PTN3222 `1-004f`.
  Antes aparece `qcom-spmi-gpio ... gpio@8800: pin_config_group_set op failed
  for group 3`. El DTS usaba `drive-strength = <2>`, propiedad no aceptada por
  el pinctrl SPMI Qualcomm. Se reprodujo el FDT stock del reset PM8550VS-D
  GPIO4: función normal, entrada y salida habilitadas, push-pull, bias
  deshabilitado, `power-source = <1>` y `qcom,drive-strength` medio.
- Una primera generación etiquetada v0.13 se completó antes de descubrir que
  EVDEV seguía como módulo. Su SHA empezaba por `501cc`; se descartó, no se
  copió a la tablet y no debe probarse. Después se recompiló kernel, DTB y
  bundle con EVDEV built-in. Una ejecución de build agotó el tiempo del runner
  cuando los outputs ya estaban completos; los hashes y las dos ejecuciones
  finales del empaquetado validaron esos outputs.
- Build directa final: `Image.gz` SHA-256
  `7cd3f980dab521874823d2a066b616cbfe39f13e6309c39ed0aa06a2b88f5c8b`;
  DTB `f38a0cfd5f5ed3430f210b2c8533f836871038992ee7b318f28577e1ca74a60f`;
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
  La compilación incluye `goodix_berlin_core.o` y `drivers/input/evdev.o`.
- El validador exige ahora `CONFIG_INPUT_EVDEV=y`, descomprime el Image
  empaquetado y localiza la cadena diagnóstica del parche, valida 1848×2960 y
  el intercambio de ejes, y comprueba todas las propiedades del reset PTN3222
  además de la cadena USB ya existente.
- ZIP final v0.13:
  `postmarketos-edge-xfce-mainline-v0.13-goodix-ptn-reset-sm-x910-twrp.zip`,
  22.018.623 bytes, SHA-256
  `c69e7b53db8e176eca2396fea4137e26c1ccdf6e8dce8fab1f166ca8e74a0b98`.
  Hashes internos: boot
  `b0c717000339e410f31a897bee511be162276345d8e4fbc294a8a95a3c4e27ca`,
  vendor_boot
  `10063d103778eb260a4558dac952862988e6e5b6edc45f5502e17ffc40b6aeba`.
  Dos generaciones finales fueron idénticas y el hash del ZIP copiado a
  `/sdcard` coincide. El asistente no flasheó ninguna partición.
- Reto inmediato: flashear manualmente v0.13, probar táctil en LightDM y
  observar la enumeración USB. Si NCM/RNDIS aparece, conectar por SSH y
  verificar en vivo eventos Goodix, PTN3222/DWC3 y estado de red.

## 2026-07-19 — sesión 18: resultado físico inicial v0.13

- La usuaria flasheó v0.13. El sistema vuelve a alcanzar LightDM, pero el
  táctil continúa sin producir entrada utilizable.
- El host no detecta ADB, ACM ni una interfaz NCM/RNDIS. Siguen presentes dos
  dispositivos USB desconocidos con error de solicitud de descriptor y
  `172.16.42.1:22` no responde; por tanto todavía no existe SSH sobre USB.
- Se sondeó en paralelo el puerto 22 de `<LAN_SUBNET>`, excluyendo el propio
  host, `.138` y `.150`. La usuaria confirmó que `.138` es otro dispositivo
  pmOS y `.150` ya estaba identificado como otro equipo; no apareció ningún
  endpoint SSH nuevo atribuible a la tablet.
- No se introducen nuevas correcciones a ciegas. El próximo paso es volver a
  TWRP y extraer en sólo lectura el journal v0.13 para comprobar el layout
  Goodix registrado, checksum, EVDEV/libinput y la cadena PTN3222/DWC3.

## 2026-07-19 — sesión 19: journal v0.13 y bundle v0.14

- En TWRP se montó `/dev/block/mmcblk1p2` como `ro,norecovery`, se extrajeron
  ambos journals persistentes, Xorg, boot y LightDM a
  `work/v013-rootfs-logs-20260719/`, y se desmontó la raíz. El journal actual
  tiene SHA-256
  `e4d2d9a437b122c83360653cfe926e20c29c9e8f5e9e8d7eb9a3343d7bd2c51a`;
  la operación no escribió en la microSD.
- El boot v0.13 (`f9385ea3b0d042f09f326ed2761c12b8`) registra Goodix a
  1,623 s y muestra `Goodix Berlin 6936 ... event layout 8/8`. A continuación
  todos los eventos reales fallan checksum. Los dumps de un contacto tienen
  10 bytes y los de dos contactos 18 porque el parser toma los bytes 8–9 o
  16–17 como checksum, aunque son todavía datos del registro Samsung; esto
  explica exactamente por qué el parche dinámico v0.13 no se activó.
- El driver Samsung no usa el `point_struct_len` leído de IC_INFO para eventos:
  fija `BYTES_PER_POINT=16`, checksum sobre `event_num * 16 + 2` y el layout
  de coordenadas ya portado. Se corrigió la hipótesis anterior: este firmware
  6936 anuncia ocho de forma incorrecta. El parche r9 fuerza 16 únicamente
  cuando el PID es `6936`, conservando ocho para firmware upstream normal.
- EVDEV está built-in y `input0` se registra; no hay evidencia de que Xorg o
  libinput sean la barrera primaria mientras todos los IRQ se descarten antes
  de reportar eventos. Los avisos de systemd intentando cargar `uinput` y
  `uhid` como módulos son secundarios porque se compilaron built-in.
- Para USB, desapareció por completo el fallo de pinctrl y ya no hay deferred
  probe del PTN3222. DWC3 alcanza el sondeo a 2,098 s, pero su soft reset no
  termina y acaba en `-ETIMEDOUT/-110`. El arreglo de GPIO de v0.13 fue por
  tanto correcto pero insuficiente.
- La comparación del driver mainline `phy-nxp-ptn3222.c` con el FDT/log vivo
  Samsung encontró la diferencia restante: mainline sólo habilita rails y
  quita reset. Samsung espera unos 4 ms, lee la versión `0xa2` y escribe cuatro
  overrides: valor `20` en registro `06`, `21` en `07`, `63` en `08` y `01`
  en `0a`. El FDT los publica como
  `qcom,param-override-seq=<20 06 21 07 63 08 01 0a>`.
- Se añadió `configure-nxp-ptn3222-from-dt.patch`: crea regmap I2C, valida una
  secuencia par acotada, espera 4–5 ms tras reset, escribe pares valor/registro
  y revierte rails/reset si falla. El DTS r9 reproduce la secuencia stock. El
  validador exige tanto la cadena compilada como los ocho valores del DTB.
- Los dos parches aplicaron limpiamente sobre un worktree 7.2-rc3 nuevo. La
  primera invocación de build fue cortada por el límite del runner a 124 s sin
  error de compilación; la segunda reutilizó los objetos parciales y terminó
  el enlace limpio en 439 s. No se aceptaron outputs hasta que terminó.
- Build directa v0.14: `Image.gz` SHA-256
  `c02c47ffca3e4d6eb5d9f7cae2a1cb5f1c3994dc5dc25b2c0ec54908979b5952`;
  DTB `454a804c38c6a3e5ea0406419f65c0adcc1c8d477dea50fb2b79e51d1f430d07`;
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
  El Image contiene los mensajes de Goodix forzado y overrides PTN3222; el
  DTB devuelve exactamente `20 6 21 7 63 8 1 a` mediante `fdtget`.
- ZIP v0.14:
  `postmarketos-edge-xfce-mainline-v0.14-goodix-force-ptn-tune-sm-x910-twrp.zip`,
  22.014.000 bytes, SHA-256
  `23cb7f066c6fecbd50d995db315906f262545ac3024af3068b3a468f947a5cfe`.
  Hashes internos: boot
  `9499d1836e2b9c7665891b46d0c13c34eea8ff2e4f7d72e8bc4a64d294a4fc4b`,
  vendor_boot
  `19c1f767c6a924a9bee4cdb0c7f70d067950327b55269f202cbb7f2c5989d904`.
  Dos generaciones fueron idénticas, pasaron Android v4/LZ4/AVB y todas las
  aserciones de hardware. Se copió a `/sdcard` y el hash remoto coincide. El
  asistente no flasheó ninguna partición.
- Reto inmediato: prueba física v0.14. El journal esperado debe mostrar layout
  Goodix 8/16 sin checksum errors y cuatro overrides PTN antes de DWC3. Si USB
  enumera, conectar por SSH; si el táctil responde, validar orientación y
  escala en LightDM antes de avanzar a DRM nativo.

## 2026-07-19 — sesión 20: resultado físico inicial v0.14

- La usuaria flasheó v0.14 y el sistema alcanzó de nuevo LightDM. El táctil
  continúa sin producir entrada utilizable.
- Windows sigue sin ADB, ACM ni NCM/RNDIS y conserva los dos dispositivos USB
  desconocidos por error de descriptor. `172.16.42.1:22` no responde.
- Se sondeó en paralelo el puerto 22 de toda `<LAN_SUBNET>`, excluyendo el
  host y los equipos conocidos `.138`/`.150`; no apareció ningún SSH nuevo
  atribuible a la tablet.
- No se puede distinguir externamente si el override Goodix no se activó, si
  cambió el checksum esperado o si la escritura PTN3222 falló/progresó sin
  resolver DWC3. Próximo paso: volver a TWRP y extraer el journal v0.14 en sólo
  lectura antes de introducir otro cambio.

## 2026-07-19 — sesión 21: journal v0.14 y bundle v0.15

- Desde TWRP se montó `/dev/block/mmcblk1p2` como `ro,norecovery`, se
  extrajeron journals, Xorg, boot y LightDM a
  `work/v014-rootfs-logs-20260719/`, y se desmontó la microSD sin escribirla.
  El journal actual tiene SHA-256
  `19d2ec68fd8d2fa3bdf30232821ba654c473f9f1ed0a7e9ed5340f970fe56e4f`;
  boot ID `7d1c4dd8eee64b67b41c876851a25cd7`.
- Goodix registra a 1,628 s `forcing 16-byte Samsung events for firmware PID
  6936`, crea `input0` y anuncia `event layout 8/16`. Ya no aparece ningún
  `touch data checksum error`: el forzado por PID de v0.14 funciona.
- Al tocar, `a90000.i2c` agota el tiempo de la transferencia GPI inicial y el
  driver termina en `failed get event head data: -110`; después el canal DMA
  puede fallar también `CH STOP`. La diferencia con v0.13 es el tamaño:
  26 bytes completaban, mientras v0.14 preleía dos registros Samsung y pedía
  42. La corrección r10 prelee sólo un contacto (26 bytes en 8/16).
- El algoritmo multitáctil conserva los dos bytes posteriores al primer
  contacto: son checksum si `n=1` o el inicio de contacto 1 si `n>1`. En este
  último caso reanuda en `header + point_len + checksum_size`, escribe desde
  `data[point_len + checksum_size]` y lee `(n - 1) * point_len`, que completa
  los contactos restantes y el checksum final sin duplicar datos.
- USB registra `ptn3222 1-004f: applied 4 register overrides` a 1,748 s. DWC3
  todavía avisa `controller soft reset failed` y devuelve `-ETIMEDOUT`; queda
  demostrado que rails, reset y tuning del repetidor ya no son la barrera.
- La comparación con `dwc3-qcom.c` identificó la omisión exacta al limitar el
  puerto a HS: el DTS borraba la SSPHY/PIPE, pero no añadía
  `qcom,select-utmi-as-pipe-clk`. Esa propiedad hace que el glue programe
  `PIPE_UTMI_CLK_SEL` antes de `dwc3_core_probe()`. Se añadió al DTS y al
  validador, sin reintroducir todavía la PHY USB3.
- El parche Goodix modificado aplica limpiamente sobre Linux 7.2-rc3. Una
  primera build limpia fue terminada a 63 s por el límite del runner, no por
  un error; la continuación incremental terminó correctamente en 478 s.
- Build v0.15: `Image.gz` SHA-256
  `1a8320c6fa49f75cafd3ec3871ce012f59270a3b1d8ba665b2ac3a35b15cd8d2`;
  DTB `13c909ec802636d7be8a6318c52be0f0b53505f6f4224e457184869ed6376c25`;
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
  La imagen contiene el mensaje Goodix y el DTB compilado contiene la
  propiedad booleana UTMI-PIPE.
- ZIP v0.15:
  `postmarketos-edge-xfce-mainline-v0.15-goodix-usb-pipe-sm-x910-twrp.zip`,
  22.012.201 bytes, SHA-256
  `e4f7432ed114227d238d161514796b6cc997a74029abe7ce9b079ef4216ae013`.
  Hashes internos: boot
  `837709a9e49e8ee25414c77ac80b3da803c9620bec155cf61529f2c66ee95aa2`,
  vendor_boot
  `9886dd75d9990d1656a00888bcc9559e984441fb8038cb1b7099d3f8b0a79921`.
  Dos generaciones fueron idénticas, pasaron Android v4/LZ4/AVB y todas las
  aserciones. El ZIP se copió a `/sdcard` y su hash remoto coincide; el
  asistente no flasheó ninguna partición.
- Reto inmediato: flashear manualmente v0.15 y probar un toque en LightDM. Si
  Windows enumera NCM/RNDIS, conectar por SSH y validar ambos subsistemas en
  vivo. Si alguno falla, volver a TWRP y extraer el nuevo journal en sólo
  lectura antes del siguiente cambio.

## 2026-07-19 — sesión 22: resultado físico inicial v0.15

- La usuaria flasheó v0.15 y el sistema alcanzó LightDM. La lectura Goodix
  reducida de 42 a 26 bytes queda validada físicamente: el táctil produce
  entrada por primera vez.
- La orientación aún es incorrecta. Tocar la parte superior activa la parte
  inferior, por lo que el eje vertical expuesto está invertido. El siguiente
  DTS añadirá `touchscreen-inverted-y` además de `touchscreen-swapped-x-y`.
- El host no presenta NCM/RNDIS ni otro adaptador USB de red. Permanecen dos
  dispositivos desconocidos con error de solicitud de descriptor y
  `172.16.42.1:22`/`<LAN_HOST_C>:22` no responden.
- Se sondeó el puerto 22 de toda `<LAN_SUBNET>`. Sólo respondieron `.138` y
  `.150`, ambos equipos conocidos que la usuaria pidió excluir; no existe SSH
  atribuible a la tablet.
- El resultado externo no demuestra todavía si UTMI-PIPE permitió superar el
  soft reset y el fallo está ahora en el gadget, o si DWC3 sigue en timeout.
  Próximo paso: volver a TWRP, extraer el journal v0.15 en sólo lectura y usar
  esa evidencia para el siguiente cambio USB junto con la inversión de eje.

## 2026-07-19 — sesión 23: journal v0.15 y bundle v0.16

- En TWRP se montó `/dev/block/mmcblk1p2` como `ro,norecovery`, se extrajeron
  journal, Xorg, boot y LightDM a `work/v015-rootfs-logs-20260719/`, y se
  desmontó la microSD. El journal actual tiene SHA-256
  `ab71752f62067cea8bd92d87850f42c873c9aace2090a2e6aba50c1d001f5496`;
  boot ID `50f794db540749b2bde8ed6ef92011c8`.
- Goodix registra `event layout 8/16` y no aparecen checksum, GPI-I2C ni DMA
  timeouts. Esto concuerda con la entrada física estable observada en v0.15.
- UTMI-PIPE resolvió el soft reset DWC3: ya no existe `-ETIMEDOUT`. El kernel
  registra el controlador, configfs crea el gadget y `usb0`; initramfs asigna
  `172.16.42.1` e inicia DHCP. En userspace Avahi publica esa dirección y sshd
  escucha en `0.0.0.0:22` y `[::]:22`.
- Como Windows sigue mostrando errores de descriptor, el fallo restante queda
  después del core/gadget y antes de una enumeración física correcta. No se
  debe seguir modificando userspace de red para este síntoma.
- Se comparó el driver mainline `drivers/phy/phy-snps-eusb2.c` con el Samsung
  funcional `drivers/usb/phy/phy-msm-snps-eusb2.c`. Divisores PLL, VREF y los
  cinco parámetros TX coinciden. Las dos diferencias concretas son una espera
  de 10 µs tras afirmar `POR` y `PHY_CFG_PLL_CPBIAS_CNTRL=1`; mainline omite la
  espera y usa cero.
- Se añadió `match-samsung-sm8550-eusb2-phy-init.patch` para reproducir ambos
  detalles. El DTS añade además `touchscreen-inverted-y`. El paquete sube a
  r11, actualiza hashes y el validador exige inversión e intercambio de ejes.
- Build limpia v0.16: kernel
  `e1ece41124f5f365e5a123fd7ec67531682397bb5cf1d3c3df2a088b525624be`,
  DTB `ce4ce2e2d09b0835641e95f26971188fa5be479c0d65aa626eed4cade9f87093`,
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
  La compilación limpia terminó en 585 s y las comprobaciones inspeccionaron
  fuente y DTB efectivos.
- ZIP v0.16:
  `postmarketos-edge-xfce-mainline-v0.16-touch-usb-phy-sm-x910-twrp.zip`,
  22.016.593 bytes, SHA-256
  `c0d768a2eb179cab95bc2776840828e36c8a50a2df598f7bbb1df6835c457ef9`.
  Hashes internos: boot
  `09984ff41ef3f799378c91d9572618742cce7375dcf2e37074ee39d0705794d7`,
  vendor_boot
  `1a57a0a114c63a30fb1e6e00f9850dee09acdf10da9c5b15ebe243a6b35aa5ed`.
  Dos generaciones fueron idénticas; pasó Android v4/LZ4/AVB y el hash en
  `/sdcard` coincide. El asistente no flasheó particiones.
- Reto inmediato: flashear manualmente v0.16, validar orientación táctil y
  enumeración NCM/RNDIS. Si aparece la interfaz, conectar por SSH a
  `172.16.42.1`; si no, capturar el journal y añadir lecturas diagnósticas de
  los registros PHY/PTN3222 antes de otro cambio.

## 2026-07-19 — sesión 24: resultado físico v0.16 y eje correcto

- v0.16 alcanza de nuevo LightDM, pero el ajuste de PHY no cambia el resultado
  externo: Windows conserva dos errores de solicitud de descriptor, no aparece
  NCM/RNDIS y no responde SSH en `172.16.42.1`, `172.16.42.2`, `.151` ni en un
  host nuevo de la LAN. `.138` y `.150` se excluyen por indicación de la
  usuaria porque pertenecen a otros dispositivos.
- La espera de 10 µs tras POR y CPBIAS=1 quedan por tanto descartados como
  arreglo suficiente para la enumeración. Se conserva el parche porque iguala
  la secuencia Samsung, pero el siguiente journal debe guiar instrumentación
  de registros PHY/PTN3222.
- La prueba táctil v0.16 deja ambos ejes visibles invertidos. La causa exacta es
  el orden de `touchscreen_apply_prop_to_x_y()`: aplica `inverted-x`, después
  `inverted-y` y finalmente `swapped-x-y`. Como el intercambio ya era
  necesario, `inverted-y` actuó sobre el X visible y no corrigió el Y visible.
- La fuente r12 sustituye `touchscreen-inverted-y` por
  `touchscreen-inverted-x` y conserva `touchscreen-swapped-x-y`. El validador
  se actualiza para exigir la propiedad correcta.
- Por petición de la usuaria, el flujo normal de futuras builds queda reducido
  a un empaquetado y una única comparación SHA-256 después de copiar el ZIP a
  `/sdcard`. Las validaciones repetidas se reservan para cambios de formato o
  boot chain que realmente eleven el riesgo.
- Reto inmediato: volver a TWRP, extraer el journal v0.16 en sólo lectura,
  integrar instrumentación USB y compilar un único siguiente bundle que pruebe
  tanto la orientación corregida como el siguiente paso de eUSB2.

## 2026-07-19 — sesión 25: referencia eUSB2 Samsung y bundle v0.17

- En TWRP se montó `/dev/block/mmcblk1p2` como ext4 `ro,norecovery`, se
  extrajeron journal, Xorg y LightDM a `work/v016-rootfs-logs-20260719/` y se
  desmontó la tarjeta. El `system.journal` actual tiene SHA-256
  `6dd5ee4399bbae29e56b10dbedc9d6178f7a7decca51728ec7c97c1215376f53`;
  boot ID `225ccfc4e1ac473f9c413502d1bbe026`.
- v0.16 confirma `event layout 8/16`, sin checksum/GPI/DMA; PTN3222 aplica los
  cuatro overrides, DWC3 arranca y configfs crea gadget/`usb0`/DHCP. No aparece
  un error interno nuevo que explique el fallo de descriptor del host.
- Se usó el kernel Samsung 5.15 de TWRP como referencia funcional y se montó
  debugfs temporalmente. El regmap PTN3222 `43-004f` contiene revisión `A2`,
  `06=20`, `07=21`, `08=63`, `0a=01`, `DEVICE_STATUS(0f)=09` y
  `LINK_STATUS(10)=05` mientras ADB enumera correctamente.
- La hoja de datos oficial NXP confirma que `0x0f` y `0x10` son los dos
  registros de estado. Esto permite una comparación directa y evita seguir
  cambiando tuning sin saber en qué lado del repetidor se rompe el enlace.
- Se añadió `diagnose-sm8550-eusb2-link.patch`: imprime la frecuencia de
  referencia y los controles MMIO efectivos de la PHY, y lee `00..16` del
  PTN3222 ocho segundos después de iniciar. Es diagnóstico de sólo lectura.
- El DTS r12 conserva `touchscreen-swapped-x-y` y sustituye la inversión
  errónea por `touchscreen-inverted-x`. El script de build aplica también el
  nuevo parche y el APKBUILD incluye fuente y checksum reproducibles.
- Build limpia v0.17 terminada en 541 s: kernel
  `48e91dfb2f42a665599d204a63e8633a8606011dc9dc4f18a4c1791975d12aa1`,
  DTB `8d600347ad1a826e0c0ef33fbf0fb68125d18d5a64939307ac4b93599c12bddf`,
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
- Se empaquetó una sola vez, siguiendo el flujo acordado. ZIP:
  `postmarketos-edge-xfce-mainline-v0.17-touch-usb-diagnostics-sm-x910-twrp.zip`,
  22.016.542 bytes, SHA-256
  `d86e978618bf00d182f705aa4b0704111b42b8f2f8dd8547e40255f205e30439`.
  Se copió a `/sdcard` y el único hash posterior coincide. El asistente no
  flasheó particiones.
- Reto inmediato: flash manual v0.17, validar ambos ejes táctiles y observar
  USB/SSH. Si no enumera, volver a TWRP y comparar `0f/10` mainline con la
  referencia Samsung `09/05` antes de aplicar el siguiente arreglo.

## 2026-07-19 — sesión 26: resultado físico inicial v0.17

- v0.17 arranca hasta LightDM y la usuaria confirma que el táctil funciona y
  queda correctamente orientado. Se valida físicamente la combinación
  `touchscreen-inverted-x` + `touchscreen-swapped-x-y`; el bring-up táctil se
  considera resuelto.
- Windows no enumera NCM/RNDIS y mantiene dispositivos USB con error de
  solicitud de descriptor. No responden `172.16.42.1:22`, `172.16.42.2:22` ni
  `<LAN_HOST_C>:22`.
- El barrido TCP/22 de `<LAN_SUBNET>` sólo encuentra `.138` y `.150`, ambos
  equipos conocidos que deben excluirse. No existe SSH atribuible a la tablet.
- Reto inmediato: volver a TWRP, extraer el journal v0.17 en sólo lectura y
  comparar los registros diferidos PTN3222 `DEVICE_STATUS(0f)` y
  `LINK_STATUS(10)` con la referencia Samsung funcional `09/05`.

## 2026-07-19 — sesión 27: PTN3222 descartado y bundle DWC3 v0.18

- En TWRP se montó `mmcblk1p2` como `ro,norecovery`, se extrajeron journal,
  Xorg y LightDM a `work/v017-rootfs-logs-20260719/` y se desmontó la tarjeta.
  Boot ID `66eb6939ed4649e197dcd6be06c0cd46`; SHA-256 de `system.journal`
  `201b71a79f2344904f9153b13e8826b32bd59a9a710d625a5ae868aa6193c13b`.
- La PHY mainline registra referencia de 38,4 MHz y los valores efectivos de
  sus controles. El PTN3222 queda fuera de reset (`logical=0`, `raw=1`) y sus
  registros `00..16` coinciden con TWRP byte a byte: revisión `A2`, overrides
  `06=20`, `07=21`, `08=63`, `0a=01`, estado `0f=09` y enlace `10=05`.
- Como el repetidor funcional y mainline presentan el mismo enlace, se
  descartan nuevos cambios de tuning/PHY. El host alcanza el enlace físico,
  pero Windows no obtiene VID/PID; el ámbito pasa a DWC3/UDC/EP0.
- La configuración de initramfs es la ruta estándar postmarketOS configfs:
  crea `ncm.usb0`, configura VID `18d1`/PID `d001`, enlaza `c.1` y escribe el
  primer UDC disponible. El journal no contiene errores de esos pasos.
- Se añadió `diagnose-dwc3-ep0-enumeration.patch`, que registra solicitud y
  resultado del pull-up, DCTL/DSTS/DEVTEN/event count, cada evento DWC3, estado
  EP0 y paquetes SETUP. No cambia lógica del controlador. APKBUILD r13 y script
  de build lo reproducen.
- Recompilación incremental v0.18 terminada en 58 s: kernel
  `6d1feaff85d4d50131a2fdb114f28ac6be410420d0226c22c09edf8465b4ffef`,
  DTB `8d600347ad1a826e0c0ef33fbf0fb68125d18d5a64939307ac4b93599c12bddf`,
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
- ZIP único v0.18:
  `postmarketos-edge-xfce-mainline-v0.18-dwc3-ep0-diagnostics-sm-x910-twrp.zip`,
  22.017.000 bytes, SHA-256
  `6706f3778c2df2b1384e1b225cf3c5af315ca0986056599dfb3fc4c42f8542e0`.
  Se copió a `/sdcard` y el único hash posterior coincide; no se flasheó.
- Reto inmediato: flash manual v0.18, esperar 15 s y probar USB/SSH. Si falla,
  volver a TWRP y clasificar el primer punto ausente entre pull-up, RUN/STOP,
  IRQ reset/connect, SETUP y respuesta EP0.

## 2026-07-19 — sesión 28: resultado físico inicial v0.18

- v0.18 arranca hasta LightDM y conserva el táctil funcional, pero USB no
  enumera. Windows muestra dos dispositivos `VID_0000&PID_0002` con error de
  solicitud de descriptor; no aparece adaptador NCM/RNDIS.
- No responden `172.16.42.1:22`, `172.16.42.2:22` ni `.151`. El barrido completo
  de `<LAN_SUBNET>` sólo encuentra SSH en `.138` y `.150`, ambos excluidos por
  pertenecer a otros dispositivos.
- Reto inmediato: volver a TWRP, extraer el journal v0.18 en sólo lectura y
  determinar con las trazas nuevas el primer punto ausente entre pull-up,
  RUN/STOP, IRQ reset/connect, paquete SETUP y respuesta EP0.

## 2026-07-19 — sesión 29: EP0 validado y bundle RNDIS/WCN7850 v0.19

- Se extrajo y leyó el journal v0.18 desde la microSD. Boot ID
  `47ee7c89dc374bd1baf30310b98cbef7`; SHA-256 de `system.journal`
  `ffcbcd4ebce12d857a91094c9712d442422001ab7533178a03db64c69d614edc`.
- Las trazas pasivas muestran pull-up/RUN efectivo, IRQ y una conversación
  EP0 completa: el host solicita descriptores device/config/string, asigna
  dirección, pide estado, ejecuta `SET_CONFIGURATION(1)` y
  `SET_INTERFACE(0)`. PTN3222, PHY, DWC3 y la entrega de descriptores quedan
  descartados como barrera. Windows no crea el adaptador CDC-NCM pese a haber
  configurado la función; se seleccionó `rndis.usb0` como siguiente prueba
  mínima de compatibilidad.
- El FDT vivo/stock Kiwi v2 contiene IDs 1103 y 1107; el perfil de esta placa
  es WCN7850 PCIe `17cb:1107` en PCIe0. Se confirmaron contra downstream
  WLAN_EN GPIO80, BT_EN GPIO81, PCIe PERST GPIO94 y wake GPIO96.
- El DTS r14 añade `vph_pwr`, `wcn7850-pmu`, sus diez LDO, rails PM8550VS,
  sleep clock PMK8550, pinctrl y `pcieport0/wifi@0`. El fragmento activa
  PCIe Qualcomm, `POWER_SEQUENCING_QCOM_WCN=m` y `ATH12K=m`; conserva todos
  los fixes anteriores de arranque, pantalla y táctil.
- Se extrajo `vendor.img` stock EROFS y se creó el paquete propietario
  `firmware-samsung-gts9uwifi` r1. Blobs finales y SHA-256: `amss.bin`
  `4529e42c...`, `m3.bin` `67396ffa...`, `board.bin` `9cade90a...` y
  `regdb.bin` `75cc1075...`. El script de staging exige los hashes completos y
  los binarios quedan ignorados por git.
- La primera construcción rootfs falló correctamente porque cuatro checksums
  del APKBUILD de kernel no seguían el orden posicional de `source=`. Se
  reordenaron antes de reconstruir. Firmware r1 elimina además la advertencia
  de instalar directamente en `/lib` y usa `/usr/lib` en el sistema usr-merge.
- Verificación del rootfs final: device r4, kernel `7.2_rc3-r14`, firmware r1;
  módulos `ath12k`, `ath12k_wifi7` y `pwrseq-qcom-wcn`; cuatro blobs exactos;
  RNDIS presente en deviceinfo e initramfs; DTB con PMU/GPIO/rails y
  `pci17cb,1107`.
- Imágenes Android v4 v0.19: boot
  `6d7493ffbf2f8373c86ec5936ba333601d998c0ba8ee7d78410cc40619972ab5`,
  init_boot
  `ba29d262447268a298ed192b340515417307fb5bb482bd3f2105d874dc1b59d5`,
  vendor_boot
  `392b8a3b27874405494d6b06da778a14ddf04bff04c9c6bc427e41141fa1f7c3`,
  dtbo `9f2dc02eb28fd5ffaa90745a57c4f176aa708e8a0fc67635acd4e52a7fed9e65`
  y vbmeta
  `b95e5ef931fbe588f8574c06331db56ae906b1ac91ed73204704b35cb220b3d4`.
- El empaquetador y el instalador TWRP admiten ahora un overlay opcional del
  rootfs pmOS. Antes de escribir, valida `mmcblk1p2`, ext4 y `ID=postmarketos`;
  después instala y verifica por archivo módulos, firmware y deviceinfo, sin
  tocar userdata interna, super, recovery, bootloader ni firmware Samsung.
- ZIP v0.19: 80.821.386 bytes, SHA-256
  `3ca3e44fb2a8e26bec76515381d40f565ecc6b5215b52d8b855f7513297a686e`.
  Se copió a `/sdcard` en TWRP y el único hash posterior coincide. El asistente
  no flasheó ninguna partición.
- Se comprimió también la imagen GPT limpia de 4.643.094.528 bytes como
  `postmarketos-edge-xfce-mainline-v0.19-rndis-wifi-pcie-sm-x910-sd.img.zst`:
  513.383.398 bytes, SHA-256
  `ed7a92c2645eb3ea2118a77be28afba16fee7a30bbbfb4b614026df492fd6f10`.
  Contiene los mismos paquetes r4/r14/r1 y sirve para la prueba desde cero.
- Próximo paso: flash manual v0.19. Probar RNDIS/SSH en `172.16.42.1`; en
  paralelo observar si PCIe0 enumera 17cb:1107 y si NetworkManager obtiene una
  interfaz Wi-Fi. Si no hay red, volver a TWRP para extraer el journal v0.19.

## 2026-07-19 — sesión 30: corrección del validador TWRP v0.19.1

- El intento manual de instalar v0.19 abortó con `microSD rootfs is not
  postmarketOS`. La comprobación sucede antes de los `dd`, por lo que no se
  escribió ninguna partición de arranque ni archivo del rootfs.
- Diagnóstico directo por ADB/TWRP: `/dev/block/mmcblk1p2` existe, monta como
  ext4 y `/etc/os-release` es un enlace válido a `../usr/lib/os-release`. La
  identidad real es `ID="postmarketos"`; el instalador sólo aceptaba la forma
  legal alternativa sin comillas `ID=postmarketos`.
- El validador acepta ahora exactamente cualquiera de esas dos formas. No se
  modifica ninguna imagen, módulo, blob ni contenido del overlay v0.19.
- Se reempaquetó como
  `postmarketos-edge-xfce-mainline-v0.19.1-rndis-wifi-pcie-sm-x910-twrp.zip`:
  80.821.400 bytes, SHA-256
  `3a3431c1ea994536feadc6eb18712b1de38664babadb6b45e40da467dd66f89f`.
  Copiado a `/sdcard`; el único hash posterior coincide. El asistente no lo
  flasheó.

## 2026-07-19 — sesión 31: fallo ABL v0.19.1 y restauración del appended-DTB

- Tras instalar v0.19.1, el reboot mostró la pantalla Odin/Download y no llegó
  a Linux. La usuaria volvió manualmente a TWRP; no hubo brick.
- `/proc/last_kmsg` contiene el boot fallido restaurado por `sec_log_buf`. ABL
  descomprime el kernel, pero registra `ApplyOverlay: ufdt apply overlay
  failed`, `Root Node is not found at BoardDtb`, `Invalid device tree header`
  y `Launching odin -927639495`. No existe panic ni journal nuevo porque Linux
  nunca recibió el control.
- La comparación de `BUILD-METADATA.txt` fija la regresión: v0.18 arrancable
  tenía `append_dtb_to_kernel=1` y `disable_runtime_dtbo=1`; v0.19 se generó
  accidentalmente con `0/0` al llamar al script sin las variables que antes
  aportaba el flujo de build. Esto reactivó exactamente la ruta ufdt descartada
  en v0.2/v0.3.
- El script device-specific usa ahora por defecto `1/1`. v0.19.2 reutiliza el
  mismo kernel r14, DTB WCN7850, initramfs, rootfs y overlay; sólo corrige el
  empaquetado Android para recuperar el fallback appended-DTB validado desde
  v0.4.
- Imágenes v0.19.2: boot appended-DTB
  `082a3bcb51c4b53a52b98c1d226621d57f6ce2ab6e88874e6ddc0fcd597e7e8c`;
  dtbo fallback
  `c17418be08365c03a5ce3a220af734b14ec2e6b03c0cbc1ed9721be6f21d3ef3`.
  `init_boot`, `vendor_boot` y `vbmeta` conservan respectivamente
  `ba29d262...`, `392b8a3b...` y `b95e5ef9...`. La metadata confirma ambos
  flags en uno y los primeros ocho bytes del DTBO fallback son cero.
- ZIP v0.19.2:
  `postmarketos-edge-xfce-mainline-v0.19.2-appended-dtb-rndis-wifi-sm-x910-twrp.zip`,
  80.852.094 bytes, SHA-256
  `a8a6f28ab58c594478dda11a738ba0deb90c09d2865824b2aff845c655c0b8a6`.
  Copiado a `/sdcard`; el único hash posterior coincide. El asistente no lo
  flasheó.

## 2026-07-19 — sesión 32: userspace v0.19.2, diagnóstico WCN y bundle v0.20

- v0.19.2 abandona la regresión Odin y arranca mainline desde la microSD. Las
  tres fotos corresponden a boots de systemd, no a kernel panic. Se extrajeron
  en sólo lectura los journals con IDs `214544eee54741ab86c8d276cdcefe87`,
  `e159c2334b9f4a87afb08ee8bf67301e` y
  `8773907e091e43f2b60962f4560177e1`.
- Dos boots completos superan 51 segundos. systemd alcanza graphical target;
  RNDIS crea `usb0=172.16.42.1`, NetworkManager ve carrier y OpenSSH escucha
  en todas las direcciones. Xorg abre simpledrm a 2960x1848, LightDM activa
  VT7 y slick-greeter entra en su bucle principal. No hay panic ni fallo fatal
  de X, por lo que la pantalla de consola persistente es un problema de
  presentación/VT, no de arranque.
- v0.20 retira `console=tty0` del cmdline Android y del paquete device. Se
  mantienen `ttyMSM0`, earlycon, journal persistente, `sec_log_buf` y
  `/proc/last_kmsg`, de modo que fbcon deja de competir con X sin perder la
  capacidad de diagnóstico desde TWRP o por red.
- PCIe0 v0.19.2 inicializa el controlador y enumera su root port
  `17cb:0113`, pero tras aproximadamente un segundo termina `Device not
  found`; no existe endpoint ni interfaz ath12k. `pwrseq-qcom_wcn` informa
  además que falta `vddio1p2`.
- El driver Linux 7.2-rc3 de WCN7850 pide siete rails, incluido `vddio1p2`.
  El DTS antiguo de SM8550 QRD usado como base declara sólo seis, mientras DTs
  WCN7850 posteriores conectan ese rail a un LDO de 1,2 V. El perfil stock X910
  mapea explícitamente `l3g` a RF y su pinctrl activa WLAN_EN GPIO80 como
  salida alta, pull-up y 16 mA; la versión v0.19 lo dejaba en pull-down.
- r15 añade PM8550VS-G LDO3, su alimentación desde S4G y
  `vddio1p2-supply`; GPIO80 reproduce el estado activo stock. El DTB empaquetado
  fue decompilado y confirma esas propiedades. Paquetes finales: device r5,
  kernel `7.2_rc3-r15`, firmware r1.
- Artefacto TWRP:
  `postmarketos-edge-xfce-mainline-v0.20-wcn-power-rndis-no-fbcon-sm-x910-twrp.zip`,
  80.853.798 bytes, SHA-256
  `9a73808d30e6aa9b317a7550a36a5c6a271245d8fcdff17808ecba5e17f76998`.
  Copiado a `/sdcard`; el único hash posterior coincide. No se flasheó.
- Imagen SD limpia del mismo rootfs:
  `postmarketos-edge-xfce-mainline-v0.20-wcn-power-rndis-no-fbcon-sm-x910-sd.img.zst`,
  478.250.065 bytes.
- Próxima prueba: flash manual del ZIP, esperar al menos 45 segundos y probar
  primero SSH en `172.16.42.1`; después comprobar login visible, `lspci -nn`,
  `ip link`, `nmcli` y `dmesg` de `qcom-pcie`/`ath12k`. `.138` y `.150` siguen
  excluidos por ser otros dispositivos.

## 2026-07-19 — sesión 33: bloqueo v0.20 y diagnóstico WCN v0.21

- La prueba física v0.20 queda visualmente en los pingüinos porque retiró
  `console=tty0`, pero no se detiene allí. Desde TWRP se extrajeron en sólo
  lectura `/proc/last_kmsg`, journals y logs X/LightDM a
  `work/v020-rootfs-logs-20260719/`.
- El boot v0.20 `56c2f5b944d14e2e8bc81741e54c8ef1` confirma kernel
  `#16-samsung-gts9uwifi-mainline`/paquete r15, montaje de ambas particiones,
  systemd, gadget RNDIS y socket OpenSSH. El journal se corta exactamente a
  18,987144 s tras imprimir los rangos del host `qcom-pcie 1c00000.pcie`; no
  existe panic ni oops y fue necesario un reinicio manual.
- El DT v0.20 añade además el aviso temprano `Fixed dependency cycle(s)` entre
  `/soc@0/rsc@17a00000/regulators-5` y `smps4`. Es una regresión respecto a
  v0.19.2 y coincide con el nuevo PM8550VS-G LDO3 alimentado por S4G. Se
  descarta repetir esa asignación sin antes demostrar la topología correcta.
- v0.21 revierte LDO3, `vdd-l3-supply` y `vddio1p2-supply`; el driver vuelve a
  su dummy rail conocido. GPIO80 conserva `drive-strength = <16>` y
  `bias-pull-up`, pero ya no tiene `output-high`: el secuenciador debe elevarlo
  en el orden previsto. Se restaura `console=tty0` para recuperar el verbose.
- `diagnose-wcn7850-power-sequence.patch` registra valor inicial, resultado de
  dirección y transición de WLAN_EN, además del registro del secuenciador. Se
  integra tanto en el APKBUILD como en la build directa. El módulo final fue
  inspeccionado y contiene las cadenas `SM-X910 WCN diag`.
- Build limpia verificada: device r6, kernel `7.2_rc3-r16`, firmware r1. El
  DTB decompilado no contiene el rail experimental y sí contiene GPIO80
  pull-up/16 mA y `wlan-enable-gpios`.
- ZIP TWRP generado una vez:
  `postmarketos-edge-xfce-mainline-v0.21-wcn-diagnostics-verbose-sm-x910-twrp.zip`,
  80.851.485 bytes, SHA-256
  `c46b30538b486ee1b93c938464c8f339d93b3127450d3a34f39c4861bc3f9032`.
  Usa appended-DTB, DTBO runtime deshabilitado y overlay completo. Se copió a
  `/sdcard`; el único hash posterior coincide. El asistente no flasheó.
- Próxima prueba: flash manual v0.21, dejarla al menos 45 segundos y observar
  el verbose. Si no aparece RNDIS/SSH, volver a TWRP para extraer el journal y
  localizar la última traza `SM-X910 WCN diag`; no hace falta vídeo mientras
  la persistencia de la microSD continúe funcionando.

## 2026-07-19 — sesión 34: v0.21 sí arranca y bundle visual/SSH v0.22

- La foto v0.21 parecía quedar detenida tras `SM-X910 WCN diag: power
  sequencer registered`. Se volvió manualmente a TWRP y se extrajeron en sólo
  lectura 19 journals, `last_kmsg` y logs de X/LightDM a
  `work/v021-rootfs-logs-20260719/`.
- El boot completo `f1d854a068194803b30089cb0d6554a3` usa kernel r16. El
  secuenciador adquiere los siete rails, `regulator_bulk_enable()` retorna 0 y
  WLAN_EN permanece en 1 antes/después de la transición. PCIe termina de forma
  normal un segundo después con `Device not found`; el WCN7850 aún no enumera,
  pero no existe deadlock, panic ni oops.
- Userspace continúa: RNDIS obtiene carrier, `usb0` conserva `172.16.42.1`,
  NetworkManager arranca a 21,315 s, OpenSSH a 21,318 s, LightDM a 21,555 s y
  `graphical.target` a 21,604 s. El journal sigue activo al menos hasta 51 s.
- La causa de la pantalla estática es conocida y aislada: `console=tty0`
  mantiene fbcon mostrando el último printk mientras X/greeter corre en VT7.
  Esa consola se restauró deliberadamente en v0.21 para obtener las trazas.
- v0.22 no recompila ni cambia kernel/DTB: conserva r16 y firmware r1, sube el
  device a r7 y retira `console=tty0` tanto del cmdline Android como del
  `kernel-cmdline.conf` reproducible. Se generó un rootfs limpio y se verificó
  device r7/kernel r16/firmware r1.
- ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.22-rndis-ssh-greeter-sm-x910-twrp.zip`,
  80.851.469 bytes, SHA-256
  `85c70c79f1b0e0bb3c7facd47ac7b817807dd6159a15a4dd8d6f42f5e204f9c6`.
  Usa appended-DTB, DTBO runtime deshabilitado y overlay completo. Se copió a
  `/sdcard` y el único hash posterior coincide; el asistente no flasheó.
- Próxima prueba: flash manual v0.22, esperar 45 s, dejar el sistema vivo y
  conectado por USB. Debe aparecer el greeter; se probará inmediatamente SSH
  en `172.16.42.1` para continuar la enumeración WCN desde el sistema vivo.

## 2026-07-19 — sesión 35: carrera PCIe/WCN v0.22 y aislamiento v0.23

- La prueba v0.22 permaneció físicamente en los pingüinos pese a no contener
  `console=tty0`. Se volvió manualmente a TWRP y se extrajeron en sólo lectura
  journals, `last_kmsg` y logs gráficos a
  `work/v022-rootfs-logs-20260719/`.
- Los boots `d34857ab68a9422a9dda48d6b2467373` y
  `cbab67c1ce7241e18c49ca1523ca0d7e` usan kernel r16. Ambos montan rootfs,
  activan el gadget USB y llegan a los probes PCIe/WCN, pero el journal deja
  de progresar respectivamente a 21,727 y 19,040 s, antes de NetworkManager,
  OpenSSH y LightDM. Los cuatro ficheros X/LightDM están vacíos.
- No hay panic ni oops. El boot v0.21 `f1d854...` había completado exactamente
  la activación de siete rails, WLAN_EN, PCIe y userspace; otros boots r16 se
  detienen antes o durante esa ruta. La evidencia apunta a una carrera
  intermitente de probe/deferred-probe entre PCIe0, pci-pwrctrl y el proveedor
  WCN, no a un fallo determinista de X ni a `console=tty0`.
- El endpoint Wi-Fi sigue sin enumerar incluso en el boot completo, así que no
  aporta ninguna función al primer hito. v0.23 lo aísla como bloque: añade una
  etiqueta al `wcn7850-pmu` y marca `disabled` ese PMU, `pcie0` y `pcie0_phy`.
  Pantalla/simpledrm, Goodix, SDHC2, DWC3, RNDIS y OpenSSH no cambian.
- Build limpia verificada: device r7, kernel `7.2_rc3-r17`, firmware r1. La
  consulta directa del DTB instalado devuelve `status=disabled` para
  `/wcn7850-pmu`, `/soc@0/pcie@1c00000` y `/soc@0/phy@1c06000`; el cmdline no
  contiene `console=tty0`.
- ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.23-stable-rndis-no-wcn-sm-x910-twrp.zip`,
  80.851.833 bytes, SHA-256
  `a050c7d88ec223619c231f102593c5ae03d0b81dccaadda6256abd2d30b43fcd`.
  Usa appended-DTB, DTBO runtime deshabilitado y overlay completo. Se copió a
  `/sdcard`; el único hash posterior coincide. El asistente no flasheó.
- Próxima prueba: flash manual v0.23 y mantenerla viva/conectada al menos 45 s.
  Validar greeter y SSH RNDIS en `172.16.42.1`; sólo entonces reintroducir
  PCIe/WCN con acceso remoto y trazas más finas.

## 2026-07-19 — sesión 36: v0.23 estable y handoff VT de v0.24

- La prueba física v0.23 volvió a parecer detenida en los pingüinos. La usuaria
  regresó manualmente a TWRP y los logs se extrajeron en sólo lectura a
  `work/v023-rootfs-logs-20260719/`; no fue necesario un vídeo del verbose.
- El boot `563abe3add6e4cd893b4ceeaceb88eea` usa kernel
  `#18-samsung-gts9uwifi-mainline`/paquete r17 y demuestra que el aislamiento
  WCN funciona: no aparecen probes WCN/PCIe0, panic, oops ni interrupción del
  journal. RNDIS crea `usb0=172.16.42.1` con carrier; NetworkManager arranca a
  21,021 s, OpenSSH a 21,024 s, LightDM a 21,316 s y los targets multi-user y
  gráfico se alcanzan a 21,373 s.
- `Xorg.0.log` tiene 11.076 bytes y no contiene fallo fatal. Xorg abre
  `/dev/dri/card0` mediante modesetting/simpledrm, selecciona 2960x1848 y usa
  VT7. `lightdm.log` tiene 3.654 bytes, lanza `slick-greeter` y lo deja en
  autenticación de `phablet`.
- La discrepancia queda aislada al scanout: LightDM registra que Plymouth sigue
  en VT1, inicia X con `vt7 -novtswitch` y luego dice `Activating VT 7`, pero la
  pantalla física conserva el framebuffer de VT1. Los logs X/LightDM de v0.11,
  que sí mostró el login, son esencialmente iguales; no hay evidencia para
  cambiar kernel, simpledrm, resolución ni greeter en esta iteración.
- v0.24 mantiene sin cambios kernel r17, DTB y aislamiento WCN. El paquete
  device sube a r8, depende explícitamente de `kbd` y añade una unidad oneshot
  posterior a LightDM. El script espera hasta 15 s el socket X0, registra la VT
  antes/después y fuerza `chvt 1`, pausa y `chvt 7` para provocar
  `LeaveVT`/`EnterVT` y un redraw de simpledrm.
- La build limpia contiene device r8, kernel `7.2_rc3-r17`, firmware r1 y
  `kbd-2.8.0-r0`. Se verificaron script ejecutable/sintácticamente válido,
  unidad habilitada, `chvt`/`fgconsole`, cmdline sin `console=tty0` y
  `status=disabled` en PMU WCN, PCIe0 y su PHY.
- Durante el empaquetado se detectó que el overlay incremental anterior sólo
  incluía módulos, firmware y deviceinfo: el paquete r8 nuevo no habría
  actualizado por sí mismo la microSD ya instalada. v0.24 transporta además el
  script, la unidad y su activación. `make-twrp-zip.py` preserva ahora los modos
  POSIX del overlay; se comprobó que el script queda `0755` dentro del ZIP.
- ZIP TWRP final:
  `postmarketos-edge-xfce-mainline-v0.24-vt-handoff-rndis-sm-x910-twrp.zip`,
  80.853.551 bytes, SHA-256
  `b7c1a8bc2e3cc6bb0b68c89a5eea8882d85ef664291e80e54e275cfa8ef37b6e`.
  Se copió a `/sdcard` y la única comparación local/remota coincide. El
  asistente no flasheó ninguna partición.
- Próxima prueba: flash manual v0.24, dejar la tablet arrancada incluso si aún
  muestra pingüinos y mantener USB conectado. Probar SSH inmediatamente en
  `172.16.42.1` y leer el journal de
  `gts9uwifi-display-handoff.service`; si el rebote automático no repinta, se
  podrá repetir en vivo y observar DRM/VT sin otro ciclo ciego.

## 2026-07-20 — sesión 37: no-op del overlay v0.24 y fallback fbdev v0.25

- La prueba física v0.24 siguió mostrando únicamente los ocho pingüinos y el
  cursor. La usuaria volvió manualmente a TWRP. Se montó `mmcblk1p2` como
  ext4 `ro,noload` y se extrajeron journals y logs gráficos a
  `work/v024-rootfs-logs-20260720/`.
- El boot nuevo `96a5a5ecfc28401a8010ad616a9a5afc` no está colgado. RNDIS
  obtiene carrier y `usb0=172.16.42.1`; NetworkManager arranca a 21,400 s,
  OpenSSH a 21,403 s y escucha desde 21,493 s, LightDM arranca a 21,791 s,
  `graphical.target` se alcanza a 21,797 s y slick-greeter continúa activo. El
  journal llega al menos a 51,296 s sin panic, oops ni stall.
- El servicio v0.24 nunca se ejecutó. A 10,892 s systemd registra literalmente
  que `graphical.target.wants/gts9uwifi-display-handoff.service` no es un
  symlink y lo ignora. La inspección del rootfs confirma que tanto la unidad
  wants como el script son ficheros regulares `0644`.
- La causa está en el instalador incremental: `make-twrp-zip.py` sí guardaba el
  script como `0755`, pero `mainline-update-binary` extraía cada miembro con
  `unzip -p` y aplicaba `chmod 0644` incondicional. La activación se había
  empaquetado como copia regular porque el overlay no preservaba symlinks. El
  rebote VT propuesto en v0.24, por tanto, no llegó a someterse a prueba.
- v0.25 amplía `ROOTFS-OVERLAY-SHA256SUMS` a `hash modo ruta`. El instalador
  acepta únicamente `0644`/`0755`, aplica el modo por miembro y, cuando existe
  la unidad de handoff, elimina la entrada anterior y crea el enlace real
  `graphical.target.wants/... -> ../gts9uwifi-display-handoff.service`.
- La comparación completa de Xorg/LightDM v0.11 frente a v0.24 no muestra una
  diferencia funcional aparte del kernel/cmdline/táctil: ambas usan Xorg
  1.21.1.23, VT7, 2960x1848, modesetting sobre simpledrm, glamor rechazado por
  llvmpipe, `ShadowFB` deshabilitado y el mismo `-novtswitch`. Sin embargo sólo
  v0.11 repintó físicamente el panel.
- Para no depender otra vez exclusivamente de ese page-flip, device r9 añade
  temporalmente `20-gts9uwifi-fbdev.conf`: fuerza el DDX fbdev y `ShadowFB`
  sobre `/dev/fb0`, que el kernel registra como `simpledrmdrmfb` y cuyo
  contenido de consola ya es visible. El handoff VT corregido se conserva como
  segunda vía de repintado.
- La build limpia v0.25 conserva kernel `7.2_rc3-r17`, firmware r1 y el
  aislamiento PMU WCN/PCIe0/PHY. Se verificaron device r9, `fbdev_drv.so`, la
  configuración X, script ejecutable, unidad/enlace, kbd y cmdline sin
  `console=tty0`.
- ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.25-fbdev-vt-rndis-sm-x910-twrp.zip`,
  80.853.846 bytes, SHA-256
  `8834678cceb50b7fc6d85b35daabcad8c57ff8ac0c34af3e8c7eaebcee74f054`.
  El manifiesto dentro del ZIP marca el script `0755`, el instalador incluido
  contiene la creación del symlink y la configuración fbdev está presente.
  Se copió a `/sdcard` y la única comparación local/remota coincide; el
  asistente no flasheó ninguna partición.
- Próxima prueba: flash manual v0.25 y dejar el sistema vivo/conectado por USB
  aunque la imagen no cambie. Probar SSH en `172.16.42.1` antes de volver a
  TWRP; si aún falla la presentación, el journal distinguirá de forma directa
  carga del DDX fbdev, resultado del handoff y estado de `/dev/fb0`.

## 2026-07-20 — sesión 38: VT7 validada, fbdev con sombra y captura v0.26

- Tras v0.25 la imagen física siguió en los pingüinos. Windows mantuvo el USB
  como `USB descriptor failure (Code 43)` incluso después de desconectar y
  reconectar físicamente, por lo que no se creó una interfaz RNDIS accesible y
  no fue posible usar SSH. La usuaria volvió manualmente a TWRP.
- La inspección offline confirma que el instalador v0.25 sí corrigió el fallo
  anterior: `20-gts9uwifi-fbdev.conf` está presente, el script es `0755` y
  `graphical.target.wants/gts9uwifi-display-handoff.service` es un enlace real
  hacia la unidad. Los hashes coinciden con el artefacto.
- El journal nuevo se extrajo a `work/v025-rootfs-logs-20260720/`. El boot
  `4803b789a4b545ff97b0829a4bac2062` monta el rootfs, crea RNDIS internamente,
  inicia NetworkManager/OpenSSH/LightDM y llega a `graphical.target` a
  23,453 s. Continúa registrando hasta al menos 905 s; no hay cuelgue, panic,
  oops ni stall.
- La unidad de handoff se ejecuta esta vez: X0 está listo, `fgconsole` devuelve
  1 antes del rebote y 7 después. El servicio termina correctamente a
  23,447 s. Por tanto la imagen estática no se debe ya a una activación rota ni
  a que la VT lógica permanezca en la consola.
- `Xorg.0.log` confirma el DDX solicitado: `fbdev_drv.so` usa `/dev/fb0`, ve
  hardware `simpledrmdrmfb`, 21.367 KiB, 2960x1848, pitch 2960 y 32 bpp. La
  opción `ShadowFB=true` está activa y carga `libshadow.so`. Los mensajes
  `FBIOPUTCMAP: Invalid argument` se repiten al programar la paleta, pero son
  no fatales: DPMS, extensiones, Goodix, sesión LightDM y slick-greeter siguen
  inicializando.
- Las dos rutas probadas quedan separadas: modesetting/simpledrm sin sombra
  (v0.23/v0.24) y fbdev con sombra (v0.25) mantienen el scanout físico. v0.26
  cubre el cuadrante restante cambiando sólo a `ShadowFB=false`, para que X
  renderice directamente sobre el mmap de `/dev/fb0`.
- El handoff v0.26 espera cinco segundos adicionales y lee exactamente
  21.880.320 bytes (`2960*1848*4`) desde `/dev/fb0` a
  `/var/log/gts9uwifi-fb0-after-x.raw`, sincroniza el archivo y registra su
  SHA-256. Si el panel no cambia, esa captura permitirá convertir y comparar
  el contenido real de X con los pingüinos sin depender de USB ni vídeo.
- Build limpia verificada: device r10, kernel `7.2_rc3-r17`, firmware r1 y
  kbd; configuración fbdev directa, captura, script ejecutable, enlace systemd
  y aislamiento WCN/PCIe0 presentes.
- ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.26-direct-fbdev-capture-sm-x910-twrp.zip`,
  80.854.080 bytes, SHA-256
  `e2713a80edebd9897ccbdf7a4143d83d055579fb896056b15156357816c9b876`.
  Se copió a `/sdcard` y la única comparación local/remota coincide. El
  asistente no flasheó ninguna partición.
- Próxima prueba: flash manual v0.26 y dejarla arrancada al menos 45 s. Si el
  panel sigue en los pingüinos y SSH no enumera, volver a TWRP sin necesidad de
  vídeo; extraer y convertir `gts9uwifi-fb0-after-x.raw` antes de cualquier
  cambio adicional.

## 2026-07-20 — sesión 39: framebuffer correcto y refresco KMS v0.27

- Tras v0.26 el panel siguió mostrando los pingüinos y Windows mantuvo el USB
  con Code 43, por lo que la usuaria regresó manualmente a TWRP. El asistente
  no escribió ninguna partición.
- Desde `mmcblk1p2` se recuperó
  `/var/log/gts9uwifi-fb0-after-x.raw`: mide exactamente 21.880.320 bytes
  (`2960*1848*4`) y su SHA-256 es
  `a987f44c03315694b0716b929f6d9c7bb2aeee0a3c412dd4871bc357689d6aed`.
- La conversión XRGB8888 little-endian se conserva en
  `work/v026-rootfs-logs-20260720/gts9uwifi-fb0-after-x.png`. La inspección
  visual muestra el greeter completo de LightDM, fondo XFCE, reloj, entrada de
  contraseña y teclado en pantalla. X dibuja correctamente; el panel físico
  continúa leyendo el buffer de la consola.
- La captura descarta de forma concluyente nuevos cambios ciegos en boot,
  systemd, LightDM, greeter, selección de VT o contenido de `/dev/fb0`. El
  defecto actual está entre el daño del buffer y el scanout físico de
  simpledrm.
- v0.27 cambia el DDX a `modesetting`, fija `AccelMethod=none` y
  `ShadowFB=true`. Después del handoff VT1→VT7 ejecuta con la autoridad de
  LightDM `xrandr --output None-1 --off`, espera un segundo y reactiva
  `None-1 --mode 2960x1848`, intentando forzar una copia de daño y actualización
  completa del plano KMS.
- Build limpia verificada: device r11, kernel `7.2_rc3-r17`, firmware r1 y
  kbd; configuración X, `xrandr`, script ejecutable, unidad/enlace systemd y
  nodos WCN/PCIe0/PHY deshabilitados presentes.
- ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.27-kms-shadow-refresh-sm-x910-twrp.zip`,
  80.854.291 bytes, SHA-256
  `e665a73e8efa51198f87a3fba2dc5bed8a8839406af00a05309d04b47bd58bc8`.
  Se copió a `/sdcard` y la única comparación local/remota coincide. Pendiente
  flash manual y validación física; el asistente no flasheó la tablet.

## 2026-07-20 — sesión 40: resultado físico v0.27

- La usuaria flasheó manualmente v0.27 y dejó la tablet arrancada y conectada.
  El panel continúa mostrando únicamente los ocho pingüinos del framebuffer de
  arranque; el refresco solicitado no produjo un cambio visible.
- El host no detecta ADB. Windows vuelve a enumerar el enlace como dispositivo
  USB desconocido con error de solicitud de descriptor (Code 43), y
  `172.16.42.1:22` no responde. Por tanto no es posible consultar en vivo el
  journal ni el resultado de `xrandr`.
- Próximo paso: regresar manualmente a TWRP y extraer en sólo lectura el journal
  de v0.27. Si el servicio confirma que `xrandr` desactivó/reactivó `None-1`,
  se abandona la capa X para este defecto y se instrumenta/corrige la ruta de
  actualización dirty/scanout de simpledrm en el kernel.

## 2026-07-20 — sesión 41: causa raíz encontrada (rpmhpd sync_state) y v0.28

- Desde TWRP se montó `mmcblk1p2` como `ro,noload` y se extrajo el journal
  completo de v0.27 (boot `2cbe9bc2f5fd4beda28cceaaeb934e9b`, reconstruido a
  partir de `system.journal` más los rotados) a
  `work/v027-rootfs-logs-20260720/`, junto con `Xorg.0.log`, ambos logs de
  LightDM y la nueva captura `gts9uwifi-fb0-after-x.raw`.
- El servicio de handoff v0.27 se ejecutó íntegro: `active-before=1`,
  `active-after=7`, ambos `xrandr` sin error y captura a los 32,69 s.
  `Xorg.0.log` registra el ciclo completo: `xrandr --off` reduce la pantalla a
  320x200 y produce ~100 `failed to add fb -22` (simpledrm limita
  min/max_width al modo firmware, EINVAL esperado), y `--mode 2960x1848`
  reasigna un framebuffer nativo nuevo sin error. Aun así el panel siguió en
  los pingüinos: la capa X queda definitivamente descartada.
- La captura fb0 de v0.27 (SHA-256 `dc6c3e70...`) es negra: con el DDX
  modesetting X dibuja en su dumb buffer, no en la emulación fbdev. Es
  coherente y no aporta contradicción.
- Comparando el dmesg de v0.18 (greeter visible) con v0.27 apareció la
  regresión estructural: los kernels de v0.4–v0.18 eran builds directas con
  release `7.2.0-rc3-dirty`, de modo que `/lib/modules/7.2.0-rc3` del rootfs
  nunca casaba y ningún módulo llegó a cargar (el journal v0.18 registra
  `modprobe: FATAL: Module ext4 not found in directory
  /lib/modules/7.2.0-rc3-dirty`). Desde v0.19 el boot usa el payload APK con
  release `7.2.0-rc3` y udev coldplug carga por fin el árbol de módulos.
- La cadena causal exacta del panel congelado: `sm8550.dtsi` deja `dispcc`,
  `videocc` y `camcc` habilitados (mdss está `disabled`, `msm.ko` no carga);
  el rootfs contiene `dispcc-sm8550.ko`, `videocc-sm8550.ko`,
  `camcc-sm8550.ko` y sus alias casan con los nodos DT. `qcom-rpmhpd`
  mantiene cada dominio en su corner de arranque hasta `sync_state()`, que
  dispara cuando TODOS sus consumidores DT han sondeado; el journal muestra
  `qcom-rpmhpd ... sync_state() pending due to ade0000/aaf0000
  .clock-controller` justo antes del coldplug. Al cargar esos módulos
  (~17–20 s), rpmhpd ejecuta sync_state, suelta el voto de arranque de MMCX y
  el MDSS/DSI se apaga; el panel AMOLED en command-mode retiene el último
  frame de su GRAM: los ocho pingüinos.
- La evidencia temporal encaja al milisegundo: la foto v0.21 quedó congelada
  tras `SM-X910 WCN diag: power sequencer registered` (20,208 s), y su
  journal sitúa la carga de qcomtee/rtc/clock-controllers justo en esa
  ventana; en v0.27 esos módulos cargan entre 17 y 20,3 s, antes de que X
  arranque a los 21,6 s. En v0.11–v0.18 el mismo sync_state quedaba pendiente
  para siempre y por eso el greeter sí se veía.
- v0.28 aplica la corrección mínima reproducible: device r12 instala
  `/usr/lib/modprobe.d/gts9uwifi-display-hold.conf` con `blacklist` de
  `dispcc_sm8550`, `videocc_sm8550`, `camcc_sm8550` y `gpucc_sm8550`. Sólo
  bloquea el autoload por modalias; los módulos siguen empaquetados y el
  fichero debe eliminarse cuando exista el stack DRM/DSI real. No cambia
  kernel, DTB, cmdline, X ni el aislamiento WCN/PCIe0.
- Build limpia verificada: device r12, kernel `7.2_rc3-r17`, firmware r1 y
  kbd; blacklist con los cuatro módulos, los `.ko` conservados en el árbol,
  configuración X modesetting/sombra intacta, script/unidad/enlace de handoff
  presentes, cmdline sin `console=tty0` y los tres nodos WCN/PCIe0
  deshabilitados.
- ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.28-hold-boot-display-sm-x910-twrp.zip`,
  80.855.122 bytes, SHA-256
  `a9b169d40400cfa0bea239138194ce36dd428a9e492a52e6e60c590ec5ddfedc`.
  El manifiesto del overlay transporta
  `usr/lib/modprobe.d/gts9uwifi-display-hold.conf` con modo `0644`. Se copió a
  `/sdcard` y la única comparación local/remota coincide; el asistente no
  flasheó ninguna partición.
- Próxima prueba: flash manual v0.28 y dejar la tablet arrancada al menos
  60 s. Si el diagnóstico es correcto, rpmhpd nunca ejecutará sync_state, el
  scanout del bootloader seguirá vivo y el greeter de LightDM debe sustituir
  físicamente a los pingüinos (con el parpadeo del rebote VT y del ciclo
  xrandr por el camino). Si sigue congelado, la siguiente iteración añadirá
  `console=tty0` para fechar el instante exacto de la congelación con el
  último printk visible y continuar el bisect de módulos (qcomtee, qcom_ice,
  icc_bwmon, icc_osm_l3).

## 2026-07-20 — sesión 42: v0.28 refuta MMCX, red USB viva y v0.29 (TZ/SCM)

- La usuaria flasheó v0.28; el panel siguió en los pingüinos. Con la tablet aún
  en pmOS se recuperó por primera vez el enlace de red USB: forzando el driver
  compuesto USB en Windows (devcon + re-scan), el gadget enumeró como
  `UsbNcm Host Device` con `172.16.42.2` en el host y `ping 172.16.42.1`
  respondiendo (1 ms, TTL 64). El sshd respondía, pero el `172.16.42.1` de esa
  prueba resultó ser OTRO dispositivo de la LAN, no la tablet; la usuaria
  confirmó que la contraseña de `phablet` es `<DEV_PASSWORD>` y movió la tablet a TWRP.
- Desde TWRP (`mmcblk1p2` `ro,noload`) se extrajo el journal de v0.28 a
  `work/v028-rootfs-logs-20260720/`. Confirmado: el fichero
  `/usr/lib/modprobe.d/gts9uwifi-display-hold.conf` está presente con su
  contenido (el `V:1-r3` del apk db es esperado: el overlay copia ficheros pero
  no reescribe la base apk).
- El blacklist FUNCIONÓ pero la hipótesis era incompleta: en el boot
  `fb59080f343b4d3bafdb6aaaa446e1b4` no aparece ningún `dispcc/videocc/camcc`
  y `qcom-rpmhpd ... sync_state() pending due to ade0000/aaf0000` sigue
  pendiente igual que en v0.11–v0.18. Aun así, pingüinos. Por tanto el voto
  MMCX/sync_state NO es el diferenciador.
- Nueva lectura decisiva: el scanout muere ~18–20 s, mucho antes de X (en v0.21
  con `console=tty0` el panel se congeló a 20,2 s). En esa ventana v0.28
  ejecuta dos drivers nuevos desde v0.19 que hacen llamadas SCM a TrustZone:
  `qcom-ice 1d88000.crypto` (18,59 s) y `qcomtee QTEE 5.2.0` (18,62 s). En este
  XBL Samsung la TZ suele ser dueña del splash; una llamada SCM puede desmontar
  el pipeline de display del bootloader. Ninguno cargaba en las builds `-dirty`
  de v0.11–v0.18 que sí mostraban el greeter. No hay ningún mensaje de display
  en el kernel tras `simpledrm fb0` (1,14 s), coherente con un teardown externo
  (TZ), no de un driver Linux.
- v0.29 (device r13) añade al blacklist `qcomtee` y `qcom_ice`. Seguro para el
  arranque: la raíz es la microSD (`sdhc_2`, `8804000.mmc`); el ICE `1d88000`
  pertenece a la UFS interna que no tocamos, y nada del bring-up usa qcomtee.
  Mantiene el blacklist de los mm clock controllers (inofensivo) y no cambia
  kernel, DTB, cmdline ni el aislamiento WCN/PCIe0.
- Build limpia verificada: device r13, kernel `7.2_rc3-r17`, firmware r1 y kbd;
  los seis módulos en el blacklist y sus `.ko` conservados. ZIP:
  `postmarketos-edge-xfce-mainline-v0.29-hold-tz-display-sm-x910-twrp.zip`,
  80.855.449 bytes, SHA-256
  `3d9ecfcc78699d7dfa47baf6ea9175b3068d8ea7c973324ab4d7641e73ecb460`,
  copiado a `/sdcard` con la única comparación local/remota coincidente. El
  asistente no flasheó ninguna partición.
- Durante esta sesión se resolvió además el acceso USB: forzar el driver
  compuesto USB de Windows (`devcon update usb.inf`) tras un re-scan hace que el
  gadget RNDIS/NCM enumere como `UsbNcm Host Device` y `172.16.42.x` quede
  enrutable. Es la primera vez que el enlace USB de pmOS es utilizable desde
  Windows (antes siempre Code 43).
- Próxima prueba: flash manual v0.29, dejar ≥60 s. Si el panel muestra el
  greeter, `qcomtee`/`qcom_ice` (SCM→TZ) eran quienes desmontaban el splash y
  el hito de escritorio queda alcanzado. Si sigue en pingüinos, la teoría TZ se
  descarta y la siguiente build restaura `console=tty0` para fechar visualmente
  el instante exacto de la congelación (técnica ya validada en v0.21).

## 2026-07-20 — sesión 43: auditoría v0.19 y baseline recuperable v0.30

- Se revisaron los cambios y la documentación dejados por el agente anterior.
  v0.27 descarta correctamente X/LightDM/VT; v0.28 bloqueó los clock
  controllers multimedia, el journal confirmó que el blacklist funcionaba y
  la prueba física refutó que MMCX/rpmhpd fuese por sí solo la causa.
- v0.29 añade `qcomtee` y `qcom_ice` por correlación temporal con 18,59–18,62 s,
  pero no se considera aún una solución demostrada. La transición v0.19 no
  activó sólo esos dos módulos: cambió del kernel directo
  `7.2.0-rc3-dirty`, sin directorio de módulos coincidente, al kernel APK
  `7.2.0-rc3` con coldplug completo, además de añadir WCN/RNDIS y modificar el
  DT. Hace falta un control total antes del bisect.
- El Xorg log físicamente funcional de v0.18 usa modesetting simpledrm por
  defecto, rechaza glamor/llvmpipe, deja `ShadowFB` deshabilitado y activa
  2960x1848 en VT7. Las configuraciones forzadas y el servicio de rebote
  VT/xrandr son posteriores y se neutralizan para el control.
- v0.30 reutiliza byte por byte las cinco imágenes de boot del ZIP v0.18:
  `boot.img=f5307277...`, `init_boot.img=bedcad22...`,
  `vendor_boot.img=a5ce2203...`, `dtbo.img=c17418be...` y
  `vbmeta.img=b95e5ef9...`. Esa combinación ya mostró físicamente LightDM y
  conserva el táctil corregido.
- El ZIP se regenera con el instalador TWRP actual para aceptar
  `ID="postmarketos"`, validar el overlay y manejar vbmeta read-only. El
  overlay deja `20-gts9uwifi-fbdev.conf` sin secciones Xorg y reemplaza el
  script de handoff por un no-op, reproduciendo el comportamiento gráfico
  anterior a v0.19 sobre el rootfs actual.
- Se añadieron `scripts/package-v018-display-baseline.sh` y
  `configs/display-baseline/` para que la build de recuperación sea
  reproducible y no un parche manual de la instalación.
- ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.30-known-good-v018-display-sm-x910-twrp.zip`,
  22.018.867 bytes, SHA-256
  `4f4797b29559496aa678f70e2f2a51bbb510b58258a49d62f4b3355b6735c83b`.
  Se copió a `/sdcard` y la comparación local/remota coincide; el asistente no
  flasheó ninguna partición.
- Próxima prueba: flash manual v0.30 y esperar al menos 60 s. Si vuelve el
  greeter, conservar la tablet sobre esta base usable y hacer un bisect por
  grupos de los módulos que empezaron a cargar en v0.19, trasladando al kernel
  r17 únicamente la exclusión causal mínima.

## 2026-07-20 — sesión 44: v0.30 visible y aislamiento sin módulos v0.31

- La usuaria flasheó manualmente v0.30. El control funcionó: la tablet arranca,
  el táctil responde y se puede iniciar sesión hasta llegar al escritorio.
  Esto confirma que el rootfs actual no es la causa y recupera una base
  físicamente usable anterior a la regresión v0.19.
- Windows enumera además `UsbNcm Host Device #7`; el host usa
  `172.16.42.2/24` y `172.16.42.1:22` responde con OpenSSH 10.3. El usuario
  configurado sigue siendo `phablet`, pero la autenticación automatizada con
  la contraseña documentada `<DEV_PASSWORD>` fue rechazada; no se alteró el sistema vivo.
- Para separar los dos cambios simultáneos de v0.19 se construyó v0.31 con el
  kernel y DTB actuales mediante `scripts/build-mainline-kernel.sh`, pero sin
  módulos. El release embebido es `7.2.0-rc3-dirty` y el rootfs no contiene un
  directorio coincidente, reproduciendo el aislamiento de módulos de v0.18 sin
  revertir los arreglos actuales del kernel/DTS.
- El DTB v0.31 confirma `status=disabled` para WCN PMU, PCIe0 y PCIe0 PHY. El
  overlay conserva Xorg modesetting por defecto y el handoff no-op validado en
  v0.30. Se añadió `scripts/build-current-no-modules-control.sh` para hacer la
  prueba reproducible.
- ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.31-current-kernel-no-modules-sm-x910-twrp.zip`,
  22.008.887 bytes, SHA-256
  `be37c78307d00dc065ed368ec4e35ecac434d7a11beead7b010e924ae1406d0e`.
  Se copió a `/sdcard` desde TWRP y la única comparación local/remota coincide.
  v0.30 permanece en la tarjeta como rollback visible; el asistente no flasheó
  ninguna partición.
- Interpretación prevista: si v0.31 muestra el escritorio, el culpable es uno
  de los módulos que empezaron a cargar en v0.19; si muestra pingüinos, debe
  bisectarse kernel/DTS/initramfs entre v0.18 y la base actual.

## 2026-07-20 — sesión 45: v0.31 a LightDM, Goodix completo y v0.32

- La prueba física v0.31 confirma que los ocho pingüinos son sólo el contenido
  inicial: tras unos segundos el panel cambia y aparece LightDM. El kernel y
  DTB actuales, el initramfs y el userspace quedan validados para display al
  conservar el release `7.2.0-rc3-dirty` sin módulos coincidentes. La regresión
  permanente de v0.19–v0.29 está causada exclusivamente por uno de los módulos
  que entonces empezaron a autocargarse.
- El táctil no respondió en v0.31. NCM enumeró y el puerto SSH respondió en
  `172.16.42.1`, pero la autenticación `phablet`/`<DEV_PASSWORD>` fue rechazada de nuevo,
  por lo que la usuaria regresó manualmente a TWRP.
- Se montó `mmcblk1p2` desde TWRP con `ro,noload` y se extrajeron journals,
  dmesg y logs X/LightDM a `work/v031-rootfs-logs-20260720/`. El boot relevante
  es `b3a671533e71486d949090199774a7dc`: LightDM arranca a 19,369 s y el no-op
  termina a 19,657 s. Goodix está registrado y recibe actividad, pero todos los
  paquetes se descartan como `touch data checksum error`.
- La comparación del kernel v0.18 con v0.31 localizó la diferencia. v0.18
  contiene el mensaje `forcing 16-byte Samsung events for firmware PID 6936`
  y la prelectura de un solo contacto; v0.31 no contenía el mensaje. El
  worktree directo conservaba un parche Samsung parcial y la guarda del script
  sólo buscaba `GOODIX_BERLIN_SAMSUNG_EVENT_ID_MASK`, por lo que saltaba
  incorrectamente el parche completo.
- Se añadió
  `upgrade-partial-goodix-samsung-events.patch` y se endureció
  `scripts/build-mainline-kernel.sh`: ahora exige el mensaje final exacto. Si
  detecta un estado parcial, añade `GOODIX_BERLIN_PRE_READ_TOUCHES=1`, fuerza
  16 bytes para PID 6936 y lee inicialmente un único contacto (26 bytes); si
  no encuentra ningún soporte Samsung, aplica el parche completo existente.
- El kernel v0.32 recompilado contiene el mensaje PID 6936, release
  `7.2.0-rc3-dirty` y la fuente compilada confirma la prelectura de un contacto.
  Mantiene el DT actual con WCN PMU, PCIe0 y PHY deshabilitados y sigue sin
  directorio de módulos coincidente, para cambiar una sola variable respecto a
  v0.31.
- ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.32-current-kernel-goodix-no-modules-sm-x910-twrp.zip`,
  22.007.128 bytes, SHA-256
  `c4509790f42bb6cff93e73ca0a7bdd2609d6c2b1f19eb6a6526bac263d5a67b9`.
  Se copió a `/sdcard` y la única comparación local/remota coincide. v0.30
  permanece como rollback; el asistente no flasheó ninguna partición.
- Próxima prueba: flash manual v0.32. El resultado esperado es el mismo
  handoff a LightDM de v0.31 con el táctil funcional. Si se confirma, se usará
  esta base para un bisect acumulativo de los módulos y conservar USB SSH antes
  de retomar WCN7850.
