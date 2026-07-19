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
