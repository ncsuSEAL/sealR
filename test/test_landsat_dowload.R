library(terra)
source("R/hlp_landsat_pro.R")



roifile <- "data/chengdu_city.geojson"
study_period <- "2022-08-15/2022-08-31"
# Create a tmp directory
tmpdir <- "test/tmp"
if (dir.exists(tmpdir) == FALSE) dir.create(tmpdir)

# Download EVI2 images
LandsatPro$Download(
    roifile = roifile, 
    study_period = study_period,
    out_dir = tmpdir,
    evi2_only = TRUE,
    crop = TRUE
)

# Download all bands
LandsatPro$Download(
    roifile = roifile, 
    study_period = study_period,
    out_dir = tmpdir,
    evi2_only = FALSE,
    crop = TRUE
)

# Delete the tmp directory
unlink(tmpdir, recursive = TRUE)
