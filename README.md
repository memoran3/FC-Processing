# Processing Fluorcam data for Tcrit and T50
### Written by Madeline Moran, last modified on 16Sept2024 by MM

Based on processing steps outlined in [Arnold et al. 2021](https://doi.org/10.1071/FP20344), refined by Owen Atkin's lab, then modified by Madeline Moran (referring to previous code and work done by Jessica Guo), this repository provides a workflow for automating detection of thermal limits in high-throughput chlorophyll imaging fluorescence. The final outputs include a CSV file with Date, Run, Sample ID, Tcrit, Tcrit standard error, T50, the upper and lower bounds used in the code (xlow, xhigh), and the threshold used to trim the raw FC data. There will also be a folder created with all of the plots for one run, the plot will include a the original raw FC curve, the trimmed curve, the breakpoint regression to cacluate Tcrit, and a green diamond indicating T50.

## How to use this code

1.  Download `Tcrit Processing 2024.R` from GitHub or the DPEL Drive folder and move to an empty directory where only FluorCam data is processed. This code will create new directories here when necessary, so it is better to start with a folder that can be completely dedicated to this data processing.


2. This code is separated into two main sections:

-  `RUN ONCE` section are for lines of code that need to be executed on the first run, but do not need to be ran again if processing more than one FC .txt file. This section includes library initializing, creating necessary directories if they don't already exist, and establishing two custom functions.

-  `START RUNNING SUBSEQUENT FILES HERE` is where you would start running the code after you've done one .txt file. This section is where all of the actual data and image processing occurs, and is where the final output data frame can be downloaded as a .csv file.


3. After running the `RUN ONCE` portion, make sure that you copy all of the raw FC .txt files in the directory titled `data_raw` and that any label .csv files are entered into the directory titled `data_labels`. When the files are in the appropriate directories, proceed with the rest of the code.

-  Note: The label files should be CSVs. The first column should be titled `well` and will include the labels that were used in the FC pre-processing tab that are present in the raw FC .txt file. The second column should be `sample` and will include the actual name of the sample that you would like to rename the heading with. A template and sample file are included on GitHub, and the template can stay in the `data_labels` folder as long as you don't have raw data with the same file name.


4. The `INPUTS REQUIRED` section will require updating every time there is a new file. If you do not plan to use label files, make sure that the line of code that reads `csv <- 0` is not commented out. When `csv == 0` the renaming function will not run. As a note, if you have a label file an error will come up in this section of code:

```{r}
# Renaming csv if there's a label file
if (csv != 0){ # throws a warning message if csv is a file, don't worry about it
  fluorscale <- rename(fluorscale, csv)
}
```

This warning does not interfere with the function working properly. The warning appears becaue it's looking for a numeric value and getting a string, which is what the code is intended to do. If `csv == 0` then no error will appear.


5. Running this code once will process one raw FC .txt file. After completing one file, start again at the `START RUNNING SUBSEQUENT FILES HERE` and continue to repeat that until all of the .txt files have been processed.


## Notes and plans for updates

- T50 is only working well on curves that are very textbook perfect. It needs to be checked very carefully at this point in time before including in final data sets. Future updates will hopefully fix this problem, but as of now T50 has to be manually removed from the final data sets if the T-F0 curve is atypical.

- If you run this code until `fn` is empty, then try to reset `fn` with the same or new data, it can sometimes run into problems and may not read the new files correctly (it will say that `fn` is empty when it shouldn't be). If this happens, just clear the global environment and restart from the `RUN ONCE` section. It should work fine after that.
