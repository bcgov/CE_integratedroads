-------
-- Load cariboo consolidated roads to output integrated roads table, where
--  - project tracking index indicates data is ready
--  - data is within the cariboo region
-------

-- create output table
drop table if exists ir_cariboo;
create table ir_cariboo (like ir including all);


-- overlay each road source with the cutter
-- note that the usual overlay speedup (case when st_coveredby()) fails with topology error for coveredby
drop table if exists ir_cut;
create table ir_cut as
with overlay as (
  select distinct
    integratedroads_id,
    b.region_name,
    b.deskex_status,
    st_makevalid((st_dump(st_intersection(a.geom, b.geom))).geom) as geom
  from ir a
  inner join cariboo_cutter b on st_intersects(a.geom, b.geom)
),
-- remove any point intersections
lines as (
  select *
  from overlay
  where st_geometrytype(geom) = 'ST_LineString'
)
-- remove really short fragments
select * from lines
where st_length(geom) > .0001;


drop table if exists ccr_cut;
create table ccr_cut as
with overlay as (
  select distinct
    a.ogc_fid,
    b.region_name,
    b.deskex_status,
    st_makevalid((st_dump(st_intersection(a.geom, b.geom))).geom) as geom
  from ccr a
  inner join cariboo_cutter b on st_intersects(a.geom, b.geom)
),
-- remove any point intersections
lines as (
  select *
  from overlay
  where st_geometrytype(geom) = 'ST_LineString'
)
-- remove really short fragments
select * from lines
where st_length(geom) > .0001;


-- load ir data where applicable
insert into ir_cariboo (
  integratedroads_id,
  bcgw_source,
  cef_road_priority_rank,
  cef_road_attr_src_list,
  map_tile,
  transport_line_id,
  dra_structure,
  dra_type,
  dra_surface,
  dra_name_full,
  dra_road_name_id,
  dra_data_capture_date,
  dra_total_number_of_lanes,
  ften_map_label,
  ften_forest_file_id,
  ften_road_section_id,
  ften_file_status_code,
  ften_file_type_code,
  ften_file_type_description,
  ften_life_cycle_status_code,
  ften_award_date,
  ften_retirement_date,
  ften_client_number,
  ften_client_name,
  results_forest_cover_id,
  results_opening_id,
  results_stocking_status_code,
  results_stocking_type_code,
  results_silv_polygon_number,
  results_reference_year,
  results_when_created,
  results_when_updated,
  og_petrlm_dev_rd_pre06_pub_id,
  petrlm_development_road_type,
  application_received_date,
  proponent,
  ogp_road_segment_permit_id,
  ogp_road_number,
  ogp_segment_number,
  ogp_road_type,
  ogp_road_type_desc,
  ogp_activity_approval_date,
  ogp_proponent,
  ogprow_og_road_area_permit_id,
  ogpermitsrow_road_number,
  ogp_row_road_segment,
  ogp_row_land_stage_desc,
  ogp_row_land_stage_eff_date,
  ogp_row_construction_desc,
  ogp_row_proponent,
  ogp_row_land_type,
  length_metres,
  geom
)
select
  a.integratedroads_id,
  a.bcgw_source,
  a.cef_road_priority_rank,
  a.cef_road_attr_src_list,
  a.map_tile,
  a.transport_line_id,
  a.dra_structure,
  a.dra_type,
  a.dra_surface,
  a.dra_name_full,
  a.dra_road_name_id,
  a.dra_data_capture_date,
  a.dra_total_number_of_lanes,
  a.ften_map_label,
  a.ften_forest_file_id,
  a.ften_road_section_id,
  a.ften_file_status_code,
  a.ften_file_type_code,
  a.ften_file_type_description,
  a.ften_life_cycle_status_code,
  a.ften_award_date,
  a.ften_retirement_date,
  a.ften_client_number,
  a.ften_client_name,
  a.results_forest_cover_id,
  a.results_opening_id,
  a.results_stocking_status_code,
  a.results_stocking_type_code,
  a.results_silv_polygon_number,
  a.results_reference_year,
  a.results_when_created,
  a.results_when_updated,
  a.og_petrlm_dev_rd_pre06_pub_id,
  a.petrlm_development_road_type,
  a.application_received_date,
  a.proponent,
  a.ogp_road_segment_permit_id,
  a.ogp_road_number,
  a.ogp_segment_number,
  a.ogp_road_type,
  a.ogp_road_type_desc,
  a.ogp_activity_approval_date,
  a.ogp_proponent,
  a.ogprow_og_road_area_permit_id,
  a.ogpermitsrow_road_number,
  a.ogp_row_road_segment,
  a.ogp_row_land_stage_desc,
  a.ogp_row_land_stage_eff_date,
  a.ogp_row_construction_desc,
  a.ogp_row_proponent,
  a.ogp_row_land_type,
  round(st_length(i.geom)::numeric, 4) as length_metres,
  b.geom
from ir a
inner join ir_cut b on a.integratedroads_id = b.integratedroads_id
where (b.region_name != 'Cariboo Natural Resource Region' or coalesce(b.deskex_status, 'NA') != 'Complete');

-- load ccr data where applicable
insert into ir_cariboo (
  bcgw_source,
  cef_road_priority_rank,
  cef_road_attr_src_list,
  dra_data_capture_date,
  dra_name_full,
  dra_structure,
  ccr_transport_line_type_code,
  ccr_transport_line_tenure_type_code,
  ccr_deactivation_date,
  ccr_private_flag,
  ccr_access_restricted_flag,
  ccr_access_restriction_type,
  ccr_ground_truth_required,
  ccr_desktop_ex_status,
  map_tile,
  length_metres,
  geom
)
select
  'CARIBOO_CONSOLIDATED_ROADS' as bcgw_source,
  1 as cef_road_priority_rank,
  1 as cef_road_attr_src_list,
  a.capture_date as dra_data_capture_date,
  a.structured_name_1 as dra_name_full,
  dra_struct.description as dra_structure,
  a.transport_line_type_code as ccr_transport_line_type_code,
  a.transport_line_tenure_type_code as ccr_transport_line_tenure_type_code,
  a.deactivation_date as ccr_deactivation_date,
  a.private_flag as ccr_private_flag,
  a.access_restricted_flag as ccr_access_restricted_flag,
  a.access_restriction_type as ccr_access_restriction_type,
  a.ground_truth_required as ccr_ground_truth_required,
  a.desktop_ex_status as ccr_desktop_ex_status,
  a.map_tile,
  round(st_length(b.geom)::numeric, 4) as length_metres,
  b.geom
from ccr a
inner join ccr_cut b on a.ogc_fid = b.ogc_fid
left outer join whse_basemapping.transport_line_structure_code dra_struct
  on a.transport_line_structure_code = dra_struct.transport_line_structure_code
where b.region_name = 'Cariboo Natural Resource Region'
and b.deskex_status = 'Complete';