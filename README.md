# CE integrated roads

Quickly merge various BC road data sources into a single layer for Cumulative Effects (CE) analysis.

## Method

1. Source datasets are downloaded from file where possible
2. Where source data are not avialable via file, download is via WFS, using queries defined in [bcdata.json](bcdata.json)
3. Data are cut by BC 1:20k tile and written to Parquet files on S3 compatible object storage
4. Downloaded data are preprocessed in PostGIS as required:
    1. centerlines of polygon road sources are approximated
    2. FTEN roads are cleaned slightly, snapping endpoints within 7m to other same-source roads
5. Still using PostGIS, the "integration" is processed per 1:250k tile:
    1. roads are loaded to the output table in order of decreasing priority
    2. portions of lower priority roads within 7m of a higher priority road are deleted
    3. where the endpoint of a remaining lower priority road is within 7m of a higher prioirity road, the endpoint of the lower priority road is snapped to the closest point on the higher priority road
6. Output (for a given 250k tile) is written to Parquet file on object storage
7. When all tiles are complete, the resulting collection of Parquet files is consolidated into a single zipped file geodatabase on NRS object storage

## Processing

All processing is done via Github Actions. To run the job, navigate to the `ce-integratedroads` workflow in the [Actions tab](https://github.com/bcgov/CE_integratedroads/actions/workflows/ce-integratedroads.yaml). Press the `Run workflow` button to trigger the job. A fresh extract should be availalbe on NRS object storage after about 2hrs.

## Output documentation

See [metadata](metadata.md).


## Development and testing 

### Requirements 

Docker

### Setup

Clone the repository, navigate to the project folder:

        git clone https://github.com/bcgov/CE_integratedroads.git
        cd CE_integratedroads

To build and start the containers:

        docker compose build
        docker compose up -d

Postgresql data is stored in the local `postgres-data` folder.
If you have shut down Docker or the container, re-start it the same command and all data loaded to the db will still be available.

        docker compose up -d

**Platform notes**

The provided Docker configuration files assume that pre-built postgis images are not availalable for the development platform (ie arm64/apple silicon) - the `docker compose build` process uses files in `docker/db` to build a postgis enabled postgres database image. Therefore, [`docker/db/Dockerfile`](docer/db/Dockerfile) requires updating as postgres/postgis upgrades become available. See the [source files](https://github.com/postgis/docker-postgis) for updated references, and remember to keep the db version synced with the db version used in the Github Actions yaml files. If pre-built images are available for your platform, modify `docker-compose.yml` to use them instead.

### Usage

Call scripts in the `/jobs` folder in order as needed:

        docker compose run --rm runner 01_download_wfs
        docker compose run --rm runner 02_download_files

or run the entire job:

        docker compose run --rm runner ce_integratedroads.sh

Note that connecting to the dockerized database from your local OS is possible via the port specified in `docker-compose.yml` / `.env`:

        psql postgresql://postgres:postgres@localhost:$DB_PORT/postgres

And a script can often be debugged by dropping in to a bash session on the container:

        $ docker compose run -it --rm runner bash
        [+] Creating 1/0
         ✔ Container ce_integratedroads_db  Running                                                                                                                      0.0s
        root@094dd23d6d25:/home/ce_integratedroads#
