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

```r
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
``` r
# Function to create shapefiles of a coordinate with the specified buffer
# NOTE: This function generates warnings about the projection, but it creates the correct buffered coordinates
coord_to_shp <- function(coordX, coordY, coord_name, coord_data = data.frame(), buffer_m = buffer, utm_zone = utm_zone, 
                         prj = CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs")) {
  # Convert coordinates to a SpatialPoint
  coords <- data.frame(x = coordX, y = coordY) # Set the coordinates
  centroid <- SpatialPoints(coords, proj4string = prj) # Create the spatialPoints
  
  # Convert to UTM, to specify the buffer size in units of meters 
  # NOTE TO SELF: parameterize the UTM zone so the user doesn't have to change it in the code
  centroid_utm <- spTransform(centroid, CRS("+proj=utm +zone=46, +ellps=WGS84")) # Convert to UTM
  buffered <- gBuffer(centroid_utm, width = buffer_m)
  # add ID column to match the buffered SpatialPolygons
  
  # Extract polygon IDs
  pid <- sapply(slot(buffered, "polygons"), function(x) slot(x, "ID"))
  # Create dataframe with correct rownames
  p.df <- data.frame(ID=1:length(buffered), row.names = pid)
  
  # Create an SPDF of the buffered coordinate
  buffered_spdf <- SpatialPolygonsDataFrame(buffered, p.df)
  
  # Save to output shapefile directory
  shapefile(buffered_spdf, filename = paste0(shp_dir, "/", coord_name, ".shp"))
}

# Set the work dir
setwd(base_dir)

# Import the .csv of data
imgs_to_get <- data.table(read.csv(csv_name))

# Ensure that the dates are in date format
imgs_to_get$dateDist <- as.Date(imgs_to_get$dateDist, format="%Y-%m-%d")
imgs_to_get$datePre <- as.Date(imgs_to_get$datePre, format="%Y-%m-%d")

# If the output folders don't not yet exist, create them
if (!dir.exists(geojson_dir)) { # Geojsons
  dir.create(geojson_dir)
}

if (!dir.exists(shp_dir)) { # Shapefiles
  dir.create(shp_dir)
}

if (!dir.exists(idlist_dir)) { # Planet idlists
  dir.create(idlist_dir)
}

if (!dir.exists(out_dir)) { # Directory for PlanetScope images
  dir.create(out_dir)
}

# Convert each coordinate in the .csv to a .shp with the specified buffer size in output shapefile folder
# coord_to_shp(imgs_to_get$coordX[1], imgs_to_get$coordY[1], coord_name = imgs_to_get$pointid[1]) # to test
# NOTE: this will generate warnings about an unknown datum based on WGS84 ellipsoid, you can ignore it!
apply(imgs_to_get, 1, function(coord_data) {
  coord_to_shp(as.numeric(coord_data['coordX']), as.numeric(coord_data['coordY']), coord_name = coord_data['pointid'])
})
```

Alternatively, if you have shapefiles of polygons of interest: 
```

```

## Step 4: Order your images 
First, make sure you are in your activated conda environment, then initialize planet using `planet init` and sign in.

``` r
# In your activated conda environment, first execute "planet init" in terminal 
# Then, you will be prompted to log into your Planet account via your email and password.

# Convert all .shp files to .geojson
system(paste0("porder convert --source ", shp_dir, " --destination ", geojson_dir))

# Get the list of IDs of PlanetScope images available on the dates of interest
all_geojsons <- list.files(path=geojson_dir, pattern="*.geojson", full.names=TRUE)

## Load this file if you didn't just run part 2 above
setwd(base_dir)
imgs_to_get <- data.table(read.csv(file.path(base_dir, csv_name))) #import csv of desired points
imgs_to_get$dateDist <- as.Date(imgs_to_get$dateDist, format="%Y-%m-%d")
imgs_to_get$datePre <- as.Date(imgs_to_get$datePre, format="%Y-%m-%d")

