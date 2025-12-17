##### Tcrit/50 Data Processing Shiny App #####
### Processing code originally sourced from file "FC-Processing.R"
### Shiny app originally created by Ana Rowley (uploaded on 11/22/25)
### Shiny app last updated by Madeline Moran on 12/17/25



# PACKAGES ----------------------------------------------------------------

library(shiny)
library(segmented) # required for break-point regression
library(readr)
library(here)
library(rlang)
library(dplyr)
library(rsconnect)


# CUSTOM FUNCTIONS --------------------------------------------------------

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

# condense function: Takes the average fluorescence of every 5 measuring flashes
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
  
  colnames(newDF) <- colnames(rawFC)
  return(newDF)
}



# USER INTERFACE (UI) -----------------------------------------------------

ui <- fluidPage(
  titlePanel(HTML(paste0("FluorCam T",tags$sub("crit")," & T", tags$sub("50")," Data Processing App")),
             windowTitle = "FluorCam Tcrit & T50 Data Processing App"),
  
  sidebarLayout(
    sidebarPanel(
      
      style = "max-height: 90vh; overflow-y: scroll;", # sidebar scrolling
      
      h4("1. Select Data File"), #h4 is used to generate a heading 4-style heading
      fileInput(
        inputId = "chosen_file", # FC raw data
        label = "Upload a .TXT FluorCam file",
        accept = ".TXT"),
      
      h4("2. Select Label File (Optional)"),
      fileInput(
        inputId = "label_file", # label csv
        label = "Upload a .CSV label file",
        accept = ".csv"),
      
      h4("3. Modify Parameters"),
      numericInput("xlow", "Lower temperature limit (xlow)", value =  30), #defining numeric inputs 
      numericInput("xhigh", "Upper temperature limit (xhigh)", value = 60),
      numericInput("maxthreshold", "Max fluorescence threshold", value = 0.9,
                   step = 0.01), #moves at smaller increments
      
      h4("4. Save Results to Table"),
      actionButton("save_btn", 
                   HTML(paste0("Save T",tags$sub("crit"),"/T",tags$sub("50")," for this sample")), 
                   class = "btn-primary"),
      
      hr(),
      h4("5. Navigate Samples"),
      actionButton("prev_sample", "Previous Sample"), #generating UI buttons
      actionButton("next_sample", "Next Sample"),
      br(), br(), #used to create a line break
      uiOutput("sample_dropdown"),

      ),
    
    mainPanel(
      plotOutput("fluorPlot", height = "500px"),
      hr(),
      h4("Results Table"),
      tableOutput("results_table"),
      downloadButton("download_csv", "Download All Results as .CSV")
    )
  )
)



# SERVER ------------------------------------------------------------------

