# Port de postmarketOS para Samsung Galaxy Tab S9 Ultra Wi-Fi

> Documento vivo del proyecto. Debe actualizarse con cada avance, fallo,
> decisión de arquitectura y artefacto generado.
>
> Última actualización: 2026-07-19.

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
| Kernel mainline SM8550 | ✅ v0.11 arranca Linux 7.2-rc3; v0.14 fuerza el layout Goodix 6936 real y programa el PTN3222 por I2C |
| DTS `gts9uwifi` | 🟡 v0.14 incluye tamaño táctil, reset y tuning PTN3222 exactos; framebuffer, SD, UART y GT9916 descritos |
| Acceso temprano a microSD | ✅ Mainline enumera físicamente `mmcblk1`, `mmcblk1p1` y `mmcblk1p2` |
| Paquetes pmaports | ✅ Fuentes r9 reproducen GPI DMA, EVDEV, Goodix Samsung y tuning I2C PTN3222; build limpia validada |
| Rootfs postmarketOS | ✅ v0.11 monta físicamente la imagen GPT v0.6 desde microSD y arranca systemd |
| Escritorio | ✅ LightDM/XFCE4 muestran la pantalla de login `phablet` mediante simpledrm |
| SSH | 🔴 v0.14 no enumera NCM/RNDIS ni ofrece SSH por USB/LAN; pendiente journal v0.14 |
| Táctil | 🔴 v0.14 llega a LightDM pero sigue sin entrada; pendiente confirmar layout 8/16 en journal |
| Bundle Android v4 | ✅ v0.14 LZ4 legacy, imágenes, AVB, Goodix forzado, tuning PTN y reproducción validados |
| Restauración Ubuntu Touch | ✅ ZIP boot-only v8/DTBO stock generado y validado |
| Imagen/paquete de prueba | 🧪 SD v0.6 + ZIP v0.14 arrancan hasta login; táctil y USB/SSH siguen bloqueados |

## Reto en curso

Extraer el journal v0.14 para obtener el primer acceso interactivo:

- v0.11 queda validada físicamente: ejecuta `/init`, monta `pmOS_boot` y
  `pmOS_root`, arranca systemd, LightDM y XFCE4, y conserva correctamente el
  framebuffer del bootloader. El arreglo LZ4 era la barrera exacta;
- el journal v0.12 extraído en sólo lectura demuestra que `gpi_dma1` ya permite
  sondear I2C4: Goodix registra `Goodix Berlin Capacitive TouchScreen` como
  `input0`. Cada paquete se rechaza después con `touch data checksum error`;
- el journal v0.13 corrige la hipótesis anterior: el firmware PID `6936`
  anuncia `event layout 8/8`, pero los dumps muestran que el checksum está
  después de 16 bytes y el driver Samsung usa incondicionalmente ese tamaño.
  v0.14 fuerza 16 sólo para PID 6936 y conserva el formato upstream normal;
- el journal v0.12 fija la cadena USB diferida en PTN3222 y registra
  `pin_config_group_set op failed for group 3`. El reset PM8550VS-D GPIO4
  copiaba `drive-strength`, no aceptado por `qcom-spmi-gpio`; v0.13 reproduce
  el estado stock con `qcom,drive-strength`, `power-source`, entrada/salida,
  push-pull y bias deshabilitado;
- la prueba física v0.13 sigue llegando a LightDM, pero el táctil no responde.
  Windows no enumera ADB, ACM ni NCM/RNDIS y conserva dos errores de descriptor;
  tampoco responde `172.16.42.1:22` ni apareció otro SSH en la LAN, excluyendo
  expresamente `.138` y `.150`, que son otros dispositivos conocidos;
- el journal v0.13 demuestra que el pinctrl ya funciona y el PTN3222 deja de
  estar diferido, pero DWC3 falla el soft reset. El driver mainline sólo saca
  el repetidor de reset; Samsung además escribe `06=20`, `07=21`, `08=63` y
  `0a=01`. v0.14 aplica esa secuencia I2C exacta tras esperar 4–5 ms;
