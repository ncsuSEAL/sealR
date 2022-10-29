#'******************************************************************************
#' Description: Download the global GIMMS NDVI3g product.
#' 
#' Author: Xiaojie(J) Gao
#' Date: 2022-09-22
#'******************************************************************************
# library(curl)

# From : https://data.tpdc.ac.cn/en/data/c6113f70-884a-4716-98e3-933421c57f25/?q=gimms
# Ftp server: 210.72.14.198
# Ftp username: download_414169
# Ftp password: 31879907
url <- "ftp://210.72.14.198"

# Output dir. This is in our SEAL folder
dir <- "Z:/Global_GIMMS_NDVI3g_1981_2015"


# Get file names in the folder
h <- new_handle(
    dirlistonly = TRUE,
    username = "download_414169",
    password = "31879907"
)
con = curl(url, "r", h)
tbl = read.table(con, stringsAsFactors=TRUE, fill=TRUE)
close(con)

# Download each file
urls <- paste0(url, "/", tbl[2:nrow(tbl), 1])
pb <- txtProgressBar(min = 0, max = 100, style = 3)
for (i in seq_along(urls)) {
    f_url <- urls[i]
    f_name <- basename(f_url)

    curl::curl_download(f_url, 
        file.path(dir, f_name), 
        handle = new_handle(
            username = "download_414169",
            password = "31879907"
        )
    )

    setTxtProgressBar(pb, i * 100 / length(urls)) # update progress
}
close(pb)

