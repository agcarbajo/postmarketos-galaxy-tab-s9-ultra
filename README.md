# Port de postmarketOS para Samsung Galaxy Tab S9 Ultra Wi-Fi

> Documento vivo del proyecto. Debe actualizarse con cada avance, fallo,
> decisión de arquitectura y artefacto generado.
>
> Última actualización: 2026-07-20 (sesión 45, v0.32).

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
| Kernel mainline SM8550 | ✅ v0.31 demuestra que el kernel/DTS actuales llegan a LightDM sin módulos; v0.32 corrige la aplicación incompleta del parche Goodix en la build directa |
| DTS `gts9uwifi` | 🧪 v0.27 conserva táctil/pantalla/SD/USB y mantiene deshabilitados PMU WCN, PCIe0 y su PHY durante el hito SSH |
| Acceso temprano a microSD | ✅ Mainline enumera físicamente `mmcblk1`, `mmcblk1p1` y `mmcblk1p2` |
| Paquetes pmaports | ✅ v0.27 reproducible: device r11, kernel r17 y firmware WCN7850 r1; modesetting con sombra software y refresco KMS |
| Rootfs postmarketOS | ✅ v0.27 limpio generado con XFCE4/OpenSSH y módulos completos; el ZIP actualiza la SD física existente |
| Escritorio | ✅ v0.31 llega físicamente a LightDM con el kernel/DTS actuales; la regresión de los pingüinos queda aislada a la carga de algún módulo |
| Wi-Fi | ⏸️ Aislado temporalmente en v0.23; v0.21 ejecuta rails/WLAN_EN pero el endpoint `17cb:1107` da `Device not found` |
| SSH | ✅ v0.23 aislada levanta RNDIS, carrier, `usb0=172.16.42.1`, NetworkManager y OpenSSH sin la carrera WCN |
| Táctil | 🧪 v0.31 registra Goodix pero rechaza eventos por checksum; v0.32 restaura el arreglo completo ya validado en v0.17 |
| Bundle Android v4 | ✅ v0.27 empaquetado con appended-DTB, LZ4 legacy/AVB y overlay con modos POSIX para la microSD existente |
| Restauración Ubuntu Touch | ✅ ZIP boot-only v8/DTBO stock generado y validado |
| Imagen/paquete de prueba | 🧪 v0.32 copiada a `/sdcard` y verificada; pendiente flash manual para validar LightDM + táctil con kernel actual sin módulos |

## Reto en curso

Probar físicamente v0.32. v0.31 ya confirma que el kernel/DTS/initramfs
actuales, manteniendo WCN/PCIe0/PHY deshabilitados y sin módulos cargables,
llegan a LightDM; por tanto la regresión que deja los pingüinos en pantalla
desde v0.19 pertenece exclusivamente a algún módulo autocargado. El táctil de
v0.31 falló por un problema distinto y ya identificado: la build directa
detectaba el marcador de un parche Goodix parcial y omitía tanto el forzado de
eventos Samsung de 16 bytes para PID 6936 como la prelectura de un solo
contacto. v0.32 corrige la guarda, actualiza automáticamente los worktrees
parciales y conserva el aislamiento sin módulos. Si LightDM y el táctil
funcionan juntos, esta será la base usable para reintroducir por grupos los
módulos, conservar SSH NCM/RNDIS y después reactivar WCN7850:

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
- el journal v0.14 extraído en sólo lectura confirma `event layout 8/16` y
  elimina por completo los errores de checksum. Al tocar, la lectura inicial
  de 42 bytes bloquea GPI-I2C con `-ETIMEDOUT`; las lecturas de 26 bytes de
  v0.13 sí completaban. v0.15 prelee sólo un contacto (26 bytes para Samsung)
  y recupera el resto únicamente cuando el contador indica multitáctil;
- el mismo journal confirma `applied 4 register overrides` en PTN3222, pero
  DWC3 sigue fallando `DCTL.CSFTRST`. Como el DTS elimina la PHY SuperSpeed,
  faltaba `qcom,select-utmi-as-pipe-clk`: el glue Qualcomm la usa para
  alimentar PIPE desde UTMI antes de registrar el core. v0.15 lo añade;
- la prueba física v0.15 confirma que Goodix ya reporta toques: tocar arriba
  activa abajo, por lo que falta invertir el eje Y tras el intercambio de ejes.
  USB no enumera NCM/RNDIS, conserva dos errores de descriptor y no hay SSH en
  `172.16.42.1`, `.151` ni en la LAN excluyendo `.138`/`.150`;
- el journal v0.15 extraído en sólo lectura demuestra que UTMI-PIPE resolvió el
  soft reset: no hay error DWC3, configfs enlaza el gadget, existe `usb0` con
  `172.16.42.1`, DHCP arranca y `sshd` escucha en todas las interfaces. El fallo
  restante está en la señal física/PHY porque Windows no puede leer descriptor;
- el driver Samsung funcional difiere del mainline sólo en dos detalles de esa
  inicialización relevante: espera 10 µs tras afirmar `POR` y programa
  `PHY_CFG_PLL_CPBIAS_CNTRL=1`; mainline no espera y escribe cero. v0.16 porta
  ambos y añade `touchscreen-inverted-y`;
- la prueba física v0.16 no crea NCM/RNDIS, conserva los dos errores de
  descriptor de Windows y no expone SSH en USB ni en la LAN. La espera POR y
  CPBIAS=1 no bastan para arreglar la señal eUSB2;
- v0.16 añadió `touchscreen-inverted-y`, pero el helper del kernel aplica las
  inversiones antes de `touchscreen-swapped-x-y`: esto invirtió el X visible y
  dejó invertido el Y visible. La corrección exacta en r12 es
  `touchscreen-inverted-x` + `touchscreen-swapped-x-y`, sin `inverted-y`;
- el journal v0.16 extraído en sólo lectura confirma de nuevo que PTN3222,
  DWC3, configfs, `usb0`, DHCP y `sshd` arrancan sin error interno nuevo;
- TWRP ofrece una referencia funcional del mismo hardware: PTN3222 revisión
  `A2`, overrides efectivos `06=20`, `07=21`, `08=63`, `0a=01`, y con ADB
  enumerado registra `DEVICE_STATUS=09` y `LINK_STATUS=05`;
- v0.17 registra el reloj y los controles efectivos de la PHY al inicializar,
  y ocho segundos después lee `00..16` del PTN3222. La comparación de
  `0f/10` distinguirá el lado eUSB2/repetidor del gadget/EP0;
- la prueba física v0.17 valida completamente la orientación táctil. USB sigue
  sin enumerar NCM/RNDIS, `172.16.42.1:22` no responde y el barrido de la LAN
  sólo encuentra `.138`/`.150`, dispositivos excluidos conocidos;
- el journal v0.17 muestra exactamente los mismos `00..16` del PTN3222 que el
  kernel Samsung funcional, incluidos `0f=09`, `10=05`, revisión `A2` y los
  cuatro overrides. Reset lógico/físico y reloj PHY de 38,4 MHz son coherentes;
- por tanto no se debe volver a cambiar PHY, repetidor, alimentación o tuning.
  El host alcanza el enlace pero no recibe ni VID/PID: el fallo queda en
  DWC3/UDC/EP0 o en la entrega del descriptor;
