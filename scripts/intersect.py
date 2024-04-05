import logging

import sys

import click
import geopandas
from cligj import quiet_opt, verbose_opt

LOG_FORMAT = "%(asctime)s:%(levelname)s:%(name)s: %(message)s"


def configure_logging(verbosity):
    log_level = max(10, 30 - 10 * verbosity)
    logging.basicConfig(stream=sys.stderr, level=log_level, format=LOG_FORMAT)


@click.command()
@click.argument("source_dataset")
@click.argument("tile_dataset")
@click.argument("out_file")
@verbose_opt
@quiet_opt
def intersect(source_dataset, tile_dataset, out_file, verbose, quiet):
    """
    Find intersection of source_dataset with tile_dataset and write results to out_file
    """
    verbosity = verbose - quiet
    configure_logging(verbosity)

    # load, overlay, dump
    click.echo(f"Intersecting {source_dataset} with {tile_dataset}")
    source = geopandas.read_parquet(source_dataset)
    tiles = geopandas.read_parquet(tile_dataset)
    tiled_data = source.overlay(tiles, how="intersection")
    click.echo(f"Writing overlay to {out_file}")
    tiled_data.to_parquet(out_file)


if __name__ == "__main__":
    intersect()