- la prueba física v0.14 vuelve a LightDM, pero el táctil no responde. Windows
  conserva dos errores de descriptor, sin ADB/ACM/NCM/RNDIS; no responde
  `172.16.42.1:22` ni apareció otro SSH en la LAN al excluir `.138` y `.150`;
- volver a TWRP y extraer el journal v0.14 en sólo lectura. Hay que verificar
  si registra `event layout 8/16`, si persisten los checksum errors, si el
  PTN3222 anuncia cuatro overrides o falla al escribirlos, y el estado DWC3;
- una vez exista SSH, depurar en vivo Goodix, DRM nativo y el resto del
  hardware sin depender de ciclos TWRP.

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
- El primer reboot con v0.1 no llegó a Linux: la pantalla con datos RPMB y
  código de barras era Odin lanzado por ABL. `/proc/last_kmsg` conserva la
  causa exacta: ABL descomprime el kernel, registra `No match found for Soc
  Dtb type` y `Appended Soc Device Tree blob not found`, y entra en Odin.
  `pstore` está vacío porque el kernel nunca recibió el control.
- Comparar el DTB mainline con el FDT vivo reveló que la raíz mainline sólo
  tenía `samsung,gts9uwifi`/`qcom,sm8550`; faltaban los selectores downstream
  que Samsung ABL usa antes de arrancar. El DTS contiene ahora, exactamente,
  `qcom,kalama-mtp`, `qcom,kalama`, `qcom,mtp`, los cuatro pares
  `qcom,msm-id` y `qcom,board-id = <0x10008 0x03>`.
- Generado el ZIP v0.2, SHA-256
  `9288af69c694fdc84b7b1f9694265152c5f7959a880d338f98b2e3d106c0f65c`.
  Conserva kernel, initramfs, DTBO, vbmeta y rootfs de v0.1; sólo cambia
  `vendor_boot` por el DTB corregido. El validador comprueba también los
  selectores de ABL extraídos del propio `vendor_boot`. El ZIP se copió a
  `/sdcard/` y se verificó allí el mismo hash; no se flasheó.
- El arranque v0.2 confirmó que los selectores son correctos: desapareció por
  completo `No match found for Soc Dtb type` y ABL ejecutó `FindBestMatch`.
  La siguiente barrera fue `ApplyOverlay: ufdt apply overlay failed`, seguida
  de `Root Node is not found at BoardDtb`, `Invalid device tree header` y Odin.
  El fallo se reprodujo dos veces y Linux tampoco llegó a ejecutarse.
- El DTB Samsung funcional contiene `/__symbols__`; v0.2 no lo contenía porque
  upstream no compila este DTB como base de overlays. Se añadió
  `DTC_FLAGS_sm8550-samsung-gts9uwifi := -@`. El DTB v0.3 exporta 474 símbolos
  y tanto `fdtoverlay` como `ufdt_apply_overlay` oficial aplican correctamente
  el overlay no-op board03 sobre él.
- Generado el ZIP v0.3, SHA-256
  `0a0d5b0e749c17155a0503e1c6a14e340ea3b9b437a3fbbcfbd77d9219bde240`.
  De nuevo conserva kernel, initramfs, DTBO, vbmeta y rootfs; sólo cambia el DTB
  dentro de `vendor_boot`. Se reprodujo byte a byte, se copió a `/sdcard/` y
  se verificó allí el mismo hash; no se flasheó.
- El arranque v0.3 volvió a fallar exactamente en `ufdt_apply_overlay`, con
  los mismos mensajes y unos 10,6 ms que v0.2. Por tanto `/__symbols__` no era
  suficiente para el fork Samsung. Se deja de iterar sobre el overlay no-op.
- El flujo Qualcomm ABL de referencia (`BootLinux.c`, commit `2a0c8e97...`)
  demuestra una segunda ruta: si `dtbo` no es una tabla Android válida, ABL
  no invoca ufdt y busca un FDT concatenado justo después del miembro gzip del
  kernel. Esta ruta no necesita adivinar PMIC IDs ni fusionar nodos downstream.
- Generado el ZIP v0.4, SHA-256
  `2083daf1ad515b32634a8f5686adc4972064ff8fd03153da0e6654d49f97a679`.
  `boot` contiene el payload empaquetado original seguido byte a byte por el
  DTB mainline; `dtbo` conserva tamaño/footer AVB correctos pero empieza por
  cero para forzar el fallback. `vendor_boot` mantiene otra copia del DTB. El
  ZIP se reprodujo, se copió a `/sdcard/` y se verificó allí; no se flasheó.
