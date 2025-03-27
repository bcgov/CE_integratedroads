-- -----------------------
-- Clean FTEN roads slightly
-- - snap endpoints
-- - reduce precision to .001
-- - remove duplicate geometries (with same life cycle status code)
-- - re-node (break at intersections)
--
-- Note that active and retired records are processed separately to avoid
-- re-noding along duplicate geoms. Any de-duplication between active/retired
-- geometries is taken care of by the integration process)
-- -----------------------

WITH src AS (
  SELECT row_number() over() as id, *
  FROM (
    SELECT
      forest_file_id,
      road_section_id,
      file_status_code,
      file_type_code,
      file_type_description,
      life_cycle_status_code,
      award_date,
      retirement_date,
      client_number,
      client_name,
      map_label,
      map_tile,
      (ST_Dump(geom)).geom as geom
    FROM whse_forest_tenure.ften_road_section_lines_svw r
    WHERE map_tile = :'tile'
    AND life_cycle_status_code = :'status'
    ) as f
),

start_snapped AS
(
  SELECT
  a.id,
  ST_LineInterpolatePoint(
    nn.geom,
    ST_LineLocatePoint(
      nn.geom,
        ST_StartPoint(a.geom)
    )
  ) as geom
FROM src a
CROSS JOIN LATERAL (
  SELECT
    id,
    ST_Distance(ST_StartPoint(a.geom), b.geom) as dist,
    geom
  FROM src b
  WHERE a.id != b.id
  AND ST_Distance(ST_Startpoint(a.geom), b.geom) > 0
  ORDER BY ST_StartPoint(a.geom) <-> b.geom
  LIMIT 1
) as nn
INNER JOIN whse_basemapping.bcgs_20k_grid t
ON a.map_tile = t.map_tile
WHERE nn.dist <= 7
AND NOT ST_DWithin(ST_Startpoint(a.geom), ST_ExteriorRing(t.geom), .1) -- do not snap endpoints created at tile intersections
),

end_snapped AS
(
  SELECT
  a.id,
  ST_LineInterpolatePoint(
    nn.geom,
    ST_LineLocatePoint(
      nn.geom,
        ST_EndPoint(a.geom)
    )
  ) as geom
FROM src a
CROSS JOIN LATERAL (
  SELECT
    id,
    ST_Distance(ST_EndPoint(a.geom), b.geom) as dist,
    geom
  FROM src b
  WHERE a.id != b.id
  AND ST_Distance(ST_Endpoint(a.geom), b.geom) > 0
  ORDER BY ST_EndPoint(a.geom) <-> b.geom
  LIMIT 1
) as nn
INNER JOIN whse_basemapping.bcgs_20k_grid t
ON a.map_tile = t.map_tile
WHERE nn.dist <= 7
AND NOT ST_DWithin(ST_Endpoint(a.geom), ST_ExteriorRing(t.geom), .1) -- do not snap endpoints created at tile intersections
),

snapped AS
(
  SELECT
    a.id,
    a.map_label,
    a.map_tile,
    CASE
      WHEN s.id IS NOT NULL AND e.id IS NULL                        -- snap just start
      THEN ST_Setpoint(a.geom, 0, s.geom)
      WHEN s.id IS NOT NULL AND e.id IS NOT NULL                    -- snap just end
      THEN ST_SetPoint(ST_Setpoint(a.geom, 0, s.geom), -1, e.geom)
      WHEN s.id IS NULL AND e.id IS NOT NULL                        -- snap start and end
      THEN ST_Setpoint(a.geom, -1, e.geom)
      ELSE a.geom
    END as geom
  FROM src a
  LEFT JOIN start_snapped s ON a.id = s.id
  LEFT JOIN end_snapped e ON a.id = e.id
),

-- drop duplicates at .001m precision
distinct_geom AS (
  select
    count(*) as n,
    map_tile,
    array_agg(map_label) as map_label,
    st_snaptogrid(geom, .001) as geom
  from snapped
  group by st_snaptogrid(geom, .001), map_tile
),

-- node the linework
noded AS
(
  SELECT
    row_number() over() as id,
    n,
    geom
  FROM (
    SELECT
      n,
      (st_dump(st_node(st_union(geom)))).geom as geom
    FROM distinct_geom
    GROUP BY n
    ) AS f
),

-- get the map_label back via spatial query
noded_attrib AS
(
  SELECT DISTINCT ON (n.id)
    n.id,
    t.map_tile,
    t.map_label,
    n.geom
  FROM noded n
  INNER JOIN distinct_geom t
  ON ST_Intersects(n.geom, t.geom)
  ORDER BY n.id, ST_Length(ST_Intersection(n.geom, t.geom)) DESC
),

-- unnest the map label
unnested AS (
  SELECT
    map_tile,
    unnest(map_label) as map_label,
    geom
  FROM noded_attrib
),

-- get distinct records
unique_recs as (
  SELECT DISTINCT
    s.forest_file_id,
    s.road_section_id,
    s.file_status_code,
    s.file_type_code,
    s.file_type_description,
    s.life_cycle_status_code,
    s.award_date,
    s.retirement_date,
    s.client_number,
    s.client_name,
    n.map_label,
    n.map_tile,
    n.geom
  FROM unnested n
  left outer join src s on n.map_label = s.map_label
)

INSERT INTO ften_cleaned (
  forest_file_id,
  road_section_id,
  file_status_code,
  file_type_code,
  file_type_description,
  life_cycle_status_code,
  award_date,
  retirement_date,
  client_number,
  client_name,
  map_label,
  map_tile,
  geom
)

SELECT
  array_to_string(array_agg(forest_file_id), ';') as forest_file_id,
  array_to_string(array_agg(road_section_id), ';') as road_section_id,
  array_to_string(array_agg(file_status_code), ';') as file_status_code,
  array_to_string(array_agg(file_type_code), ';') as file_type_code,
  array_to_string(array_agg(file_type_description), ';') as file_type_description,
  array_to_string(array_agg(life_cycle_status_code), ';') as life_cycle_status_code,
  array_to_string(array_agg(award_date), ';') as award_date,
  array_to_string(array_agg(retirement_date), ';') as retirement_date,
  array_to_string(array_agg(client_number), ';') as client_number,
  array_to_string(array_agg(client_name), ';') as client_name,
  array_to_string(array_agg(map_label), ';') as map_label,
  map_tile,
  geom
FROM unique_recs
GROUP BY map_tile, geom