# NOTE: If you had more than 500 images per geojson, you would have to add a command to split the idlist into separate .csvs of max length 500
lapply(all_geojsons, function(coord_file) {
  # Extract the pointid from the name of the geojson file
  point_id <- sub(pattern = "(.*)\\..*$", replacement = "\\1", basename(coord_file))
  
  # Get the data for this coordinate
  coord_data <- imgs_to_get[`pointid` == point_id]
  
  # Make paths for the pre- and post-disturbance .csvs of PlanetScope IDs, and IDs to order
  pre_csv <- paste0(idlist_dir, "/", point_id, "_pre.csv") # pre-disturbance IDs
  dist_csv <- paste0(idlist_dir, "/", point_id, "_post.csv") # post-disturbance IDs
  to_order_csv <- paste0(idlist_dir, "/", point_id, "_toOrder.csv") # pre- and post-disturbance IDs to order
  
  # Get the IDs of candidate pre-disturbance images 
  pre_disturb_start <- coord_data$datePre - days_to_consider # Date <days_to_consider> days before the pre-disturbance date
  system(paste0("porder idlist --input ", coord_file, " --start ", pre_disturb_start, " --end ", coord_data$datePre, " --item ", item_type, " --asset ", asset_type, " --outfile ", pre_csv, " --cmin ", min_cloud_cover, " --cmax ", max_cloud_cover, " --overlap ", area_overlap))
  
  # Get the ids of candidate post-disturbance images
  post_disturb_end <- coord_data$dateDist + days_to_consider # Date <days_to_consider> days after the disturbance date
  system(paste0("porder idlist --input ", coord_file, " --start ", coord_data$dateDist, " --end ", post_disturb_end, " --item ", item_type, " --asset ", asset_type, " --outfile ", dist_csv, " --cmin ", min_cloud_cover, " --cmax ", max_cloud_cover, " --overlap ", area_overlap))
  
  # Select only the most recent pre-disturbance image(s) and the earliest post-disturbance image(s) available
  pre_dist_IDs <- read.csv(pre_csv) # Load the .csv of pre-disturbance PlanetScope image IDs
  post_dist_IDs <- read.csv(dist_csv) # Load .csv of post-disturbance PlanetScope image IDs
  
  # Get the IDs of the most recent pre-disturbance image(s) and earliest post-disturbance image(s)
  selected_IDs <- head(pre_dist_IDs[[1]], n = num_to_select)
  selected_IDs <- c(selected_IDs, tail(post_dist_IDs[[1]], n = num_to_select))
  
  # Write selected IDs to a new .csv file 
  write.table(selected_IDs, to_order_csv, row.names = FALSE, col.names = FALSE)
  
  # Order them
  system(paste0("porder order --name ", point_id, " --idlist ", to_order_csv, " --item ", item_type, " --bundle ", bundle, " --boundary ", coord_file, " --op ", ops))
  # To order all candidate pre-disturbance images
  #system(paste0("porder order --name ", point_id, "_pre --idlist ", paste0(idlist_dir, "/", point_id, "_pre.csv"), " --item ", item_type, " --bundle ", bundle, " --boundary ", coord_file, " --op ", ops))
  # Order all candidate post-disturbance images 
  #system(paste0("porder order --name ", point_id, "_dist --idlist ", paste0(idlist_dir, "/", point_id, "_dist.csv"), " --item ", item_type, " --bundle ", bundle, " --boundary ", coord_file, " --op ", ops))
})
```

## Step 5: Download the images
``` r
# Wait for these orders to process 
# To check on the progress, uncomment the line with the state of interest (queued, running, success, failed, partial) 
# system(paste0("porder ostate --state queued --start ", date_ordered, " --end ", date_today))
# system(paste0("porder ostate --state running --start ", date_ordered, " --end ", date_today))
# system(paste0("porder ostate --state failed --start ", date_ordered, " --end ", date_today))
# system(paste0("porder ostate --state partial --start ", date_ordered, " --end ", date_today))
# system(paste0("porder ostate --state success --start ", date_ordered, " --end ", date_today))

# Get the successful orders and save their summaries to a .txt file
# (Uncomment the following line once your orders have finished)
system(paste0("porder ostate --state success --start ", date_ordered, " --end ", date_today, " > ", orders_txt))

# Then, extract the URLs of successful orders from the text file and use the API to download the orders from the URLs 
# Extract all of the URLs from the .txt file
summary_txt <- read.delim(orders_txt)

# Use Planet's Orders API to download the orders with the URLs
urls <- lapply(summary_txt, function(order) {return(sub(".*(https:\\S+).*", "\\1", order))})
urls_to_order <- urls[[1]]
urls_to_order <- urls_to_order[3:(length(urls_to_order)-1)] # Selects only the URLs

# Order the PS images for all of the data! 
# Because we're running this on a login node, I will keep this serial rather than parallel
for (url in urls_to_order) {
  #print(url)
  system(paste0("porder multiproc --url ", url, " --local ", out_dir))
}
```

View the [porder Github repository](https://github.com/tyson-swetnam/porder) for more information on how the CLI works! If you have any additional questions, reach out to Izzi with questions. 