- v0.18 registra el pull-up solicitado/efectivo, DCTL/DSTS/DEVTEN/event count,
  todos los eventos DWC3, transiciones EP0 y cada paquete SETUP decodificado;
- la prueba física v0.18 vuelve a LightDM pero no enumera: Windows conserva dos
  errores de descriptor, no hay NCM/RNDIS ni SSH en `172.16.42.1/.2`, y la LAN
  sólo expone los equipos excluidos `.138`/`.150`;
- el journal v0.18 demuestra que DWC3 ejecuta pull-up/RUN y recibe por EP0
  `GET_DESCRIPTOR` de dispositivo/configuración/string, `SET_ADDRESS`,
  `GET_STATUS`, `SET_CONFIGURATION(1)` y `SET_INTERFACE(0)`. Hardware,
  PTN3222, PHY, IRQ, EP0 y entrega de descriptores quedan demostrados; no se
  debe volver a retocar esa cadena para el síntoma actual;
- Windows no enlaza la función CDC-NCM aunque completa la configuración. v0.19
  cambia explícitamente el gadget a `rndis.usb0`, manteniendo
  `172.16.42.1`/DHCP/OpenSSH como transporte de compatibilidad;
- en paralelo, v0.19 describe el WCN7850 (`PCI 17cb:1107`) en PCIe0 con PMU,
  reguladores, sleep clock, WLAN_EN GPIO80, BT_EN GPIO81, PERST GPIO94 y wake
  GPIO96. Incluye `ath12k`, `pwrseq-qcom-wcn` y los cuatro blobs Kiwi v2 stock;
- el ZIP v0.19 actualiza además el árbol completo de módulos 7.2.0-rc3,
  `deviceinfo` y firmware en `mmcblk1p2`, tras verificar que es un rootfs pmOS.
  La misma configuración está integrada en la imagen SD limpia;
- v0.19.2 sí completa el arranque: tres journals persistentes no contienen
  panic y dos boots llegan a systemd, RNDIS, NetworkManager, OpenSSH, Xorg,
  LightDM y slick-greeter. X configura simpledrm a 2960x1848 y activa VT7;
- la consola visible de las fotos de v0.19.2 no era un bloqueo de systemd.
  v0.20 retiró `console=tty0` para separar fbcon de X, pero v0.21 la restaura
  temporalmente porque el diagnóstico visual es prioritario durante el
  bring-up del Wi-Fi;
- PCIe0 v0.19.2 crea el root port `17cb:0113`, pero termina `Device not found`:
  el DT omitía el séptimo rail exigido por `pwrseq-qcom-wcn` y dejaba WLAN_EN
  en pull-down. v0.20 ensayó PM8550VS-G LDO3 como `vddio1p2-supply` y forzó
  GPIO80 alto;
- el journal v0.20 demuestra que el kernel r15 sí monta rootfs, arranca systemd,
  RNDIS y OpenSSH, pero deja de escribir exactamente a los 18,987144 s tras
  los rangos del host PCIe0. No hay panic ni oops. El DTB registra antes un
  ciclo de dependencias entre `regulators-5` y `smps4`, evidencia que acota la
  regresión al rail real/orden de alimentación nuevo;
- v0.21 revierte PM8550VS-G LDO3 y `vddio1p2-supply`, deja que el driver use el
  dummy regulator conocido de v0.19.2 y conserva sólo la parte eléctrica
  justificada de GPIO80 (`bias-pull-up`, 16 mA). Elimina `output-high` para que
  `pwrseq-qcom-wcn` eleve WLAN_EN en su secuencia normal;
- el journal v0.21 demuestra que no existe cuelgue: el boot
  `f1d854a068194803b30089cb0d6554a3` activa sin error los siete rails,
  conserva WLAN_EN alto, completa el sondeo PCIe con `Device not found`,
  inicia NetworkManager/OpenSSH/LightDM y alcanza `graphical.target` a los
  21,604 s. Continúa registrando actividad más allá de 51 s;
- la pantalla permanece en el último printk sólo porque v0.21 volvió a añadir
  `console=tty0`. v0.22 reutiliza exactamente kernel r16/DTB/firmware, sube el
  device a r7 y retira únicamente esa consola de framebuffer tanto del bundle
  Android como del paquete reproducible;
- v0.22 retira correctamente `console=tty0`, pero dos boots nuevos
  (`d34857ab68a9422a9dda48d6b2467373` y
  `cbab67c1ce7241e18c49ca1523ca0d7e`) dejan de progresar a 21,727 y 19,040 s
  durante sondeos repetidos PCIe/WCN, antes de LightDM; los cuatro ficheros
  X/LightDM quedan vacíos. Comparado con el boot v0.21 que sí completa la misma
  secuencia, el fallo es intermitente y está acotado a esa carrera de probe;
- v0.23 deshabilita como unidad `wcn7850-pmu`, `pcie0` y `pcie0_phy`. El DTB
  instalado confirma los tres `status = "disabled"`; firmware, módulos y
  fuentes se conservan para reactivarlos después. No se modifica pantalla,
  táctil, SD, DWC3, RNDIS ni OpenSSH;
- el boot aislado v0.23 `563abe3add6e4cd893b4ceeaceb88eea` no se cuelga:
  NetworkManager y OpenSSH arrancan a 21,021/21,024 s, LightDM a 21,316 s y
  `graphical.target` a 21,373 s. Xorg abre simpledrm a 2960x1848 en VT7 y
  slick-greeter queda ejecutándose; no hay panic, oops ni probes WCN/PCIe0;
- la imagen física permanece en los pingüinos aunque LightDM registra
  `Plymouth is running on VT 1`, lanza X con `-novtswitch` y declara
  `Activating VT 7`. Los logs de v0.11, que sí mostró el greeter, son
  esencialmente iguales; el defecto queda acotado al handoff/repintado de VT;
- el boot v0.24 `96a5a5ecfc28401a8010ad616a9a5afc` vuelve a completar
  userspace: OpenSSH escucha desde 21,493 s, LightDM arranca a 21,791 s,
  `graphical.target` a 21,797 s y slick-greeter está activo. El fallo no es un
  cuelgue del kernel ni de pmOS;
- el handoff v0.24 no llegó a ejecutarse: el instalador TWRP imponía `0644` a
  todos los ficheros del overlay y la entrada regular copiada en
  `graphical.target.wants` fue ignorada por systemd por no ser un enlace. El
  journal lo registra explícitamente a 10,892 s;
- v0.25 cambia el manifiesto incremental a `hash modo ruta`, restaura `0755`
  al script y crea un symlink systemd real durante la instalación. Además
  fuerza temporalmente el DDX `fbdev` con `ShadowFB` sobre `/dev/fb0`: así X
  escribe directamente en el framebuffer que ya muestra los pingüinos y no
  depende del cambio de scanout del DDX modesetting/simpledrm;
- v0.25 demuestra que no queda un fallo de activación: el boot
  `4803b789a4b545ff97b0829a4bac2062` llega a OpenSSH/LightDM/greeter, el
  handoff se ejecuta y registra `active-before=1`, `active-after=7`. Xorg usa
  `/dev/fb0` a 2960x1848, pero con `using shadow framebuffer`; el panel sigue
  conservando los pingüinos pese a más de 900 s de userspace estable;
