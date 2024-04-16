-------
-- Load cariboo consolidated roads to output integrated roads table, where
--  - project tracking index indicates data is ready
--  - data is within the cariboo region
-------

-- create output table
drop table if exists cer_cariboo;
create table cer_cariboo (like cer including all);


-- generate the cookie cutter - completed tiles, cut to the cariboo region
drop table if exists cutter;
create table cutter as
select
  'cariboo' as desc,
  (st_dump(geom)).geom as geom
from (
  select
    case
      when st_coveredby(a.geom, b.geom) then a.geom
      else st_intersection(a.geom, b.geom)
    end as geom
  from ccr_index a
  inner join whse_admin_boundaries.adm_nr_regions_spg b on st_intersects(a.geom, b.geom)
  and a.deskex_status = 'Complete'
) as f;
create index on cutter using gist (geom);

-- note which ce roads intersect the cutter
drop table if exists cer_cutter_intersection;
create table cer_cutter_intersection as
select distinct
  integratedroads_id
from cer i
inner join cutter c on st_intersects(i.geom, c.geom);

-- First, load ce roads that *do not* intersect cutter
insert into cer_cariboo
select a.*
from cer a
left outer join cer_cutter_intersection b
on a.integratedroads_id = b.integratedroads_id
where b.integratedroads_id is null;

-- cut ce roads that intersect with the cutter but are not completely covered by cutter
-- note that this query is v slow, creating a definition of what is *not* in the cutter
-- and intersecting with that may be faster than running st_difference on the aggregated shape?
drop table if exists cutter_agg;
create table cutter_agg as
select st_union(geom, .1) as geom
from cutter;

with to_cut as (
select
  a.integratedroads_id,
  a.geom
from cer a
inner join cer_cutter_intersection b on a.integratedroads_id = b.integratedroads_id
)

insert into cer_cariboo (
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
  geom
)
select * from (
select
  a.integratedroads_id,
  i.bcgw_source,
  i.cef_road_priority_rank,
  i.cef_road_attr_src_list,
  i.map_tile,
  i.transport_line_id,
  i.dra_structure,
  i.dra_type,
  i.dra_surface,
  i.dra_name_full,
  i.dra_road_name_id,
  i.dra_data_capture_date,
  i.dra_total_number_of_lanes,
  i.ften_map_label,
  i.ften_forest_file_id,
  i.ften_road_section_id,
  i.ften_file_status_code,
  i.ften_file_type_code,
  i.ften_file_type_description,
  i.ften_life_cycle_status_code,
  i.ften_award_date,
  i.ften_retirement_date,
  i.ften_client_number,
  i.ften_client_name,
  i.results_forest_cover_id,
  i.results_opening_id,
  i.results_stocking_status_code,
  i.results_stocking_type_code,
  i.results_silv_polygon_number,
  i.results_reference_year,
  i.results_when_created,
  i.results_when_updated,
  i.og_petrlm_dev_rd_pre06_pub_id,
  i.petrlm_development_road_type,
  i.application_received_date,
  i.proponent,
  i.ogp_road_segment_permit_id,
  i.ogp_road_number,
  i.ogp_segment_number,
  i.ogp_road_type,
  i.ogp_road_type_desc,
  i.ogp_activity_approval_date,
  i.ogp_proponent,
  i.ogprow_og_road_area_permit_id,
  i.ogpermitsrow_road_number,
  i.ogp_row_road_segment,
  i.ogp_row_land_stage_desc,
  i.ogp_row_land_stage_eff_date,
  i.ogp_row_construction_desc,
  i.ogp_row_proponent,
  i.ogp_row_land_type,
  (st_dump(st_difference(a.geom, c.geom))).geom as geom
from to_cut a
inner join cer i on a.integratedroads_id = i.integratedroads_id
, cutter_agg c
) as f where st_geometrytype(geom) = 'ST_LineString';


-- now cut and load the cariboo roads
with overlay as (
  select
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
    case
      when st_coveredby(a.geom, b.geom) then a.geom
      else st_intersection(a.geom, b.geom)
    end as geom
  from ccr a
  inner join cutter b on st_intersects(a.geom, b.geom)
  left outer join whse_basemapping.transport_line_structure_code dra_struct
    on a.transport_line_structure_code = dra_struct.transport_line_structure_code
),
singlepart as (
  select
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
    (st_dump(geom)).geom
  from overlay
)

insert into cer_cariboo (
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
  round(st_length(geom)::numeric, 4) as length_metres,
  geom
from singlepart
where  st_geometrytype(geom) = 'ST_LineString';