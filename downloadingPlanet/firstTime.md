# First time downloading planet

(Not?) surprisingly, the potential is high to have a number of issues arise when trying to download Planet images for the first time, primarily due to conda environments and Rstudio. These issues are documented here.

Step 1: Download conda via [Miniconda](https://docs.conda.io/en/latest/miniconda.html) (unless you have some other reason for Anaconda).

Step 2: Initialize conda in terminal using `conda init`.

The primary steps below are for VS Code. In June 2022, we discovered there are issues with trying to do this in Rstudio. Because we're not sure why this is happening (e.g. was this only for one specific computer? is it windows 11? Is it newer versions of Rstudio?), we're documenting this here.

## VS Code (both Mac and PC)
1. Open the terminal in VS Code.
2. If you don't have an environment already, create the conda environment for the planet orders by following the steps from [porder github](https://github.com/tyson-swetnam/porder). Specifically, run `conda create -n planet_orders python` and then activate the environment with `conda activate planet_orders`.
3. Now we want to install `porder` in the environment. To do so, run `pip install porder`. If that doesn't work, try `pip3 install porder --user`.
4. The main script to download the planet images is in R, so we also need to install R, the medium for it (radian), and necessary packages. In the same terminal (because you're still in the conda environment), install radian first via `conda install -c conda-forge radian`. Then, install R with `conda install -c r r` and finally, install the necessary package (data.table) with `conda install -c conda-forge r-data.table`.
5. Once everything is successfully installed, close and reopen the terminal.
6. Activate your `planet_orders` environment, start radian (by typing `radian`), and begin running through the `downloadPlanet.R` script. When you get to the line saying `system("planet init")`), R will send the command directly to the terminal and you should have a pop-up for you to enter your email and password. 
7. Assuming Step 6 works, everything else should run smoothly.

## Rstudio (both Mac and PC)
1. Open Rstudio and navigate to the terminal.
2. If you don't have an environment already, create the conda environment for the planet orders by following the steps from [porder github](https://github.com/tyson-swetnam/porder). Specifically, run `conda create -n planet_orders python` and then activate the environment with `conda activate planet_orders`.
3. Now we want to install `porder` in the environment. To do so, run `pip install porder`. If that doesn't work, try `pip3 install porder --user`.
4. ERROR
5. This is where things stop working. We don't need to call `radian` here because we're already using R via Rstudio. Yet, when we try to do `system("planet init")`, we get an error saying the following, *despite* the command `planet init` working fine if typed directly into terminal.

```r
sh: planet: command not found
Warnings message:
In system("planet init") : error in running command
```

6. NB in the PC Rstudio, you're not even given an error message and instead are returned `127`, which is a numerical code indicating an error that the commmand was not run.
7. This happens regardless of the shell you're using, and the same result (nothing happens) occurs when using `system()`, `system2()`, and `shell()`. It appears that, at least with `system()`, Rstudio is trying to send the terminal command to a specific shell we don't have access to.
8. Currently the only workaround for this (if you don't want to go to VS Code) is to make the command lines as they are in the R script, and then manually copy/paste into the Rstudio terminal (in the conda environment).
