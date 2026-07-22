# Artefactos

Los ficheros binarios de este directorio no se incluyen en Git. Cada bundle
publicado debe figurar aquí con su propósito, validación y SHA-256.

## Bundle actual v0.66 — reverse PRIME acelerado

`postmarketos-edge-xfce-mainline-v0.66-reverse-prime-sm-x910-twrp.zip`

- SHA-256:
  `f54322f0dbd5145f57f5c138d3e52ec09ff78b6a3a6991cf1c2a77ddc87b7466`.
- Tamaño: 29.420.384 bytes.
- Kernel mainline 7.2-rc3/r37 con Wi-Fi, Goodix, Adreno, DPU/DSI/DSC, panel
  ANA38407 y UFS. Mantiene `msm.separate_gpu_kms=1` y expone recursos KMS
  vacíos en la DRM Adreno para poder usarla como source reverse PRIME.
- El overlay incluye el APK local `xorg-server-999921.1.23-r10`, su instalador
  previo a LightDM, la configuración Adreno-primary/DPU-output y el hook que
  asocia providers y recupera el OLED mediante un ciclo DSI.
- Build desde worktree kernel pristino con `BUILD_EXIT=0`. Validación local:
  ZIP/CRC correcto y presencia/contenido de APK, config, scripts y drop-ins.
- Validación física equivalente: el mismo boot v0.65/r37 y userspace r10
  sobreviven a un reinicio completo; Wi-Fi/SSH, XFCE, Goodix y FD740 acelerado
  vuelven solos. `glmark2` se ve en el OLED central sin faults. El ZIP v0.66
  todavía no se ha flasheado; debe hacerlo manualmente la usuaria.

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

## Bundle experimental mainline v0.6

El ZIP v0 anterior, SHA-256 `7af75c71...`, está obsoleto: falla al tratar como
escribible el `vbmeta` RO de este TWRP. No debe volver a flashearse.

El ZIP v0.1, SHA-256 `aaef2bb5...`, también está obsoleto: ABL descomprime su
kernel pero rechaza su DTB por no contener los selectores Qualcomm legacy de
la placa y abre Odin. No debe volver a flashearse.

El ZIP v0.2, SHA-256 `9288af69...`, está obsoleto: ABL ya selecciona su DTB,
pero el ufdt Samsung no puede aplicar el overlay sobre una base sin
`/__symbols__` y abre Odin. No debe volver a flashearse.

El ZIP v0.3, SHA-256 `0a0d5b0e...`, también está obsoleto: aun con 474
símbolos, el fork ufdt de Samsung falla exactamente igual al aplicar el no-op.
No debe volver a flashearse.

El ZIP v0.4, SHA-256 `2083daf1...`, validó el fallback appended-DTB y llegó a
mostrar Linux, pero después TrustZone reinició el SoC con un fatal NoC. Le
faltaban los carveouts que la DTBO Samsung aporta normalmente. Está obsoleto y
no debe volver a flashearse.

El ZIP v0.5, SHA-256 `1ae10d4e...`, añadió esos carveouts pero reprodujo el
mismo fatal NoC. El vídeo sitúa el último probe completado justo antes de
`lpass_ag_noc@7e40000`. Está obsoleto y no debe volver a flashearse.

`postmarketos-edge-xfce-mainline-v0.6-sm-x910-sd.img.zst`

- SHA-256:
  `6250db18ed8afaad2afd8d98dad376305fccefa0518be806c3cf08af0791939e`.
- Tamaño comprimido: 472.948.641 bytes.
- Al descomprimir: imagen raw GPT de 4.634.705.920 bytes, SHA-256
  `62704236c7faa4b819a19751eefb32dfdafbf6151ce834738ac5a4d3d191a759`.
- Contiene `pmOS_boot` ext2 y `pmOS_root` ext4 con edge, systemd, XFCE,
  NetworkManager, OpenSSH, usuario `phablet` y kernel/módulos r4.

`postmarketos-edge-xfce-mainline-v0.6-sm-x910-twrp.zip`

- SHA-256:
  `0890bbe1160aa5b03d40963209ae2a5193d7857531ee2518f0adbaf522d31a9a`.
- Tamaño: 21.883.967 bytes.
- Escribe `boot`, `init_boot`, `vendor_boot` y `dtbo`. Escribe `vbmeta` sólo
  si es RW; si es RO exige AVB flags 2 y lo conserva. Valida todo esto antes de
  escribir la primera partición.
- El kernel comprimido se extrae del EFI zboot del mismo paquete que instaló
  los módulos en el rootfs. El `vendor_boot` incorpora el DTB recompilado con
  `qcom,kalama-mtp`, los IDs SM8550/kalama exactos y `board-id 0x10008/3` que
  Samsung ABL usa para seleccionar el DTB. Está compilado con `-@`, contiene
  474 símbolos y puede actuar como base del overlay ufdt de ABL.
- En v0.6 ese DTB se concatena también tras el miembro `Image.gz` dentro de
  `boot.img`. `dtbo.img` empieza por cuatro bytes cero en vez de la magia
  Android DT table, forzando a ABL a usar su ruta de DTB appended sin ufdt.
  La imagen mantiene footer AVB válido y los 16 MiB exactos de la partición.
- El DTB añade los carveouts Samsung ausentes en v0.4: UH/KASLR, `chipinfo`,
  `sec_xbl`, LLCC, HW-fence X910 y las reservas altas de bootloader/depuración
  segura. El validador compara individualmente sus 15 rangos contra los
  valores extraídos del FDT vivo.
- `lpass_ag_noc@7e40000` queda deshabilitado para aislar el fatal observado al
  final del vídeo v0.5. El kernel incluye una consola `LOGM` sobre
  `sec_log_buf`, de modo que un nuevo fallo temprano debería quedar legible en
  `/proc/last_kmsg` desde TWRP.

Validación local: headers Android v4, offsets, prefijo gzip y sufijo FDT de
`boot` comparados byte a byte, DTB/selectores ABL/`__symbols__`, magia DTBO
nula deliberada, AVB, tamaños y comparaciones correctos; CRC/modos/hashes del
ZIP y stream zstd correctos. v0.4 sí confirmó ejecución del kernel y
simpledrm, pero v0.6 aún requiere prueba física. Se debe realizar siguiendo
`../docs/testing-mainline-v0.md`, con una microSD sacrificable y el ZIP de
restauración a mano.
