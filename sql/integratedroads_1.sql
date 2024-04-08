-- initial geom load table
DROP TABLE IF EXISTS integratedroads_1 CASCADE;

CREATE TABLE integratedroads_1 (
    integratedroads_id serial primary key,
    map_tile character varying,
    transport_line_id integer,
    map_label character varying,
    results_id integer,
    road_section_line_id integer,
    og_petrlm_dev_rd_pre06_pub_id integer,
    og_road_segment_permit_id integer,
    og_permits_row_id integer,
    geom geometry(Linestring, 3005)
);
CREATE INDEX ON integratedroads_1 USING GIST (geom);

-- initial source id table
-- note that the id is not unique, rows are inserted per source
DROP TABLE IF EXISTS integratedroads_sources CASCADE;
CREATE TABLE integratedroads_sources
(
  integratedroads_id integer,
  map_label character varying,
  ften_length numeric,
  forest_cover_id integer,
  results_area numeric,
  road_section_line_id integer,
  og_petrlm_dev_rd_pre06_pub_id integer,
  og_dev_pre06_length numeric,
  og_road_segment_permit_id integer,
  og_permits_length numeric,
  og_road_area_permit_id integer,
  og_permits_row_area numeric
);