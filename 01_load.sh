#!/bin/bash
set -euxo pipefail

# -----------------------------------------
# load all required data to the postgres db
# -----------------------------------------

# ensure required extensions are present in the db
psql -c "CREATE EXTENSION postgis"
psql -c "CREATE EXTENSION postgis_sfcgal"

# bc2pg depends on DATABASE_URL variable - set it here because it is not set in the conda env
DATABASE_URL=postgresql://$PGUSER@$PGHOST:$PGPORT/$PGDATABASE

# use 20k tiles for chunking the processing
bcdata bc2pg WHSE_BASEMAPPING.BCGS_20K_GRID \
  --fid MAP_TILE

# DRA
# Get compressed DRA from ftp rather than via WFS uncompressed GeoJSON - much faster/more reliable
wget --trust-server-names -qNP source_data ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/DRA_Public/dgtl_road_atlas.gdb.zip
unzip -qun -d source_data "source_data/dgtl_road_atlas.gdb.zip"
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -overwrite \
  -lco GEOMETRY_NAME=geom \
  -lco FID=transport_line_id \
  -nln whse_basemapping.transport_line \
  -where "TRANSPORT_LINE_SURFACE_CODE <> 'B'" \
  source_data/dgtl_road_atlas.gdb \
  TRANSPORT_LINE
# Because we are not loading this table via bc2pg, no record is added to bcdata table.
# Do this manually here so we know what day this data was extracted
psql -c "INSERT INTO bcdata (table_name, date_downloaded)
   SELECT 'whse_basemapping.transport_line', CURRENT_TIMESTAMP
   ON CONFLICT (table_name) DO
   UPDATE SET date_downloaded = EXCLUDED.date_downloaded;"

# include the code tables
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -overwrite \
  -nln whse_basemapping.transport_line_structure_code \
  source_data/dgtl_road_atlas.gdb \
  TRANSPORT_LINE_STRUCTURE_CODE

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -overwrite \
  -nln whse_basemapping.transport_line_type_code \
  source_data/dgtl_road_atlas.gdb \
  TRANSPORT_LINE_TYPE_CODE

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -overwrite \
  -nln whse_basemapping.transport_line_surface_code \
  source_data/dgtl_road_atlas.gdb \
  TRANSPORT_LINE_SURFACE_CODE

# FTEN (active and retired)
bcdata bc2pg WHSE_FOREST_TENURE.FTEN_ROAD_SECTION_LINES_SVW \
  --fid MAP_LABEL \
  --query "LIFE_CYCLE_STATUS_CODE IN ('ACTIVE','RETIRED')"

# Results (polygons)
bcdata bc2pg WHSE_FOREST_VEGETATION.RSLT_FOREST_COVER_INV_SVW \
  --fid FOREST_COVER_ID \
  --query "STOCKING_STATUS_CODE = 'NP' AND STOCKING_TYPE_CODE IN ('RD','UNN') AND SILV_POLYGON_NUMBER NOT IN ('landing', 'lnd') AND GEOMETRY_EXIST_IND = 'Y'"

# As built roads
# **This presumes the file has already been downloaded to source_data/ABR.gdb/ABR_ROAD_SECTION_LINE**
ogr2ogr -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -overwrite \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco FID=ROAD_SECTION_LINE_ID \
  -nln whse_forest_tenure.abr_road_section_line \
  source_data/ABR.gdb \
  ABR_ROAD_SECTION_LINE
# Because we are not loading this table via bc2pg, no record is added to bcdata table.
# Do this manually here so we know what day this data was extracted
psql -c "INSERT INTO bcdata (table_name, date_downloaded)
   SELECT 'whse_forest_tenure.abr_road_section_line', CURRENT_TIMESTAMP
   ON CONFLICT (table_name) DO
   UPDATE SET date_downloaded = EXCLUDED.date_downloaded;"

# Oil and Gas Dev, pre06
bcdata bc2pg WHSE_MINERAL_TENURE.OG_PETRLM_DEV_RDS_PRE06_PUB_SP \
  --fid OG_PETRLM_DEV_RD_PRE06_PUB_ID

# Oil and Gas permits, road segments
bcdata bc2pg WHSE_MINERAL_TENURE.OG_ROAD_SEGMENT_PERMIT_SP \
  --fid OG_ROAD_SEGMENT_PERMIT_ID

# Oil and Gas permits, road right of way (polygons)
bcdata bc2pg WHSE_MINERAL_TENURE.OG_ROAD_AREA_PERMIT_SP \
  --fid OG_ROAD_AREA_PERMIT_ID