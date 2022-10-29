#************************************************************************
# Description: This file process batch downloading from a bunch of provided links.
#              It can be used to download both the image query result from 
#              the Appears application and general files. The input of this script is
#              a "*.txt" file that contains downloadable links.
# Author: Xiaojie Gao
# Date: 2020-11-26
#************************************************************************
# library(utils)


# user inputs
# ==============================================================
# txt file containing links
# txtFile <- "download_list_from_appears.txt"
# output folder
# out_dir <- "Z:/Gao/"
# ==============================================================

batch_download <- function(txtFile, out_dir) {
    # links txt file
    links <- read.table(txtFile, stringsAsFactors = FALSE)

    if(dir.exists(out_dir) == FALSE) dir.create(out_dir)

    # download
    for (i in 1:nrow(links)) {
        cur_link <- links[i, 1]
        tmp <- unlist(strsplit(cur_link, "/"))
        filename <- tmp[length(tmp)]
        download.file(cur_link, file.path(out_dir, filename), method = "curl")
    }
}













