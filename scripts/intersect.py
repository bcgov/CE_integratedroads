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
@click.argument("dataset_a")
@click.argument("dataset_b")
@click.argument("out_file")
@click.option("--sort_by", "-s", help="Name of sort column")
@verbose_opt
@quiet_opt
def intersect(dataset_a, dataset_b, out_file, sort_by, verbose, quiet):
    """
    Compute intersection of dataset_a with dataset_b and write results to out_file
    """
    verbosity = verbose - quiet
    configure_logging(verbosity)

    # load, overlay, dump
    click.echo(f"Intersecting {dataset_a} with {dataset_b}")
    df_a = geopandas.read_parquet(dataset_a)
    df_b = geopandas.read_parquet(dataset_b)
    overlay = df_a.overlay(df_b, how="intersection")
    if sort_by:
        if sort_by not in overlay.columns:
            raise ValueError(f"Sort column {sort_by} not found in sources")
        overlay = overlay.sort_values(sort_by)
    click.echo(f"Writing overlay to {out_file}")
    overlay.to_parquet(out_file, index=False)


if __name__ == "__main__":
    intersect()
