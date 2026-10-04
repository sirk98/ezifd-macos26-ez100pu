#!/bin/bash

set -euo pipefail

driver_bundle="/usr/local/libexec/SmartCardServices/drivers/ifd-ez-castles.bundle"

if [[ "$driver_bundle" != "/usr/local/libexec/SmartCardServices/drivers/ifd-ez-castles.bundle" ]]; then
	echo "Refusing to remove an unexpected path." >&2
	exit 1
fi

if [[ ! -e "$driver_bundle" ]]; then
	echo "The EZ100PU driver is not installed."
	exit 0
fi

sudo rm -rf -- "$driver_bundle"
sudo pkgutil --forget local.ezifd.castles.ez100pu >/dev/null 2>&1 || true
echo "Removed $driver_bundle"
echo "Disconnect and reconnect the reader, or restart the Mac."
