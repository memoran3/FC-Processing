#### Tcrit hot chlorophyll fluorescence calculator script ####
### Originally from file "Tcrit for Atkin Lab.R"
### Last updated on 7/2/25 by MM

#### RUN ONCE ####
library(segmented)
library(readr)
library(here)
library(rlang)


# Set working directory to where this R project lives
setwd(here())

# Creating directories if they don't already exist
if(!dir.exists("data_raw/")) {
  dir.create("data_raw/")}

if(!dir.exists("data_processed/")) {
  dir.create("data_processed/")}

if(!dir.exists("data_labels/")) {
  dir.create("data_labels/")}



# CUSTOM FUNCTIONS

# Function that rescales fluorescence values between 0 and 1
rescale <- function(x){ (x - min(x))/(max(x) - min(x))} # x is one column in raw FC data

# Rename function
rename <- function(data, csv){  # csv needs well and leafID column
  
  newnames <- c("temp") # initial vector set-up
  
  for (i in 2:ncol(data)){ # iterating through data columns after temp
    for (j in 1:nrow(csv)){ # iterating through label rows (should = ncol(data) - 1)
      if (colnames(data)[i] == csv[j,1]){ # if heading matches label, rename it
        newnames <- c(newnames, as_string(csv[j,2]))
      }
    }
  }
  
  colnames(data) <- newnames
  
  return(data)
}

# Condense function
condense <- function(rawFC){ # rawFC is the raw FC dataframe
  newDF <- data.frame(matrix(NA, (nrow(rawFC)/5), ncol(rawFC))) # condensed dataframe
  
  mod <- 0 # counter for rows
  for (i in 1:ncol(rawFC)){ # iterating through columns
    for (j in 1:120){ # iterating through rows
      # averaging the 5 measurements per checkpoint
      newDF[j,i] <- (rawFC[j+mod,i] + rawFC[j+mod+1,i] + rawFC[j+mod+2,i] + rawFC[j+mod+3,i] + rawFC[j+mod+4,i])/5 
      mod <- mod+4 # increasing counter to the next group of measurements
    }
    mod <- 0
  }
  
  colnames(newDF) <- colnames(rawFC)
  
  return(newDF)
}


setwd(here())

#### START RUNNING SUBSEQUENT FILES HERE ####

# List of .txt file names that have not yet been processed (files not listed in the data_processed directory)
fn <- setdiff(list.files("data_raw/"), list.files("data_processed/"))
print(fn[1]) # to see date and run information better


#### INPUTS REQUIRED ####
xlow         <- 30       # low end ramp temperature removing initial values (30 as default)
xhigh        <- 63       # high end ramp temperature removing highest values (60 as default)
maxthreshold <- 0.9      # value between 0 and 1 for fluorescence (0.9 as default)
date         <- 20250512 # the date of the experiment YEAR/MONTH/DAY
run          <- "PM2"     # the run number for the date
csv          <- read.csv(paste0("./data_labels/",strsplit(fn[1], ".TXT"),".csv"))
# csv        <- 0  # use this line of code instead of the previous one if there's no label file

# Raw kinetic data
rawFC <- read.table(file = paste0("data_raw/",fn[1]), skip = 2, header = T) # if errors occur, try adding fileEncoding = "latin1" after header
rawFC <- rawFC[-1] # remove time stamp column
colnames(rawFC)[1] <- "temp" # rename temperature column


# Checking headers
# head(fluor)

fluor <- condense(rawFC)


# The number of leaf areas of interest specified in this run
nsamples <- ncol(fluor) - 1


# Subset the data to set a more sensible upper limit
fluor <- subset(fluor, fluor$temp > xlow & fluor$temp < xhigh)
# head(fluor)
# tail(fluor)


# Creating new data frame for scaled data
fluorscale <- data.frame(matrix(NA, nrow(fluor), ncol(fluor)))
colnames(fluorscale) <- colnames(fluor)
fluorscale$temp <- fluor$temp

# Rescaling the fluor data
for (column in 2:(nsamples + 1)) {
  fluorscale[column] <- rescale(fluor[column])
}

# head(fluorscale)


# Renaming csv if there's a label file
if (class(csv) == "data.frame"){
  fluorscale <- rename(fluorscale, csv)
}

# head(fluorscale)

# Making the output data frame
output <- matrix(NA, nsamples, 9)
output[,1] <- date
output[,2] <- run
output[,3] <- colnames(fluorscale)[2:ncol(fluorscale)]
output[,7] <- xlow
output[,8] <- xhigh
output[,9] <- maxthreshold

# Creating the output folder for the file being processed
if(!dir.exists(paste0("data_processed/", fn[1]))) {
  dir.create(paste0("data_processed/", fn[1]))
}

