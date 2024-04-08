-- output table
DROP TABLE IF EXISTS integratedroads;

CREATE TABLE integratedroads as
SELECT distinct on (s.integratedroads_id)
  i.integratedroads_id                      AS INTEGRATEDROADS_ID,
  -- source used for the linework (taken from the _1 table)
  CASE
    WHEN i.transport_line_id IS NOT NULL THEN 'WHSE_BASEMAPPING.TRANSPORT_LINE'
    WHEN i.map_label IS NOT NULL THEN 'WHSE_FOREST_TENURE.FTEN_ROAD_SECTION_LINES_SVW'
    WHEN i.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL THEN 'WHSE_MINERAL_TENURE.OG_PETRLM_DEV_RDS_PRE06_PUB_SP'
    WHEN i.og_road_segment_permit_id IS NOT NULL THEN 'WHSE_MINERAL_TENURE.OG_ROAD_SEGMENT_PERMIT_SP'
    WHEN i.results_id IS NOT NULL THEN 'WHSE_FOREST_VEGETATION.RSLT_FOREST_COVER_INV_SVW'
    WHEN i.og_permits_row_id IS NOT NULL THEN 'WHSE_MINERAL_TENURE.OG_ROAD_AREA_PERMIT_SP'
  END AS bcgw_source,
  i.map_tile                                AS MAP_TILE,
  s.transport_line_id                       AS TRANSPORT_LINE_ID,
  dra_struct.description                    AS DRA_STRUCTURE,
  dra_type.description                      AS DRA_TYPE,
  dra_surf.description                      AS DRA_SURFACE,
  dra.structured_name_1                     AS DRA_NAME_FULL,
  dra.structured_name_1_id                  AS DRA_ROAD_NAME_ID,
  dra.capture_date                          AS DRA_DATA_CAPTURE_DATE,
  dra.total_number_of_lanes                 AS DRA_TOTAL_NUMBER_OF_LANES,
  s.map_label                               AS FTEN_MAP_LABEL,
  ften.forest_file_id                       AS FTEN_FOREST_FILE_ID,
  ften.road_section_id                      AS FTEN_ROAD_SECTION_ID,
  ften.file_status_code                     AS FTEN_FILE_STATUS_CODE,
  ften.file_type_code                       AS FTEN_FILE_TYPE_CODE,
  ften.file_type_description                AS FTEN_FILE_TYPE_DESCRIPTION,
  ften.life_cycle_status_code               AS FTEN_LIFE_CYCLE_STATUS_CODE,
  ften.award_date                           AS FTEN_AWARD_DATE,
  ften.retirement_date                      AS FTEN_RETIREMENT_DATE,
  ften.client_number                        AS FTEN_CLIENT_NUMBER,
  ften.client_name                          AS FTEN_CLIENT_NAME,
  s.forest_cover_id                         AS RESULTS_FOREST_COVER_ID,
  results.opening_id                        AS RESULTS_OPENING_ID,
  results.stocking_status_code              AS RESULTS_STOCKING_STATUS_CODE,
  results.stocking_type_code                AS RESULTS_STOCKING_TYPE_CODE,
  results.silv_polygon_number               AS RESULTS_SILV_POLYGON_NUMBER,
  results.reference_year                    AS RESULTS_REFERENCE_YEAR,
  results.forest_cover_when_created         AS RESULTS_WHEN_CREATED,
  results.forest_cover_when_updated         AS RESULTS_WHEN_UPDATED,
  s.og_petrlm_dev_rd_pre06_pub_id           AS OG_PETRLM_DEV_RD_PRE06_PUB_ID,
  og_dev_pre06.petrlm_development_road_type AS PETRLM_DEVELOPMENT_ROAD_TYPE,
  og_dev_pre06.application_received_date    AS APPLICATION_RECEIVED_DATE,
  og_dev_pre06.proponent                    AS PROPONENT,
  s.og_road_segment_permit_id               AS OGP_ROAD_SEGMENT_PERMIT_ID,
  og_permits.road_number                    AS OGP_ROAD_NUMBER,
  og_permits.segment_number                 AS OGP_SEGMENT_NUMBER,
  og_permits.road_type                      AS OGP_ROAD_TYPE,
  og_permits.road_type_desc                 AS OGP_ROAD_TYPE_DESC,
  og_permits.activity_approval_date         AS OGP_ACTIVITY_APPROVAL_DATE,
  og_permits.proponent                      AS OGP_PROPONENT,
  og_permits_row.og_road_area_permit_id     AS OGPROW_OG_ROAD_AREA_PERMIT_ID,
  og_permits_row.road_number                AS OGPERMITSROW_ROAD_NUMBER,
  og_permits_row.road_segment               AS OGP_ROW_ROAD_SEGMENT,
  og_permits_row.land_stage_desc            AS OGP_ROW_LAND_STAGE_DESC,
  og_permits_row.land_stage_eff_date        AS OGP_ROW_LAND_STAGE_EFF_DATE,
  og_permits_row.construction_desc          AS OGP_ROW_CONSTRUCTION_DESC,
  og_permits_row.proponent                  AS OGP_ROW_PROPONENT,
  og_permits_row.land_type                  AS OGP_ROW_LAND_TYPE,
  st_length(i.geom)                AS LENGTH_METRES,
  i.geom
FROM integratedroads_2 s
INNER JOIN integratedroads_1 i on s.integratedroads_id = i.integratedroads_id
LEFT OUTER JOIN whse_basemapping.transport_line dra
  ON s.transport_line_id = dra.transport_line_id
LEFT OUTER JOIN whse_basemapping.transport_line_structure_code dra_struct
  ON dra.transport_line_structure_code = dra_struct.transport_line_structure_code
LEFT OUTER JOIN whse_basemapping.transport_line_type_code dra_type
  ON dra.transport_line_type_code = dra_type.transport_line_type_code
LEFT OUTER JOIN whse_basemapping.transport_line_surface_code dra_surf
  ON dra.transport_line_surface_code = dra_surf.transport_line_surface_code
LEFT OUTER JOIN whse_forest_tenure.ften_road_section_lines_svw ften
  ON s.map_label = ften.map_label
LEFT OUTER JOIN whse_forest_vegetation.rslt_forest_cover_inv_svw results
  ON s.forest_cover_id = results.forest_cover_id
LEFT OUTER JOIN whse_mineral_tenure.og_petrlm_dev_rds_pre06_pub_sp og_dev_pre06
  ON s.og_petrlm_dev_rd_pre06_pub_id = og_dev_pre06.og_petrlm_dev_rd_pre06_pub_id
LEFT OUTER JOIN whse_mineral_tenure.og_road_segment_permit_sp og_permits
  ON s.og_road_segment_permit_id = og_permits.og_road_segment_permit_id
LEFT OUTER JOIN whse_mineral_tenure.og_road_area_permit_sp og_permits_row
  ON s.og_road_area_permit_id = og_permits_row.og_road_area_permit_id
order by s.integratedroads_id, s.map_tile;

CREATE UNIQUE INDEX ON integratedroads (integratedroads_id);
CREATE INDEX ON integratedroads USING GIST (geom);