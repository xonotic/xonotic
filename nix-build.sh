#!/bin/sh
set -euo pipefail
cd ${0%/*}
export VERSION_data_xonotic_data_pk3dir=$(cd $PWD/data/xonotic-data.pk3dir && git describe --tags --dirty --long --always)
exec nix-build $@
