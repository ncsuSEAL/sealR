#************************************************************************
# Description: Use AppEEARS API to submit point or area jobs
# Author: Xiaojie(J) Gao
# Date: 2021-11-19
#************************************************************************
# library(httr)
# library(jsonlite)
# library(tools)
# library(rgdal)
# library(geojsonio)
# library(geojsonR)


#' @examples
#' \dontrun{
#' 
#' # Query all products
#' all_products <- QueryALLProducts()
#' 
#' # Search products
#' desired_products <- QueryProducts(filter = "Landsat ARD")
#' names(desired_products)
#' 
#' # Get all available layers
#' all_layers <- QueryLayers("CU_LC08.001")
#' names(all_layers)
#' 
#' # Get all projections
#' projs <- QueryProjections()
#' projs$Name
#'
#'
#' # ~ submit point task
#' # ~~~~~~~~~~~~~~~~~
#' lat <- c(36.206228, 37.289327) # Latitude of the point sites
#' lon <- c(-112.127134, -112.973760) # Longitude of the point sites
#' id <- c("0", "1") # ID for the point sites
#' category <- c("Grand Canyon", "Zion") # Category for point sites
#' 
#' pts_df <- data.frame(id = id, longitude = lon, latitude = lat, category = category)
#' 
#' layers <- data.frame(
#'     product = c("CU_LE07.001", "CU_LC08.001"),
#'     layer = c("SRB3", "SRB3")
#' )
#' 
#' # login and get the token, note that if no arguments passed, input username and password in the terminal
#' token <- Login(usr = "[your username]", pwd = "[your password]")
#' 
#' SubmitTask(
#'     token = token, task_name = "test", task_type = "point",
#'     start_date = "01-01-2018", end_date = "06-01-2018",
#'     layers = layers, point_df = pts_df
#' )
#' 
#' 
#' # ~ submit area task
#' # ~~~~~~~~~~~~~~~~~
#' # login and get the token, note that if no arguments passed, input username and password in the terminal
#' token <- Login(usr = "[your username]", pwd = "[your password]")
#' SubmitTask(
#'     token = token, task_name = "test2", task_type = "area",
#'     start_date = "01-01-2018", end_date = "06-01-2018", layers = layers,
#'     polygon_file = "/Volumes/GoogleDrive/My Drive/Research/urban_pheno/Data/boston_bbox.geojson",
#'     out_format = "geotiff", out_proj = "albers_ard_conus"
#' )
#' 
#' CheckTaskStatus(token, 2)
#' CheckTaskStatus(token, 2, brief = TRUE)
#' CheckTaskStatus(token, 2, task_name = "point_ex")
#' CheckTaskStatus(token, 2, task_name = "area_ex", brief = TRUE)
#' 
#' RefreshTaskStatus(token, task_id = "[your task id]")
#' 
#' DownloadTask(token, task_id = "[your task id]", out_dir = getwd())
#' 
#' # log out
#' Logout(token)
#' 
#' }


API_URL <- "https://appeears.earthdatacloud.nasa.gov/api/"


# List all available products
# Return a list
QueryALLProducts <- function() {
    # Request the info of all products from product service
    prods_req <- httr::GET(paste0(API_URL, "product")) 
    # Retrieve the content of request
    prods_content <- httr::content(prods_req) 
    
    # set names for each product 
    all_prods <- jsonlite::toJSON(prods_content, auto_unbox = TRUE)
    names(prods_content) <- jsonlite::fromJSON(all_prods)$ProductAndVersion
    
    return(prods_content)
}

# Query interested products
QueryProducts <- function(filter = "") {
    all_products <- QueryALLProducts()

    products <- all_products[grepl(filter, all_products)]

    return(products)
}

# Query available layers in a product
QueryLayers <- function(product_name) {
    req <- httr::GET(paste0(API_URL, "product/", product_name))
    cont <- httr::content(req)

    return(cont)
}

