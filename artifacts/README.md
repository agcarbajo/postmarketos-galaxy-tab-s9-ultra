# Artefactos

Los ficheros binarios de este directorio no se incluyen en Git. Cada bundle
publicado debe figurar aquí con su propósito, validación y SHA-256.

## Restauración disponible

`restore-ubuntu-touch-v8-boot-sm-x910.zip`

- SHA-256:
  `240599697c20c500cb180b31771f008401b1274a744ac3f81f15f5fd5b1dfcbe`.
- Tamaño: 34,360,677 bytes.
- Restaura exclusivamente `boot`, `init_boot`, `vendor_boot`, `dtbo` y
  `vbmeta` de la instalación estable Ubuntu Touch v8/firmware stock.
- Las cinco imágenes se expanden al tamaño completo de su partición para
  borrar cualquier resto de una imagen mainline previa.
- No toca `super`, userdata, recovery ni firmware.
- Validación local: CRC ZIP correcto, `update-binary` modo 0755 y SHA-256 de
  los cinco miembros coincidentes con `SHA256SUMS` interno.

Este ZIP es una red de seguridad; no debe flashearse salvo para volver desde
una futura prueba mainline a Ubuntu Touch.

## Bundle mainline

Pendiente. No hay todavía ningún ZIP mainline autorizado para flashear.
