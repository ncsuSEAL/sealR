# Spike filter example 
Example data includes messy EVI2 time series of PlanetScope data of 213 different fields

(Will soon add a description of how the algorithm works, and suggestions for changes for different uses of the algorithm)

## Things to change if you use this detect_outliers function for different purposes: 
#### 1. Change the input, window, threshold, spike_amp, and timeframe arguments to fit your data
      input:     data.table of time series of imput data with at least two
                 columns, one called "date" for observation dates and the other
                 called "EVI2" for EVI2 values (will change these to be specified
                 in the function ASAP!)
                 (EVI2, etc.)
      window:    the # of observations to consider in the window (odd number)
                 (the observation of interest is in the middle of the window)
      threshold: # of standard deviations away from the mean in the window
                 before/after each observation
      spike_amp: spike amplitude (in units of values being compared)
      timeframe: if the observations in your window span more than this many days,
                 don't consider the middle observation a spike
                 (ex: if your data are sparse and your window of 5 observations
                 span a timeframe of more than 100 days, don't consider the
                 middle observation a spike no matter what)

#### 2. The columns of interest in the example data.table are "date" for the observation dates and "EVI2" for the EVI2 values on each observation date. Change all instances of these two column names within the detect_outliers function to use the function on your own data.table. I'll add parameters to the function so you don't have to manually do these changes in the future! 

## Output
The function will return the input data.table with a new binary column called "spike"; observations with a 1 in the "spike" column were detected as spikes, 0s were not.

NOTE: the algorithm will probably require some tweaking of the parameters to get it to work for your data! Ask Izzi if you have any questions
