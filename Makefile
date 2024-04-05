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