- El arranque físico v0.4 superó por primera vez toda la cadena ABL: apareció
  la salida verbose y el logo de Linux mediante el framebuffer conservado.
  Después el SoC se reinició; por tanto el fallback appended-DTB queda validado
  y el fallo actual ya está dentro de Linux/firmware, no en el cargador.
- Desde TWRP se guardaron `/proc/last_kmsg`, dmesg y pstore en
  `work/v04-linux-crash-20260718/`. Pstore estaba vacío, pero el registro de
  reset identifica `TZBSP_ERR_FATAL_NOC_ERROR`; Samsung cifra el detalle del
  maestro/esclavo NoC y no permite atribuirlo a un driver concreto.
- Comparar el DTB v0.4 compilado con el FDT vivo reveló que al evitar la DTBO
  stock faltaban carveouts de placa que ABL no reconstruye: UH/KASLR,
  `chipinfo`, `sec_xbl`, LLCC y casi 180 MiB de memoria alta de
  bootloader/depuración segura. Sólo `sec_log_buf` estaba reservado. Linux
  podía tratar las demás zonas protegidas como RAM ordinaria, causa coherente
  con el fatal NoC.
- El DTS v0.5 replica los rangos fijos exactos del FDT vivo y amplía
  `hwfence-shbuf` al tamaño X910. El DTB de 152.392 bytes tiene SHA-256
  `78397ab9c916084a68b37a5b19de2d1cd2619691201552f1ecc60a483ab44cd0`;
  el validador exige individualmente los 15 carveouts críticos.
- ZIP v0.5:
  `postmarketos-edge-xfce-mainline-v0.5-sm-x910-twrp.zip`, 21.885.945 bytes,
  SHA-256
  `1ae10d4effba444a3d970e9c6a68bd11f9304692a7bffcf309633b9063388314`.
  Headers, AVB, appended DTB, reservas, tamaños, CRC, manifiestos y reproducción
  byte a byte pasaron. Se copió a `/sdcard/` y se verificó allí el mismo hash;
  no se flasheó.
- El arranque v0.5 volvió a mostrar Linux y terminó con el mismo fatal NoC.
  TWRP confirmó `restart_reason = 0x5023a01` y
  `TZBSP_ERR_FATAL_NOC_ERROR`; por tanto los carveouts quedan conservados por
  corrección, pero no eran el desencadenante inmediato del reset.
- El vídeo `20260718_033322.mp4` permite leer el final de `initcall_debug`.
  A `26.772 s` regresan correctamente `7400000.interconnect` y
  `7430000.interconnect`; el siguiente proveedor según `sm8550.dtsi` es
  `lpass_ag_noc@7e40000`, pero nunca aparece su retorno antes del apagado.
- v0.6 deshabilita sólo `lpass_ag_noc`, innecesario para SD/pantalla/SSH. Los
  otros dos NOC LPASS permanecen activos porque la evidencia demuestra que sus
  probes terminan. Se añade además una consola built-in que escribe el printk
  en el ring Samsung `sec_log_buf` con cabecera `LOGM`, legible por el siguiente
  TWRP mediante `/proc/last_kmsg`.
- Se reconstruyeron el APK `linux-samsung-gts9uwifi-mainline-7.2_rc3-r4`,
  módulos, initramfs y rootfs. Release y vermagic son `7.2.0-rc3`; el payload
  empaquetado contiene la consola persistente y el DTB instalado marca
  `7e40000` como `disabled`.
- Artefactos v0.6 reproducidos byte a byte: imagen SD comprimida SHA-256
  `6250db18ed8afaad2afd8d98dad376305fccefa0518be806c3cf08af0791939e`
  y ZIP TWRP SHA-256
  `0890bbe1160aa5b03d40963209ae2a5193d7857531ee2518f0adbaf522d31a9a`.
  El ZIP se copió a `/sdcard/` y se verificó allí; no se flasheó.
