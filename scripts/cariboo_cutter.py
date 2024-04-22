import logging
import sys

import bcdata
import click
import geopandas
from cligj import quiet_opt, verbose_opt

LOG_FORMAT = "%(asctime)s:%(levelname)s:%(name)s: %(message)s"


def configure_logging(verbosity):
    log_level = max(10, 30 - 10 * verbosity)
    logging.basicConfig(stream=sys.stderr, level=log_level, format=LOG_FORMAT)


@click.command()
@click.argument("out_file")
@verbose_opt
@quiet_opt
def cariboo_cutter(out_file, verbose, quiet):
    """
    Create cariboo mask
    """
    verbosity = verbose - quiet
    configure_logging(verbosity)

    # get data
    tile250 = bcdata.get_data("WHSE_BASEMAPPING.NTS_250K_GRID", as_gdf=True).to_crs(
        "EPSG:3005"
    )
    region = bcdata.get_data(
        "WHSE_ADMIN_BOUNDARIES.ADM_NR_REGIONS_SPG",
        query="REGION_NAME = 'Cariboo Natural Resource Region'",
        as_gdf=True,
    ).to_crs("EPSG:3005")
    ccr_index = geopandas.read_file("/vsizip/tmp/Project_Tracking_20240304.gdb.zip")

    # pull columns of interest
    tile250 = tile250[["MAP_TILE", "geometry"]]
    region = region[["REGION_NAME", "geometry"]]
    ccr_index = ccr_index[["DeskEx_Status", "geometry"]]

    # overlay
    overlay1 = tile250.overlay(region, how="union")
    overlay2 = overlay1.overlay(ccr_index, how="union")

    # tidy
    overlay2.columns = [x.lower() for x in overlay2.columns]

    # dump
    overlay2.to_parquet(out_file)


if __name__ == "__main__":
    cariboo_cutter()
