-- ----------------------------
-- load_sources.sql
--
-- Find *all* additional sources that intersect the 7m buff of every road loaded to integratedroads_1 table.
-- Look at each source separately, in order of priority, finding roads of lower priority that intersect the 7m buffer.
-- For polygonal road sources, also identify which polygonal road is the source as the poly ids are not
-- retained in integratedroads_1 table.
-- ----------------------------

CREATE TEMPORARY TABLE buffers AS
SELECT
  integratedroads_id,
  st_buffer(geom, 7) as geom
FROM integratedroads_1
WHERE map_tile = :'tile';

ANALYZE buffers;

-- Consider DRA roads first
INSERT INTO integratedroads_sources
(
  integratedroads_id,
  map_label,
  ften_length,
  forest_cover_id,
  results_area,
  og_petrlm_dev_rd_pre06_pub_id,
  og_dev_pre06_length,
  og_road_segment_permit_id,
  og_permits_length,
  og_road_area_permit_id,
  og_permits_row_area
)

SELECT
  i.integratedroads_id,
  ften.map_label,
  ROUND((ST_Length(ST_Intersection(b.geom, ften.geom)))::numeric, 2) as ften_length,
  results.forest_cover_id,
  ROUND((ST_Area(ST_Intersection(b.geom, results.geom)))::numeric, 2) as results_area,
  og_dev_pre06.og_petrlm_dev_rd_pre06_pub_id,
  ROUND((ST_Length(ST_Intersection(b.geom, og_dev_pre06.geom)))::numeric, 2) as og_dev_pre06_length,
  og_permits.og_road_segment_permit_id,
  ROUND((ST_Length(ST_Intersection(b.geom, og_permits.geom)))::numeric, 2) as og_permits_length,
  og_permits_row.og_road_area_permit_id,
  ROUND((ST_Area(ST_Intersection(b.geom, og_permits_row.geom)))::numeric, 2) as og_permits_row_area
FROM integratedroads_1 i
INNER JOIN buffers b ON i.integratedroads_id = b.integratedroads_id
LEFT OUTER JOIN whse_forest_tenure.ften_road_section_lines_svw ften
  ON ST_Intersects(b.geom, ften.geom)