- El arranque físico v0.6 volvió a reiniciar con
  `TZBSP_ERR_FATAL_NOC_ERROR`; por tanto `lpass_ag_noc@7e40000` no era el
  desencadenante. La consola `LOGM` sí funcionó: TWRP expuso un
  `/proc/last_kmsg` de 453.717 bytes con el log completo de Linux desde
  `Linux version 7.2.0-rc3` hasta deferred probe. Ya no hacen falta vídeos
  para las iteraciones normales.
- El último retorno es de nuevo `7430000.interconnect` a 26,813 s. Antes,
  `8804000.mmc` había devuelto `-EPROBE_DEFER`, por lo que su reintento es el
  siguiente candidato por orden del DT. La v0.7 instrumenta
  `really_probe_debug()` para persistir dispositivo y driver antes de entrar
  en `->probe()`.
- ZIP diagnóstico v0.7 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.7-probe-trace-sm-x910-twrp.zip`,
  22.012.743 bytes, SHA-256
  `1362e7f9ecf4cedd082af4cbabb963a651215292a7bcd847007978bf5bd3c2be`.
  Pasó bundle Android v4, AVB, appended-DTB, tamaños, hashes internos y CRC;
  se copió y verificó con el mismo hash en `/sdcard`. No requiere reescribir
  la SD v0.6 y el asistente no lo flasheó.
- El arranque v0.7 confirmó el valor de la traza: tras completar
  `7430000.interconnect`, la última línea mainline es
  `probing f100000.pinctrl with driver sm8550-tlmm`; no existe retorno y el
  siguiente XBL registra `TZBSP_ERR_FATAL_NOC_ERROR`. `8804000.mmc` queda
  descartado como desencadenante de este reset.
- El FDT vivo/DTBO Samsung marca GPIO36–39 como reservados en TLMM. Esa
  información faltaba en el DTS mainline; la placa mainline Fold5 usa el mismo
  patrón con `gpio-reserved-ranges`. v0.8 añade exactamente `<36 4>`, sin
  importar los GPIO50–51 que son específicos del Fold5.
- ZIP v0.8 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.8-tlmm-reserved-sm-x910-twrp.zip`,
  22.012.795 bytes, SHA-256
  `74607d30076c92cc7fcae787534e26d9ea083a4da60280c551e0a75e87788c92`.
  Bundle Android v4, AVB, appended-DTB, propiedad compilada, tamaños, hashes
  internos y CRC pasaron; el ZIP se copió y verificó en `/sdcard`. No requiere
  reescribir la SD v0.6 y el asistente no lo flasheó.
- El arranque físico v0.8 ya no reinició por TrustZone: quedó detenido en un
  kernel panic normal hasta que la usuaria reinició manualmente a TWRP. Esto
  valida físicamente `gpio-reserved-ranges = <36 4>` y elimina el fatal NoC
  que bloqueaba todas las versiones v0.4–v0.7.
- El `/proc/last_kmsg` posterior contenía 2.097.136 bytes del recovery anterior,
  no el panic mainline. El reinicio manual no ejecutó la ruta Samsung que
  actualiza `previous_index`; nuestro ring sólo avanzaba `index`. v0.9 actualiza
  ambos índices en cada escritura para preservar el log en esta situación.
