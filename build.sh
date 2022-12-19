#!/bin/bash
# refer : https://stackoverflow.com/questions/50658326/device-tree-compiler-not-recognizes-c-syntax-for-include-files
PATH="/usr/bin:/usr/sbin"
workdir="$(realpath "$0")" && cd "${workdir%/*}"
mainline_ver="5.15.79"
debian_ver="5.10.149-2"
#source="${1-mainline}" # debian, mainline
source="${1-debian}" # debian, mainline
dev_name="meson-gxl-s905d-phicomm-n1"
curl="curl -sSfL -m10 --connect-timeout 5"
tempdir=""
die () { printf "%s\n" "$@" ; [[ -d "$tempdir" ]] && rm -rf "$tempdir" ; exit 1 ; }
check_cmd () { for i in "$@" ; do command -v "$i" &>/dev/null || die "$i not found" ; done ; }
check_cmd curl cpp dtc
dts="meson-gxl-s905d-p230.dts,meson-gxl-s905d.dtsi,meson-gxl.dtsi,meson-gx.dtsi,meson-gxl-mali.dtsi,meson-gx-mali450.dtsi,meson-gx-p23x-q20x.dtsi"
header="dt-bindings/input/input.h,dt-bindings/clock/gxbb-clkc.h,dt-bindings/clock/gxbb-aoclkc.h,dt-bindings/gpio/meson-gxl-gpio.h,dt-bindings/reset/amlogic\,meson-gxbb-reset.h,dt-bindings/gpio/gpio.h,dt-bindings/interrupt-controller/irq.h,dt-bindings/interrupt-controller/arm-gic.h,dt-bindings/power/meson-gxbb-power.h,dt-bindings/thermal/thermal.h,dt-bindings/sound/meson-aiu.h"
# parse url
case "$source" in
    mainline)
        kv="${2-$mainline_ver}"
        dts_url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/arch/arm64/boot/dts/amlogic/{$dts}?h=v$kv"
        header_url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/include/{$header}?h=v$kv"
        extra_header_url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/include/uapi/linux/input-event-codes.h?h=v$kv";;
    debian)
        kv="${2-$debian_ver}"
        dts_url="https://sources.debian.org/data/main/l/linux/$kv/arch/arm64/boot/dts/amlogic/{$dts}"
        header_url="https://sources.debian.org/data/main/l/linux/$kv/include/{$header}"
        extra_header_url="https://sources.debian.org/data/main/l/linux/$kv/include/uapi/linux/input-event-codes.h" ;;
    *)
        die "wrong args" ;;
esac
# prepare
tempdir="$(mktemp -d)" || die "failed to create tempdir"
dts_dir="$tempdir/dts_include" ; header_dir="$tempdir/header_include"
mkdir -p "$dts_dir" "$header_dir"
# download dts
$curl -Z -o "$dts_dir"/"#1" "$dts_url" || die "failed to curl dts"
# download header , linux-event-codes.h is a special header needed by input.h 
$curl -Z -o "$header_dir"/"#1" --create-dirs "$header_url" || die "failed to curl header"
$curl -o "$header_dir"/linux-event-codes.h "$extra_header_url" || die "failed to curl header"

# process
cpp -E -D __DTS__ -nostdinc -undef -x assembler-with-cpp -I "$dts_dir" -I "$header_dir" "${dev_name}.dts" "$tempdir/${dev_name}.dts.preprocessed" || die "failed to run cpp"
dtc -q --symbols -I dts -O dtb -o "${dev_name}-${source}-${kv}.dtb" "$tempdir/${dev_name}.dts.preprocessed" || die "failed to run dtc"
# install
(( EUID )) && _sudo="sudo" || _sudo=""
$_sudo cp -f "${dev_name}-${source}-${kv}.dtb" "/boot/${dev_name}.dtb"
# clean
rm -rf "$tempdir"
