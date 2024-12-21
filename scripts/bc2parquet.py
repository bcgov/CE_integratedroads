import json
import logging
import os
import sys

import bcdata
import click
from cligj import quiet_opt, verbose_opt


LOG_FORMAT = "%(asctime)s:%(levelname)s:%(name)s: %(message)s"


def configure_logging(verbosity):
    log_level = max(10, 30 - 10 * verbosity)
    logging.basicConfig(stream=sys.stderr, level=log_level, format=LOG_FORMAT)


@click.command()
@click.argument("config")
@click.option("--out_path", default=".")
@verbose_opt
@quiet_opt
def bc2parquet(
    config,
    out_path,
    verbose,
    quiet,
):
    """Dump BC Data to parquet"""
    verbosity = verbose - quiet
    configure_logging(verbosity)
    with open(config) as f:
        for layer in json.load(f):
            # request the data
            df = bcdata.get_data(
                dataset=layer["dataset"],
                lowercase=True,
                query=layer["query"],
                promote_to_multi=layer["promote_to_multi"],
                as_gdf=True
            )
            
            # retain only specified columns
            if layer["columns"]:
                df = df[layer["columns"] + ["geometry"]]
            
            df.to_parquet(os.path.join(out_path, layer["dataset"]+".parquet"))


if __name__ == "__main__":
    bc2parquet()