# Plotting the rescaled data
par(mfrow = c(4,4), mar = c(1,4,1,1))
for (i in (2:ncol(fluorscale))) {
  tryCatch({
    
    # Plot without modification
    plot(fluorscale[,i] ~ fluorscale$temp, 
         data = fluorscale, 
         type = "l", 
         ylab = names(fluorscale[i]),
         xlim = c(xlow, xhigh), 
         ylim = c(0,1))
    segments(xlow, 0, xlow, 1, 
             lwd = 2, 
             lty = 3, 
             col = "blue")
    thresholdval <- which(fluorscale[,i] > maxthreshold)
    tempatthreshold <- fluorscale$temp[thresholdval[1]]
    segments(tempatthreshold, 0, tempatthreshold, 1, 
             lwd = 2, 
             lty = 3, 
             col = "blue")
    
    fluor_sub <- subset(fluorscale, fluorscale$temp > xlow & fluorscale$temp < tempatthreshold)
    fluor_sub <- subset(fluor_sub, fluor_sub[,i] < maxthreshold)
    
    # Find T50 -> temperature when fluorscale$i F0 is closest to 0.5
    t50 <- fluor_sub[which.min(abs(fluor_sub[,i] - 0.5)),1]
    
    # linear regression for the data, then finding the breakpoint
    response  <- fluor_sub[,i]
    model1     <- lm(response ~ temp, data = fluor_sub)
    seg_model1 <- segmented(model1, seg.Z = ~ temp, data = fluor_sub)
    
    fitted_val1 <- fitted(seg_model1)
    breakmodel1 <- data.frame(Temperature = fluor_sub$temp, fluor_sub = fitted_val1) # regression lines for slow and fast rise phases
    
    
    # # calculate T50 using the breakmodel1 values -> works for clean data, doesn't work for messy data -MM
    # t1 <- breakmodel1$Temperature[nrow(breakmodel1)] # last point in the regression (x1)
    # t2 <- breakmodel1$Temperature[nrow(breakmodel1)-1] # second to last point in the regression (x2)
    # f1 <- breakmodel1$fluor_sub[nrow(breakmodel1)] # last point in the regression (y1)
    # f2 <- breakmodel1$fluor_sub[nrow(breakmodel1)-1] # second to last point in the regression (y2)
    # 
    # t50 <- round(t1 + (((t2-t1)*(0.5-f1))/(f2-f1)), digits = 3) # derived from point-slope form equation
    
    
    # plots with breakpoints
    plot(fluor_sub[,i] ~ temp, 
         data = fluor_sub, 
         ylab = names(fluor_sub[i]), 
         ylim = c(0,1), 
         xlim = c(xlow, xhigh))
    lines(fluor_sub ~ Temperature, 
          data = breakmodel1, 
          type = "l", 
          col = "red", 
          lwd = 2)
    points(fluor_sub[which.min(abs(fluor_sub[,i] - 0.5)),i] ~ t50,
           pch = 22, 
           bg = "green",
           cex = 1.5)
    tcrit1     <- round(seg_model1$psi[[2]], 3)
    tcriterr1  <- round(seg_model1$psi[[3]], 3)
    tcrittext1 <- paste(tcrit1, "°C")
    legend("topleft", legend = tcrittext1, bty = "n", horiz = TRUE)
    
    
    # Saving PNGs for later, comment out to the next comment if you don't want this
    png(filename = paste0("./data_processed/", fn[1],"/", colnames(fluorscale)[i],".png"),
        width = 800,
        height = 500,
        units = "px")
    
    # Plots for PNG files
    plot(fluorscale[,i] ~ temp,
         data = fluorscale,
         ylab = names(fluor_sub[i]),
         ylim = c(0,1),
         xlim = c(xlow, xhigh),
         type = "l",
         cex = 2)
    segments(xlow, 0, xlow, 1,
             lwd = 2,
             lty = 3,
             col = "blue")
    segments(tempatthreshold, 0, tempatthreshold, 1,
             lwd = 2,
             lty = 3,
             col = "blue")
    lines(fluor_sub ~ Temperature,
          data = breakmodel1,
          type = "l",
          col = "red",
          lwd = 2)
    points(fluor_sub[which.min(abs(fluor_sub[,i] - 0.5)),i] ~ t50,
           pch = 22, 
           bg = "green",
           cex = 1.5)
    tcrit1 <- round(seg_model1$psi[[2]], 3)
    tcriterr1 <- round(seg_model1$psi[[3]], 3)
    tcrittext1 <- paste("Tcrit =",tcrit1, "°C")
    t50text <- paste("T50 =",t50,"°C")
    legend("top", legend = c(tcrittext1, t50text), bty = "n")
    
    dev.off()
    
    # Filling out output table
    output[(i-1),4] <- tcrit1
    output[(i-1),5] <- tcriterr1
    output[(i-1),6] <- t50
  }, error = function(e) {cat("ERROR :",conditionMessage(e), "\n")})
}


#### FINAL TCRIT-HOT VALUES ####
output <- as.data.frame(output)
colnames(output) <- c("Date", "Run", "LeafID", "Tcrit", "StdErr", "T50", "xlow", "xhigh", "maxthreshold")
# print(output)


# Write the output as a .csv file to be called into another script
wd <- getwd()
write.csv(output, paste0(wd,"/data_processed/",strsplit(fn[1], ".TXT"),".csv"), row.names = F)

