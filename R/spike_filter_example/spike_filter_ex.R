rm(list = ls()) # Start with a clean slate

# Load necessary libraries
library(data.table)

# Set working directory to location of "spike_filter_example" dir
setwd("C:\\Users\\irhinks\\Desktop\\spike_filter_example")
test_data <- readRDS("test_data.r") # example EVI2 time series

par(xpd = FALSE) # enable objects to be drawn outside of plot regions?

# Spike filter function, similar to that described in section 2.2.4 of:
# https://www.mdpi.com/2072-4292/12/24/4191/htm
# Args:
#   input:     data.table of time series of imput data with at least two
#              columns, one called "date" for observation dates and the other
#              called "EVI2" for EVI2 values (will change these to be specified
#              in the function ASAP!)
#              (EVI2, etc.)
#   window:    the # of observations to consider in the window (odd number)
#              (the observation of interest is in the middle of the window)
#   threshold: # of standard deviations away from the mean in the window
#              before/after each observation
#   spike_amp: spike amplitude (in units of values being compared)
#   timeframe: if the observations in your window span more than this many days,
#              don't consider the middle observation a spike
#              (ex: if your data are sparse and your window of 5 observations
#              span a timeframe of more than 100 days, don't consider the
#               middle observation a spike no matter what)
# Returns:
#   The input data.table with a new binary column called "spike":
#   observations with a spike value of 1 are spikes, 0 are non-spikes
#
# FOR NOW: change instances of "date" and "EVI2" to the names of the appropriate
# columns in your input data.set
# 
detect_outliers <- function(input, window, threshold, spike_amp,
                            timeframe) {
    # data <- input[, mean(EVI2), date] # uncomment if want to find
    #                                       the mean observation value
    #                                       by date
    data <- input # Make copy of the input data to change
    w_floor <- floor(window / 2) # number of obs to consider before/after
    #                              date of interest
    n_obs <- nrow(data)
    if (n_obs < window) {
        warning("Window size is larger than the number of dates
         with observations.")
        return(input) # no spike
    }
    input$spike <- 0 # all observations are spikeless (0) by default
    spike_dates <- c() # Create list to keep track of spike dates
    # Loop through moving windows
    for (i in (w_floor + 1):(nrow(data) - w_floor)) {

        # Determine observation of interest and window before/after
        center <- data[i, ] # Center observation of interest
        pre <- data[(i - w_floor):(i - 1), ] # Obs before date of interest
        post <- data[(i + 1):(i + w_floor), ] # Obs after date of interest

        # Calculate diffs between the median values before/after central obs
        pre_diff <- center$EVI2 - median(pre$EVI2)
        post_diff <- median(post$EVI2) - center$EVI2

        # If differences before/after central obs > threshold deviations
        # between the median values pre- and post-obs of interest
        if ((abs(pre_diff + post_diff) >= (threshold * sd(c(pre$EVI2,
             post$EVI2), na.rm = TRUE))) &
             # and the range of dates is within the timeframe threshold
            (max(post$date) - min(pre$date) <= timeframe)) {
            # If difference before AND after the central obs >= spike amplitude
            if (((pre_diff <= - spike_amp) & (post_diff >= spike_amp)) |
            ((pre_diff >= spike_amp) & (post_diff <= - spike_amp))) {
                # add this observation date to list of spike dates
                spike_dates <- c(spike_dates, data[i, date])
            }
        }
    }
    # If there's at least one spike date, add a "spike" column where 1 == spike
    if (length(spike_dates >= 1)) {
        input[date %in% spike_dates, "spike"] <- 1 # spike found
    }
    # Return the data with the added spike column, if any spikes detected
    return(input)
}

# Plot results in .pdf
colors <- c("#808080", "#F15BB5") # normal obs, outliers
pdf("field_spike_results.pdf")
par(mfrow = c(2, 2))

# Loop through all greenup periods for different fields and plot timeseries
# w/ pink obs for spikes
for (i in 1:213) {
    spike_data <- test_data[field == i, ]
    spike_results <- detect_outliers(spike_data, 7, 1, 0.1, 20)
    # spike_results$spike
    plot(spike_results$date, spike_results$EVI2,
        col = colors[factor(spike_results$spike)], pch = 19,
        xlab = "Date", ylab = "Median EVI2 in Image")
}
dev.off()