# Query available projections
QueryProjections <- function() {
    req <- httr::GET(paste0(API_URL, "spatial/proj"))
    req_cont <- httr::content(req)

    projs <- jsonlite::fromJSON(jsonlite::toJSON(req_cont, auto_unbox = TRUE))
    return(projs)
}

# log in to AppEEARS
# Return the token string
Login <- function(usr, pwd) {
    # if username and password are not provided, input them in the ternimal window
    if(is.null(usr) | is.null(pwd)) {
        require(getPass)
        message("username and password must be provided. 
            You can create one on the EarthData website."
        )
        usr <- getPass::getPass(msg = "Enter NASA Earthdata Login Username: ")
        pwd <- getPass::getPass(msg = "Enter NASA Earthdata Login Password: ")
    }
    response <- httr::POST(
        paste0(API_URL, "login"),
        httr::authenticate(usr, pwd)
    )
    response_content <- httr::content(response)
    token <- paste("Bearer", response_content$token)
    
    return(token)
}

# log out from AppEEARS
Logout <- function(token) {
    req <- httr::POST(paste0(API_URL, "logout"), 
        httr::add_headers(Authorization = token)
    )
}

# Submit a point task
# task_name can either be 'point' or 'area', but relative params need to be provided
SubmitTask <- function(token, task_name, task_type = "point", 
    start_date = NULL, end_date = NULL, recursive = FALSE, 
    from_year = NULL, to_year = NULL, 
    layers = NULL, point_df = NULL, polygon_file = NULL, 
    out_format = "geotiff", out_proj = NULL
) {
    
    # check arguments
    if (sum(is.null(start_date), is.null(end_date), is.null(layers)) > 0) {
        stop("Please specify parameters!")
    }
    if (tolower(task_type) == "point" && is.null(point_df)) {
        stop("Point task but no points provided!")
    }
    if (tolower(task_type) == "Area" && 
        (is.null(polygon_file) | is.null(out_format) | is.null(out_proj))) {
        stop("Area task but paramter(s) not specified!")
    }
    

    # Format Dates
    dates <- data.frame(startDate = start_date, endDate = end_date)

    if (tolower(task_type) == "point") { # ~ Point tasks
        task_info <- list(dates, layers, point_df) # Create a list of data frames
        names(task_info) <- c("dates", "layers", "coordinates") # Assign names

        task <- list(task_info, task_name, task_type) # Create a nested list
        names(task) <- c("params", "task_name", "task_type") # Assign names

        task_json <- jsonlite::toJSON(task, auto_unbox = TRUE) # Convert to JSON object

        response <- httr::POST(paste0(API_URL, "task"),
            body = task_json,
            encode = "json",
            httr::add_headers(Authorization = token, 
                "Content-Type" = "application/json"
            )
        )

        task_content <- httr::content(response) # Retrieve content of the request
        task_response <- jsonlite::prettify(
            jsonlite::toJSON(task_content, auto_unbox = TRUE)
        ) # Convert the content to JSON object
        
        return(task_response)

    } else if (tolower(task_type) == "area") { # ~ Area tasks
        # read the polygon file
        if (tools::file_ext(polygon_file) == "geojson") {
            polygon_f <- rgdal::readOGR(polygon_file)
        } else if (tools::file_ext(polygon_file) == "shp") {
            polygon_f <- rgdal::readOGR(dsn = dirname(polygon_file), 
            layer = tools::file_path_sans_ext(basename(polygon_file)))
        } else {
            stop("Please provide a valid shp or geojson file!")
        }

        # Convert the data frame to GeoJSON
        gc_json <- geojsonio::geojson_json(polygon_f, geometry = "polygon")
        gc_js <- geojsonR::FROM_GeoJson(gc_json) # Read the GeoJSON
        gc_js$features[[1]]$geometry$coordinates <- list(gc_js$features[[1]]$geometry$coordinates)

        out <- list(out_proj)
        names(out) <- c("projection")
        out$format$type <- out_format

        task_info <- list(dates, layers, out, gc_js) # Create a list of data frames
        names(task_info) <- c("dates", "layers", "output", "geo") # Assign names
        task <- list(task_info, task_name, task_type) # Create a nested list
        names(task) <- c("params", "task_name", "task_type") # Assign names
        task_json <- jsonlite::toJSON(task, auto_unbox = TRUE, digits = 10)

        response <- httr::POST(paste0(API_URL, "task"),
            body = task_json, encode = "json",
            httr::add_headers(Authorization = token, 
                "Content-Type" = "application/json"
            )
        )

        task_content <- httr::content(response) # Retrieve content of the request
        task_response <- jsonlite::toJSON(task_content, auto_unbox = TRUE)
        jsonlite::prettify(task_response)
    }
}

