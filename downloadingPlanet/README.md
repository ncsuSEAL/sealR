# Batch downloading Planet data

Planet's porder CLI (Command-Line Interface) for the Planet ordersV2 API enables users to batch download Planet data. With the script in this folder, you can: 
- Optionally clip tiles to a desired location (bounding coordinates, or a buffer around a single coordinate)
- Get all available data _between_ two dates (under a specific % cloud cover threshold, if desired)
- Get Planet images _on_ specific dates
- Get pre-calculated bands of indices (simple ratio, NDVI, GNDVI, BNDVI, TVI, OSAVI, EVI2, NDWI, MSAVI2), if you're gathering 4-band PlanetScope ("PSScene4Band")

## Step 1: Install prerequisites and the porder CLI
Head to [this link](https://github.com/tyson-swetnam/porder#prerequisites) to install all of the prerequisites and the porder CLI.
NOTE: It is best to do this in a conda environment, so all of your packages are compatible and constant. 

Steps 2-5 will guide you through the development of a script that will order Planet data based on your specific needs (clipped tiles of predefined polygons/buffered coordinates, data on/between two dates, pre-calculated bands, etc.).

## Step 2: 
This step either requires you to have a .csv file with columns for lat/lon coordinates, or shapefiles of existing polygons with which you would like to clip your Planet data. 

With the CLI installed (and your conda environment activated, if applicable), run the following code to set your working directory and folder names. 
Before you run the code: 
- Change the `base_dir` to your preferred base path
- *If you have a .csv of individual coordinates that you'd like to use to clip the Planet images*: 
- - Uncomment and change the `csv_name` to the name of your csv in the base_dir
- - Uncomment and change the column names for your lat/lon coordinates in the .csv file
- *If you want to use existing shapefiles to clip your Planet imagery*: 
- - Change the `shp_dir` to the path to your folder of shapefiles

```
library(sp)
library(rgeos)
library(rgdal)
library(raster)
library(data.table)

# Set the file paths and names of files/folders to be created 
base_dir <- "/Your/Path"
# csv_name <- "planet_coords_dates.csv"
shp_dir <- file.path(base_dir, "shapefiles")
geojson_dir <- file.path(base_dir, "geojsons") 
idlist_dir <- file.path(base_dir, "idlists")
orders_txt <- file.path(base_dir, "successful_orders.txt")
```

## Step 3: Generate geojsons of your area(s) of interest 
Use the following code to generate geojsons of individual coordinates: 
``` 

```

Alternatively, if you have shapefiles of polygons of interest: 
```

```

## Step 4: Order your images 
```

```

## Step 5: Download the images
```

```

View the [porder Github repository](https://github.com/tyson-swetnam/porder) for more information on how the CLI works! If you have any additional questions, reach out to Izzi with questions. 