- ZIP v0.9 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.9-panic-log-sm-x910-twrp.zip`,
  22.012.505 bytes, SHA-256
  `e7a2d8b3264cc94cdf6863d8abdbbd5c90e6515d1c4577b4f3fd3651fd680375`.
  Conserva el DTB v0.8, initramfs, módulos y SD; sólo cambia el kernel built-in
  del logger. Pasó bundle, AVB, appended-DTB, tamaños, hashes internos y CRC;
  se copió y verificó en `/sdcard`. El asistente no lo flasheó.
- La primera captura posterior a v0.9 se realizó con TWRP a 1.026 s de uptime.
  `/proc/last_kmsg` ya medía el máximo de 2.097.136 bytes y sólo contenía el
  recovery actual: sus mensajes habían dado una vuelta completa al ring y
  sobrescrito el panic. No requiere otra build; se repetirá el mismo v0.9 y se
  extraerá el fichero inmediatamente después de volver a TWRP.
- Repetir v0.9 y capturar a los 146 s tampoco recuperó mainline. El ring muestra
  `XBL(28, restored from storage)`: el reset forzado desde el panic restaura la
  copia persistida del recovery anterior y descarta el `sec_log_buf` mainline;
  no era sólo una carrera contra el volumen de printk.
- El driver Samsung moderno confirma que `last_kmsg` copia el ring usando
  `idx` al arrancar y después registra el logger actual. La solución práctica
  es conservar RAM mediante un reinicio caliente del propio kernel.
- ZIP v0.10 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.10-auto-panic-sm-x910-twrp.zip`,
  22.012.502 bytes, SHA-256
  `47331b9616f68048f381b61d52e9a6e1ff74f3ab35dcb46addae5d39e7ae372a`.
  Sólo cambia la cmdline de `vendor_boot`: `panic=10`, sin `initcall_debug` y
  con `loglevel=7`. Kernel, DTB, initramfs, módulos y SD no cambian. Pasó AVB,
  bundle, hashes, tamaños, CRC y reproducción; se verificó en `/sdcard`.
- Las pruebas físicas de v0.10 no recuperaron mainline en `last_kmsg`: el
  fichero de 2.097.136 bytes vuelve a contener recovery/XBL restaurado. La
  inspección completa del initramfs reveló que su ruta de fallo no hace panic:
  crea `PMOS_LOGS`, entra en shell y queda en un bucle infinito.
- Se reinició la v0.10 ya instalada sin reflashear y se sondeó el host durante
  más de 80 s. No aparecieron almacenamiento masivo, ACM ni red USB; sí dos
  instancias de dispositivo USB desconocido por fallo al solicitar descriptor.
  Esto confirma actividad física parcial del enlace, pero no un gadget usable.
- La foto fija de v0.10 hizo legible el diagnóstico que faltaba: Linux imprime
  `Initramfs unpacking failed: invalid magic at start of compressed archive`,
  espera root, lista `mmcblk1`, `mmcblk1p1` y `mmcblk1p2`, y finalmente hace
  panic por `unknown-block(0,0)`. No llegó a ejecutar `/init`; la hipótesis del
  bucle de `fail_halt_boot()` queda descartada para esta versión.
- TWRP confirma que la misma SD tiene `pmOS_boot` ext2 y `pmOS_root` ext4;
  puede montar `p1`, y un `e2fsck -n` recorre sus cinco pasadas. El fallo no es
  ausencia de tarjeta ni de particiones.
- El ramdisk genérico v0.10 es un gzip válido de 2.134.007 bytes que expande a
  un CPIO válido de 7.168.248 bytes. El kernel tiene todos los descompresores
  `CONFIG_RD_*`, pero stock empaqueta ambos ramdisks Android v4 con LZ4 legacy.
- El generador usa ahora LZ4 legacy por defecto para `init_boot`; el validador
  exige la magia stock, prueba ambos streams y compara el CPIO descomprimido
  con el initramfs pmOS original.
