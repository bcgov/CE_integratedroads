# CE integrated roads

Quickly merge various BC road data sources into a single layer for Cumulative Effects (CE) analysis.

## Method

1. Source datasets are downloaded - from file where possible, via WFS where files are not available (using queries defined in [bcdata.json](bcdata.json))
2. Downloaded data are preprocessed as required:
    - centerlines of polygon road sources are approximated
    - FTEN roads are cleaned slightly, snapping endpoints within 7m to other same-source roads
    - Source/preprocessed data are cut by BC 1:20k tile and written to parquet file on NRS object store
3. "Integration" is processed per 1:250k tile:
    - roads are loaded to the output table in order of decreasing priority
    - portions of lower priority roads within 7m of a higher priority road are deleted
    - where the endpoint of a remaining lower priority road is within 7m of a higher prioirity road, the endpoint of the lower priority road is snapped to the closest point on the higher priority road
4. Output (for a given 250k tile) is written to parquet file on NRS object store
5. When all tiles are complete, the resulting collection of Parquet files is consolidated into a single zipped file geodatabase on NRS object store

## Processing

Processing can be done via Github Actions. To run the processing workflow, navigate to the `ce-integratedroads` workflow in the [Actions tab](https://github.com/bcgov/CE_integratedroads/actions/workflows/ce-integratedroads.yaml). Press the `Run workflow` button to trigger the job. A fresh extract should be availalbe in the NRS object storage bucket after about 2hrs.

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

### Usage

Edit and run scripts in the `/jobs` folder in order as needed. For example:

        docker compose run --rm runner jobs/01_download
        docker compose run --rm runner jobs/02_preprocess_ften

or run the entire process:

        docker compose run --rm runner ce_integratedroads.sh

Note that connecting to the dockerized database from your local OS is possible via the port specified in `docker-compose.yml` / `.env`:

        psql postgresql://postgres:postgres@localhost:$DB_PORT/postgres

Scripts/commands can often be debugged by dropping in to a bash session on the container:

        $ docker compose run -it --rm runner bash
        [+] Creating 1/0
         ✔ Container ce_integratedroads_db  Running                                                                                                                      0.0s
        root@094dd23d6d25:/home/ce_integratedroads#