- v0.26 cambia únicamente `ShadowFB` a `false`, de modo que X renderiza sobre
  la memoria fbdev sin depender de la copia de daños. Cinco segundos después
  del handoff guarda exactamente 21.880.320 bytes de `/dev/fb0` en
  `/var/log/gts9uwifi-fb0-after-x.raw` y registra su SHA-256;
- tras el flash manual v0.26, mantenerla encendida y conectada por USB aunque
  la imagen no cambie. Si RNDIS vuelve a fallar en Windows, regresar a TWRP:
  la captura raw permitirá determinar si el framebuffer contiene el greeter o
  todavía los pingüinos, separando definitivamente renderizado y scanout.

El DTS v0 no incluye DRM/DSI nativo. Mantiene el scanout del bootloader y usa
simpledrm para separar el primer arranque del futuro driver dual-DSI del panel.

No se flasheará la tablet automáticamente. Todo artefacto debe validarse
estáticamente y acompañarse de instrucciones de restauración antes de pedir una
prueba física.

Para las builds ordinarias siguientes se evita repetir baterías de hashes y
dos empaquetados reproducibles: tras compilar y empaquetar una vez, se copia el
ZIP a `/sdcard/` y se hace una única comparación SHA-256 entre el archivo local
y el ya copiado. Las comprobaciones adicionales se reservan para cambios de
boot chain, formato o particiones con riesgo especial.

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
- El journal v0.14 se extrajo desde TWRP con la raíz microSD montada como
  `ro,norecovery`; SHA-256
  `19d2ec68fd8d2fa3bdf30232821ba654c473f9f1ed0a7e9ed5340f970fe56e4f`.
  Goodix fuerza correctamente 8/16 y ya no genera errores de checksum. Los
  toques disparan en cambio timeouts GPI-I2C sobre la lectura inicial de 42
  bytes, mientras que las lecturas anteriores de 26 bytes sí completaban.
- El mismo journal acredita que PTN3222 aplica sus cuatro overrides antes de
  DWC3. El soft reset continúa en `-ETIMEDOUT`, lo que descarta el repetidor
  como barrera restante. Al operar sin SSPHY faltaba seleccionar UTMI como
  reloj PIPE, ruta implementada explícitamente por `dwc3-qcom`.
- La fuente r10/v0.15 prelee un único contacto Goodix: 18 bytes en el formato
  upstream o 26 en Samsung. Para multitáctil, la segunda lectura empieza tras
  contacto 0 más los dos bytes ya recibidos y completa contactos/checksum. El
  DTS añade `qcom,select-utmi-as-pipe-clk`; el validador lo exige en el DTB.
- Build limpia v0.15: `Image.gz` SHA-256
  `1a8320c6fa49f75cafd3ec3871ce012f59270a3b1d8ba665b2ac3a35b15cd8d2`;
  DTB `13c909ec802636d7be8a6318c52be0f0b53505f6f4224e457184869ed6376c25`;
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
  Se comprobó la ruta Goodix en la fuente/imagen y la propiedad UTMI-PIPE en
  el DTB compilado.
