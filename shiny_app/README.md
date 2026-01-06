
# Processing Fluorcam data for Tcrit and T50 ShinyApp 
### Originally from “FC-Processing.R”

### Written by Ana Rowley
#### Last updated January 6, 2026 by Madeline Moran

## Background

This code is base on modified FluorCam processing code by Madeline Moran (referring to previous code and work done by Owen Atkin's lab, Madeline Moran, and Jessice Guo). This repository provides a workflow for the Shiny App that makes the `FC-Processing.R` processing of Tcrit and T50 more efficient. This processing workflow uses the F0 method for Tcrit and T50 analysis. This app can be run locally by cloning or downloading this directory or via web browser [here](https://memoran.shinyapps.io/shiny_app/).

The final output includes an interactive Shiny App where the user can select and upload data files, select a given sample, and modify the temperature boundries and max fluorescence threshold. The Shiny App will display the corresponding plot, including the original raw FC curve, the trimmed curve, the break-point regression to calculate Tcrit, and a green square deliniating T50. A reactive table will generate with the following columns:  

#### Output	Table Description
* File: name of the processed FluorCam file	(text)
* Sample: Sample ID (text)
* Tcrit: Estimated critical temperature (°C)
* SE: Standard error of Tcrit from segmented regression (°C)
* T50: Temperature at which fluorescence reaches 50% of its maximum value (°C)
* xlow: Lower x-axis limit selected by user (°C)
* xhigh: Upper x-axis limit selected by user (°C)
* maxthreshold:	Proportion of maximum fluorescence included in the Tcrit break-point regression

The user can save the Tcrit/50 results for one sample at a time, and the results will populate in a table. The whole results table can be downloaded when processing is complete. 
## Repo Contents

* shiny_app/ - 
    (Deployment directory for ShinyApps.io; auto-generated)

* rsconnect/shinyapps.io/memoran/ - 
    Files used by rsconnect to deploy the app

 * .gitignore
    Git exclusion rules

* README.md
    Documentation (this file)

* ShinyTcrit.Rproj - 
    RStudio project file

* app.R - 
    Main Shiny App for visualizing FluorCam curves, setting bounds,
    calculating Tcrit/T50, and exporting results

* LICENSE
    MIT license



## How to use "app.R"

Upload a raw (FluorCam) data file, adjust the temperature limits and max threshold as needed, and examine the plotted regression. Optionally, you can also upload a label file to rename the samples. Save each sample's results as you move through them. When finished, download the compiled CSV. Repeat for each individual data file (if working with multiple raw data files, the compiled CSV will use the current file name to make the output CSV file name). 

1. Upload a raw FluorCam data file (.txt). See the [Sample-FC-Data.TXT](https://github.com/memoran3/FC-Processing/blob/79fd0618fcec59e128680c7899190a5251bfdb9a/Sample-FC-Data.TXT) for an example of a raw data file.
2. Optional: Upload a labels file (.csv). This is a way to rename leaf samples if need be, see [Sample-Labels.csv](https://github.com/memoran3/FC-Processing/blob/79fd0618fcec59e128680c7899190a5251bfdb9a/Sample-Labels.csv) for an example of what this looks like. It will be helpful to have your raw data and label files in the same directory which is specifically different than the `FC-Processing.R` workflow
    - In the Hultine lab, we use a mask that automatically labels our columns A-H and our rows 1-6, so the top left well in our 48-well heating block is A1, and the bottom right well is H6. That is what is included in the `well` column. The FluorCam often uses "Area#" notation as a default, so that could also go in the `well` column. The `sample` column is then what you would like your samples to be renamed as. In Sample-Labels.csv, our individual plants were given numbers between 101 and 145 so that is what we want our sample labels changed to.

A plot should now be loaded in the main panel that shows the cleaned up raw data as a black line, the break-point regression for Tcrit as a red line, Tcrit as a green circle, T50 as a yellow square, and two blue dashed lines to denote the range for the break-point regression. If you need to modify the parameters to get a better fit for Tcrit or T50, then you modify the parameters. If your plot looks good without modification, jump to step 4.

3. Modify the parameters if needed. Generally modifying xhigh and/or maxthreshold are best for fine-tuning the regression line. It's recommended to manually type your modifications instead of using the arrows. If you use the scrolling arrows, the plot will update through each step and will take much longer than if you just manually type new values. 

4. Save the results of this one sample to the Results Table (blue button), which will populate below the plot in the main panel. This table will save the file name, sample name, Tcrit, Tcrit standard error, T50, and final parameter values (xlow, xhigh, maxthreshold). Each new sample will be given its own row in the Results table. If you wish to delete a row from the Results Table, you can select one row at a time and delete it using the red Delete Sample button.

5. Navigate samples which you can do by clicking Previous Sample or Next sample, or you can use the dropdown menu to select one specific sample. At this time, the parameters will automatically reset to 30 (xlow), 60 (xhigh), and 0.9 (maxthreshold) when using the Next Sample and Previous Sample buttons, but they will not reset if you choose a sample from the drop-down menu.

6. When you have completed your processing, you can save the entire Results Table by clicking the `Download All Results as CSV` button.

7. If you wish to save a plot image, you can do so by right clicking on the image and Save Image As... If you wish to modify the color scheme or point characters, you can do so in the `app.R` file and run the app locally.

### Notes and Plans for Updates

Ideas for future improvements include an option to highlight anomalous curves, add sample-specific comments while processing, adding a Clear Table button, and minor bug fixes with the drop-down sample selection method. 

If the app fails to load after toggling between files repeatedly, restart your R session to reset reactive objects. Performance may slow if many users share the same hosting server. If the app fails to load after switching between files repeatedly, try restarting the R session and launching the app again. This resets reactive objects and prevents issues where the file list appears empty. Due to limited server bandwidth, the app may lag or become temporarily unaccessbile if multiple are on the same server at a time. By keeping only the required raw files and label templates in the working directory, the app should process FluorCam data smoothly across multiple sessions.

UPDATE 11/22/25:Resolved an error where label templates containing blank sample names would overwrite column names incorrectly. Blank or NA labels now preserve the raw header. -AR

UPDATE 11/15/25: Improved the segmented regression fit and added a visual overlay of the segmented model to the plot. Also fixed an issue where the first sample column could not be selected directly. -AR

UPDATE 1/6/26: Delete Sample button added. There was a rounding problem occurring with T50 and that has now been fixed as well. Parameters now restore to default settings after navigating to next/previous samples, but they still do not reset with the drop-down sample selection option. -MM


## Run the application 
`shinyApp(ui = ui, server = server)`
Using RStudio, you have the option of running the app within Rstudio or in an external browser

## Acknowledgements

I would like to thank Dr. Jessica Guo for her guidance throughout this semester and the duration of this project. I also would like to thank Madeline Moran for her time and for trusting me with her research.

- [FC-Processing.R](https://github.com/arowley04/FC-Processing/blob/main/README.md)
 


# Appendix

- [Access the app](https://memoran.shinyapps.io/shiny_app/)

- [Access the background](https://docs.google.com/document/d/12kKXWAjVvlxS80Q98abpgT8BywTy19nuaID-Na7OnbA/edit?usp=sharing)

