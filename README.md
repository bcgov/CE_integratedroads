# CE integrated roads

Quckly merge various BC road data sources into a single layer for Cumulative Effects (CE) analysis.

## Method

All processing is done via a [manually triggered Github Actions workflow](https://github.com/bcgov/CE_integratedroads/actions/workflows/ce-integratedroads.yaml) (click on the `Run Workflow` button for the `ce-integratedroads` workflow to trigger a run).

1. source datasets are downloaded from file where possible
2. where source data are not avialable via file, download is via WFS, using queries defined in [bcdata.json](bcdata.json)
3. data are cut by BC 1:20k tile and written to Parquet files on S3 compatible object storage
4. downloaded data are preprocessed in PostGIS as required:
   a) centerlines of polygon road sources are approximated
   b) FTEN roads are cleaned slightly, snapping endpoints within 7m to other same-source roads
5. still using PostGIS, the "integration" is processed per 1:250k tile:
   a) roads are loaded to the output table in order of decreasing priority
   b) portions of lower priority roads within 7m of a higher priority road are deleted
   c) where the endpoint of a remaining lower priority road is within 7m of a higher prioirity road, the endpoint of the lower priority road is snapped to the closest point on the higher priority road
6. output (for a given 250k tile) is written to Parquet file on object storage
7. when all tiles are complete, the resulting collection of Parquet files is consolidated into a single zipped file geodatabase on NRS object storage

## Output documentation

See [metadata](metadata.md).

## Development and testing 

### Requirements 

- bash/zip/unzip/parallel (see Dockerfile)
- PostgreSQL >= 14
- PostGIS >= 3.3
- GDAL >= 3.8
- Python >= 3.9
- [bcdata](https://github.com/smnorris/bcdata) >= 0.10.2

### Setup

Clone the repository, navigate to the project folder:

        git clone https://github.com/bcgov/CE_integratedroads.git
        cd CE_integratedroads

If you do not have above noted requirements installed on your system (via apt / conda / brew etc), consider using Docker. To build and start the containers:

        docker-compose build
        docker-compose up -d

As long as you do not remove the container `roadintegrator-db`, it will retain all the data you put in it. If you have shut down Docker or the container, start it up again with this command:

        docker-compose up -d

### Usage

Call scripts in the `/jobs` folder in order as needed. Or run the full job:

        ./ce_integratedroads.sh

or with docker:

        docker-compose run --rm app ce_integratedroads.sh

Note that connecting to the dockerized database from your local OS is possible via the port specified in `docker-compose.yml`:

        psql postgresql://postgres:postgres@localhost:8001/postgres
