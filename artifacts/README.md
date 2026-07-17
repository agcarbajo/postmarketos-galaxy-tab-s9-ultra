# Artefactos

Los ficheros binarios de este directorio no se incluyen en Git. Cada bundle
publicado debe figurar aquí con su propósito, validación y SHA-256.

## Restauración disponible

`restore-ubuntu-touch-v8-boot-sm-x910.zip`

- SHA-256:
  `fd1d31a5fb77c3586171601e438bc7aa7b439fd7e4981d05f1d0aa0f209234f3`.
- Tamaño: 34.360.761 bytes.
- Restaura exclusivamente `boot`, `init_boot`, `vendor_boot`, `dtbo` y
  `vbmeta` de la instalación estable Ubuntu Touch v8/firmware stock.
- Las cinco imágenes se expanden al tamaño completo de su partición para
  borrar cualquier resto de una imagen mainline previa.
- No toca `super`, userdata, recovery ni firmware.
- Validación local: CRC ZIP correcto, `update-binary` modo 0755 y SHA-256 de
  los cinco miembros coincidentes con `SHA256SUMS` interno.

Este ZIP es una red de seguridad; no debe flashearse salvo para volver desde
una futura prueba mainline a Ubuntu Touch.

## Bundle experimental mainline v0

`postmarketos-edge-xfce-mainline-v0-sm-x910-sd.img.zst`

- SHA-256:
  `592deff221c271b03a6830d2b7dc89497e327151951ceac043f4ebadb8c0b237`.
- Tamaño comprimido: 474.829.040 bytes.
- Al descomprimir: imagen raw GPT de 4.634.705.920 bytes, SHA-256
  `103fe9980b7322b2fe2878bd6cf191cabe7152f4d31561623be1a9f0b36ef3b4`.
- Contiene `pmOS_boot` ext2 y `pmOS_root` ext4 con edge, systemd, XFCE,
  NetworkManager, OpenSSH y usuario `phablet`.

`postmarketos-edge-xfce-mainline-v0-sm-x910-twrp.zip`

- SHA-256:
  `7af75c71dcb451e0cc1400a6275c2a01908894e1bde9a34f9b85f34702837bc3`.
- Tamaño: 21.850.347 bytes.
- Escribe exclusivamente `boot`, `init_boot`, `vendor_boot`, `dtbo` y
  `vbmeta`; detecta rutas con y sin sufijo A/B y valida modelo y tamaños.
- El kernel comprimido se extrae del EFI zboot del mismo paquete que instaló
  los módulos en el rootfs. Tanto las imágenes como los ZIP mainline/rollback
  se regeneraron dos veces con hashes idénticos y timestamps normalizados.

Validación local: headers Android v4, offsets, DTB, dos DTBO, AVB, tamaños y
comparaciones byte a byte correctos; CRC/modos/hashes del ZIP y stream zstd
correctos. Esto **no equivale a una prueba de arranque físico**. El primer boot
sigue siendo experimental y se debe realizar siguiendo
`../docs/testing-mainline-v0.md`, con una microSD sacrificable y el ZIP de
restauración a mano.
