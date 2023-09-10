# ******************************************************************************
# Basic image processing functions
# 
# Usage example: 
#     roifile <- "roi.shp"
#     study_period <- "1984-01-01/2022-12-31"
#     landsat_data_dir <- "Jobs/LandsatEVI2/"
#     LandsatPro$Download(roifile, study_period, landsat_data_dir, 
#         evi2_only = FALSE, crop = TRUE
#     )
#
# Author: Xiaojie Gao
# Date: 2023-07-03
# ******************************************************************************
require(terra)
require(magrittr)
require(rstac)

LandsatPro <- list(
    
    # Planetary Computer API
    s_obj = stac("https://planetarycomputer.microsoft.com/api/stac/v1/"),

    #' Calculate EVI2 values
    #'
    #' @param nir_val NIR band value.
    #' @param red_val RED band value.
    #' @return EVI2 values.
    #' @noRd
    CalEVI2 = function(nir_val, red_val) {
        red <- red_val * 0.0000275 - 0.2
        nir <- nir_val * 0.0000275 - 0.2

        evi2 <- 2.5 * ((nir - red) / (1 + nir + 2.4 * red))

        return(as.numeric(evi2))
    },

    #' Parse Landsat cloud and snow QA values
    #'
    #' @param x The QA value.
    #' @return A list with logic values indicating `fill`, `cloud`, 
    #' `cloudShadow`, and `snow`.
    #' @noRd
    CloudSnowQA = function(x) {
        ## Bit 0 - if pixel is fill, then true
        fill <- ifelse(bitwAnd(x, 1), TRUE, FALSE)
        ## Bit 3 - if cloud, then true
        cloud <- ifelse(bitwAnd(bitwShiftR(x, 3), 1), TRUE, FALSE)
        ## Bit 4 - if cloud shadow, then true
        cloudShadow <- ifelse(bitwAnd(bitwShiftR(x, 4), 1), TRUE, FALSE)
        ## Bit 5 - if snow, then true
        snow <- ifelse(bitwAnd(bitwShiftR(x, 5), 1), TRUE, FALSE)

        return(list(
            fill = fill,
            cloud = cloud, cloudShadow = cloudShadow,
            snow = snow
        ))
    },

    #' Split the entire study period into several sub parts
    #'
    #' @description 
    #' B/c of the limitation of the Microsoft Planetary Computer, we cannot
    #' request the entire study period if it's long, and b/c the requested urls
    #' may become invalid if unused for a long time, so we split it and request
    #' for multiple times.
    #'
    #' @param study_period E.g., "1984-01-01/2022-12-31".
    #'
    #' @return A vector containing the sub time periods.
    SplitStudyPeriod = function(study_period) {
        start_date <- strsplit(study_period, "/")[[1]][1] %>% as.Date()
        end_date <- strsplit(study_period, "/")[[1]][2] %>% as.Date()

        if ((data.table::year(end_date) - data.table::year(start_date)) <= 1) {
            start_end_dates <- study_period
        } else {
            yrs <- seq(data.table::year(start_date),
                data.table::year(end_date),
                by = 1
            )

            start_end_dates <- NULL
            for (i in seq_along(yrs)) {
                if (i == 1) {
                    sd <- start_date
                    ed <- paste0(yrs[i + 1] - 1, "-12-31") %>% as.Date()
                } else if (i == length(yrs)) {
                    sd <- paste0(yrs[i], "-01-01") %>% as.Date()
                    ed <- end_date
                } else {
                    sd <- paste0(yrs[i], "-01-01") %>% as.Date()
                    ed <- paste0(yrs[i + 1] - 1, "-12-31") %>% as.Date()
                }

                start_end_dates <- c(start_end_dates, paste(sd, ed, sep = "/"))
            }
        }

        return(start_end_dates)
    },

    #' Do a single EVI2 image calculation and exporting
    #'
    #' @param roi_ext Study region extent. 
    #' @param fea The STAC feature
    #' @param out_file Output file path.
    #'
    #' @return NULL.
    DoSingleEVI2 = function(roi_ext, fea, out_file, crop = TRUE) {
        date <- as.Date(gsub("T.*", "", fea$properties$datetime))
        epsg <- fea$properties$`proj:epsg`

        # Project the point buffer to the epsg
        # Have to create the points again as terra doesn't serielize spatial
        #   objects.
        ext_coords <- rbind(
            cbind(roi_ext[1], roi_ext[3]),
            cbind(roi_ext[1], roi_ext[4]),
            cbind(roi_ext[2], roi_ext[4]),
            cbind(roi_ext[2], roi_ext[3])
        )
        roi <- vect(ext_coords, type = "polygons", crs = "EPSG:4326") %>%
            terra::project(paste0("EPSG:", epsg))

        tryCatch({
            # Red
            red_band <- paste0("/vsicurl/", fea$assets$red$href) %>%
                terra::rast()
            if (crop == TRUE) {
                red_band <- crop(red_band, roi)
            }

            # Nir
            nir_band <- paste0("/vsicurl/", fea$assets$nir08$href) %>%
                terra::rast()
            if (crop == TRUE) {
                nir_band <- crop(nir_band, roi)
            }

            evi2_img <- LandsatPro$CalEVI2(nir_band, red_band)

            # QA
            qa_band <- paste0("/vsicurl/", fea$assets$qa_pixel$href) %>%
                terra::rast()
            if (crop == TRUE) {
                qa_band <- crop(qa_band, roi)
            }

            qa_parse <- LandsatPro$CloudSnowQA(values(qa_band))

            bad_idx <- which(
                qa_parse$fill == TRUE | 
                qa_parse$cloud == TRUE |
                qa_parse$cloudShadow == TRUE | 
                qa_parse$snow == TRUE
            )

            evi2_img[bad_idx] <- NA

            if (all(is.na(values(evi2_img))) == FALSE) {
                writeRaster(evi2_img, filename = out_file)
            }
        }, error = function(e) {
            message(paste(out_file, "failed!"))
        })
    },

    #' Do a single image
    #' 
    #' @param roi_ext Study region extent.
    #' @param fea The STAC feature
    #' @param out_dir Output directory.
    #'
    #' 
    #' @return NULL
    DoSingleImg = function(roi_ext, fea, out_dir, crop = TRUE) {
        date <- as.Date(gsub("T.*", "", fea$properties$datetime))
        epsg <- fea$properties$`proj:epsg`

        # Project the point buffer to the epsg
        # Have to create the points again as terra doesn't serielize spatial
        #   objects.
        ext_coords <- rbind(
            cbind(roi_ext[1], roi_ext[3]),
            cbind(roi_ext[1], roi_ext[4]),
            cbind(roi_ext[2], roi_ext[4]),
            cbind(roi_ext[2], roi_ext[3])
        )
        roi <- vect(ext_coords, type = "polygons", crs = "EPSG:4326") %>%
            terra::project(paste0("EPSG:", epsg))

        tryCatch(
            {
                # Create a folder to store all files
                destdir <- file.path(out_dir, fea$id)
                if (!dir.exists(destdir)) {
                    dir.create(destdir)
                }

                null <- lapply(fea$assets, function(b) {
                    # Download metadata
                    if (grepl("image/tiff", b$type) == FALSE) {
                        filename <- file.path(
                            destdir, 
                            strsplit(basename(b$href), "\\?")[[1]][1]
                        )
                        # Skip the MTL.json file
                        if (grepl("MTL.json", basename(filename)) == TRUE) {
                            return(NULL)
                        }
                        download.file(b$href, filename, quiet = TRUE)
                        return(NULL)
                    }
                    
                    # Download and/or crop all image bands
                    bb <- paste0("/vsicurl/", b$href) %>%
                        terra::rast()
                    if (crop == TRUE) {
                        bb <- crop(bb, roi)
                    }
                    filename <- file.path(destdir, paste0(names(bb), ".tiff"))
                    if (file.exists(filename) == FALSE) {
                        writeRaster(bb, filename)
                    }
                    return(NULL)
                })
            },
            error = function(e) {
                message(paste(fea$id, "failed!"))
            }
        )
    },

    #' Download Landsat image time series for a given region using MPC
    #' 
    #' @description
    #' 
    #' @param roifile
    #' @param study_period
    #' @param out_dir Output directory.
    #' @param evi2_only Logical, indicates whether download EVI2 images only.
    #' @param crop Logical, indicates whether images should be cropped by roi.
    #'
    #' @return NULL
    #'
    #' @export
    Download = function(roifile, study_period, out_dir, 
        evi2_only = FALSE, crop = TRUE
    ) {
        # Split the entire time period
        start_end_dates <- LandsatPro$SplitStudyPeriod(study_period)

        # Reproject to lon/lat projection as MPC only supports this projection
        roi <- vect(roifile)
        roi <- project(roi, "epsg:4326")
        roi_ext <- as.vector(ext(roi))

        # Request image urls
        null <- lapply(start_end_dates, function(focal_dates) {
            # Search some data
            obj <- stac_search(LandsatPro$s_obj,
                collections = "landsat-c2-l2",
                ids = NULL, # could specify this if wanted
                bbox = roi_ext[c(1, 3, 2, 4)],
                datetime = focal_dates,
                limit = 1000
            ) %>%
                get_request() %>%
                items_sign(sign_fn = sign_planetary_computer()) %>%
                suppressWarnings()

            # Process and export
            print(paste(
                "Processing", focal_dates, "...",
                "total:", length(obj$features)
            ))
            if (length(obj$features) == 0) {
                print("No image!")
                return(NULL)
            }

            pb <- txtProgressBar(min = 0, max = length(obj$features), style = 3)
            null <- lapply(1:length(obj$features), function(i) {
                fea <- obj$features[[i]]

                if (evi2_only == TRUE) {
                    out_file <- file.path(out_dir, paste0(fea$id, "_evi2.tiff"))
                    if (!file.exists(out_file)) {
                        LandsatPro$DoSingleEVI2(roi_ext, fea, out_file, crop)
                    }
                } else {
                        LandsatPro$DoSingleImg(roi_ext, fea, out_dir, crop)
                }

                # update progress
                setTxtProgressBar(pb, i)
            })
            close(pb)
        })
    }

)


