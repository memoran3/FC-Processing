# Processing Fluorcam data for Tcrit and T50
### Written by Madeline Moran
#### last updated on December 17, 2025 by MM

## IMPORTANT UPDATE:
As of 12/17/25, there is now a Shiny app to help streamline this data processing workflow. To learn how to use the app, please follow the README in the `shiny_app` directory. Running the Shiny app can completely replace using this code manually, they do the same thing, and the app has a better user interface. Special thank you to Ana Rowley for creating this app, and to Jessica Guo for adivisng on it! Please contact me if you run into problems with the app.

## Background
This code is based on processing steps outlined in [Arnold et al. 2021](https://doi.org/10.1071/FP20344), refined by Owen Atkin's lab, then modified by Madeline Moran (referring to previous code and work done by Jessica Guo and Madeline Moran). This repository provides a workflow for automating detection of thermal limits in high-throughput chlorophyll imaging fluorescence using a closed FluorCam and TR2000 thermoregulator (Photon System Instruments, Drásov, Czech Republic). The final outputs include a CSV file with Date, Run, Sample ID, Tcrit, Tcrit standard error, T50, the upper and lower bounds used in the code (xlow, xhigh), and the threshold used to trim the raw FC data (maxthreshold). This code will also create a folder with all of the plots for one run, and the plots will include the original raw FC curve, the trimmed curve, the breakpoint regression to cacluate Tcrit, and a green square indicating T50.

## How to use "FC-Processing.R"
1.  Clone or download this repository from GitHub and move all files to an empty directory where only FluorCam data is processed. Open the `FC-Processing.Rproj` file and open the `FC-Processing.R` (and `Combine-Files.R` if relevant) within that project. The processing code will create new directories wherever the project is saved when necessary, so it is more streamlined to start with a folder that can be completely dedicated to this data processing. 

2. `FC-Processing.R` is separated into two main sections:

-  `RUN ONCE` section are for lines of code that need to be executed on the first run, but do not need to be ran again if processing more than one FC .txt file. This section includes library initializing, creating necessary directories if they don't already exist, and establishing two custom functions.

-  `START RUNNING SUBSEQUENT FILES HERE` is where you would start running the code after you've done one .txt file. This section is where all of the actual data and image processing occurs, and is where the final output data frame can be downloaded as a .csv file.


3. After running the `RUN ONCE` portion, make sure that you copy all of the raw FC .txt files in the directory titled `data_raw` and that any label .csv files are entered into the directory titled `data_labels`. When the files are in the appropriate directories, proceed with the rest of the code.

-  Note: The label files should be CSVs. The first column should be titled `well` and will include the labels that were used in the FC pre-processing tab that are shown as headings in the raw FC .txt file. The second column should be titled `sample` and will include the actual name of the sample that you would like to rename the heading with. A template and sample file are included on GitHub, and the template can stay in the `data_labels` folder as long as you don't have raw data with the same file name.


4. The `INPUTS REQUIRED` section will require updating every time there is a new file. If you do not plan to use label files, make sure that line 68 (`csv <- read.csv(paste0("./data_labels/",strsplit(fn[1], ".TXT"),".csv")`) is commented out and line 69 (`csv <- 0`) is not.


5. This code runs one raw FluorCam output file at a time. After completing one FluorCam file, start again at the `START RUNNING SUBSEQUENT FILES HERE` and continue to repeat that until all of the .txt files have been processed.

6. After running the files once, look at the plots to see if there are any regressions that look irregular. If there are, you can re-run those raw FluorCam files and modify the xhigh, xlow, and/or maxthreshold values accordingly to get a better regression fit. At this point there is not a way to isolate the samples that need to be re-run, so the whole file will have to be re-run and the good breakpoints from each modified run can be manually added to the final spreadsheet.


## How to use "Combine-Files.R"
This code takes all of the individual CSV files created from the previous code and combines them into one long CSV files that can be used for further data analysis. Make sure that the only CSVs in this directory are the ones that need to be combined.

1. Change the variable `wd` to the directory where the processed CSV files created from "FC-Processing.R" are being kept. Ideally this should still be the "data_processed" folder that was created in the other code.

2. Set `fn` to the filename that you would like the output to be called. This has to start with a slash (/).

3. Run the rest of the code, the output file will be created in the same file where the individual CSV files are.


### Notes and plans for updates
- A problem was found with the T50 portion of this code, results for it should not be used at this time. An updated version will be posted when the problem is fixed, as well as an updated note here in the README file.
- UPDATE 6/13/25: T50 works on the code for good curves where Tmax is captured by the FluorCam and noise is limited, but should be verified before using in any analysis. Do not use the T50 values if there is noise around the 50% fluorescence mark or if Tmax is not captured.
- UPDATE 7/2/25: Tested a T50 calculation method based on the regression line rather than finding the point closest to 50% fluorescence, which works well when the regression line fits closely with the data. It does not work well when the data is noisy in the fast-rise phase. This code was left in, but commented out (lines 182-188) in case others want to try using it. If you want to use this method instead, comment out line 171 first.

- If you run this code until `fn` is empty, then try to reset `fn` with the same or new data, it can sometimes run into problems and may not read the new files correctly (it will say that `fn` is empty when it shouldn't be). If this happens, just clear the global environment and restart from the `RUN ONCE` section. It should work fine after that.
- UPDATE 12/17/25: New Shiny app added! Main note added to the top of the README

