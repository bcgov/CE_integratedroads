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


.make/00_setup_db: jobs/00_setup_db
	$< && touch $@

.make/01_download_wfs: jobs/01_download_wfs .make/00_setup_db
	$< && touch $@

.make/02_download_files: jobs/02_download_files .make/00_setup_db
	$< && touch $@

.make/03_preprocess_ften: jobs/03_preprocess_ften .make/01_download_wfs
	$< && touch $@

.make/04_preprocess_results: jobs/04_preprocess_results .make/01_download_wfs
	$< && touch $@

.make/05_preprocess_og_permits_row: jobs/05_preprocess_og_permits_row .make/01_download_wfs
	$< && touch $@

.make/06_integratedroads: jobs/06_integratedroads .make/05_preprocess_og_permits_row .make/04_preprocess_results .make/03_preprocess_ften .make/02_download_files
	for tile in $(shell bcdata cat WHSE_BASEMAPPING.NTS_250K_GRID --query "MAP_TILE = '092B'" | jq -c '.properties.MAP_TILE' | tr '\n' ' ') ; do  \
		set -e ; jobs/06_integratedroads $$tile ; \
	done
	touch $@

.make/07_dump: jobs/07_dump .make/06_integratedroads
	$< && touch $@