# Check the status of current tasks
CheckTaskStatus <- function(token, limit, task_name = NULL, brief = FALSE) {
    params <- list(limit = limit, pretty = TRUE)
    response_req <- httr::GET(paste0(API_URL, "task"), 
        query = params, 
        httr::add_headers(Authorization = token)
    )
    response_content <- httr::content(response_req) # Retrieve content of the request
    status_response <- jsonlite::toJSON(response_content, auto_unbox = TRUE)
    response_df <- jsonlite::fromJSON(status_response)
    names(response_content) <- response_df$task_name

    if(is.null(task_name) == FALSE) {
        my_task <- response_content[grepl(task_name, response_content)]
        my_task_json <- jsonlite::toJSON(my_task, auto_unbox = TRUE)

        if (brief == TRUE) {
            my_task_df <- jsonlite::fromJSON(my_task_json)[[task_name]]
            my_task_df_b <- data.frame(
                task_name = my_task_df$task_name, 
                status = my_task_df$status, 
                id = my_task_df$task_id
            )
            return(my_task_df_b)
        } else {
           return(jsonlite::prettify(my_task_json))
        }
    }

    if (brief == TRUE) {
        return(response_df[, c("task_name", "status", "task_id")])
    } else {
       return(jsonlite::prettify(jsonlite::toJSON(response_content)))
    }
}

# Constantly checking the task status until it's done.
# interval is in seconds.
RefreshTaskStatus <- function(token, task_id, interval = 60) {
    stat <- ""
    while (stat != "done") {
        # Request the task status and retrieve content of request from task URL
        stat_content <- httr::content(httr::GET(paste0(API_URL, "task/", task_id), 
            httr::add_headers(Authorization = token))
        )
        stat <- jsonlite::fromJSON(
            jsonlite::toJSON(stat_content, auto_unbox = TRUE)
        )$status 
        print(stat)

        Sys.sleep(interval)
    }
}

# Download a task result
DownloadTask <- function(token, task_id, out_dir) {
    # Request the task bundle info from API bundle URL
    response <- httr::GET(paste0(API_URL, "bundle/", task_id), 
        httr::add_headers(Authorization = token)
    )
    response_content <- httr::content(response) # Retrieve content of the request
    bundle_response <- jsonlite::toJSON(response_content, auto_unbox = TRUE) 
    jsonlite::prettify(bundle_response)

    bundle <- jsonlite::fromJSON(bundle_response)$files
    for (id in bundle$file_id) {
        # retrieve the filename from the file_id
        filename <- bundle[bundle$file_id == id, ]$file_name
        # create a destination directory to store the file in
        filepath <- paste(out_dir, filename, sep = "/")
        suppressWarnings(dir.create(dirname(filepath)))
        # write the file to disk using the destination directory and file name
        response <- httr::GET(
            paste0(API_URL, "bundle/", task_id, "/", id),
            write_disk(filepath, overwrite = TRUE),
            progress(),
            httr::add_headers(Authorization = token)
        )
    }
}