server <- function(input, output, session){
  
  # Condense and rename raw FC data -------------------------------------
  
  # Load labels from project root
  labels <- reactive({
    if(is.null(input$label_file) || is.null(input$label_file$datapath)){
      return(NULL)
    }
    #req(input$label_file$datapath)
    read.csv(input$label_file$datapath)
  })
  
  
  # Reactive: load + process selected file
  processed <- reactive({ # reactive means it will change when inputs are changed
    req(input$chosen_file)

    # Load the uploaded file
    rawFC <- read_table( # switch from original read.table
      input$chosen_file$datapath,
      skip = 2
    )
    
    rawFC <- rawFC[-1]  # remove time column
    colnames(rawFC)[1] <- "temp" # rename the °C column
    
    condensed <- condense(rawFC) # going from 600 obs to 120 obs
    condensed <- subset(condensed, temp > input$xlow & temp < input$xhigh) # sub-setting based on xlow and xhigh inputs
    
    fluorscale <- condensed
    for(i in 2:ncol(condensed)) {
      fluorscale[, i] <- rescale(condensed[, i])
    }
    
    if(!is.null(labels())){
      fluorscale <- rename(fluorscale, labels())
    }
    fluorscale
  })
  
  

  # Tracking and navigation -------------------------------------------------

    # Track current sample
  sample_index <- reactiveVal(2) #start at sample column 2 (column 1 - temperature)
  
  # navigating to previous sample
  observeEvent(input$prev_sample, {
    idx <- sample_index()
    if(idx > 2) sample_index(idx - 1) #prevents going past first sample column
  })
  
  # navigating to next sample
  observeEvent(input$next_sample, {
    idx <- sample_index()
    max_sample <- ncol(processed())
    if(idx < max_sample) sample_index(idx + 1) #prevents going past the last sample 
  })
  
  # dropdown to choose sample directly
  output$sample_dropdown <- renderUI({
    req(processed())
    selectInput("sample_select", "Or choose sample:", 
                choices = colnames(processed())[2:ncol(processed())])
  })
  
  observeEvent(input$sample_select, {
    idx <- which(colnames(processed()) == input$sample_select) #dropdown selection displays sample_index()
    sample_index(idx)
  })
  
  

  # Calculating Tcrit/T50 ---------------------------------------------------

  # Calc Tcrit + T50
  calc_results <- reactive({
    df <- processed() # condensed, renamed, and xlow-xhigh trimmed data
    idx <- sample_index() # sample index
    req(ncol(df) >= idx) # required: number of df columns >= index value 
    
    
    temp <- df$temp # temp column between xlow and xhigh (from processed())
    y <- df[, idx] # data for selected sample column
    
    th_vals <- which(y > input$maxthreshold) #find where fluorescence first exceeds maxthreshold
    tempatthreshold <- temp[th_vals[1]] # temperature at that maxthreshold cut-off
    
    sample_col <- colnames(df)[idx]   #get sample column name
    
    # filters df for data in between xlow temp and temp at maxthreshold cut-off
    df_sub <- df |> 
      filter(temp > input$xlow & temp < tempatthreshold) |> 
      filter(.data[[ sample_col ]] < input$maxthreshold)
    
    # finding T50
    response <- df_sub[, sample_col]
    t50 <- df_sub$temp[which.min(abs(response - 0.5))] #T50 = midpoint of fluorescence (value closest to 0.5)
    
    # calculating Tcrit
    model1 <- lm(response ~ temp, data = df_sub) #fit linear model
    seg_model1 <- segmented(model1, seg.Z = ~temp) #fit segmented model & estimate break-point in temp data
    seg_fit <- fitted(seg_model1) # extract fitted segmented line for plotting
    tcrit <- round(seg_model1$psi[2], 3) #break-point estimate (temperature)
    stderr <- round(seg_model1$psi[3], 3) #standard error around break-point estimate
    
    
    list(
      tcrit = tcrit,
      stderr = stderr,
      t50 = t50,
      df_main = df,
      df_sub = df_sub,
      tempatthreshold = tempatthreshold,
      seg_fit = seg_fit
    )
  })
  
  
  # Plot --------------------------------------------------------------------
  
  output$fluorPlot <- renderPlot({
    req(processed())
    req(calc_results())
    req(input$maxthreshold)
    
    df <- processed()   # full processed data frame
    idx <- sample_index()  # index of selected sample
    sample <- colnames(df)[idx]  # column name
    res <- calc_results()  # Tcrit, T50, df_sub, etc.
    temp <- df$temp  # temperature column
    y <- df[[sample]]  # data for selected sample column
    seg_fit <- res$seg_fit  # fitted regression lines for plot
    

    plot(
      temp, y,
      type = "l",
      lwd = 1,
      col = "black",
      xlab = "Temperature (°C)",
      ylab = "% Maximum Fluorescence",
      main = paste0("Sample: ",sample)
    )
    
    
    # Add the segmented model fit
    lines(res$df_sub$temp, seg_fit, col = "red", lwd = 2)
    
    # Vertical dashed lines for Tcrit window (xlow, xhigh)
    abline(v = input$xlow,  col = "#0072B2", lty = 2, lwd = 2)
    abline(v = res$tempatthreshold, col = "#0072B2", lty = 2, lwd = 2)
    
    # Add Tcrit point
    points(res$tcrit, y[which.min(abs(temp - res$tcrit))],
           pch = 21, bg = "#009E73", col = "black", cex = 1.5)
    
    # Add T50 point
    points(res$t50, y[which.min(abs(temp - res$t50))],
           pch = 22, bg = "#F0E442", col = "black", cex = 1.5)
    
    # Add text labels
    text(min(temp) + 3,
         max(y) - 0.1,
         adj = c(0,0),
         labels = paste0(
           "Tcrit = ", round(res$tcrit, 3), " °C\n",
           "T50 = ",   round(res$t50, 2), " °C"
         )
    )
  })
  

  # Saved results table -----------------------------------------------------
  
  # Store saved results
  saved_results <- reactiveVal(data.frame())
  
  observeEvent(input$save_btn, {
    df <- processed()
    idx <- sample_index()
    res <- calc_results()
    
    new_row <- data.frame(
      File = input$chosen_file$name,
      Sample = colnames(df)[idx],
      Tcrit = res$tcrit,
      StdErr = res$stderr,
      T50 = res$t50,
      xlow = input$xlow,
      xhigh = input$xhigh,
      maxthreshold = input$maxthreshold
    )
    
    saved_results(rbind(saved_results(), new_row))
  })
  
  # Render table of saved results
  output$results_table <- renderTable({
    saved_results()
  })

  # Download all results as CSV
  output$download_csv <- downloadHandler(
    filename = function() { paste0("Processed_", input$chosen_file, "_results.csv") },
    content = function(file) { write.csv(saved_results(), file, row.names = FALSE) }
  )
}



# RUN APPLICATION ---------------------------------------------------------

shinyApp(ui = ui, server = server)

# Use this if you only want it to load in an external browser
# shinyApp(ui = ui, server = server, options = list(launch.browser = TRUE)) 