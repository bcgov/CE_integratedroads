# CE integrated roads

Quckly merge various BC road data sources into a single layer for Cumulative Effects (CE) analysis.

## Sources


|Priority | Name                        | Table                        |
|---------|-----------------------------|------------------------------|
| 1 |[Digital Road Atlas (DRA)](https://catalogue.data.gov.bc.ca/dataset/digital-road-atlas-dra-master-partially-attributed-roads) | WHSE_BASEMAPPING.TRANSPORT_LINE (*from DRA ftp*) |
| 2 | [Forest Tenure Road Section Lines](https://catalogue.data.gov.bc.ca/dataset/forest-tenure-road-section-lines) | WHSE_FOREST_TENURE.FTEN_ROAD_SECTION_LINES_SVW |
| 3 | [RESULTS - Forest Cover Inventory - roads](https://catalogue.data.gov.bc.ca/dataset/results-forest-cover-inventory) | WHSE_FOREST_VEGETATION.RSLT_FOREST_COVER_INV_SVW |
| 4 | [OGC Petroleum Development Roads Pre-2006](https://catalogue.data.gov.bc.ca/dataset/ogc-petroleum-development-roads-pre-2006-public-version) | WHSE_MINERAL_TENURE.OG_PETRLM_DEV_RDS_PRE06_PUB_SP |
| 5 | [Oil and Gas Commission Road Segment Permits](https://catalogue.data.gov.bc.ca/dataset/oil-and-gas-commission-road-segment-permits) | WHSE_MINERAL_TENURE.OG_ROAD_SEGMENT_PERMIT_SP |
| 6 | [Oil and Gas Commission Road Right of Way Permits](https://catalogue.data.gov.bc.ca/dataset/oil-and-gas-commission-road-right-of-way-permits) | WHSE_MINERAL_TENURE.OG_ROAD_AREA_PERMIT_SP |

## Method

First, sources are preprocessed:
- centerlines of polygon road sources are approximated
- FTEN roads are cleaned slightly, snapping endpoints within 7m to other same-source roads

Next, all roads are loaded to the output table in order of decreasing priority. Portions of lower priority roads within 7m of a higher priority road are deleted. Where the endpoint of a remaining lower priority road is within 7m of a higher prioirity road, the endpoint of the lower priority road is snapped to the closest point on the higher priority road.


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


## Requirements

- bash/make/zip/unzip/parallel (see Dockerfile)
- PostgreSQL >= 14
- PostGIS >= 3.3
- GDAL >= 3.8
- Python >= 3.9
- [bcdata](https://github.com/smnorris/bcdata) >= 0.10.2

## Setup

Clone the repository, navigate to the project folder:

        git clone https://github.com/bcgov/CE_integratedroads.git
        cd CE_integratedroads

If you do not have above noted requirements installed on your system (via apt / conda / brew etc), using Docker is recommended.

### Docker

Build and start the containers:

        docker-compose build
        docker-compose up -d

As long as you do not remove the container `roadintegrator-db`, it will retain all the data you put in it.
If you have shut down Docker or the container, start it up again with this command:

        docker-compose up -d

## Usage

Scripts are called via make. To run the full job:

        make

If using Docker:

        docker-compose run --rm app make

Note that connecting to the dockerized database from your local OS is possible via the port specified in `docker-compose.yml`:

        psql postgresql://postgres:postgres@localhost:8001/postgres

## Duplications

As mentioned above, this analysis is very much a rough approximation. It works well in areas where roads are not duplicated between sources or where source road networks are near-coincident.

These diagrams illustrate a problematic sample area, showing three similar input road layers and the resulting output.

### three input layers
![inputs](img/roadintegrator_inputs.png)

### resulting output
![inputs](img/roadintegrator_output.png)


## Alternative approaches

Road network conflation is a common task, many additional approaches and tools are available. This list provides a starting point for additional reading:

- RoadMatcher JUMP/OpenJump plugin [source](https://github.com/ssinger/roadmatcher), [wiki](http://wiki.openstreetmap.org/wiki/RoadMatcher)
- [PostGIS topology](http://blog.mathieu-leplatre.info/use-postgis-topologies-to-clean-up-road-networks.html)
- [Average Path Length Similarity](https://medium.com/the-downlinq/spacenet-road-detection-and-routing-challenge-part-ii-apls-implementation-92acd86f4094)
- [Tiled similarity scoring](https://medium.com/strava-engineering/activity-grouping-the-heart-of-a-social-network-for-athletes-865751f7dca)
- [Hootenanny - a conflation tool](https://github.com/ngageoint/hootenanny)
- [Graph based merging](https://open.library.ubc.ca/cIRcle/collections/ubctheses/24/items/1.0398182)