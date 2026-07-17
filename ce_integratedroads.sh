#!/bin/bash
set -euxo pipefail

# ----
# run all jobs (on a single db)
# ----

jobs/01_download
jobs/02_preprocess_ften
jobs/03_preprocess_results
jobs/04_preprocess_og_permits_row
jobs/05_load


for tile in $(bcdata cat WHSE_BASEMAPPING.NTS_250K_GRID | jq -r '.properties.MAP_TILE' | tr '\n' ' ')
do
  set -e ; jobs/06_integrate $tile
  set -e ; jobs/07_aggregate_buffers $tile
done

jobs/08_dump