- ZIP v0.15 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.15-goodix-usb-pipe-sm-x910-twrp.zip`,
  22.012.201 bytes, SHA-256
  `e4f7432ed114227d238d161514796b6cc997a74029abe7ce9b079ef4216ae013`.
  Pasó Android v4, LZ4, AVB, appended-DTB y todas las aserciones. Se copió a
  `/sdcard` y el hash remoto coincide; el asistente no flasheó particiones.
- La prueba física v0.15 valida la corrección de lectura corta: el táctil
  produce entrada por primera vez. La geometría está escalada, pero el eje
  vertical queda invertido (`arriba → abajo`), corrección declarativa pendiente
  mediante `touchscreen-inverted-y`.
- El cambio UTMI-PIPE no produjo aún un gadget utilizable. Windows mantiene dos
  errores de descriptor, no crea NCM/RNDIS y no existe SSH en USB ni en la LAN;
  se requiere el journal v0.15 para saber si DWC3 superó el soft reset.
- El journal v0.15 se extrajo con la raíz como `ro,norecovery`; SHA-256
  `ab71752f62067cea8bd92d87850f42c873c9aace2090a2e6aba50c1d001f5496`,
  boot ID `50f794db540749b2bde8ed6ef92011c8`. Goodix no registra fallos y DWC3 ya
  supera el soft reset. Configfs crea gadget/`usb0`, asigna `172.16.42.1`,
  Avahi lo publica y OpenSSH escucha en `0.0.0.0:22`/`[::]:22`.
- La comparación directa entre `phy-snps-eusb2.c` mainline y
  `phy-msm-snps-eusb2.c` Samsung encontró dos diferencias antes del PLL:
  downstream espera 10 µs tras `POR` y usa CPBIAS=1; mainline omite la espera
  y usa cero. El resto de divisores PLL y cinco parámetros TX coincide.
- La fuente r11 integra `match-samsung-sm8550-eusb2-phy-init.patch`, que porta
  esas dos diferencias, y el DTS añade `touchscreen-inverted-y`. Ambos parches
  aplican limpiamente sobre Linux 7.2-rc3.
- Build limpia v0.16: `Image.gz` SHA-256
  `e1ece41124f5f365e5a123fd7ec67531682397bb5cf1d3c3df2a088b525624be`;
  DTB `ce4ce2e2d09b0835641e95f26971188fa5be479c0d65aa626eed4cade9f87093`;
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
  Fuente y DTB compilados se verificaron antes de empaquetar.
- ZIP v0.16 reproducido byte a byte:
  `postmarketos-edge-xfce-mainline-v0.16-touch-usb-phy-sm-x910-twrp.zip`,
  22.016.593 bytes, SHA-256
  `c0d768a2eb179cab95bc2776840828e36c8a50a2df598f7bbb1df6835c457ef9`.
  Pasó Android v4/LZ4/AVB/appended-DTB, se copió a `/sdcard` y el hash remoto
  coincide. El asistente no flasheó ninguna partición.
- La prueba física v0.16 vuelve a LightDM, pero no resuelve USB: Windows
  mantiene los dos fallos de solicitud de descriptor, no crea NCM/RNDIS y no
  hay SSH atribuible a la tablet en USB ni en la LAN (`.138` y `.150` siguen
  excluidos por ser otros dispositivos).
- El táctil de v0.16 queda invertido en ambos ejes visibles. La inspección de
  `touchscreen_apply_prop_to_x_y()` demuestra que el kernel invierte antes de
  intercambiar ejes. Con el `swap` necesario para este panel, invertir el Y
  visible requiere `touchscreen-inverted-x`; r12 elimina `inverted-y` y añade
  `inverted-x`.
- El journal v0.16 se extrajo como `ro,norecovery`; `system.journal` tiene
  SHA-256 `6dd5ee4399bbae29e56b10dbedc9d6178f7a7decca51728ec7c97c1215376f53`
  y el boot actual es `225ccfc4e1ac473f9c413502d1bbe026`. Confirma el mismo
  estado USB interno de v0.15 y no muestra fallos Goodix nuevos.
- En TWRP, el regmap del PTN3222 funcional identifica revisión `0xA2` y deja
  `06=20`, `07=21`, `08=63`, `0a=01`, `0f=09`, `10=05`. Según la
  [hoja de datos oficial de NXP](https://www.nxp.com/docs/en/data-sheet/PTN3222_CUK.pdf),
  `0x0f` es `DEVICE_STATUS` y `0x10` es `LINK_STATUS`.
- `diagnose-sm8550-eusb2-link.patch` imprime los controles efectivos de la PHY
  y lee `00..16` del PTN3222 ocho segundos después de iniciar el enlace, sin
  cambiar ningún registro. La fuente r12 lo integra en todas las builds.
- Build limpia v0.17: `Image.gz` SHA-256
  `48e91dfb2f42a665599d204a63e8633a8606011dc9dc4f18a4c1791975d12aa1`;
  DTB `8d600347ad1a826e0c0ef33fbf0fb68125d18d5a64939307ac4b93599c12bddf`;
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
- ZIP v0.17 generado una vez:
  `postmarketos-edge-xfce-mainline-v0.17-touch-usb-diagnostics-sm-x910-twrp.zip`,
  22.016.542 bytes, SHA-256
  `d86e978618bf00d182f705aa4b0704111b42b8f2f8dd8547e40255f205e30439`.
  Se copió a `/sdcard` y una única comprobación posterior dio el mismo hash;
  el asistente no lo flasheó.
- La prueba física v0.17 confirma que el táctil queda correctamente orientado
  y alineado. Windows aún muestra errores de solicitud de descriptor, no crea
  NCM/RNDIS y no hay SSH por USB ni en un host nuevo de la LAN; `.138` y `.150`
  siguen siendo los dos únicos SSH y pertenecen a otros dispositivos.
- El journal v0.17 extraído en sólo lectura tiene boot ID
  `66eb6939ed4649e197dcd6be06c0cd46`; `system.journal` SHA-256
  `201b71a79f2344904f9153b13e8826b32bd59a9a710d625a5ae868aa6193c13b`.
  PTN3222 mainline coincide byte a byte en `00..16` con TWRP: `0f=09`,
  `10=05`, revisión `A2` y overrides correctos. La PHY usa 38,4 MHz y registra
  todos sus controles efectivos sin errores.
- `diagnose-dwc3-ep0-enumeration.patch` añade trazas pasivas a pull-up,
  registros DWC3, eventos, EP0 y SETUP. El APKBUILD sube a r13 y el build
  directo aplica el parche en futuras compilaciones.
- Build incremental v0.18: `Image.gz` SHA-256
  `6d1feaff85d4d50131a2fdb114f28ac6be410420d0226c22c09edf8465b4ffef`;
  DTB sin cambios
  `8d600347ad1a826e0c0ef33fbf0fb68125d18d5a64939307ac4b93599c12bddf`;
  config `c2060ed1d41547e469cbeb07c87f39be1f810ccf6e55ecc0c53f6df7546d3b86`.
- ZIP v0.18 generado una vez:
  `postmarketos-edge-xfce-mainline-v0.18-dwc3-ep0-diagnostics-sm-x910-twrp.zip`,
  22.017.000 bytes, SHA-256
  `6706f3778c2df2b1384e1b225cf3c5af315ca0986056599dfb3fc4c42f8542e0`.
  Copiado a `/sdcard`; la única comprobación posterior coincide. No se flasheó.
- La prueba física v0.18 no cambia el síntoma externo: dos errores de solicitud
  de descriptor, sin NCM/RNDIS y sin SSH USB. El barrido LAN sólo encuentra
  `.138` y `.150`, que pertenecen a otros dispositivos. Se requiere su journal
  para explotar las nuevas trazas DWC3/EP0.
- El journal v0.18 (`47ee7c89dc374bd1baf30310b98cbef7`, SHA-256
  `ffcbcd4ebce12d857a91094c9712d442422001ab7533178a03db64c69d614edc`)
  prueba una enumeración EP0 completa hasta `SET_CONFIGURATION(1)` y
  `SET_INTERFACE(0)`. El problema externo restante es compatible con el
  binding CDC-NCM de Windows, no con un fallo de PHY, repetidor o DWC3.
- El FDT stock identifica Kiwi v2/WCN7850 con PCI ID `17cb:1107`; confirma
  WLAN_EN GPIO80, BT_EN GPIO81, PERST GPIO94 y wake GPIO96. Linux 7.2-rc3 ya
  contiene soporte ath12k WCN7850 y la infraestructura PMU/PCIe de SM8550.
- Se añadió `firmware-samsung-gts9uwifi` r1. El script
  `stage-stock-wifi-firmware.sh` extrae del `vendor.img` oficial y verifica
  `amss20.bin`, `phy_ucode20.elf`, `bdwlan.elf` y `regdb.bin`; no se versionan
  los blobs propietarios. Se instalan como los nombres upstream bajo
  `/usr/lib/firmware/ath12k/WCN7850/hw2.0`.
- Rootfs v0.19 verificado: device r4, kernel `7.2_rc3-r14`, firmware r1,
  `CONFIG_USB_CONFIGFS_RNDIS=y`, `CONFIG_ATH12K=m` y
  `CONFIG_POWER_SEQUENCING_QCOM_WCN=m`. El initramfs contiene
  `deviceinfo_usb_network_function="rndis.usb0"` y el DTB final contiene el
  PMU/reguladores y `wifi@0` compatible `pci17cb,1107`.
- ZIP único v0.19:
  `postmarketos-edge-xfce-mainline-v0.19-rndis-wifi-pcie-sm-x910-twrp.zip`,
  80.821.386 bytes, SHA-256
  `3ca3e44fb2a8e26bec76515381d40f565ecc6b5215b52d8b855f7513297a686e`.
  Incluye 2.011 archivos de overlay (69 MiB sin comprimir): árbol completo de
  módulos, firmware WCN7850 y deviceinfo. Se copió a `/sdcard` y el único hash
  posterior coincide; el asistente no lo flasheó.
- El primer intento manual de instalar ese ZIP abortó antes de cualquier `dd`:
  la microSD se montó correctamente, pero Alpine publica
  `ID="postmarketos"` y el validador exigía `ID=postmarketos` sin comillas. La
  fuente v0.19.1 acepta exactamente ambas formas; no cambia kernel, rootfs ni
  overlay.
- ZIP correctivo v0.19.1:
  `postmarketos-edge-xfce-mainline-v0.19.1-rndis-wifi-pcie-sm-x910-twrp.zip`,
  80.821.400 bytes, SHA-256
  `3a3431c1ea994536feadc6eb18712b1de38664babadb6b45e40da467dd66f89f`.
  Copiado a `/sdcard`; el único hash posterior coincide. Pendiente de flash
  manual.
- La instalación v0.19.1 terminó, pero el reboot no llegó a Linux. El
  `last_kmsg` restaurado por TWRP registra `ApplyOverlay: ufdt apply overlay
  failed`, `Invalid device tree header` y `Launching odin`. La metadata reveló
  `append_dtb_to_kernel=0` y `disable_runtime_dtbo=0`: al invocar directamente
  el empaquetador se omitieron los flags que todas las builds arrancables usan
  desde v0.4. No es un fallo del nuevo DTB Wi-Fi.
- `build-android-v4-bundle.sh` usa ahora por defecto la ruta físicamente
  validada de la X910: DTB anexado al kernel y DTBO runtime deshabilitado. La
  siguiente v0.19.2 sólo regenera las imágenes Android; kernel, initramfs,
  rootfs, módulos y firmware permanecen idénticos.
- ZIP v0.19.2:
  `postmarketos-edge-xfce-mainline-v0.19.2-appended-dtb-rndis-wifi-sm-x910-twrp.zip`,
  80.852.094 bytes, SHA-256
  `a8a6f28ab58c594478dda11a738ba0deb90c09d2865824b2aff845c655c0b8a6`.
  Metadata comprobada `append_dtb_to_kernel=1` y
  `disable_runtime_dtbo=1`; copiado a `/sdcard` y el único hash posterior
  coincide. Pendiente de flash manual.
- Imagen SD limpia v0.19 comprimida:
  `postmarketos-edge-xfce-mainline-v0.19-rndis-wifi-pcie-sm-x910-sd.img.zst`,
  513.383.398 bytes, SHA-256
  `ed7a92c2645eb3ea2118a77be28afba16fee7a30bbbfb4b614026df492fd6f10`.
  Es la salida del mismo rootfs verificado y permite validar una instalación
  desde cero sin depender del overlay incremental.
- La prueba física v0.19.2 alcanza userspace completo. Los boots
  `214544eee54741ab86c8d276cdcefe87` y
  `e159c2334b9f4a87afb08ee8bf67301e` continúan más de 51 segundos; LightDM
  activa VT7 y slick-greeter muestra su ventana. Xorg usa simpledrm a
  2960x1848 sin errores fatales. La consola que permanece visible no implica
  un cuelgue del kernel ni de systemd.
- En esos boots `usb0` tiene `172.16.42.1`, RNDIS queda configurado,
  NetworkManager detecta carrier y OpenSSH escucha en IPv4/IPv6. Falta probar
  desde Windows antes de afirmar que RNDIS ya es utilizable externamente.
- Wi-Fi v0.19.2 no enumera: PCIe0 crea el root port Qualcomm `17cb:0113`, pero
  no aparece el endpoint `17cb:1107` y registra `Device not found`. El driver
  WCN7850 avisaba además `supply vddio1p2 not found`.
- La fuente r15 corrige dos diferencias demostrables con el DT stock X910:
  añade PM8550VS-G LDO3 a 1,2 V como `vddio1p2-supply` y configura WLAN_EN
  GPIO80 como salida alta, pull-up y 16 mA. El DTB instalado en el rootfs fue
  inspeccionado y contiene ambas propiedades efectivas.
- Build limpia v0.20: device r5, kernel `7.2_rc3-r15` y firmware r1. Se retiró
  `console=tty0` tanto del bundle Android como del paquete device para que X
  sea el único consumidor visual del framebuffer; la consola serie y todos
  los mecanismos de log permanecen disponibles.
- ZIP v0.20:
  `postmarketos-edge-xfce-mainline-v0.20-wcn-power-rndis-no-fbcon-sm-x910-twrp.zip`,
  80.853.798 bytes, SHA-256
  `9a73808d30e6aa9b317a7550a36a5c6a271245d8fcdff17808ecba5e17f76998`.
  Incluye el overlay completo de módulos/firmware/deviceinfo, usa appended-DTB
  y DTBO runtime deshabilitado. Copiado a `/sdcard`; el único hash posterior
  coincide. El asistente no flasheó particiones.
- Imagen SD limpia v0.20:
  `postmarketos-edge-xfce-mainline-v0.20-wcn-power-rndis-no-fbcon-sm-x910-sd.img.zst`,
  478.250.065 bytes. Procede del mismo rootfs r5/r15/r1 y sirve para una
  instalación desde cero.
- Los logs v0.20 se extrajeron de la microSD en sólo lectura a
  `work/v020-rootfs-logs-20260719/`. El boot
  `56c2f5b944d14e2e8bc81741e54c8ef1` usa kernel r15, monta rootfs y boot,
  inicializa el gadget RNDIS y el socket OpenSSH, pero el journal termina
  bruscamente a 18,987144 s durante los rangos de `qcom-pcie 1c00000.pcie`.
  No contiene panic ni oops; la usuaria tuvo que reiniciar manualmente.
- La regresión v0.20 coincide con un nuevo aviso temprano de ciclo fijo entre
  `/soc@0/rsc@17a00000/regulators-5` y `smps4`. v0.21 retira completamente el
  LDO3/`vddio1p2-supply` experimental, restaura `console=tty0` y mantiene
  GPIO80 como pull-up/16 mA sin `output-high`.
- `diagnose-wcn7850-power-sequence.patch` añade trazas pasivas al módulo
  `pwrseq-qcom-wcn`: valor inicial/dirección/transición de WLAN_EN y registro
  del secuenciador. El módulo empaquetado contiene esas cadenas y el DTB final
  fue decompilado para comprobar que ya no conserva el rail experimental.
- Build limpia v0.21: device r6, kernel `7.2_rc3-r16` y firmware r1. ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.21-wcn-diagnostics-verbose-sm-x910-twrp.zip`,
  80.851.485 bytes, SHA-256
  `c46b30538b486ee1b93c938464c8f339d93b3127450d3a34f39c4861bc3f9032`.
  Incluye overlay completo, appended-DTB y DTBO runtime deshabilitado. Se
  copió a `/sdcard` y la única comprobación posterior coincide; el asistente
  no flasheó ninguna partición.
