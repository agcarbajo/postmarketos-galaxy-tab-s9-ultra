# Estrategia de arranque y recuperación

## Restricciones demostradas

- SM-X910 no es A/B.
- Samsung expone Download Mode/Odin, no un `fastboot boot` utilizable.
- La cadena Android usa boot header v4.
- El port Ubuntu Touch funcional carga el kernel desde `boot`, el initramfs
  desde `init_boot` y el DTB/vendor cmdline desde `vendor_boot`.
- La DTBO stock contiene APIs downstream y no se puede aplicar sobre un DTB
  mainline.
- `recovery` v2 lleva su propio recovery DTBO y DTB, por lo que TWRP no depende
  de reemplazar temporalmente la partición física `dtbo`.

## Diseño de la prueba

El rootfs postmarketOS vivirá en una microSD ext4. Samsung ABL no busca el
kernel en la tarjeta, así que el conjunto mainline mínimo fiable reemplaza
temporalmente cinco particiones internas:

| Partición | Tamaño exacto | Contenido |
|---|---:|---|
| `boot` | 100663296 | `Image.gz`, header v4, sin ramdisk ni DTB |
| `init_boot` | 8388608 | initramfs postmarketOS |
| `vendor_boot` | 100663296 | DTB X910, cmdline, bootconfig y fragmento vendor vacío |
| `dtbo` | 16777216 | dos overlays no-op con los selectores Samsung originales |
| `vbmeta` | 65536 | AVB con verification/verity desactivados (`flags=2`) |

No se toca `super`, `userdata`, UFS de datos, bootloader, PIT, EFS, persist,
modem ni recovery.

## DTBO mainline segura

El `dtbo.img` stock tiene dos entradas, header de 32 bytes, entry size 32 y
page size 4096. Las entradas de tabla tienen id/rev/custom en cero; los
selectores están en las propiedades raíz de cada FDT:

- board 00: `qcom,board-id=<0x10008 0>`, revisión `0..2`;
- board 03: `qcom,board-id=<0x10008 3>`, revisión `3..0x20`;
- ambas conservan los cuatro pares `qcom,msm-id` stock.

Los nuevos overlays sólo añaden `postmarketos,noop` a `/`. No se usa un DTBO
vacío ni se conserva el overlay downstream.

## Empaquetado reproducible

`scripts/build-android-v4-bundle.sh` reproduce los offsets probados por Ubuntu
Touch:

- base `0x80000000`;
- kernel `0x80008000`;
- ramdisk `0x82000000`;
- tags `0x81e00000`;
- DTB `0x81f00000`;
- page size 4096.

Cada imagen recibe un AVB hash footer con el nombre y tamaño de su partición.
El script comprueba los cinco tamaños y genera SHA-256. No contiene comandos
de flasheo.

## Recuperación obligatoria

Antes de la primera prueba física hay que guardar copias verificadas de las
cinco particiones actuales. La restauración se hará desde TWRP usando
`/dev/block/by-name/<partición>` o con el paquete Odin oficial. Nunca se usarán
números `sdaN` codificados.

La microSD actualmente insertada en la tablet es una tarjeta exFAT de 238.3 GB,
está al 96 % y contiene datos. No se escribirá. La prueba requiere otra tarjeta
sacrificable; primero se generará un fichero de imagen, sin seleccionar ningún
dispositivo físico automáticamente.

## Orden de observación del primer boot

1. simpledrm/consola sobre el splash conservado por ABL;
2. rootfs ext4 por UUID/label en `sdhc_2`;
3. ramoops en el carveout Samsung `0x8:0x80200000 + 2 MiB` tras reinicio en
   caliente;
4. UART7 si los pads resultan accesibles;
5. USB NCM sólo si el repetidor NXP conserva la inicialización de ABL;
6. Wi-Fi/SSH tras incorporar firmware y BDF correctos.

No se anunciará una imagen como flasheable hasta que kernel, DTB, initramfs,
DTBO, AVB y tamaños hayan pasado validación estática.
