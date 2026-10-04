#!/bin/bash

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd -P)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/ezifd-build.XXXXXX")"
stage_dir="$work_dir/stage"
build_dir="$work_dir/build"
source_link="$work_dir/source"
dist_dir="$repo_dir/dist"
package_version="1.5.5.1"
output_pkg="$dist_dir/EZ100PU-arm64-macOS26-${package_version}.pkg"

cleanup() {
	rm -rf -- "$work_dir"
}
trap cleanup EXIT

for command_name in autoreconf automake glibtoolize pkg-config brew make pkgbuild codesign; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		echo "Missing build tool: $command_name" >&2
		exit 1
	fi
done

libusb_prefix="$(brew --prefix libusb)"
build_jobs="$(sysctl -n hw.logicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
ln -s "$repo_dir" "$source_link"
mkdir -p "$build_dir" "$stage_dir" "$dist_dir"

(
	cd "$repo_dir"
	if [[ -f config.status ]]; then
		make distclean
	fi
	autoreconf --install
)

(
	cd "$build_dir"
	CFLAGS='-DRESPONSECODE_DEFINED_IN_WINTYPES_H' \
	PCSC_CFLAGS="-I$source_link/MacOSX" \
	PCSC_LIBS='-framework PCSC' \
	LIBUSB_CFLAGS="-I$libusb_prefix/include/libusb-1.0" \
	LIBUSB_LIBS="$libusb_prefix/lib/libusb-1.0.a -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,Security" \
	"$source_link/configure" \
		--disable-dependency-tracking \
		--enable-oslog \
		--enable-usbdropdir=/usr/local/libexec/SmartCardServices/drivers \
		--disable-static \
		--disable-pcsclite \
		--enable-composite-as-multislot \
		--disable-class \
		--enable-bundle=ifd-ez-castles.bundle \
		--prefix=/fake/castles-ez100pu

	make -j"$build_jobs"
	make install DESTDIR="$stage_dir"
)

bundle="$stage_dir/usr/local/libexec/SmartCardServices/drivers/ifd-ez-castles.bundle"
xattr -cr "$bundle"
codesign --force --deep --sign - "$bundle"
codesign --verify --deep --strict --verbose=2 "$bundle"

if nm -m "$bundle/Contents/MacOS/libccid.dylib" | grep -q '(undefined).*dynamically looked up'; then
	echo "The bundle still contains unresolved internal symbols." >&2
	exit 1
fi

rm -f -- "$output_pkg"
pkgbuild \
	--root "$stage_dir" \
	--identifier local.ezifd.castles.ez100pu \
	--version "$package_version" \
	--install-location / \
	"$output_pkg"

echo "Built: $output_pkg"
shasum -a 256 "$output_pkg"
