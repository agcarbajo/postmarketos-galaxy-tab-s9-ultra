# postmarketOS para la Samsung Galaxy Tab S9 Ultra Wi-Fi

Port **mainline-first** de postmarketOS para la Samsung Galaxy Tab S9 Ultra
Wi-Fi (**SM-X910**, nombre en clave `gts9uwifi`, Qualcomm SM8550 «kalama»),
sobre Linux **7.2-rc3** upstream.

El objetivo es un Linux de escritorio de verdad en la tablet —DRM/KMS,
Mesa/Turnip, XFCE— sin depender del kernel downstream 5.15 de Samsung, que aquí
solo se usa como documentación del hardware.

## Estado general

La tablet arranca a un escritorio XFCE completo a **2960×1848 @ 120 Hz** con
GPU acelerada, Wi-Fi, Bluetooth, audio, botones físicos y lectura de batería.
Lo que queda por hacer son sensores, cámaras, carga rápida y la protección
térmica de los altavoces.

Todo lo que aparece como ✅ está **verificado en el hardware real**, no
deducido de que un driver cargue. El audio, por ejemplo, solo se dio por bueno
tras medirlo acústicamente.

Se instala sobre microSD y se arranca por `boot`/`vendor_boot` en la UFS
interna; TWRP, Download Mode y Odin siguen siendo recuperables en todo momento.

## Compatibilidad del hardware

| Componente | Estado | Notas |
|---|---|---|
| **Pantalla** | ✅ | ANA38407 / AMSA46AS02, 2960×1848 @ 120 Hz, DSI command mode + DSC + TE |
| **GPU** | ✅ | Adreno 740, Mesa/freedreno, OpenGL 4.6. Escaneo por reverse PRIME (`card0` Adreno → `card1` DPU) |
| **Brillo y DPMS** | ✅ | Control por software y apagado de pantalla |
| **Táctil** | ✅ | Goodix Berlin, eventos Samsung de 16 bytes |
| **Almacenamiento UFS** | ✅ | Las seis LUN `sda`–`sdf` enumeran |
| **microSD** | ✅ | `mmcblk1`, raíz del sistema |
| **Wi-Fi** | ✅ | WCN7850, ath12k. Requiere el mux PIPE de PCIe des-aparcado y la BDF QRD |
| **Bluetooth** | ✅ | WCN7850, dirección nativa desde EFS, bonds persistentes, A2DP con audio real. HID sin probar |
| **Altavoces** | ✅ | Cuatro Cirrus CS35L45 por MI2S, confirmado acústicamente |
| **Micrófonos** | ✅ | DMIC por el VA macro, captura medida a −30,6 dBFS |
| **Audio de sistema** | ✅ | Perfil UCM propio → PulseAudio, todas las apps y control de volumen |
| **Botones** | ✅ | Volumen ±, y power (suspende) |
| **Batería** | ✅ | Porcentaje, voltaje, corriente y temperatura vía Silicon Mitus SM5714 |
| **Carga** | ✅ | Detecta carga/descarga; UPower expone batería y línea |
| **Suspensión** | 🟡 | El botón suspende, pero el resume del panel no está validado |
| **USB** | 🟡 | Canal secundario; en Windows exige forzar el driver compuesto (Code 43) |
| **Carga rápida 45 W** | ❌ | Limitada a ~9 W. Necesita el bloque USB-PD del SM5714 y negociación PD PPS |
| **Protección de altavoces** | ❌ | El firmware DSP de Cirrus no se carga; por eso el volumen de hardware va con margen |
| **Sensores** | ❌ | Sin empezar |
| **Cámaras** | ❌ | Sin empezar |
| **Módem** | — | No aplica: modelo solo Wi-Fi |

## Documentación

| Documento | Contenido |
|---|---|
| [docs/development-notes.md](docs/development-notes.md) | Objetivo, estrategia, hechos de hardware confirmados, reglas de seguridad, y el inventario de qué funcionó y qué no repetir |
| [docs/porting-log.md](docs/porting-log.md) | Historial cronológico, sesión a sesión |
| [docs/boot-strategy.md](docs/boot-strategy.md) | Cadena de arranque, particiones, riesgos y recuperación |
| [docs/upstream-audit.md](docs/upstream-audit.md) | Qué soporta mainline y qué hay que escribir |
| [docs/panel-ana38407-bringup.md](docs/panel-ana38407-bringup.md) | Bring-up del panel |
| [docs/testing-mainline-v0.md](docs/testing-mainline-v0.md) | Procedimiento de prueba y rollback |

## Estructura

```text
├── pmaports/device/testing/   paquetes Alpine: kernel + DTS + parches,
│                              paquete de dispositivo y firmware
├── scripts/                   build, empaquetado, staging de firmware,
│                              auditoría y validación reproducibles
├── configs/                   audio (UCM, udev), display, Bluetooth,
│                              Wi-Fi, vendor_boot, TWRP
└── docs/                      documentación del port
```

## Firmware

El repositorio **no contiene firmware propietario**. Los blobs de Samsung y
Qualcomm —Wi-Fi, Bluetooth, GPU, ADSP, CS35L45 y la topología de audio— se
extraen del propio dispositivo o del volcado open-source de Samsung mediante
los scripts `scripts/stage-stock-*.sh`, que verifican cada fichero contra
checksums fijados. Cada propietario de una SM-X910 regenera los suyos.

## Licencias

Este proyecto es **MIT** (véase [LICENSE](LICENSE)), salvo los ficheros que
derivan de Linux y por tanto no pueden llevar otra cosa. Cada fichero declara
lo suyo con una cabecera SPDX, que **prevalece** sobre esta nota:

| Parte | Licencia | Por qué |
|---|---|---|
| Drivers de kernel (`sm5714_battery.c`, `panel-samsung-ana38407.c`) y parches | `GPL-2.0-only` | Son obra derivada de Linux; es un requisito, no una elección |
| Device tree (`sm8550-samsung-gts9uwifi.dts`) | `BSD-3-Clause` | Convención de los DTS de Qualcomm en el kernel |
| Empaquetado (`pmaports/`) | `MIT` | Igual que pmaports upstream, para poder enviarlo allí |
| Scripts, configuración y documentación | `MIT` | |
| Firmware de Samsung/Qualcomm | Propietario | No se redistribuye; se extrae del dispositivo |

MIT como licencia por defecto es deliberado: es compatible con GPL-2.0, así que
el trabajo puede fluir tanto hacia el kernel como hacia pmaports (que es MIT),
mientras que lo contrario no sería posible. Es la opción que menos estorba a
quien quiera contribuir.

## Contribuir

Las aportaciones son bienvenidas, sobre todo en lo que está en ❌ o 🟡. Al
enviar un cambio aceptas publicarlo bajo la licencia que corresponda a esa
parte del árbol según la tabla anterior.

Dos costumbres del proyecto que conviene mantener:

- **Nada de parches en vivo.** Todo arreglo acaba en DTS, config, APKBUILD o
  script reproducible, con `pkgrel` incrementado y checksums actualizados.
- **Verificar en el hardware.** Que un driver cargue no prueba que el
  subsistema funcione.
