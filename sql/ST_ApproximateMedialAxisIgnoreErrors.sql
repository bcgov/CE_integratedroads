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