- Los logs v0.21 se extrajeron en sólo lectura a
  `work/v021-rootfs-logs-20260719/`. El boot
  `f1d854a068194803b30089cb0d6554a3` prueba que la aparente congelación era
  exclusivamente visual: los siete rails retornan 0, WLAN_EN permanece en 1,
  PCIe devuelve `Device not found`, pero RNDIS obtiene carrier,
  NetworkManager y OpenSSH arrancan, LightDM se inicia a 21,555 s y
  `graphical.target` se alcanza a 21,604 s. No hay hang, panic ni oops.
- Build limpia v0.22: device r7, kernel r16 y firmware r1. Sólo se retira
  `console=tty0` del cmdline Android y del paquete device para entregar el
  framebuffer a X; UART, earlycon, journal y todas las trazas permanecen.
- ZIP TWRP v0.22:
  `postmarketos-edge-xfce-mainline-v0.22-rndis-ssh-greeter-sm-x910-twrp.zip`,
  80.851.469 bytes, SHA-256
  `85c70c79f1b0e0bb3c7facd47ac7b817807dd6159a15a4dd8d6f42f5e204f9c6`.
  Copiado a `/sdcard`; la única comparación posterior local/remota coincide.
  El asistente no flasheó ninguna partición.
- Los logs v0.22 se extrajeron en sólo lectura a
  `work/v022-rootfs-logs-20260719/`. Sus dos boots nuevos terminan antes de
  LightDM durante los sondeos repetidos de PCIe0/WCN; `Xorg.0.log`, su `.old`
  y ambos logs LightDM tienen cero bytes. No hay panic ni oops, pero tampoco
  progreso de systemd tras 21,727/19,040 s. El boot completo v0.21 demuestra
  que la misma ruta puede terminar, por lo que se trata como carrera
  intermitente y no como fallo del framebuffer.
- v0.23 aísla temporalmente el subsistema que aún no funciona: marca
  `wcn7850-pmu`, `pcie0` y `pcie0_phy` como deshabilitados. Build limpia
  verificada: device r7, kernel `7.2_rc3-r17`, firmware r1; el DTB instalado
  devuelve `status=disabled` para los tres nodos y mantiene fuera
  `console=tty0`.
