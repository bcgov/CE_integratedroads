CREATE EXTENSION postgis;
CREATE EXTENSION postgis_sfcgal;

CREATE SCHEMA whse_basemapping;
CREATE SCHEMA whse_forest_tenure;
CREATE SCHEMA whse_forest_vegetation;
CREATE SCHEMA whse_mineral_tenure;

CREATE OR replace FUNCTION ST_ApproximateMedialAxisIgnoreErrors(arg geometry)
RETURNS geometry LANGUAGE plpgsql
AS $$
BEGIN
    BEGIN
        RETURN CG_ApproximateMedialAxis(arg);
    EXCEPTION WHEN OTHERS THEN
        RETURN null;
    end;
END $$;

-- 20k tile table with 250k tile ref added
CREATE TABLE whse_basemapping.bcgs_20k_grid (
  map_tile text primary key,
  map_tile_250k text GENERATED ALWAYS AS (left(map_tile, 4)) STORED,
  geom geometry(polygon, 3005)
);
