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
      h4("1. Select Data File"),
      uiOutput("file_selector"),
      
      hr(),
      h4("2. Set Parameters"),
      numericInput("xlow", "Lower temperature limit (xlow)", 30),
      numericInput("xhigh", "Upper temperature limit (xhigh)", 60),
      numericInput("maxthreshold", "Max fluorescence threshold", 0.9),
      
      hr(),
      h4("3. Navigate Samples"),
      actionButton("prev_sample", "Previous Sample"),
      actionButton("next_sample", "Next Sample"),
      br(), br(),
      uiOutput("sample_dropdown"),
      
      hr(),
      h4("4. Save Results"),
      actionButton("save_btn", "Save Tcrit/T50 for this sample", class = "btn-primary")
    ),
    
    mainPanel(
      plotOutput("sample_plot", height = "500px"),
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
  labels <- read.csv(here("data_labels", "Label-Template.csv"))
  
  # Dynamically list .TXT files from data_raw
  output$file_selector <- renderUI({
    files <- list.files(here("data_raw"), pattern = "\\.TXT$", full.names = FALSE)
    selectInput("chosen_file", "Choose a file:", choices = files)
  })
  
  # Reactive: load + process selected file
  processed <- reactive({
    req(input$chosen_file)
    
    filepath <- here("data_raw", input$chosen_file)
    rawFC <- read.table(filepath, skip = 2, header = TRUE, sep = "\t")
    rawFC <- rawFC[-1] # remove time column
    colnames(rawFC)[1] <- "temp"
    
    condensed <- condense(rawFC)
    condensed <- subset(condensed, temp > input$xlow & temp < input$xhigh)
    
    fluorscale <- condensed
    for(i in 2:ncol(condensed)) fluorscale[, i] <- rescale(condensed[, i])
    
    fluorscale <- rename(fluorscale, labels)
    
    fluorscale
  })
  
  # Track current sample
  sample_index <- reactiveVal(2)
  
  observeEvent(input$prev_sample, {
    idx <- sample_index()
    if(idx > 2) sample_index(idx - 1)
  })
  
  observeEvent(input$next_sample, {
    idx <- sample_index()
    max_sample <- ncol(processed())
    if(idx < max_sample) sample_index(idx + 1)
  })
  
  # Dropdown to choose sample directly
  output$sample_dropdown <- renderUI({
    req(processed())
    selectInput("sample_select", "Or choose sample:", 
                choices = colnames(processed())[2:ncol(processed())])
  })
  
  observeEvent(input$sample_select, {
    idx <- which(colnames(processed()) == input$sample_select)
    sample_index(idx)
  })
  
  # Calculate Tcrit + T50
  calc_results <- reactive({
    df <- processed()
    idx <- sample_index()
    req(ncol(df) >= idx)
    
    temp <- df$temp
    y <- df[, idx]
    
    th_vals <- which(y > input$maxthreshold)
    tempatthreshold <- temp[th_vals[1]]
    
    sample_col <- colnames(df)[idx]   # ← get sample column name
    
    df_sub <- df %>%
      filter(temp > input$xlow & temp < tempatthreshold) %>%
      filter(.data[[ sample_col ]] < input$maxthreshold)
    
    response <- df_sub[, sample_col]
    t50 <- df_sub$temp[which.min(abs(response - 0.5))]
    
    model1 <- lm(response ~ temp, data = df_sub)
    seg_model1 <- segmented(model1, seg.Z = ~temp)
    
    tcrit <- round(seg_model1$psi[2], 3)
    stderr <- round(seg_model1$psi[3], 3)
    
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
    req(input$col_select)

    df <- rawFC() %>% select(Time, Fluor = all_of(input$col_select))

    # Fit segmented model
    lin_mod <- lm(Fluor ~ Time, data = df)
    seg_mod <- segmented(lin_mod, seg.Z = ~Time, psi = list(Time = 50)) # adjust psi if needed

    # Breakpoint / Tcrit
    Tcrit <- seg_mod$psi["Time","Est."]

    # Estimate T50 (midpoint of fluorescence)
    T50 <- df$Time[which.min(abs(df$Fluor - mean(df$Fluor)))]

    # X-limits for dashed lines
    x_low <- Tcrit - 5
    x_high <- Tcrit + 5

    # Plot
    ggplot(df, aes(x = Time, y = Fluor)) +
      geom_line(color = "black", size = 1) +                               # raw curve
      geom_line(aes(y = predict(seg_mod)), color = "red", size = 1) +      # segmented fit
      geom_vline(xintercept = c(x_low, x_high), color = "blue", linetype = "dashed") +
      geom_point(aes(x = T50, y = df$Fluor[which.min(abs(df$Fluor - mean(df$Fluor)))]),
                 color = "green", size = 3) +
      annotate("text", x = max(df$Time)*0.7, y = max(df$Fluor)*0.9,
               label = paste0("Tcrit = ", round(Tcrit,1), "\nT50 = ", round(T50,1)),
               hjust = 0, color = "black") +
      labs(x = "Time (s)", y = "Fluorescence") +
      coord_cartesian(xlim = c(min(df$Time), max(df$Time)),
                      ylim = c(min(df$Fluor), max(df$Fluor))) +
      theme_minimal(base_size = 14) +
      theme(
        panel.grid.major = element_line(color = "grey80"),
        panel.grid.minor = element_line(color = "grey90")
      )
  })

  # Store saved results
  saved_results <- reactiveVal(data.frame())

  observeEvent(input$save_btn, {
    df <- processed()
    idx <- sample_index()
    res <- calc_results()

    new_row <- data.frame(
      File = input$chosen_file,
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
  
  output$results_table <- renderTable({ saved_results() })
  
  # Download all results as CSV
  output$download_csv <- downloadHandler(
    filename = function() { paste0("Processed_", input$chosen_file, "_results.csv") },
    content = function(file) { write.csv(saved_results(), file, row.names = FALSE) }
  )
}

# Run the application 
shinyApp(ui = ui, server = server, options = list(launch.browser = TRUE)) #ran into issues opening app

