#### Tcrit hot chlorophyll fluorescence calculator Shiny APP ####
### Originally from file "FC-Processing.R"
### Last updated on 11/22/25 by Ana Rowley


library(shiny)
library(segmented) #helpful for model data with break points
library(readr)
library(here)
library(rlang)
library(dplyr)
# install.packages("rsconnect")
library(rsconnect)

# --------------------------------------
# Loading functions from existing script 
# ---------------------------------------

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
  
  colnames(newDF) <- colnames(rawFC)
  return(newDF)
}

# ---------------------------
# User Interface (UI)
# ---------------------------

ui <- fluidPage(
  titlePanel("FluorCam Tcrit + T50 Breakpoint App"),
  
  sidebarLayout(
    sidebarPanel(
      h4("1. Select Data File"), #h4 is used to generate a heading 4-style heading
      fileInput(
        inputId = "chosen_file",
        label = "Upload a .TXT fluorcam file",
        accept = ".TXT"),
      
      hr(), #used to create horizontal breakpoints
      h4("2. Set Parameters"),
      numericInput("xlow", "Lower temperature limit (xlow)", value =  30), #defining numeric inputs 
      numericInput("xhigh", "Upper temperature limit (xhigh)", value = 60),
      numericInput("maxthreshold", "Max fluorescence threshold", value = 0.9,
                   step = 0.01), #moves at smaller increments
      
      hr(),
      h4("3. Navigate Samples"),
      actionButton("prev_sample", "Previous Sample"), #generating UI buttons
      actionButton("next_sample", "Next Sample"),
      br(), br(), #used to create a line break
      uiOutput("sample_dropdown"),
      
      hr(),
      h4("4. Save Results"),
      actionButton("save_btn", "Save Tcrit/T50 for this sample", class = "btn-primary")
    ),
    
    mainPanel(
      plotOutput("fluorPlot", height = "500px"),
      hr(),
      h4("Saved Results"),
      tableOutput("results_table"),
      downloadButton("download_csv", "Download All Results")
    )
  )
)

# ---------------------------
# Server
# ---------------------------

server <- function(input, output, session){
  
  # Load labels from project root
  labels <- read.csv("data_labels/Label-Template.csv")
  
  
  
  # Reactive: load + process selected file
  processed <- reactive({
    req(input$chosen_file)
    
    # Load the uploaded file
    rawFC <- read_table( # switch from original read.table
      input$chosen_file$datapath,
      skip = 2,
      # header = TRUE,
      # sep = "\t"
    )
    
    rawFC <- rawFC[-1]  # remove time column
    colnames(rawFC)[1] <- "temp"
    
    condensed <- condense(rawFC)
    condensed <- subset(condensed, temp > input$xlow & temp < input$xhigh)
    
    fluorscale <- condensed
    for(i in 2:ncol(condensed)) {
      fluorscale[, i] <- rescale(condensed[, i])
    }
    
    fluorscale <- rename(fluorscale, labels)
    fluorscale
  })
  
  # Track current sample
  sample_index <- reactiveVal(2) #start at sample column 2 (column 1 - tempeature)
  
  observeEvent(input$prev_sample, {
    idx <- sample_index()
    if(idx > 2) sample_index(idx - 1) #prevents going past first sample column
  })
  
  observeEvent(input$next_sample, {
    idx <- sample_index()
    max_sample <- ncol(processed())
    if(idx < max_sample) sample_index(idx + 1) #prevents going past the last sample 
  })
  
  # Dropdown to choose sample directly
  output$sample_dropdown <- renderUI({
    req(processed())
    selectInput("sample_select", "Or choose sample:", 
                choices = colnames(processed())[2:ncol(processed())])
  })
  
  observeEvent(input$sample_select, {
    idx <- which(colnames(processed()) == input$sample_select) #dropddown selection displays sample_index()
    sample_index(idx)
  })
  
  # Calc Tcrit + T50
  calc_results <- reactive({
    df <- processed()
    idx <- sample_index()
    req(ncol(df) >= idx)
    
    temp <- df$temp
    y <- df[, idx]
    
    th_vals <- which(y > input$maxthreshold) #find where fluorescence first exceeds threshold
    tempatthreshold <- temp[th_vals[1]]
    
    sample_col <- colnames(df)[idx]   #get sample column name
    
    df_sub <- df |> 
      filter(temp > input$xlow & temp < tempatthreshold) |> #keeps only data inside temp window and under the threshold
      filter(.data[[ sample_col ]] < input$maxthreshold)
    
    response <- df_sub[, sample_col]
    t50 <- df_sub$temp[which.min(abs(response - 0.5))] #T50 = midpoint of fluorescence (value closest to 0.5)
    
    model1 <- lm(response ~ temp, data = df_sub) #fit linear model
    seg_model1 <- segmented(model1, seg.Z = ~temp) #fit segmented model & estimate breakpoint
    
    tcrit <- round(seg_model1$psi[2], 3) #breakpoint location
    stderr <- round(seg_model1$psi[3], 3) #stder around breakpoint
    
    list(
      tcrit = tcrit,
      stderr = stderr,
      t50 = t50,
      df_main = df,
      df_sub = df_sub,
      tempatthreshold = tempatthreshold
    )
  })
  
  output$fluorPlot <- renderPlot({
    req(processed())
    req(calc_results())
    
    df      <- processed()                  # full processed data frame
    idx     <- sample_index()               # index of selected sample
    sample  <- colnames(df)[idx]            # column name
    res     <- calc_results()               # Tcrit, T50, df_sub, etc.
    
    temp <- df$temp
    y    <- df[[sample]]
    
    # Fit segmented model for plotting
    model1     <- lm(y ~ temp)
    seg_model1 <- segmented(model1, seg.Z = ~temp)
    
    # Extract fitted segmented line
    seg_fit <- fitted(seg_model1)
    
    # -----------------------------
    # PLOT
    # -----------------------------
    plot(
      temp, y,
      type = "l",
      lwd = 1,
      col = "black",
      xlab = "Temperature (°C)",
      ylab = "% Maximum Photosynthesis",
      main = paste("Sample:", sample)
    )
    
    # Add the segmented model fit
    lines(temp, seg_fit, col = "red", lwd = 2)
    
    # Vertical dashed lines for Tcrit window (xlow, xhigh)
    abline(v = input$xlow,  col = "blue", lty = 2, lwd = 2)
    abline(v = input$xhigh, col = "blue", lty = 2, lwd = 2)
    
    # Add Tcrit point
    points(res$tcrit, y[which.min(abs(temp - res$tcrit))],
           pch = 15, col = "green", cex = 1.3)
    
    # Add T50 point
    points(res$t50, y[which.min(abs(temp - res$t50))],
           pch = 19, col = "orange", cex = 1.3)
    
    # Add text labels
    text(max(temp) - 5,
         max(y) - 0.1,
         labels = paste0(
           "Tcrit = ", round(res$tcrit, 3), " °C\n",
           "T50 = ",   round(res$t50, 2), " °C"
         ),
         pos = 2
    )
  })
  
  # --------------------------
  # SAVED RESULTS TABLE
  # --------------------------
  
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

# Run the application 
shinyApp(ui = ui, server = server, options = list(launch.browser = TRUE)) #ran into issues opening app
