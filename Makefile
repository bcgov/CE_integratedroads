.PHONY: all build clean

PSQL=psql $(DATABASE_URL) -v ON_ERROR_STOP=1

JOBS=$(wildcard jobs/*)
TARGETS=$(patsubst jobs/%,.make/%,$(JOBS))

# Make all targets
all: $(TARGETS)

# get/build required docker images
build:
	docker-compose build
	docker-compose up -d
	#docker-compose run app psql -c "CREATE DATABASE $(PGDATABASE)" postgres
	#docker-compose run app psql -c "CREATE EXTENSION POSTGIS" ce_integratedroads

# Remove all generated targets, stop and delete the db container
clean:
	rm -Rf .make
	docker-compose down

# run all scripts
.make/% : jobs/%
	mkdir -p .make
	$< && touch $@



# for all output features, identify what other source roads intersect with the road's 7m buffer
.make/integratedroads_sources:
	$(PSQL) -tXA \
	-c "SELECT DISTINCT map_tile FROM integratedroads ORDER BY map_tile" \
	    | parallel --jobs -2 --progress --joblog integratedroads_sources.log \
	      $(PSQL) -f sql/load_sources.sql -v tile={1}
	$(PSQL) -c "CREATE INDEX ON integratedroads_sources (integratedroads_id)"
	$(PSQL) -c "CREATE INDEX ON integratedroads_sources (map_label)"
	$(PSQL) -c "CREATE INDEX ON integratedroads_sources (forest_cover_id)"
	$(PSQL) -c "CREATE INDEX ON integratedroads_sources (road_section_line_id)"
	$(PSQL) -c "CREATE INDEX ON integratedroads_sources (og_petrlm_dev_rd_pre06_pub_id)"
	$(PSQL) -c "CREATE INDEX ON integratedroads_sources (og_road_segment_permit_id)"
	$(PSQL) -c "CREATE INDEX ON integratedroads_sources (og_road_area_permit_id)"
	touch $@

# create output view with required data/columns
.make/integratedroads_vw: .make/integratedroads .make/integratedroads_sources
	$(PSQL) -c "REFRESH MATERIALIZED VIEW integratedroads_vw"
	touch $@

# dump to geopackage
integratedroads.gpkg: .make/integratedroads_vw
	ogr2ogr \
    -f GPKG \
    -progress \
    -nlt LINESTRING \
    -nln integratedroads \
    -lco GEOMETRY_NULLABLE=NO \
    -sql "SELECT * FROM integratedroads_vw" \
    integratedroads.gpkg \
    "PG:$(DATABASE_URL)" \

	# summarize road source by length and percentage in the output gpkg
	ogr2ogr \
	  -f GPKG \
	  -progress \
	  -update \
	  -nln bcgw_source_summary \
	-sql "WITH total AS \
	( \
	  SELECT SUM(ST_Length(geom)) AS total_length \
	  FROM integratedroads_vw \
	) \
	SELECT \
	  bcgw_source, \
	  to_char(bcgw_extraction_date, 'YYYY-MM-DD') as bcgw_extraction_date, \
	  ROUND((SUM(ST_Length(geom) / 1000)::numeric))  AS length_km, \
	  ROUND( \
	    (((SUM(ST_Length(geom)) / t.total_length)) * 100)::numeric, 1) as pct \
	FROM integratedroads_vw, total t \
	GROUP BY bcgw_source, to_char(bcgw_extraction_date, 'YYYY-MM-DD'), total_length \
	ORDER BY bcgw_source" \
	integratedroads.gpkg \
	"PG:$(DATABASE_URL)"

# compress the output gpkg
integratedroads.gpkg.zip: integratedroads.gpkg
	zip -r $@ integratedroads.gpkg

# summarize outputs in a csv file
summary.csv: .make/integratedroads_vw
	$(PSQL) -c "refresh materialized view integratedroads_summary_vw"
	$(PSQL) --csv -c "select * from integratedroads_summary_vw" > summary.csv

# archive the source data
integratedroads_source_data.zip: .make/integratedroads_vw
	zip -r integratedroads_source_data.zip data