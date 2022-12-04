# build_dtb
build dtb without a kernel source tree

# intro
to build a dtb without a kernel source tree, we need

- cpp to preprocess the dts and it's includes
    - all the include dts
    - all the include headers
    - correct directory structure
- dtc to compile dts to dtb

# cpp preprocess

### command explain
```
cpp \
-E \
-D __DTS__ \
-nostdinc \
-undef \
-x assembler-with-cpp \
-I dts_include \
-I header_include \
device.dts device.dts.preprocessed
```
- -E : ask cpp to do preprocessing only
- -D \_\_DTS\_\_ : Predefine \_\_DTS\_\_ as a macro, with definition 1
- -nostdinc : Do not search the standard system directories for header files.
- -undef : Do not predefine any system-specific or GCC-specific macros
- -x assembler-with-cpp
- -I includes files that device.dts needs
- device.dts is the dts of your device, [for instance](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/arch/arm64/boot/dts/amlogic/meson-gxl-s905d-phicomm-n1.dts?h=v5.15.78)

### find the include files needed

- look at lines in device.dts start with **`#include`** , trackdown all the `#include` files and until there is no more `#include` on every file

- download the files and put them into correct dir structure based on the `#include` call

# dtc compile
```sh
dtc \
--symbols \
-I dts \
-O dtb \
-o device.dtb device.dts.preprocessed 
```
- --symbols : Enable generation of symbols
- -I : input format, we ask for dts
- -O : output format, we generate dtb
- -o : output file name
- device.dts.preprocessed : we use this dts as input

# scripts
build.sh : the script to do all the above mentioned automatically, with some tricks

- define all the files needed, separate with ',' for curl to use, man curl and search '{}'
- if the filename has ',' , it needs to be escaped with '\\'
- -Z : run curl parallel
- -o "#1" --create-dirs : it will create the dt-bindings/abc/xyz automatically, "#1" is really useful
-  the rest are just bash codes, define source/version, error handling, no need to mention here

# auto compile when kernel updates

debian for example:
- create a kernel hook

the hook will be run when a kernel installed

```sh
doas touch /etc/kernel/postinst.d/zzz-edit-extlinux
doas chmod +x /etc/kernel/postinst.d/zzz-edit-extlinux
```
- hook content

everytime debian updates the kernel, it links the latest install kernel to `/vmlinuz` and `/initrd.img`, we can use this as reference to update the uboot bootloader conf and of course call our dtb build.sh :)

```sh
#!/bin/bash
k="$(realpath /vmlinuz)"
k="${k##*/}"

i="$(realpath /initrd.img)"
i="${i##*/}"

# uboot conf
sed -i \
-e "s|vmlinuz-.*-arm64|$k|g" \
-e "s|initrd.img-.*-arm64|$i|g" \
/boot/extlinux/extlinux.conf

echo "modified /boot/extlinux/extlinux.conf :"
grep -E 'LINUX|INITRD' /boot/extlinux/extlinux.conf

# dtb
echo "building dtb, this takes few seconds"
v="$(dpkg --list linux-image-${k#vmlinuz-} | tail -n1 | awk '{print $3}')"
/boot/build_dtb/build.sh debian "$v" &&
ls -il /boot/meson-gxl-s905d-phicomm-n1.dtb
```
