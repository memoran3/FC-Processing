
# Processing Fluorcam data for Tcrit and T50 ShinyApp 
### Originally from “FC-Processing.R”

### Written by Ana Rowley
#### last updated December 9, 2025 by AR

## Background

This code is base on modified processsing code by Madeline Moran (referring to previous code and work done by Jessice Guo and Maeline Moran). This repository provides a workflow for the Shiny App that makes Madeline Moran's previous script automating detection of Tcrit and T50 more efficient. 

The final output includes an interactive Shiny App where the user can select and upload data files, select a given sample, and input the upper and lower bounds, and max threshold. The Shiny App will display the corresponding plot, including the original raw FC curve, the trimmed curve, the breakpoint regression to calculate Tcrit, and a green square deliniating T50. A reactive table will generate with the following columns:  

#### Output	Table Description
* File	Name of the processed FluorCam file	text
* Sample ID after relabeling	text
* Tcrit	Estimated critical temperature	°C
* SE	Standard error from segmented regression	°C
* T50	Temperature at which fluorescence is reduced 50%	°C
* xlow	Lower bound selected by user	°C
* xhigh	Upper bound selected by user	°C
* maxthreshold	% of initial fluorescence used to trim noise

The user can press a download button, which generates a CSV file with the results of the interactive table.  
## Repo Contents

* shiny_app/ - 
    (Deployment directory for ShinyApps.io; auto-generated)

* rsconnect/shinyapps.io/anarowley/ - 
    Files used by rsconnect to deploy the app

* app.R - 
    Main Shiny App for visualizing FluorCam curves, setting bounds,
    calculating Tcrit/T50, and exporting results

* FC-Processing.R - 
    Core processing script adapted from Moran/Guo pipeline

* Combine-Files.R - 
    Script that merges multiple output CSVs into one long file

* Sample-Labels.csv.- 
    Template for mapping FC well names → sample IDs

* DBG_2025.05.07_PM_F0_kin.TXT - 
    Example raw FluorCam output file

* Final.Rproj - 
    RStudio project file

* LICENSE
    MIT license

* .gitignore
    Git exclusion rules

* README.md
    Documentation (this file)


## How to use "app.R"

Select a file, adjust the temperature limits and max threshold as needed, and examine the plotted regression. Save each sample's results as you move through them. When finished, download the compiled CSV. Repeat for each file. 

### Notes and Plans for Updates

Future improvements should include an option to highlight anomalous curves, add sample-specific comments while processing, and allow users to edit or remove entries from the saved results table.

If the app fails to load after toggling between files repeatedly, restart your R session to reset reactive objects. Performance may slow if many users share the same hosting server.

UPDATE 11/22/25:Resolved an error where label templates containing blank sample names would overwrite column names incorrectly. Blank or NA labels now preserve the raw header.

UPDATE 11/15/25: Improved the segmented regression fit and added a visual overlay of the segmented model to the plot. Also fixed an issue where the first sample column could not be selected directly.

If the app fails to load after switching between files repeatedly, try restarting the R session and launching the app again. This resets reactive objects and prevents issues where the file list appears empty. Due to limited server bandwidth, the app may lag or become temporarily unaccessbile if multiple are on the same server at a time. 

By keeping only the required raw files and label templates in the working directory, the app should process FluorCam data smoothly across multiple sessions.


## Run the application 
shinyApp(ui = ui, server = server, options = list(launch.browser = TRUE)) 

## Acknowledgements

I would like to thank Dr. Jessica Guo for her guidance throughout this semester and the duration of this project. I also would like to thank Madeline Moran for her time and for trusting me with her research.

- [FC-Processing.R](https://github.com/arowley04/FC-Processing/blob/main/README.md)
- [README Files](https://datamanagement.hms.harvard.edu/collect-analyze/documentation-metadata/readme-files)
 - [Awesome Readme Templates](https://awesomeopensource.com/project/elangosundar/awesome-README-templates)
 - [Awesome README](https://github.com/matiassingers/awesome-readme)
 - [How to write a Good readme](https://bulldogjob.com/news/449-how-to-write-a-good-readme-for-your-github-project)
 


# Appendix

- [Access the app](https://anarowley.shinyapps.io/shiny_app/)

- [Access the background](https://docs.google.com/document/d/12kKXWAjVvlxS80Q98abpgT8BywTy19nuaID-Na7OnbA/edit?usp=sharing)

## Background

This code is base on modified processsing code by Madeline Moran (referring to previous code and work done by Jessice Guo and Maeline Moran). This repository provides a workflow for the Shiny App that makes Madeline Moran's previous script automating detection of Tcrit and T50 more efficient. 

The final output includes an interactive Shiny App where the user can select and upload data files, select a given sample, and input the upper and lower bounds, and max threshold. The Shiny App will display the corresponding plot, including the original raw FC curve, the trimmed curve, the breakpoint regression to calculate Tcrit, and a green square deliniating T50. A reactive table will generate with the following columns:  

#### Output	Table Description
* File	Name of the processed FluorCam file	text
* Sample ID after relabeling	text
* Tcrit	Estimated critical temperature	°C
* SE	Standard error from segmented regression	°C
* T50	Temperature at which fluorescence is reduced 50%	°C
* xlow	Lower bound selected by user	°C
* xhigh	Upper bound selected by user	°C
* maxthreshold	% of initial fluorescence used to trim noise

The user can press a download button, which generates a CSV file with the results of the interactive table.  
