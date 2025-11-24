#### Tcrit hot chlorophyll fluorescence calculator Shiny APP ####
### Originally from file "FC-Processing.R"
### Last updated on 11/22/25 by Ana Rowley


library(shiny)
library(segmented) #helpful for model data with break points
library(readr)
library(here)
library(rlang)
library(dplyr)


# ---------------------------
# Loading functions from existing script 
# ---------------------------

# CUSTOM FUNCTIONS

# Function that rescales fluorescence values between 0 and 1
rescale <- function(x){ (x - min(x)) / (max(x) - min(x)) }

# Rename function
rename <- function(data, csv){  
  newnames <- c("temp")
  
  for(i in 2:ncol(data)){
    for(j in 1:nrow(csv)){
      
      if(colnames(data)[i] == csv[j,1]){
        label <- csv[j, 2]
        
        # If label is blank or NA, keep original column name
        if (is.na(label) || label == "") {
          label <- colnames(data)[i]
        }
        
        # Add cleaned label to name list
        newnames <- c(newnames, as.character(label))
        
      }
    }
  }
  
  colnames(data) <- newnames
  return(data)
}

# Condense function
condense <- function(rawFC){
  newDF <- data.frame(matrix(NA, (nrow(rawFC)/5), ncol(rawFC)))
  
  mod <- 0
  for(i in 1:ncol(rawFC)){
    for(j in 1:120){
      newDF[j,i] <- sum(rawFC[j+mod + 0:4, i])/5
      mod <- mod + 4
    }
    mod <- 0
  }
  
