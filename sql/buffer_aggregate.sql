-- remove buffer overlaps, retaining just the highest ranking (lowest class)
-- do this by dumping to lines and rebuilding the polys (instead of running st_difference several times)
drop table if exists buffered_road_class;
create table buffered_road_class (
  road_class text,
  map_tile text,
  geom geometry(MultiPolygon, 3005)
);

-- dump poly rings and convert to lines
with rings as
(
  SELECT
    map_tile,
    ST_Exteriorring((ST_DumpRings(geom)).geom) AS geom
  FROM raw_buffers
  WHERE map_tile LIKE :'tile' || '%'  -- remove anything not in tile of interest
),

-- node the lines with st_union and dump to singlepart lines
lines as
(
  SELECT
    map_tile,
    (st_dump(st_union(geom, .1))).geom as geom
  FROM rings
  GROUP BY map_tile
),

-- polygonize the resulting noded lines
flattened AS
(
  SELECT
    map_tile,
    (ST_Dump(ST_Polygonize(geom))).geom AS geom
  FROM lines
  GROUP BY map_tile
),

-- get the attributes
sorted AS
(
  SELECT
    min(p.road_class) as road_class,  -- retain just the min road class (highest ranked)
    f.map_tile,
    f.geom
  FROM flattened f
  LEFT OUTER JOIN raw_buffers p ON ST_Contains(p.geom, ST_PointOnSurface(f.geom))
  group by f.map_tile, f.geom
)

-- aggregate
insert into buffered_road_class (road_class, map_tile, geom)
select 
  road_class,
  map_tile,
  st_makevalid(st_union(geom, .01)) as geom
from sorted
where road_class is not null
group by road_class, map_tile;
