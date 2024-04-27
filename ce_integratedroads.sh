#!/bin/bash
set -euxo pipefail

# ----
# run all jobs
# ----

jobs/01_download_wfs
jobs/02_download_files
jobs/00_setup_db                   # requires data downloaded by 01_download_wfs
jobs/03_preprocess_ften
jobs/04_preprocess_results
jobs/05_preprocess_og_permits_row

#for tile in $(shell bcdata cat WHSE_BASEMAPPING.NTS_250K_GRID --query "MAP_TILE = '092B'" | jq -c '.properties.MAP_TILE' | tr '\n' ' ') ; do -- test tile
for tile in $(bcdata cat WHSE_BASEMAPPING.NTS_250K_GRID | jq -c '.properties.MAP_TILE' | tr '\n' ' ')
do
	set -e ; jobs/06_integrate $tile
done

jobs/07_dump