- ZIP TWRP v0.23:
  `postmarketos-edge-xfce-mainline-v0.23-stable-rndis-no-wcn-sm-x910-twrp.zip`,
  80.851.833 bytes, SHA-256
  `a050c7d88ec223619c231f102593c5ae03d0b81dccaadda6256abd2d30b43fcd`.
  Incluye overlay completo, appended-DTB y DTBO runtime deshabilitado. Copiado
  a `/sdcard`; la única comprobación local/remota coincide. El asistente no
  flasheó ninguna partición.
- Los logs v0.23 se extrajeron en sólo lectura a
  `work/v023-rootfs-logs-20260719/`. El boot
  `563abe3add6e4cd893b4ceeaceb88eea` prueba que el aislamiento estabiliza el
  sistema: RNDIS tiene carrier y `usb0=172.16.42.1`, NetworkManager/OpenSSH
  arrancan a 21,021/21,024 s, LightDM a 21,316 s y los targets multi-user y
  gráfico a 21,373 s. No existe panic, oops ni actividad WCN/PCIe0.
- `Xorg.0.log` confirma modesetting sobre `/dev/dri/card0` simpledrm a
  2960x1848 y VT7; slick-greeter se ejecuta. LightDM observa Plymouth en VT1,
  arranca X con `-novtswitch` y después registra `Activating VT 7`, pero el
  panel sigue mostrando el último framebuffer de VT1. Por tanto los pingüinos
  ya no representan un fallo de boot, SSH, X ni greeter.
- v0.24 añade `gts9uwifi-display-handoff.service`, habilitada por el paquete
  device r8. Después de que LightDM cree `/tmp/.X11-unix/X0`, registra
  `fgconsole` y fuerza VT1→VT7 para provocar el repintado. El overlay TWRP
  incluye explícitamente script, unidad y activación para actualizar también
  la microSD existente. El ZIP conservaba el modo ejecutable, pero la prueba
  posterior demostró que el instalador lo reemplazaba por `0644` al extraerlo.
- Build v0.24 verificada: device r8, kernel `7.2_rc3-r17`, firmware r1 y
  `kbd-2.8.0-r0`; script ejecutable, unidad habilitada, cmdline sin
  `console=tty0` y los tres nodos WCN/PCIe0 aún deshabilitados. ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.24-vt-handoff-rndis-sm-x910-twrp.zip`,
  80.853.551 bytes, SHA-256
  `b7c1a8bc2e3cc6bb0b68c89a5eea8882d85ef664291e80e54e275cfa8ef37b6e`.
  Copiado a `/sdcard`; la única comparación local/remota coincide. El
  asistente no flasheó ninguna partición.
- Los logs v0.24 se extrajeron en sólo lectura a
  `work/v024-rootfs-logs-20260720/`. El boot
  `96a5a5ecfc28401a8010ad616a9a5afc` llega de nuevo a RNDIS/NetworkManager,
  OpenSSH, LightDM, Xorg y slick-greeter; `graphical.target` se alcanza a
  21,797 s y el journal continúa más allá de 51 s. No hay panic ni hang.
- La causa exacta del no-op v0.24 está registrada por systemd:
  `graphical.target.wants/gts9uwifi-display-handoff.service is not a symlink,
  ignoring`. La inspección offline confirma además modo `0644` en el script.
  El instalador TWRP extraía todos los miembros con ese modo fijo aunque el ZIP
  declarase `0755`; por tanto el rebote VT nunca fue probado físicamente.
- v0.25 usa un manifiesto `SHA-256 modo ruta`; el instalador valida `0644` o
  `0755`, aplica el modo declarado y sustituye la entrada wants por un enlace
  real a la unidad. Como segundo cambio independiente y justificado, añade
  `20-gts9uwifi-fbdev.conf`: X usará `fbdev` + `ShadowFB` sobre `/dev/fb0` en
  lugar de depender del page-flip modesetting/simpledrm que deja visible VT1.
- Build v0.25 verificada: device r9, kernel `7.2_rc3-r17`, firmware r1 y kbd;
  `fbdev_drv.so`, configuración fbdev, script ejecutable y enlace systemd
  presentes; cmdline sin `console=tty0` y WCN/PCIe0 aún aislado. ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.25-fbdev-vt-rndis-sm-x910-twrp.zip`,
  80.853.846 bytes, SHA-256
  `8834678cceb50b7fc6d85b35daabcad8c57ff8ac0c34af3e8c7eaebcee74f054`.
  Copiado a `/sdcard`; la única comparación local/remota coincide. El
  asistente no flasheó ninguna partición.
- Los logs v0.25 se extrajeron en sólo lectura a
  `work/v025-rootfs-logs-20260720/`. El boot
  `4803b789a4b545ff97b0829a4bac2062` llega a `graphical.target` a 23,453 s y
  permanece activo al menos 905 s. El handoff corre sin error, espera X0 y
  cambia la VT lógica de 1 a 7; los pingüinos no son ya una VT incorrecta.
- Xorg v0.25 carga explícitamente `fbdev_drv.so`, abre `/dev/fb0`, detecta
  `simpledrmdrmfb`, 2960x1848, 32 bpp y 21.367 KiB. La opción `ShadowFB=true`
  queda efectiva y X informa `using shadow framebuffer`; los repetidos
  `FBIOPUTCMAP: Invalid argument` no terminan el servidor ni el greeter.
- v0.26 prueba la ruta fbdev restante con `ShadowFB=false`. El mismo servicio
  guarda después de X una captura exacta de 21.880.320 bytes en
  `/var/log/gts9uwifi-fb0-after-x.raw`, por lo que una futura extracción podrá
  mostrar qué dibujó X aunque falle USB o el scanout físico.
- Build v0.26 verificada: device r10, kernel `7.2_rc3-r17`, firmware r1 y kbd;
  fbdev directo, script ejecutable con captura, enlace systemd y WCN/PCIe0
  aislado. ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.26-direct-fbdev-capture-sm-x910-twrp.zip`,
  80.854.080 bytes, SHA-256
  `e2713a80edebd9897ccbdf7a4143d83d055579fb896056b15156357816c9b876`.
  Copiado a `/sdcard`; la única comparación local/remota coincide. El
  asistente no flasheó ninguna partición.
- La captura v0.26 recuperada desde la microSD mide exactamente 21.880.320
  bytes y tiene SHA-256
  `a987f44c03315694b0716b929f6d9c7bb2aeee0a3c412dd4871bc357689d6aed`.
  Interpretada como XRGB8888 de 2960x1848 muestra completo y correcto el
  greeter de LightDM, el fondo XFCE y el teclado en pantalla. La conversión se
  conserva en `work/v026-rootfs-logs-20260720/gts9uwifi-fb0-after-x.png`.
- Esta evidencia descarta un fallo de boot, LightDM, X, VT o dibujo en fbdev:
  el panel sigue escaneando el buffer de la consola aunque `/dev/fb0` ya
  contiene otro frame. v0.27 vuelve al DDX `modesetting`, desactiva glamor con
  `AccelMethod=none`, activa `ShadowFB=true` y, tras el rebote VT1→VT7, ejecuta
  `xrandr` para desactivar y reactivar `None-1` a 2960x1848. El objetivo es
  obligar a simpledrm a enviar daño completo y actualizar el plano KMS.
- Build v0.27 verificada: device r11, kernel `7.2_rc3-r17`, firmware r1 y kbd;
  `modesetting` software, script 0755, unidad/enlace systemd y aislamiento
  WCN/PCIe0 presentes. ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.27-kms-shadow-refresh-sm-x910-twrp.zip`,
  80.854.291 bytes, SHA-256
  `e665a73e8efa51198f87a3fba2dc5bed8a8839406af00a05309d04b47bd58bc8`.
  Copiado a `/sdcard`; la única comparación local/remota coincide. El
  asistente no flasheó ninguna partición.