- ZIP v0.11 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.11-lz4-initramfs-sm-x910-twrp.zip`,
  21.988.029 bytes, SHA-256
  `9cdc1bdd4d6be730a3b64fd66c5413794889f6cc1c0fcc25ea1977604a3713f1`.
  Sólo cambia `init_boot.img` (SHA-256
  `bedcad22a49dbf442641dcaf13e3290edd87b221cbca6fb8f47b8f2460c16922`);
  se validó, reprodujo, copió a `/sdcard` y verificó allí. El asistente no lo
  flasheó.
- La prueba física v0.11 supera completamente el panic: monta las dos
  particiones pmOS de la microSD, arranca systemd y muestra LightDM/XFCE4 a
  resolución completa mediante simpledrm. Es el primer escritorio mainline
  arrancado en la SM-X910.
- El sondeo del host con el sistema vivo no encontró NCM/RNDIS, ACM ni SSH en
  `172.16.42.1`. Windows conserva dos errores de descriptor y la consola de
  Linux muestra que DWC3 no inicializa el core por timeout. Pantalla y SD son
  independientes de este fallo.
- Desde TWRP se montó `/dev/block/mmcblk1p2` exclusivamente en lectura y se
  extrajo el journal persistente v0.11 a
  `work/v011-rootfs-logs-20260719/`. USB falla exactamente durante el soft
  reset de DWC3 (`a600000.usb`, `-ETIMEDOUT`) y `a90000.i2c` queda diferido al
  no obtener su canal TX DMA. No se modificó el rootfs de la tarjeta.
- La auditoría de Linux 7.2-rc3 encontró el soporte upstream exacto
  `drivers/phy/phy-nxp-ptn3222.c` y su binding. El DTS v0.12 reproduce del FDT
  X910 el PTN3222 en I2C6 `0x4f`, LDO5B a 3.104 V, LDO15B a 1.8 V y reset
  PM8550VS-D GPIO4 activo-bajo; la PHY HS lo referencia mediante `phys`.
- El primer intento de compilación v0.12 usó por error la etiqueta inexistente
  `gpi_dma0` y falló al compilar el DT. SM8550 agrupa I2C4 e I2C6 bajo
  `gpi_dma1`; se corrigió a ese único controlador y no se conservará la
  referencia `gpi_dma0`.
- La configuración r7 integra `CONFIG_QCOM_GPI_DMA`,
  `CONFIG_PHY_NXP_PTN3222`, `CONFIG_INPUT_UINPUT` y `CONFIG_UHID`. La build
  directa resultante tiene `Image.gz` SHA-256
  `195608d3dcb49c896e48f57510bf65327190be4939c8e1995d119375b803443c`
  y DTB SHA-256
  `6f5fb0944a3438a48c09a8deaec2540c862b4fa11970595c806fb5b1337467ea`.
- ZIP v0.12 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.12-usb-touch-sm-x910-twrp.zip`,
  22.009.191 bytes, SHA-256
  `bf8067a1eb652b0154b8c8614ce254720a94cce96b428f465371890eb01fa5f2`.
  El validador comprueba además GPI DMA, ambos I2C a 400 kHz, compatible,
  supplies/reset/phandle del PTN3222 y USB peripheral/HS. Dos generaciones
  fueron idénticas y el hash remoto en `/sdcard` coincide; el asistente no lo
  flasheó.
- Desde TWRP se montó de nuevo `mmcblk1p2` como `ro,norecovery` y se extrajo
  el journal v0.12 a `work/v012-rootfs-logs-20260719/`. GPI DMA funciona:
  `a90000.i2c` sondea el GT9916 y registra `input0`, pero todos los eventos se
  descartan con `touch data checksum error`. USB queda diferido en
  `88e3000.phy` porque el proveedor PTN3222 `1-004f` no llega a estar listo.
- El FDT stock y el driver Samsung fijan las dos causas. El reset del PTN3222
  necesita la semántica PMIC Qualcomm (`qcom,drive-strength` y
  `power-source = <1>`), mientras que el Goodix Samsung usa cabecera de ocho
  bytes y puntos de 16 bytes. El driver Berlin upstream sí lee
  `point_struct_len` de `IC_INFO`, pero antes de v0.13 no lo utilizaba.
- La fuente r8 incorpora `support-samsung-goodix-16-byte-events.patch`, que
  conserva el formato upstream de ocho bytes y selecciona dinámicamente el
  Samsung de 16; también integra `CONFIG_INPUT_EVDEV=y`, corrige el área
  activa a 1848×2960 y reproduce el pinctrl stock del reset PTN3222.
