#### Tcrit csv file compiler
### Created by MM on 8/28/24
### Last updated by MM on 8/28/24


library(dplyr)
library(readr)


# Set working directory to wherever the Tcrit Processed folder is
wd <- paste0(here(),"/data_processed")

# Set up output file name
fn <- "/FCdataCombined.csv"


# Binding all the csv files together
df <- list.files(path = wd, pattern = "*.csv") %>%
  lapply(read_csv) %>%
  bind_rows()


# Saving the csv file
write.csv(df, file = paste0(wd,fn))
