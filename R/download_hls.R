#************************************************************************
# Description: Download Harmonized Landsat and Sentinel-2 imagery. See https://hls.gsfc.nasa.gov/
# Author: Xiaojie Gao
# Date: 2020-10-14
#************************************************************************
library(utils)
library(httr)
library(XML)

# example:
# out_dir <- "Z:/Gao/"
# tiles <- c("17SPC", "17SQC")
# yrs <- c(2015, 2016, 2017, 2018, 2019)
Download_HLS <- function(out_dir, tiles, yrs) {
    if(!dir.exists(out_dir)) dir.create(out_dir)

    root_url <- "https://hls.gsfc.nasa.gov/data/v1.4"

    for(prod in c("S30", "L30")) {
        if (!dir.exists(file.path(out_dir, prod))) dir.create(file.path(out_dir, prod))

        for(yr in yrs) {
            for(tile in tiles) {
                # construct data file urls
                tile_folder_url <- file.path(root_url, prod, yr, substr(tile, 1, 2), substr(tile, 3, 3), substr(tile, 4, 4), substr(tile, 5, 5))
                # request for contents
                r <- GET(tile_folder_url)
                doc <- htmlParse(r)
                links <- xpathSApply(doc, "//a/@href")
                data_links <- links[grepl(".*.hdf", links)]
                # construct data links
                data_urls <- paste0(tile_folder_url, "/", data_links)
                # download
                sapply(seq_along(data_urls), function(i) {
                    if (!file.exists(file.path(out_dir, prod, data_links[i]))) {
                         download.file(data_urls[i], file.path(out_dir, prod, data_links[i]), method = "curl")
                    }
                })
            }
        }
    }
}

























