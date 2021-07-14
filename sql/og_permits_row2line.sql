-- ---------------
-- Convert og permit right of way polys to line, loading to og_permits_row
-- ---------------

-- extract features from tile
WITH tile AS
(SELECT
  (ST_Dump(geom)).geom as geom
FROM (
  SELECT
   r.forest_cover_id,
   t.map_tile,
    CASE
      WHEN ST_CoveredBy(r.geom, t.geom) THEN r.geom
      ELSE ST_Intersection(t.geom, r.geom)
    END AS geom
  FROM whse_mineral_tenure.og_road_area_permit_sp r
  INNER JOIN whse_basemapping.bcgs_20k_grid t
  ON ST_Intersects(r.geom, t.geom)
  WHERE t.map_tile = :'tile'
) as f
WHERE ST_Dimension(geom) = 2
),

-- convert to lines, merge the lines
lines AS
(
  SELECT
   row_number() over() AS id,
   (ST_Dump(ST_Linemerge(ST_Collect(geom)))).geom as geom
  FROM (
    SELECT
      (ST_Dump(
        ST_ApproximateMedialAxisIgnoreErrors(   -- ignore valid self-touching polygons rather than erroring out
          ST_MakeValid(
            ST_ForceRHR(
              ST_FilterRings(geom, 10)  -- remove holes <10m area
          )
        )
      ))).geom as geom
    FROM tile
    WHERE ST_Area(geom) > 10  -- don't bother processing polys <10m area
  ) as f
)

INSERT INTO og_permits_row
(
  map_tile,
  geom
)

-- insert all lines >= 6m (removing artifacts at curves in input polys)
-- We could also search the <6m segments for lines that intersect 2 other
-- lines to ensure all parts of network are included.
-- Don't bother with this for now
SELECT
  :'tile' as map_tile,
  geom
FROM lines l1
WHERE ST_Length(geom) >= 6;