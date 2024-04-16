# CE integrated roads

Quckly merge various BC road data sources into a single layer for Cumulative Effects (CE) analysis.

## Sources


|Priority | Name                        | Table                        | Query                        |
|---------|-----------------------------|------------------------------|------------------------------|
| 1 | Cariboo Consolidated Roads | `Cariboo_Consolidated_Roads` from [GeoBC FTP](ftp://ftp.geobc.gov.bc.ca/pub/outgoing/for_CE/Cariboo_Consolidated_Roads_20240304.zip) |  |
| 2 | [Digital Road Atlas (DRA)](https://catalogue.data.gov.bc.ca/dataset/digital-road-atlas-dra-master-partially-attributed-roads) | `WHSE_BASEMAPPING.TRANSPORT_LINE` (*from DRA ftp*) | `TRANSPORT_LINE_SURFACE_CODE <> 'B'` |
| 3 | [Forest Tenure Road Section Lines, ACTIVE](https://catalogue.data.gov.bc.ca/dataset/forest-tenure-road-section-lines) | `WHSE_FOREST_TENURE.FTEN_ROAD_SECTION_LINES_SVW` | `LIFE_CYCLE_STATUS_CODE = 'ACTIVE'` |
| 4 | [Forest Tenure Road Section Lines, RETIRED](https://catalogue.data.gov.bc.ca/dataset/forest-tenure-road-section-lines) | `WHSE_FOREST_TENURE.FTEN_ROAD_SECTION_LINES_SVW` | `LIFE_CYCLE_STATUS_CODE = 'RETIRED'` |
| 5 | [RESULTS - Forest Cover Inventory - roads](https://catalogue.data.gov.bc.ca/dataset/results-forest-cover-inventory) | `WHSE_FOREST_VEGETATION.RSLT_FOREST_COVER_INV_SVW` | `STOCKING_STATUS_CODE in ('NP', 'U') AND STOCKING_TYPE_CODE IN ('RD', 'UNN') AND SILV_POLYGON_NUMBER NOT IN ('landing', 'lnd') AND GEOMETRY_EXIST_IND = 'Y'` |
| 6 | [OGC Petroleum Development Roads Pre-2006](https://catalogue.data.gov.bc.ca/dataset/ogc-petroleum-development-roads-pre-2006-public-version) | `WHSE_MINERAL_TENURE.OG_PETRLM_DEV_RDS_PRE06_PUB_SP` |
| 7 | [Oil and Gas Commission Road Segment Permits](https://catalogue.data.gov.bc.ca/dataset/oil-and-gas-commission-road-segment-permits) | `WHSE_MINERAL_TENURE.OG_ROAD_SEGMENT_PERMIT_SP` |
| 8 | [Oil and Gas Commission Road Right of Way Permits](https://catalogue.data.gov.bc.ca/dataset/oil-and-gas-commission-road-right-of-way-permits) | `WHSE_MINERAL_TENURE.OG_ROAD_AREA_PERMIT_SP` |

## Method

All processing is done via a [manually triggered Github Actions workflow](https://github.com/bcgov/CE_integratedroads/actions/workflows/ce-integratedroads.yaml)

First, source datasets are downloaded from DataBC's WFS server (and from file where possible), cut by BC 1:20k tile, and cached as Parquet in an S3 compatible object storage. This enables fast processing of the resulting chunked data via parallel workers.

Data are then preprocessed:

- centerlines of polygon road sources are approximated
- FTEN roads are cleaned slightly, snapping endpoints within 7m to other same-source roads

Roads are then loaded to the output table in order of decreasing priority. Portions of lower priority roads within 7m of a higher priority road are deleted. Where the endpoint of a remaining lower priority road is within 7m of a higher prioirity road, the endpoint of the lower priority road is snapped to the closest point on the higher priority road. This is done independently for each 1:250k tile and results are written to Parquet on object storage. 

When all tiles are complete, the resulting collection of Parquet files is consolidated into a single output table. 
For areas where official QA'ed consolidated roads data are available (currently only for the Cariboo Region), the "integrated" roads are removed and replaced with the official data.


## Limitations and Caveats

The authoritative source for built roads in British Columbia is the [Digital Road Atlas](https://catalogue.data.gov.bc.ca/dataset/digital-road-atlas-dra-master-partially-attributed-roads). The process used in these scripts **IS NOT A COMPRENSIVE CONFLATION/MERGE** of the input road layers, it is a quick approximation. The intent of the processing is to retain all input features not covered by a higher priority road - due to the nature of duplication in BC road data, the output will always be an over-representation of roads.

Several specific issues will lead to over-representation of roads:

- the same road present in different source layers will only be de-duplicated when features are less than 7m apart, see [Duplications](#Duplications) below)
- roads are present in the tenure layers that have not been built
- roads may have been decomissioned, overgrown or become otherwise impassible
- duplicate same-source roads are not accounted for

Additional notes:

- the various road data sources are not 100% comprehensive, there may be roads present in the landscape that are not included in the analysis and output product
- because processing is tiled by BCGS 20k tile, any portion of road falling outside of these tiles will not be included (tile edges do not exactly match the surveyed BC border)
- attributes from all sources associated with a given road feature are populated when available - attributes for the source feature will be correct but because additional overlapping roads will not always be matched correctly, use additional attribute values with caution (the matching is based only on greatest overlap)

## Duplications

As mentioned above, this analysis is very much a rough approximation. It works well in areas where roads are not duplicated between sources or where source road networks are near-coincident.

These diagrams illustrate a problematic sample area, showing three similar input road layers and the resulting output.

### three input layers
![inputs](img/roadintegrator_inputs.png)

### resulting output
![inputs](img/roadintegrator_output.png)


## Development and testing 

### Requirements 

- bash/make/zip/unzip/parallel (see Dockerfile)
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


## Why use Parquet files? 

To enable efficient processing of chunks of data in disk limited Github Actions workflows.  
Jobs within the workflow load Parquet files from object storage to ephemeral PostGIS databases for processing, then write analysis outputs to new object store Parquet files - which can then be picked up by subsequent jobs. 
Other formats could be used to cache the chunked data, but Parquet is a good tool for the job: speedy, space efficient, and chunks do not have to be merged once the processing is complete (a folder of Parquet files can be read as a single dataset). This workflow would be even more effective for file-based processing, but not all required spatial functions are available yet in tools like geopandas and duckdb.

Background:

- [CloudNativeGeo - backgrounder](https://guide.cloudnativegeo.org/geoparquet/)
- [GDAL - Parquet driver](https://gdal.org/drivers/vector/parquet.html#vector-parquet)
- [Radiant Earth - geo partitioning](https://medium.com/radiant-earth-insights/the-admin-partitioned-geoparquet-distribution-59f0ca1c6d96)
- [Crunchy Data - Parquet FDW](https://www.crunchydata.com/blog/parquet-and-postgres-in-the-data-lake)

## Alternative approaches

Road network conflation is a common task, many additional approaches and tools are available. This list provides a starting point for additional reading:

- RoadMatcher JUMP/OpenJump plugin [source](https://github.com/ssinger/roadmatcher), [wiki](http://wiki.openstreetmap.org/wiki/RoadMatcher)
- [PostGIS topology](http://blog.mathieu-leplatre.info/use-postgis-topologies-to-clean-up-road-networks.html)
- [Average Path Length Similarity](https://medium.com/the-downlinq/spacenet-road-detection-and-routing-challenge-part-ii-apls-implementation-92acd86f4094)
- [Tiled similarity scoring](https://medium.com/strava-engineering/activity-grouping-the-heart-of-a-social-network-for-athletes-865751f7dca)
- [Hootenanny - a conflation tool](https://github.com/ngageoint/hootenanny)
- [Graph based merging](https://open.library.ubc.ca/cIRcle/collections/ubctheses/24/items/1.0398182)