- La prueba física v0.27 sigue mostrando los ocho pingüinos. Con la tablet
  arrancada, Windows sólo enumera `Dispositivo USB desconocido (Error de
  solicitud de descriptor de dispositivo)`, Code 43; no hay ADB ni respuesta
  SSH en `172.16.42.1:22`.
- El journal v0.27 extraído en sólo lectura (boot
  `2cbe9bc2f5fd4beda28cceaaeb934e9b`) demuestra que el handoff completo se
  ejecutó: VT1→VT7, ambos `xrandr` sin error y captura fb0 a los 32,69 s.
  `Xorg.0.log` registra el apagado a 320x200 (con los `failed to add fb -22`
  esperables, simpledrm fija min/max al modo firmware) y la reactivación con
  un framebuffer nativo nuevo. La capa X queda definitivamente descartada.
- La comparación de dmesg v0.18↔v0.27 identifica la causa raíz del panel
  congelado: los kernels arrancados en v0.4–v0.18 eran builds directas con
  release `-dirty` que jamás cargaron módulos (`modprobe: FATAL ...
  7.2.0-rc3-dirty` en el journal), mientras que desde v0.19 udev coldplug sí
  carga `dispcc/videocc/camcc-sm8550.ko`. Con esos consumidores sondeados,
  `qcom-rpmhpd` ejecuta `sync_state()` y suelta el voto de arranque de MMCX;
  el MDSS se apaga y el panel retiene el último frame en su GRAM. La foto
  v0.21 (congelada tras `power sequencer registered`, 20,208 s) coincide al
  milisegundo con esa ventana de coldplug.
- v0.28 (device r12) aplica la corrección mínima:
  `/usr/lib/modprobe.d/gts9uwifi-display-hold.conf` bloquea el autoload de
  `dispcc_sm8550`, `videocc_sm8550`, `camcc_sm8550` y `gpucc_sm8550`. ZIP:
  `postmarketos-edge-xfce-mainline-v0.28-hold-boot-display-sm-x910-twrp.zip`,
  80.855.122 bytes, SHA-256
  `a9b169d40400cfa0bea239138194ce36dd428a9e492a52e6e60c590ec5ddfedc`, copiado
  a `/sdcard` con la única comparación local/remota coincidente. Pendiente de
  flash manual; si el greeter aparece, el fichero se retirará cuando exista el
  stack DRM/DSI nativo.
- La auditoría posterior no acepta v0.29 como solución confirmada: el cambio
  v0.19 activó todo el árbol de módulos, no sólo `qcomtee` y `qcom_ice`, y la
  correlación temporal no demuestra todavía que una llamada SCM apague el
  scanout. Para evitar más iteraciones ciegas, v0.30 vuelve al control exacto
  de v0.18 y recupera primero la interfaz físicamente conocida.
- v0.30 contiene las mismas imágenes `boot/init_boot/vendor_boot/dtbo/vbmeta`
  y los mismos hashes internos que v0.18, pero usa el instalador actual, que
  reconoce `ID="postmarketos"`, conserva vbmeta read-only correctamente y
  valida el overlay. El overlay sustituye la configuración X forzada por un
  fichero neutro y convierte el handoff posterior en un no-op; LightDM vuelve
  a usar modesetting simpledrm por defecto como en el Xorg log de v0.18.
