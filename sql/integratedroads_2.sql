drop table if exists integratedroads_2;

-- get id of each source
create table integratedroads_2 as
SELECT DISTINCT ON (i.integratedroads_id)
  i.integratedroads_id,
  i.map_tile,
  i.transport_line_id,
  COALESCE(i.map_label, src.map_label) as map_label,
  src.forest_cover_id,
  COALESCE(i.road_section_line_id, src.road_section_line_id) as road_section_line_id,
  COALESCE(i.og_petrlm_dev_rd_pre06_pub_id, src.og_petrlm_dev_rd_pre06_pub_id) as og_petrlm_dev_rd_pre06_pub_id,
  COALESCE(i.og_road_segment_permit_id, src.og_road_segment_permit_id) as og_road_segment_permit_id,
  src.og_road_area_permit_id
FROM integratedroads i
LEFT OUTER JOIN integratedroads_sources src ON i.integratedroads_id = src.integratedroads_id
ORDER BY 
  i.integratedroads_id,
  ften_length desc, 
  results_area desc,
  og_dev_pre06_length desc, 
  og_permits_length desc, 
  og_permits_row_area desc;

create index on integratedroads_2 (integratedroads_id);
create index on integratedroads_2 (transport_line_id);
create index on integratedroads_2 (forest_cover_id);
create index on integratedroads_2 (map_label);
create index on integratedroads_2 (og_petrlm_dev_rd_pre06_pub_id);
create index on integratedroads_2 (og_road_segment_permit_id);
create index on integratedroads_2 (map_tile);