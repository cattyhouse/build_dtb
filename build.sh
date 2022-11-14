#!/bin/bash
# refer : https://stackoverflow.com/questions/50658326/device-tree-compiler-not-recognizes-c-syntax-for-include-files
PATH="/usr/bin:/usr/sbin"
workdir="$(realpath "$0")"
cd "${workdir%/*}"
dev_name="meson-gxl-s905d-phicomm-n1"

#source="${1-mainline}" # debian, mainline
source="${1-debian}" # debian, mainline

mainline_ver="5.15.77"
debian_ver="5.10.149-2"

curl="curl -sSfL -m10 --connect-timeout 5"

die () { echo "$@" ; exit 1 ; }

command -v curl &>/dev/null || die "curl not found"
command -v cpp &>/dev/null || die "cpp not found"
command -v dtc &>/dev/null || die "dtc not found"

case "$source" in
    mainline)
        kv="${2-$mainline_ver}"
        url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain" ;;
    debian)
        kv="${2-$debian_ver}"
        url="https://sources.debian.org/data/main/l/linux/$kv" ;;
    *)
        die "wrong args" ;;
esac

dts_url="$url/arch/arm64/boot/dts/amlogic"
header_url="$url/include"

dts="meson-gxl-s905d-p230.dts,meson-gxl-s905d.dtsi,meson-gxl.dtsi,meson-gx.dtsi,meson-gxl-mali.dtsi,meson-gx-mali450.dtsi,meson-gx-p23x-q20x.dtsi"

header="dt-bindings/input/input.h,dt-bindings/clock/gxbb-clkc.h,dt-bindings/clock/gxbb-aoclkc.h,dt-bindings/gpio/meson-gxl-gpio.h,dt-bindings/reset/amlogic\,meson-gxbb-reset.h,dt-bindings/gpio/gpio.h,dt-bindings/interrupt-controller/irq.h,dt-bindings/interrupt-controller/arm-gic.h,dt-bindings/power/meson-gxbb-power.h,dt-bindings/thermal/thermal.h,dt-bindings/sound/meson-aiu.h"

tempdir="$(mktemp -d)" || die "failed to create tempdir"
mkdir -p "$tempdir"/{dts_include,header_include}

# download dts
pushd "$tempdir"/dts_include >/dev/null
case "$source" in
    mainline) $curl -Z -o "#1" "$dts_url/{$dts}?h=v$kv" || die "failed to curl dts" ;;
    debian) $curl -Z -o "#1" "$dts_url/{$dts}" || die "failed to curl dts" ;;
esac
popd >/dev/null

# download header
# linux-event-codes.h is a special header needed by input.h 
pushd "$tempdir"/header_include >/dev/null
case "$source" in
    mainline)
        $curl -Z -o "#1" --create-dirs "$header_url/{$header}?h=v$kv" || die "failed to curl header"
        $curl -o linux-event-codes.h "$header_url/uapi/linux/input-event-codes.h?h=v$kv" || die "failed to curl header" ;;
    debian)
        $curl -Z -o "#1" --create-dirs "$header_url/{$header}" || die "failed to curl header"
        $curl -o linux-event-codes.h "$header_url/uapi/linux/input-event-codes.h" || die "failed to curl header" ;;
esac
popd >/dev/null

cpp -E -D __DTS__ -nostdinc -undef -x assembler-with-cpp -I "$tempdir"/dts_include -I "$tempdir"/header_include "${dev_name}.dts" "$tempdir"/"${dev_name}.dts.preprocessed" || die "failed to run cpp"
dtc --symbols -I dts -O dtb -o "${dev_name}-${source}-${kv}.dtb" "$tempdir"/${dev_name}.dts.preprocessed 2>/dev/null || die "failed to run dtc"
cp -f "${dev_name}-${source}-${kv}.dtb" "/boot/${dev_name}.dtb"
rm -rf "$tempdir"
