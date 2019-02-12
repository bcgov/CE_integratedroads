-- https://github.com/gojuno/lostgis/blob/master/sql/functions/ST_Safe_Repair.sql

-- modified only to make parallel unsafe, parallel processing is per tile, and
-- handled by Python
create or replace function ST_Safe_Repair(
    geom    geometry,
    message text default '[unspecified]'
) returns geometry as
$$
begin
    if ST_IsEmpty(geom)
    then
        raise debug 'ST_Safe_Repair: geometry is empty';
-- empty POLYGON makes ST_Segmentize fail, replace it with empty GEOMETRYCOLLECTION
        return ST_SetSRID('GEOMETRYCOLLECTION EMPTY' :: geometry, ST_SRID(geom));
    end if;
    if ST_IsValid(geom)
    then
        return ST_ForceRHR(ST_CollectionExtract(geom, ST_Dimension(geom) + 1));
    end if;
    return
    ST_ForceRHR(
        ST_CollectionExtract(
            ST_MakeValid(
                geom
            ),
            ST_Dimension(geom) + 1
        )
    );
end
$$
language 'plpgsql' immutable strict parallel unsafe;