-- -----------------------
-- clean active FTEN roads slightly, snapping endpoints and re-noding
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
      map_tile_250,
      (ST_Dump(geom)).geom as geom
    FROM whse_forest_tenure.ften_road_section_lines_svw r
    WHERE map_tile = :'tile'
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

-- node the linework
noded AS
(
  SELECT
    row_number() over() as id,
    geom
  FROM (
    SELECT
      (st_dump(st_node(st_union(geom)))).geom as geom
    FROM snapped
    ) AS f
),

-- get the attributes back
noded_attrib AS
(
  SELECT DISTINCT ON (n.id)
    n.id,
    t.map_tile,
    t.map_label,
    n.geom
  FROM noded n
  INNER JOIN snapped t
  ON ST_Intersects(n.geom, t.geom)
  ORDER BY n.id, ST_Length(ST_Intersection(n.geom, t.geom)) DESC
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
  map_tile_250,
  geom
)
SELECT
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
  s.map_tile_250,
  n.geom
FROM noded_attrib n
inner join src s on n.map_label = s.map_label;