LEFT OUTER JOIN whse_forest_vegetation.rslt_forest_cover_inv_svw results
  ON ST_Intersects(b.geom, results.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_petrlm_dev_rds_pre06_pub_sp og_dev_pre06
  ON ST_Intersects(b.geom, og_dev_pre06.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_road_segment_permit_sp og_permits
  ON ST_Intersects(b.geom, og_permits.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_road_area_permit_sp og_permits_row
  ON ST_Intersects(b.geom, og_permits_row.geom)
WHERE i.map_tile = :'tile'
AND i.transport_line_id IS NOT NULL
AND (
  ften.map_label IS NOT NULL OR
  results.forest_cover_id IS NOT NULL OR
  og_dev_pre06.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL OR
  og_permits.og_road_segment_permit_id IS NOT NULL OR
  og_permits_row.og_road_area_permit_id IS NOT NULL
);

-- ften
INSERT INTO integratedroads_sources
(
  integratedroads_id,
  forest_cover_id,
  results_area,
  og_petrlm_dev_rd_pre06_pub_id,
  og_dev_pre06_length,
  og_road_segment_permit_id,
  og_permits_length,
  og_road_area_permit_id,
  og_permits_row_area
)

SELECT
  i.integratedroads_id,
  results.forest_cover_id,
  ROUND((ST_Area(ST_Intersection(b.geom, results.geom)))::numeric, 2) as results_area,
  og_dev_pre06.og_petrlm_dev_rd_pre06_pub_id,
  ROUND((ST_Length(ST_Intersection(b.geom, og_dev_pre06.geom)))::numeric, 2) as og_dev_pre06_length,
  og_permits.og_road_segment_permit_id,
  ROUND((ST_Length(ST_Intersection(b.geom, og_permits.geom)))::numeric, 2) as og_permits_length,
  og_permits_row.og_road_area_permit_id,
  ROUND((ST_Area(ST_Intersection(b.geom, og_permits_row.geom)))::numeric, 2) as og_permits_row_area
FROM integratedroads_1 i
INNER JOIN buffers b ON i.integratedroads_id = b.integratedroads_id
LEFT OUTER JOIN whse_forest_vegetation.rslt_forest_cover_inv_svw results
  ON ST_Intersects(b.geom, results.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_petrlm_dev_rds_pre06_pub_sp og_dev_pre06
  ON ST_Intersects(b.geom, og_dev_pre06.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_road_segment_permit_sp og_permits
  ON ST_Intersects(b.geom, og_permits.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_road_area_permit_sp og_permits_row
  ON ST_Intersects(b.geom, og_permits_row.geom)
WHERE i.map_tile = :'tile'
AND i.map_label IS NOT NULL
AND (
  results.forest_cover_id IS NOT NULL OR
  og_dev_pre06.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL OR
  og_permits.og_road_segment_permit_id IS NOT NULL OR
  og_permits_row.og_road_area_permit_id IS NOT NULL
);


-- results
INSERT INTO integratedroads_sources
(
  integratedroads_id,
  forest_cover_id,  -- note that we include results because we do not previously record which results road was the source
  results_area,
  og_petrlm_dev_rd_pre06_pub_id,
  og_dev_pre06_length,
  og_road_segment_permit_id,
  og_permits_length,
  og_road_area_permit_id,
  og_permits_row_area
)

SELECT
  i.integratedroads_id,
  results.forest_cover_id,
  ROUND((ST_Area(ST_Intersection(b.geom, results.geom)))::numeric, 2) as results_area,
  og_dev_pre06.og_petrlm_dev_rd_pre06_pub_id,
  ROUND((ST_Length(ST_Intersection(b.geom, og_dev_pre06.geom)))::numeric, 2) as og_dev_pre06_length,
  og_permits.og_road_segment_permit_id,
  ROUND((ST_Length(ST_Intersection(b.geom, og_permits.geom)))::numeric, 2) as og_permits_length,
  og_permits_row.og_road_area_permit_id,
  ROUND((ST_Area(ST_Intersection(b.geom, og_permits_row.geom)))::numeric, 2) as og_permits_row_area
FROM integratedroads_1 i
INNER JOIN buffers b ON i.integratedroads_id = b.integratedroads_id
LEFT OUTER JOIN whse_forest_vegetation.rslt_forest_cover_inv_svw results
  ON ST_Intersects(b.geom, results.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_petrlm_dev_rds_pre06_pub_sp og_dev_pre06
  ON ST_Intersects(b.geom, og_dev_pre06.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_road_segment_permit_sp og_permits
  ON ST_Intersects(b.geom, og_permits.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_road_area_permit_sp og_permits_row
  ON ST_Intersects(b.geom, og_permits_row.geom)
WHERE i.map_tile = :'tile'
AND i.results_id IS NOT NULL
AND (
  results.forest_cover_id IS NOT NULL OR
  og_dev_pre06.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL OR
  og_permits.og_road_segment_permit_id IS NOT NULL OR
  og_permits_row.og_road_area_permit_id IS NOT NULL
);

-- og pre06
INSERT INTO integratedroads_sources
(
  integratedroads_id,
  og_road_segment_permit_id,
  og_permits_length,
  og_road_area_permit_id,
  og_permits_row_area
)

SELECT
  i.integratedroads_id,
  og_permits.og_road_segment_permit_id,
  ROUND((ST_Length(ST_Intersection(b.geom, og_permits.geom)))::numeric, 2) as og_permits_length,
  og_permits_row.og_road_area_permit_id,
  ROUND((ST_Area(ST_Intersection(b.geom, og_permits_row.geom)))::numeric, 2) as og_permits_row_area
FROM integratedroads_1 i
INNER JOIN buffers b ON i.integratedroads_id = b.integratedroads_id
LEFT OUTER JOIN whse_mineral_tenure.og_road_segment_permit_sp og_permits
  ON ST_Intersects(b.geom, og_permits.geom)
LEFT OUTER JOIN whse_mineral_tenure.og_road_area_permit_sp og_permits_row
  ON ST_Intersects(b.geom, og_permits_row.geom)
WHERE i.map_tile = :'tile'
AND i.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL
AND (
  og_permits.og_road_segment_permit_id IS NOT NULL OR
  og_permits_row.og_road_area_permit_id IS NOT NULL
);


-- og permits
INSERT INTO integratedroads_sources
(
  integratedroads_id,
  og_road_area_permit_id,
  og_permits_row_area
)

SELECT
  i.integratedroads_id,
  og_permits_row.og_road_area_permit_id,
  ROUND((ST_Area(ST_Intersection(b.geom, og_permits_row.geom)))::numeric, 2) as og_permits_row_area
FROM integratedroads_1 i
INNER JOIN buffers b ON i.integratedroads_id = b.integratedroads_id
LEFT OUTER JOIN whse_mineral_tenure.og_road_area_permit_sp og_permits_row
  ON ST_Intersects(b.geom, og_permits_row.geom)
WHERE i.map_tile = :'tile'
AND i.og_road_segment_permit_id IS NOT NULL
AND og_permits_row.og_road_area_permit_id IS NOT NULL;


-- og_permits_row (no other source contribs to these but we do not include the source attribs to this point)
INSERT INTO integratedroads_sources
(
  integratedroads_id,
  og_road_area_permit_id,
  og_permits_row_area
)

SELECT
  i.integratedroads_id,
  og_permits_row.og_road_area_permit_id,
  ROUND((ST_Area(ST_Intersection(b.geom, og_permits_row.geom)))::numeric, 2) as og_permits_row_area
FROM integratedroads_1 i
INNER JOIN buffers b ON i.integratedroads_id = b.integratedroads_id
LEFT OUTER JOIN whse_mineral_tenure.og_road_area_permit_sp og_permits_row
  ON ST_Intersects(b.geom, og_permits_row.geom)
WHERE i.map_tile = :'tile'
AND i.og_permits_row_id IS NOT NULL;