- Build directa v0.13: `Image.gz` SHA-256
  `7cd3f980dab521874823d2a066b616cbfe39f13e6309c39ed0aa06a2b88f5c8b`;
  DTB `f38a0cfd5f5ed3430f210b2c8533f836871038992ee7b318f28577e1ca74a60f`;
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
- ZIP v0.13 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.13-goodix-ptn-reset-sm-x910-twrp.zip`,
  22.018.623 bytes, SHA-256
  `c69e7b53db8e176eca2396fea4137e26c1ccdf6e8dce8fab1f166ca8e74a0b98`.
  El validador inspecciona el payload de kernel, EVDEV, el parche Goodix, las
  dimensiones táctiles y todo el estado pinctrl del reset. Dos generaciones
  finales fueron idénticas; el ZIP se copió a `/sdcard` y su hash remoto
  coincide. El asistente no lo flasheó.
- Desde TWRP se extrajeron en sólo lectura los journals v0.13 a
  `work/v013-rootfs-logs-20260719/` y se desmontó la raíz. El journal actual
  tiene SHA-256
  `e4d2d9a437b122c83360653cfe926e20c29c9e8f5e9e8d7eb9a3343d7bd2c51a`.
  Goodix registra `event layout 8/8`, pero cada toque vuelve a fallar checksum;
  los dumps de 10/18 bytes prueban que el supuesto checksum es todavía parte
  del evento Samsung de 16 bytes.
- La corrección r9 identifica la metadata defectuosa por el PID de firmware
  `6936` y fuerza el layout 8/16. Para USB, el pinctrl ya no falla ni queda una
  cadena de deferred probe: DWC3 alcanza directamente el soft reset y termina
  en `-ETIMEDOUT`. Se comparó entonces el driver mainline con el log y FDT
  Samsung, que programan los registros PTN3222 `06=20`, `07=21`, `08=63` y
  `0a=01`; mainline no escribía ninguno.
- `configure-nxp-ptn3222-from-dt.patch` añade regmap y aplica la propiedad
  stock `qcom,param-override-seq` tras 4–5 ms de salida de reset. Ambos parches
  aplican limpiamente a Linux 7.2-rc3. Build limpia v0.14: `Image.gz` SHA-256
  `c02c47ffca3e4d6eb5d9f7cae2a1cb5f1c3994dc5dc25b2c0ec54908979b5952`;
  DTB `454a804c38c6a3e5ea0406419f65c0adcc1c8d477dea50fb2b79e51d1f430d07`;
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
- ZIP v0.14 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.14-goodix-force-ptn-tune-sm-x910-twrp.zip`,
  22.014.000 bytes, SHA-256
  `23cb7f066c6fecbd50d995db315906f262545ac3024af3068b3a468f947a5cfe`.
  Dos generaciones fueron idénticas, el validador confirmó las cadenas del
  kernel, la secuencia DT, Android v4 y AVB, y el hash copiado a `/sdcard`
  coincide. El asistente no lo flasheó.

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
- No interpretar la pantalla Samsung con overlay RPMB/código de barras como
  un panic de Linux. En la prueba v0.1 fue Odin iniciado deliberadamente por
  ABL tras rechazar el DTB, y el diagnóstico fiable estaba en
  `/proc/last_kmsg`, no en `pstore`.
- No usar un DTB mainline con sólo compatibles upstream en esta cadena de
  arranque Samsung. ABL necesita además sus compatibles Qualcomm legacy,
  `qcom,msm-id` y `qcom,board-id` en la raíz.
- No dar por suficiente que un overlay funcione con `fdtoverlay` de libfdt.
  El fork ufdt de ABL falló con el DTB v0.2 sin `/__symbols__`, aunque el
  overlay usaba `target-path = "/"` y las herramientas estándar lo aceptaban.
  Todo DTB destinado a `vendor_boot` debe compilarse con `-@` y el validador
  debe exigir `/__symbols__`.
- No seguir modificando el no-op para el fork ufdt Samsung: v0.2 sin símbolos
  y v0.3 con 474 símbolos fallaron en el mismo punto. v0.4 evita por completo
  esa ruta mediante el fallback appended-DTB documentado en ABL.
- No considerar v0.4 un arranque completo: aunque ABL entregó el control y
  simpledrm mostró Linux, el firmware reinició el SoC con
  `TZBSP_ERR_FATAL_NOC_ERROR` antes de demostrar rootfs, SD o red. Pstore quedó
  vacío y el bloque NoC del log Samsung está cifrado.
- No omitir los carveouts Samsung al usar appended-DTB. El `sm8550.dtsi` base
  cubre las reservas Qualcomm comunes, pero no las reservas específicas que
  normalmente aporta el overlay X910; v0.5 las incorpora explícitamente.
- No asumir que esos carveouts resolvían el reset: v0.5 reproduce el mismo
  fatal NoC que v0.4. La evidencia nueva del vídeo sitúa el corte durante el
  probe de los interconnects LPASS, inmediatamente antes de `7e40000`.
