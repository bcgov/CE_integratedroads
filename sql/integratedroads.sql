-- output table

DROP TABLE IF EXISTS ften_distinct CASCADE;
CREATE TABLE ften_distinct AS
SELECT DISTINCT
  map_label,
  forest_file_id,
  road_section_id,
  file_status_code,
  file_type_code,
  file_type_description,
  life_cycle_status_code,
  award_date,
  retirement_date,
  client_number,
  client_name
FROM whse_forest_tenure.ften_road_section_lines_svw
ORDER BY map_label;
CREATE INDEX ON ften_distinct (map_label);

DROP TABLE IF EXISTS road_attr_src_list CASCADE;
CREATE TABLE road_attr_src_list AS
SELECT DISTINCT ON (integratedroads_id)
  integratedroads_id,
  CASE WHEN s.transport_line_id IS NOT NULL THEN 1 ELSE NULL END as s1,
  CASE WHEN s.map_label IS NOT NULL and ften.life_cycle_status_code = 'ACTIVE' THEN 2 ELSE NULL END as s2,
  CASE WHEN s.map_label IS NOT NULL and ften.life_cycle_status_code = 'RETIRED' THEN 3 ELSE NULL END as s3,
  CASE WHEN s.forest_cover_id IS NOT NULL THEN 4 ELSE NULL END as s4,
  CASE WHEN s.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL THEN 5 ELSE NULL END as s5,
  CASE WHEN s.og_road_segment_permit_id IS NOT NULL THEN 6 ELSE NULL END as s6,
  CASE WHEN s.og_road_area_permit_id IS NOT NULL THEN 7 ELSE NULL END as s7
FROM integratedroads_2 s
LEFT OUTER JOIN ften_distinct ften ON s.map_label = ften.map_label
ORDER BY s.integratedroads_id, ften.map_label;
CREATE INDEX ON road_attr_src_list (integratedroads_id);


DROP VIEW IF EXISTS integratedroads;

CREATE VIEW integratedroads as

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
  CASE
    WHEN i.transport_line_id IS NOT NULL THEN 2
    WHEN i.map_label IS NOT NULL and ften.life_cycle_status_code = 'ACTIVE' THEN 3
    WHEN i.map_label IS NOT NULL and ften.life_cycle_status_code = 'RETIRED' THEN 4
    WHEN i.results_id IS NOT NULL THEN 5
    WHEN i.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL THEN 6
    WHEN i.og_road_segment_permit_id IS NOT NULL THEN 7
    WHEN i.og_permits_row_id IS NOT NULL THEN 8
  END AS cef_road_priority_rank,
  array_to_string(array_remove(array[rasl.s1, rasl.s2, rasl.s3, rasl.s4, rasl.s5, rasl.s6, rasl.s7], NULL),';') as cef_road_attr_src_list,
  i.map_tile                                as map_tile,
  s.transport_line_id                       as transport_line_id,
  dra_struct.description                    as dra_structure,
  dra_type.description                      as dra_type,
  dra_surf.description                      as dra_surface,
  dra.structured_name_1                     as dra_name_full,
  dra.structured_name_1_id                  as dra_road_name_id,
  dra.capture_date                          as dra_data_capture_date,
  dra.total_number_of_lanes                 as dra_total_number_of_lanes,
  s.map_label                               as ften_map_label,
  ften.forest_file_id                       as ften_forest_file_id,
  ften.road_section_id                      as ften_road_section_id,
  ften.file_status_code                     as ften_file_status_code,
  ften.file_type_code                       as ften_file_type_code,
  ften.file_type_description                as ften_file_type_description,
  ften.life_cycle_status_code               as ften_life_cycle_status_code,
  ften.award_date                           as ften_award_date,
  ften.retirement_date                      as ften_retirement_date,
  ften.client_number                        as ften_client_number,
  ften.client_name                          as ften_client_name,
  s.forest_cover_id                         as results_forest_cover_id,
  results.opening_id                        as results_opening_id,
  results.stocking_status_code              as results_stocking_status_code,
  results.stocking_type_code                as results_stocking_type_code,
  results.silv_polygon_number               as results_silv_polygon_number,
  results.reference_year                    as results_reference_year,
  results.forest_cover_when_created         as results_when_created,
  results.forest_cover_when_updated         as results_when_updated,
  s.og_petrlm_dev_rd_pre06_pub_id           as og_petrlm_dev_rd_pre06_pub_id,
  og_dev_pre06.petrlm_development_road_type as petrlm_development_road_type,
  og_dev_pre06.application_received_date    as application_received_date,
  og_dev_pre06.proponent                    as proponent,
  s.og_road_segment_permit_id               as ogp_road_segment_permit_id,
  og_permits.road_number                    as ogp_road_number,
  og_permits.segment_number                 as ogp_segment_number,
  og_permits.road_type                      as ogp_road_type,
  og_permits.road_type_desc                 as ogp_road_type_desc,
  og_permits.activity_approval_date         as ogp_activity_approval_date,
  og_permits.proponent                      as ogp_proponent,
  og_permits_row.og_road_area_permit_id     as ogprow_og_road_area_permit_id,
  og_permits_row.road_number                as ogpermitsrow_road_number,
  og_permits_row.road_segment               as ogp_row_road_segment,
  og_permits_row.land_stage_desc            as ogp_row_land_stage_desc,
  og_permits_row.land_stage_eff_date        as ogp_row_land_stage_eff_date,
  og_permits_row.construction_desc          as ogp_row_construction_desc,
  og_permits_row.proponent                  as ogp_row_proponent,
  og_permits_row.land_type                  as ogp_row_land_type,
  -- include empty cariboo consolidated roads columns
  null::text                                as ccr_transport_line_type_code,
  null::text                                as ccr_transport_line_tenure_type_code,
  null::text                                as ccr_deactivation_date,
  null::text                                as ccr_private_flag,
  null::text                                as ccr_access_restricted_flag,
  null::text                                as ccr_access_restriction_type,
  null::text                                as ccr_ground_truth_required,
  null::text                                as ccr_desktop_ex_status,
  st_length(i.geom)                         as length_metres,
  i.geom
FROM integratedroads_2 s
INNER JOIN integratedroads_1 i on s.integratedroads_id = i.integratedroads_id
INNER JOIN road_attr_src_list rasl on s.integratedroads_id = rasl.integratedroads_id
LEFT OUTER JOIN whse_basemapping.transport_line dra
  ON s.transport_line_id = dra.transport_line_id
LEFT OUTER JOIN whse_basemapping.transport_line_structure_code dra_struct
  ON dra.transport_line_structure_code = dra_struct.transport_line_structure_code
LEFT OUTER JOIN whse_basemapping.transport_line_type_code dra_type
  ON dra.transport_line_type_code = dra_type.transport_line_type_code
LEFT OUTER JOIN whse_basemapping.transport_line_surface_code dra_surf
  ON dra.transport_line_surface_code = dra_surf.transport_line_surface_code
LEFT OUTER JOIN ften_distinct ften
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