- El empaquetado queda reproducible mediante
  `scripts/package-v018-display-baseline.sh` y los dos ficheros de
  `configs/display-baseline/`. ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.30-known-good-v018-display-sm-x910-twrp.zip`,
  22.018.867 bytes, SHA-256
  `4f4797b29559496aa678f70e2f2a51bbb510b58258a49d62f4b3355b6735c83b`.
  Copiado a `/sdcard`; la comparación local/remota coincide. El asistente no
  flasheó ninguna partición.
- La prueba física v0.30 confirma el resultado esperado: arranca hasta
  LightDM, el táctil responde y la usuaria puede entrar al escritorio. Queda
  demostrado que el rootfs actual es compatible y que la regresión se limita
  al conjunto de cambios de boot introducido desde v0.19.
- v0.30 también enumera `UsbNcm Host Device` en Windows; el host recibe
  `172.16.42.2/24` y el puerto 22 de `172.16.42.1` responde con OpenSSH 10.3.
  La autenticación automática de `phablet` con `<DEV_PASSWORD>` fue rechazada, por lo
  que no se modificó la sesión viva.
- v0.31 compila el kernel/DTS actuales mediante la ruta directa y conserva
  `Linux version 7.2.0-rc3-dirty`; como el rootfs no contiene
  `/usr/lib/modules/7.2.0-rc3-dirty`, ningún módulo puede cargarse. El DTB
  confirma WCN PMU, PCIe0 y PHY deshabilitados, y el overlay conserva Xorg por
  defecto y el handoff no-op. ZIP:
  `postmarketos-edge-xfce-mainline-v0.31-current-kernel-no-modules-sm-x910-twrp.zip`,
  22.008.887 bytes, SHA-256
  `be37c78307d00dc065ed368ec4e35ecac434d7a11beead7b010e924ae1406d0e`.
  Copiado a `/sdcard`; la comparación local/remota coincide. v0.30 permanece
  también en la tarjeta como retorno inmediato a la base visible.
- La prueba física v0.31 muestra primero los pingüinos del arranque y después
  llega a LightDM. Esto demuestra que kernel, DTS, initramfs y userspace
  actuales sí pueden presentar el greeter; la congelación permanente de
  v0.19–v0.29 sólo aparece al habilitar la autocarga de módulos. NCM vuelve a
  exponer `172.16.42.1:22`, aunque `phablet`/`<DEV_PASSWORD>` sigue siendo rechazado.
- El táctil de v0.31 no responde. El journal del boot
  `b3a671533e71486d949090199774a7dc`, extraído en sólo lectura a
  `work/v031-rootfs-logs-20260720/`, confirma que Goodix registra el
  dispositivo y recibe datos, pero repite `touch data checksum error`.
- La causa es reproducible: el worktree directo contenía sólo el decodificador
  Samsung inicial. `scripts/build-mainline-kernel.sh` comprobaba únicamente
  `GOODIX_BERLIN_SAMSUNG_EVENT_ID_MASK`, lo consideraba completo y omitía el
  forzado de 16 bytes para PID 6936 y la prelectura de un contacto/26 bytes.
  El guard ahora exige el mensaje final exacto y aplica
  `upgrade-partial-goodix-samsung-events.patch` cuando encuentra el estado
  parcial; los worktrees limpios siguen usando el parche completo original.
- v0.32 conserva el kernel actual `7.2.0-rc3-dirty`, DTS con WCN/PCIe0/PHY
  deshabilitados, Xorg neutro, handoff no-op y ausencia deliberada de módulos.
  El binario contiene el forzado PID 6936 y la fuente compilada usa
  `GOODIX_BERLIN_PRE_READ_TOUCHES=1`. ZIP TWRP:
  `postmarketos-edge-xfce-mainline-v0.32-current-kernel-goodix-no-modules-sm-x910-twrp.zip`,
  22.007.128 bytes, SHA-256
  `c4509790f42bb6cff93e73ca0a7bdd2609d6c2b1f19eb6a6526bac263d5a67b9`.
  Se copió a `/sdcard` y la única comparación local/remota coincide; el
  asistente no flasheó ninguna partición. v0.30 permanece como rollback.

## Lo que no ha funcionado / no repetir

- No usar la presencia de un marcador antiguo del parche Goodix como prueba de
  que el arreglo está completo. El worktree directo puede contener el
  decodificador Samsung sin el forzado PID 6936 ni la prelectura de un solo
  contacto; la guarda debe exigir la cadena final exacta y actualizar el
  estado parcial.
- Ejecutar WSL desde el usuario de sandbox: devuelve
  `WSL_E_DISTRO_NOT_FOUND` aunque las distros sí existen para la usuaria.
- Pasar una línea compleja con paréntesis, `$()` y comillas mediante
  `wsl ... bash -lc`: PowerShell/WSL altera el quoting. Usar scripts.
- No ordenar los `sha512sums` de un APKBUILD de forma distinta a `source=`:
  abuild empareja ambas listas por posición. La primera construcción rootfs
  r14 detectó el orden incorrecto de cuatro parches aunque la build directa
  los aplicaba; se corrigió antes de aceptar el paquete.
- No confiar sólo en los bits POSIX almacenados por ZIP para un overlay TWRP:
  `unzip -p > destino` no los aplica y el instalador v0.24 imponía después
  `0644`. Tampoco copiar un fichero normal dentro de un directorio `.wants`:
  systemd exige un enlace y lo ignora explícitamente. Desde v0.25 el manifiesto
  transporta el modo y el instalador crea el symlink de activación.
- No asumir que `ID` en `/etc/os-release` carece de comillas. El rootfs físico
  usa `ID="postmarketos"`; el validador TWRP debe aceptar las dos
  representaciones exactas antes de rechazar la microSD.
- No invocar el bundle X910 con `APPEND_DTB_TO_KERNEL=0` o
  `DISABLE_RUNTIME_DTBO=0`: ABL vuelve a su fork ufdt, rechaza el DTB base y
  entra en Odin antes de Linux. Desde v0.19.2 ambos valores seguros son los
  defaults del script y cualquier experimento debe quedar explícito.
- No volver a declarar PM8550VS-G LDO3 como `vddio1p2-supply` del WCN7850 ni
  forzar GPIO80 con `output-high` en esta topología: v0.20 introduce un ciclo
  de reguladores y un bloqueo reproducible a los 18,987144 s. El dummy rail de
  v0.19.2 permite completar el arranque; v0.21 aísla primero la transición de
  WLAN_EN con trazas antes de asignar otro rail real.
- No mantener PCIe0/WCN habilitado mientras se valida el primer hito estable:
  v0.21 completa una vez la secuencia, pero boots posteriores v0.21/v0.22 se
  detienen intermitentemente antes de LightDM durante los probes repetidos.
  v0.23 ya valida los tres nodos aislados y completa userspace; reactivarlos
  sólo como un bloque desde esta base estable con SSH.
- No interpretar una pantalla inmóvil en los pingüinos como cuelgue del kernel
  sin consultar el journal persistente o probar RNDIS. v0.23 llega a
  `graphical.target`, Xorg/greeter y OpenSSH; su síntoma visual es un fallo de
  handoff/repintado entre VT1 y VT7 separado del estado de userspace.
- No seguir atribuyendo la imagen estática a boot, LightDM, X, greeter, VT ni
  al contenido dibujado en fbdev: el
  servicio corregido ejecuta `chvt 1`/`chvt 7` y `fgconsole` confirma VT7. El
  DDX fbdev abre `/dev/fb0` y v0.26 demuestra con una captura completa que el
  greeter correcto ya está en sus 21.880.320 bytes mientras el panel conserva
  los pingüinos. v0.27 ejecutó además un ciclo completo de apagado y
  reactivación KMS sin efecto físico: no queda nada que corregir en X ni en
  las VT.
- La hipótesis MMCX/rpmhpd quedó REFUTADA por v0.28: con
  `dispcc/videocc/camcc/gpucc-sm8550` bloqueados el journal confirma que no
  cargan y que `qcom-rpmhpd ... sync_state() pending` sigue reteniendo los
  dominios, pero el panel sigue en los pingüinos. Bloquearlos no basta; se
  mantienen en el blacklist sólo porque no tienen uso antes del stack msm
  nativo, no como arreglo del scanout.
- El scanout físico muere ~18–20 s, antes de X (v0.21 con `console=tty0` se
  congeló a 20,2 s). El sospechoso real son las llamadas SCM a TrustZone de
  `qcom-ice` y `qcomtee` (18,59/18,62 s), nuevas desde v0.19 y ausentes en las
  builds `-dirty` que mostraban el greeter. En XBL Samsung la TZ suele ser
  dueña del splash. v0.29 las bloquea; si no arregla, `console=tty0` fechará el
  punto exacto.
- No aceptar todavía la hipótesis SCM de v0.29 como causa raíz: que
  `qcom_ice`/`qcomtee` aparezcan cerca de la ventana de congelación es una
  correlación, y v0.19 activó simultáneamente todo el árbol de módulos. v0.30
  recupera primero el control pre-v0.19 exacto; sólo después se hará un bisect
  acumulativo de módulos desde una imagen físicamente visible.
- No usar `Set-Content`/`Out-File` de PowerShell para scripts que ejecuta bash
  en WSL: escriben CRLF y `set -euo pipefail` falla con `invalid option name`.
  Usar la herramienta Write (LF) o `dos2unix`.
- No comparar sólo configuraciones y DTS al buscar regresiones entre builds:
  verificar también el release del kernel arrancado frente a
  `/lib/modules/`. v0.4–v0.18 corrían `7.2.0-rc3-dirty` sin ningún módulo y
  eso ocultaba efectos que sólo aparecen cuando el árbol de módulos casa
  (v0.19+).
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
- No aumentar la primera lectura Goodix Samsung a dos contactos. v0.14 pide
  42 bytes y bloquea el canal GPI-I2C; preleer sólo uno mantiene la transferencia
  en 26 bytes y permite completar el resto únicamente si el contador lo exige.
- No eliminar la PHY SuperSpeed del nodo DWC3 sin seleccionar UTMI como PIPE.
  El core USB necesita ese reloj para liberar el soft reset incluso cuando el
  enlace se limita deliberadamente a `high-speed`.
- No seguir tratando v0.15 como un fallo de DWC3 o userspace de red: el journal
  demuestra core, gadget, `usb0`, DHCP y SSH activos. El fallo externo de
  descriptor queda acotado a PHY/repetidor/señal física.
- No volver a atribuir el síntoma USB de v0.18 a PHY, PTN3222, DWC3, IRQ o EP0:
  el host completa todos los requests de control hasta configurar la función.
  La siguiente variable justificada es el tipo de función de red; v0.19 prueba
  RNDIS explícito por compatibilidad con Windows.
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
