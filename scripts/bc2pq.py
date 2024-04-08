import json
import logging
import os
import re
import sys

import bcdata
import click
from cligj import quiet_opt, verbose_opt
import geopandas
from shapely.geometry.linestring import LineString
from shapely.geometry.multilinestring import MultiLineString
from shapely.geometry.multipoint import MultiPoint
from shapely.geometry.multipolygon import MultiPolygon
from shapely.geometry.point import Point
from shapely.geometry.polygon import Polygon


LOG_FORMAT = "%(asctime)s:%(levelname)s:%(name)s: %(message)s"


def configure_logging(verbosity):
    log_level = max(10, 30 - 10 * verbosity)
    logging.basicConfig(stream=sys.stderr, level=log_level, format=LOG_FORMAT)


def complete_dataset_names(ctx, param, incomplete):
    return [k for k in bcdata.list_tables() if k.startswith(incomplete)]


def from_like_context(ctx, param, value):
    """Return the value for an option from the context if the option
    or `--all` is given, else return None."""
    if ctx.obj and ctx.obj.get("like") and (value == "like" or ctx.obj.get("all_like")):
        return ctx.obj["like"][param.name]
    else:
        return None


def bounds_handler(ctx, param, value):
    """Handle different forms of bounds."""
    retval = from_like_context(ctx, param, value)
    if retval is None and value is not None:
        try:
            value = value.strip(", []")
            retval = tuple(float(x) for x in re.split(r"[,\s]+", value))
            assert len(retval) == 4
            return retval
        except Exception:
            raise click.BadParameter(
                "{0!r} is not a valid bounding box representation".format(value)
            )
    else:  # pragma: no cover
        return retval


def process(
    dataset,
    query=None,
    dst_crs=None,
    bounds=None,
    bounds_crs=None,
    count=None,
    columns=None,
    promote_to_multi=False,
    tile_dataset=None,
    out_file=None
):
    log = logging.getLogger(__name__)
    log.info(f"Processing {dataset}")

    # default output file
    if not out_file:
        out_file = dataset + ".parquet"

    if os.path.exists(out_file):
        raise ValueError(f"Output {out_file} exists")

    # load all features to geopandas dataframe
    df = bcdata.get_data(
        dataset,
        crs=dst_crs,
        query=query,
        bounds=bounds,
        bounds_crs=bounds_crs,
        count=count,
        as_gdf=True,
        lowercase=True,
    )

    # only operate on dataframe if there is data
    if len(df.index != 0):
        # tidy the dataframe
        df = df.rename_geometry("geom")

        # retain only columns requested
        if columns:
            df = df[columns + ["geom"]]

        # if specified, cast to everything multipart (responses can have mixed types)
        # geopandas does not have a built in function:
        # https://gis.stackexchange.com/questions/311320/casting-geometry-to-multi-using-geopandas
        if promote_to_multi:
            df["geom"] = [
                MultiPoint([feature]) if isinstance(feature, Point) else feature
                for feature in df["geom"]
            ]
            df["geom"] = [
                MultiLineString([feature]) if isinstance(feature, LineString) else feature
                for feature in df["geom"]
            ]
            df["geom"] = [
                MultiPolygon([feature]) if isinstance(feature, Polygon) else feature
                for feature in df["geom"]
            ]

        # if specified, intersect with tile_dataset
        if tile_dataset:
            log.info(f"Intersecting {dataset} with {tile_dataset}")
            tiles = geopandas.read_parquet(tile_dataset)
            out_df = df.overlay(tiles, how="intersection")
        else:
            out_df = df

        # dump to file
        log.info(f"Writing data to {out_file}")
        # use df.to_parquet(s3://bucket/object.parquet because
        # df.to_file(/vsis3/bucket/object.parquet) uses fiona, and fiona can be bundled
        # with older gdal without parquet support
        out_df.to_parquet(out_file)
    else:
        log.info("No data returned, parquet file not created")


# tab completion object names not currently supported
# def complete_object_names(ctx, param, incomplete):
#    return [k for k in bcdata.list_tables() if k.startswith(incomplete.upper())]


bounds_opt = click.option(
    "--bounds",
    default=None,
    callback=bounds_handler,
    help='Bounds: "left bottom right top" or "[left, bottom, right, top]". Coordinates are BC Albers (default) or --bounds_crs',
)


@click.command()
@click.argument("dataset", type=click.STRING, default="bc2pq.json")
@click.option(
    "--query",
    help="A valid CQL or ECQL query",
)
@click.option(
    "--dst-crs",
    help="CRS of output file",
    default="EPSG:3005",
)
@bounds_opt
@click.option(
    "--bounds-crs",
    "--bounds_crs",
    help="CRS of provided bounds",
    default="EPSG:3005",
)
@click.option(
    "--count",
    "-c",
    default=None,
    type=int,
    help="Total number of features to load",
)
@click.option(
    "--columns", type=click.STRING, help="Columns to retain from source dataset"
)
@click.option(
    "--promote-to-multi",
    is_flag=True,
    help="Promote all geometries to multipart (to avoid mixing types)",
)
@click.option("--tile_dataset", "-t")
@click.option("--out_file", "-o", help="Output file")
@verbose_opt
@quiet_opt
def bc2pq(
    dataset,
    query,
    dst_crs,
    bounds,
    bounds_crs,
    count,
    columns,
    promote_to_multi,
    tile_dataset,
    out_file,
    verbose,
    quiet,
):
    """
    Download BC WFS data to parquet file, optionally overlaying with tile_dataset for optimized queries
    """
    verbosity = verbose - quiet
    log_level = max(10, 20 - 10 * verbosity)
    logging.basicConfig(stream=sys.stderr, level=log_level, format=LOG_FORMAT)
    log = logging.getLogger(__name__)

    if dataset == "bcdata.json":
        log.info("Processing all datasets noted in bcdata.json config file")
        with open("bcdata.json") as f:
            for layer in json.load(f):
                process(
                    layer["dataset"],
                    out_file="s3://" + os.environ["OBJECTSTORE_BUCKET"] + "/" + layer["name"] + ".parquet",
                    query=layer["query"],
                    dst_crs=dst_crs,
                    bounds=bounds,
                    bounds_crs=bounds_crs,
                    columns=layer["columns"],
                    promote_to_multi=layer["promote_to_multi"],
                    tile_dataset=tile_dataset
                )

    else:
        process(
            dataset,
            query,
            dst_crs,
            bounds,
            bounds_crs,
            count,
            columns.split(","),
            promote_to_multi,
            tile_dataset,
            out_file
        )


if __name__ == "__main__":
    bc2pq()