- No esperar que pstore v0.4/v0.5 aparezca automáticamente en TWRP: recovery
  arranca con su propio DT y no registra el backend ramoops mainline. v0.6 usa
  en su lugar el formato `sec_log_buf` nativo que el recovery sí entiende.
- No seguir atribuyendo el fatal a `lpass_ag_noc`: v0.6 lo deshabilitó y el
  reset persistió. Tampoco inferir el culpable sólo por la última línea de
  retorno; v0.7 registra el inicio de cada probe antes del acceso peligroso.
- No atribuir el fatal v0.7 a `sdhc_2`: la traza previa demuestra que la última
  llamada es `sm8550-tlmm`. Tampoco copiar las reservas `<36 4>, <50 2>` del
  Fold5: el FDT X910 sólo acredita GPIO36–39.
- No asumir que `/proc/last_kmsg` conserva el boot anterior tras cualquier tipo
  de reinicio: en v0.8 el reinicio manual dejó `previous_index` apuntando al
  recovery previo. v0.9 mantiene ese índice sincronizado desde mainline.
- No dejar TWRP esperando antes de extraer el log: su kernel downstream es muy
  verboso y llena los 2 MiB en aproximadamente 17 minutos.
- No seguir usando `sec_log_buf`/`last_kmsg` para este panic: v0.10 acaba en
  `XBL(... restored from storage)` y no conserva mainline. La foto de la
  consola es la evidencia fiable hasta disponer de pstore o USB.
- No asumir que `export_logs()` garantiza una captura USB. En la prueba v0.10
  no enumeró `PMOS_LOGS`, ACM ni NCM/RNDIS; el host sólo vio errores de
  descriptor. Hasta arreglar USB, usar pantalla y persistencia en la SD.
- No empaquetar el initramfs genérico X910 como gzip aunque sea un stream
  válido y mainline tenga `CONFIG_RD_GZIP`. Con el vendor ramdisk LZ4, Samsung
  ABL produjo un initrd que falló por magia inválida. Ambos deben usar LZ4
  legacy como el firmware stock y el validador lo exige desde v0.11.
- No confiar en que ABL deje el repetidor NXP eUSB2 listo para mainline. v0.11
  llega al userspace pero DWC3 termina en `-ETIMEDOUT` y el host sólo ve
  errores de descriptor. Hay que describir, alimentar, sacar de reset e
  inicializar explícitamente el NXP por I2C antes del core USB.
- No considerar suficiente la descripción upstream inicial del PTN3222 ni
  integrar GPI DMA sin comprobar el hardware: v0.12 arranca hasta LightDM,
  pero físicamente siguen sin funcionar táctil ni enumeración USB. El journal
  persistente debe decidir el siguiente cambio y no se añadirán overrides a
  ciegas.
- No usar la propiedad genérica `drive-strength` en un GPIO del controlador
  `qcom-spmi-gpio`: el probe falla con `pin_config_group_set`. Para este reset
  hay que reproducir `qcom,drive-strength` y el resto del estado PMIC stock.
- No asumir que `point_struct_len` del IC_INFO sea fiable en firmware Samsung.
  El GT9916/PID 6936 anuncia ocho pero emite 16; confiar en esa metadata hace
  que bytes del propio evento se interpreten como checksum.
- No considerar completa la inicialización del PTN3222 porque el driver
  mainline controle rails y reset. En la X910 son obligatorias cuatro
  escrituras I2C de tuning acreditadas por el FDT y los logs Samsung.
- No dejar `CONFIG_INPUT_EVDEV=m` en una build directa que no instala módulos:
  el dispositivo puede registrarse como `input0` sin crear `/dev/input/event*`.
  Desde r8 EVDEV es built-in y el validador lo exige.

## Referencias locales

- `../port/README.md`: estado final del port Ubuntu Touch.
- `../port/docs/porting-log.md`: investigación y bring-up detallados.
- `../port/docs/sm-x910-x910xxs5cyg1-firmware-inventory.md`: boot chain y
  firmware.
- `../port/docs/source-compatibility-matrix.md`: kernel y módulos Samsung
  probados.
- `../port/sources/samsung-gts9u/`: adaptación downstream funcional.
