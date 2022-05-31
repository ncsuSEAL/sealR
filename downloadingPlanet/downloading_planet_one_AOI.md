---
title: "downloading_planet"
author: "Izzi Hinks"
date: "4/24/2022"
output: html_document
---

```{bash setup}
# Working directory
WORK_DIR="/Volumes/GoogleDrive/My Drive/Research/Augmentation/augmentation_official"

# Set names of relevant folder paths
DATA_DIR="$WORK_DIR/data"

poly_shps="$DATA_DIR/field_shps" # Polygon shp path
poly_geojsons="$DATA_DIR/field_geojsons" # Polygon geojson path
aoi_geojson="$poly_geojsons/<name_of_your_geojson_file>.geojson"
idlist_dir="$DATA_DIR/hand_delineated_fields/idlists"

# If you want PlanetScope data between two dates: 
start_date="2021-01-01"
end_date="2022-01-01"

# Time frame in which you want to check for orders (e.g. if you ordered images on 2022-05-31, I'd use these)
search_start="2022-05-30"
search_end="2022-06-01"
```

## Batch downloading Planet data using the porder CLI for the Planet OrdersV2 API

Planet's porder CLI (Command-Line Interface) for the Planet ordersV2 API enables users to batch download Planet data. With the script in this folder, you can: 
- Optionally clip tiles to a desired location (bounding coordinates in a shapefile/geojson, or a buffer around a single coordinate)
- Get all available data _between_ two dates (under a specific % cloud cover threshold, if desired)
- Get Planet images _on_ specific dates
- Get pre-calculated bands of indices (simple ratio, NDVI, GNDVI, BNDVI, TVI, OSAVI, EVI2, NDWI, MSAVI2), if you're gathering 4-band PlanetScope ("PSScene4Band"), or just all bands themselves

## Step 1: Install prerequisites and the porder CLI
Visit [this link](https://github.com/tyson-swetnam/porder#prerequisites) to install all of the prerequisites and the porder CLI.
NOTE: It is best to do this in a conda environment, so all of your packages are compatible and constant.

For all of these code chunks, run the code in your terminal (by copy and pasting, if you'd like)

```{bash logging_in}
# Uncomment the line below if you forgot the name of your conda environment!
# conda env list

# Activate the conda environment in which the porder API is installed
# For instance, mine is: 
conda activate field_delin

# Initialize the Planet OrdersV2 API by signing in with email/password
# planet init
```

Sign in to your Planet account before moving to the next step. 

If you have a multipolygon layer in QGIS, go to Vector > Data Management Tools > Split Vector Layer to separate it into individual polygon files within a folder.

## Step 2 (Optional): Convert a folder of shapefiles to geojsons

Planet can clip a tile to your desired AOI if you feed it a geojson. Not all geojsons work, so it's safest to pass your geojson through this convert function to make sure the geojson includes all of the data in the format that Planet needs to order your images.

```{bash convert}
# Uncomment the line below to explore the functionality of the porder API
# porder --help

# Use the convert argument and source and destination folders to convert
# shps to geojsons
porder convert --source "$poly_shps" --destination "$poly_geojsons"
```

## Step 3: Gather IDs of PlanetScope images of interest

This will just return a one-column list of the PlanetScope images in a file: AOI_IDs.csv

```{bash get_IDs}
# Use the idlist argument and input, start date, end date, item type, asset, and outfile parameters

# If you have one geojson AOI: 
porder idlist --input "$aoi_geojson" --start "$start_date" --end "$end_date" --item "PSScene4Band" --asset "analytic_sr,udm" --outfile "$idlist_dir/AOI_IDs.csv"
```

## Step 4 (optional): Split the ID lists from Step 3 into smaller lists if need be (max of 500 IDs per order)
$idlist_dir/split_IDs
```{bash idsplit}
# Split idlist into smaller lists if need be
# Will be placed into directory idlists_split inside the idlist directory
porder idsplit --idlist "$idlist_dir/AOI_IDs.csv" --lines 500 --local "$idlist_dir/idlists_split"
```

## Step 5: Order the imagery your specified parameters: 
Here, I've asked it to: 
1. Clip all of the tiles to the specified geojson polygon
2. Zip all of the files in the order into one .zip file (makes the download MUCH faster)
3. Calculate NDVI and EVI2 and have these as bands in the order. WARNING that if you specify these, you won't receive the actual RGB/NIR bands!

See what other commands you can add [here](https://samapriya.github.io/projects/porder/#order)!

The order matters when specifying these parameters, so be careful to specify your requested indices AFTER the "clip zipall", if you want them.

```{bash order}
# Change directory to the idlists split to the identified max length
cd "$idlist_dir/idlists_split"

# Order the images
# Test this if you want to see the names of your Planet orders
# for ids in *; do echo ${ids%.*}"; done

for ids in *; do porder order --name "${ids%.*}" --idlist "$idlist_dir/idlists_split/${ids}" --item "PSScene4Band" --bundle "analytic_sr_udm2,analytic_sr" --boundary "$aoi_geojson" --op clip zipall ndvi evi2; done
```

## Step 6: Check the state(s) of your order(s)
```{bash check_status}
# State can be queued, running, success, failed, or partial
# Start date and end date (format: YYYY-MM-DD) are dates to check for orders
porder ostate --state "success" --start "$search_start" --end "$search_end"
```

## Step 7: Download the successful orders of imagery!
You can either download these from the site, through the URLs shown in the ostate command, or use a separate script (Izzi will post in a sec) if you have a bunch of orders to download!
