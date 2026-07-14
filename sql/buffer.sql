-- temp table
create temporary table buffers_1 (
  road_class integer,
  map_tile text,
  geom geometry(MultiPolygon, 3005)
);
create index on buffers_1 using gist (geom);

-- output table
drop table if exists buffers;
create table buffers (
  road_class integer,
  map_tile text,
  geom geometry(Polygon, 3005)
);
create index on buffers using gist (geom);


-- create buffers (based on buffer_radius column) 
-- (loaded to temp rather than in another CTE because the spatial index significantly speeds up below steps)
insert into buffers_1 (road_class, map_tile, geom)
select
  road_class,
  map_tile,
  st_makevalid(st_buffer(geom, buffer_radius)) as geom
from integratedroads;

-- then intersect the buffers with tiles (as they will span tiles at edges) and reduce precision
insert into buffers (road_class, map_tile, geom)
with cleaned as (
select
  b.road_class,
  t.map_tile,
  CASE
    WHEN ST_CoveredBy(ST_ReducePrecision(b.geom, .1), ST_ReducePrecision(t.geom, .1)) THEN ST_MakeValid(ST_ReducePrecision(b.geom, .1))
    ELSE ST_MakeValid((ST_Intersection(ST_ReducePrecision(b.geom, .1), ST_ReducePrecision(t.geom, .1), .1)))
  END as geom
FROM buffers_1 b
INNER JOIN whse_basemapping.bcgs_20k_grid t ON st_intersects(b.geom, t.geom)
)

-- dump and subdivide resulting polygons
select * from (
  select
    road_class,
    map_tile,
    st_makevalid(st_subdivide((st_dump(geom)).geom)) as geom
  from cleaned
) as a
where st_dimension(geom) = 2 ;  -- do not include any line/point artifacts created by intersect
