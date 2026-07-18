# Artefactos

Los ficheros binarios de este directorio no se incluyen en Git. Cada bundle
publicado debe figurar aquí con su propósito, validación y SHA-256.

## Restauración disponible

`restore-ubuntu-touch-v8-boot-sm-x910.zip`

- SHA-256:
  `eee755c73105ce55311e63eb4a8a50dff42ca6338b1930c017825c510a563e06`.
- Tamaño: 34.361.129 bytes.
- Restaura `boot`, `init_boot`, `vendor_boot`, `dtbo` y, si recovery la expone
  escribible, `vbmeta` de Ubuntu Touch v8/firmware stock. Si `vbmeta` está RO,
  exige que ya tenga AVB flags 2 y la conserva.
- Las cinco imágenes se expanden al tamaño completo de su partición para
  borrar cualquier resto de una imagen mainline previa.
- No toca `super`, userdata, recovery ni firmware.
- Validación local: CRC ZIP correcto, `update-binary` modo 0755 y SHA-256 de
  los cinco miembros coincidentes con `SHA256SUMS` interno.

Este ZIP es una red de seguridad; no debe flashearse salvo para volver desde
una futura prueba mainline a Ubuntu Touch.

## Bundle experimental mainline v0.2

El ZIP v0 anterior, SHA-256 `7af75c71...`, está obsoleto: falla al tratar como
escribible el `vbmeta` RO de este TWRP. No debe volver a flashearse.

El ZIP v0.1, SHA-256 `aaef2bb5...`, también está obsoleto: ABL descomprime su
kernel pero rechaza su DTB por no contener los selectores Qualcomm legacy de
la placa y abre Odin. No debe volver a flashearse.

`postmarketos-edge-xfce-mainline-v0-sm-x910-sd.img.zst`

- SHA-256:
  `592deff221c271b03a6830d2b7dc89497e327151951ceac043f4ebadb8c0b237`.
- Tamaño comprimido: 474.829.040 bytes.
- Al descomprimir: imagen raw GPT de 4.634.705.920 bytes, SHA-256
  `103fe9980b7322b2fe2878bd6cf191cabe7152f4d31561623be1a9f0b36ef3b4`.
- Contiene `pmOS_boot` ext2 y `pmOS_root` ext4 con edge, systemd, XFCE,
  NetworkManager, OpenSSH y usuario `phablet`.

`postmarketos-edge-xfce-mainline-v0.2-sm-x910-twrp.zip`

- SHA-256:
  `9288af69c694fdc84b7b1f9694265152c5f7959a880d338f98b2e3d106c0f65c`.
- Tamaño: 21.850.752 bytes.
- Escribe `boot`, `init_boot`, `vendor_boot` y `dtbo`. Escribe `vbmeta` sólo
  si es RW; si es RO exige AVB flags 2 y lo conserva. Valida todo esto antes de
  escribir la primera partición.
- El kernel comprimido se extrae del EFI zboot del mismo paquete que instaló
  los módulos en el rootfs. El `vendor_boot` incorpora el DTB recompilado con
  `qcom,kalama-mtp`, los IDs SM8550/kalama exactos y `board-id 0x10008/3` que
  Samsung ABL usa para seleccionar el DTB.

Validación local: headers Android v4, offsets, DTB y sus selectores ABL, dos
DTBO, AVB, tamaños y comparaciones byte a byte correctos; CRC/modos/hashes del ZIP y stream zstd
correctos. Esto **no equivale a una prueba de arranque físico**. El primer boot
sigue siendo experimental y se debe realizar siguiendo
`../docs/testing-mainline-v0.md`, con una microSD sacrificable y el ZIP de
restauración a mano.
