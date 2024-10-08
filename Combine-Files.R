#### Tcrit csv file compiler
### Created by MM on 8/28/24
### Last updated by MM on 8/28/24


library(dplyr)
library(readr)


# Set working directory to wherever the Tcrit Processed folder is
wd <- "C:/Users/madel/Documents/ASU/Hultine Lab/fluorcam_processing-main/data_processed"
setwd(wd)

# Set up output file name
fn <- "/Mt Lemmon Tcrit combined 30 60 70.csv"


# Binding all the csv files together
df <- list.files(path = wd, pattern = "*.csv") %>%
  lapply(read_csv) %>%
  bind_rows()


# Saving the csv file
write.csv(df, file = paste0(wd,fn))
