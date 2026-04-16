##### Tcrit/50 Data Processing Shiny App #####
### Processing code originally sourced from file "FC-Processing.R"
### Shiny app originally created by Ana Rowley (uploaded on 11/22/25)
### Shiny app last updated by Madeline Moran on 3/16/25



# PACKAGES ----------------------------------------------------------------

library(shiny)
library(segmented) # required for break-point regression
library(readr)
library(here)
library(rlang)
library(dplyr)
library(rsconnect)
library(DT)


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
  
  # Isolating temp column, round to 2 sig figs
  mod <- 0
  for(k in 1:120){
    newDF[k,1] <- round((sum(rawFC[k+mod + 0:4, 1])/5), digits = 2)
    mod <- mod + 4
  }
  
  # FC data
  mod <- 0
  for(i in 2:ncol(rawFC)){
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
      
      tabsetPanel(
        tabPanel("Data Processing",
          
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
          
          fluidRow(
            column(width = 8,
                   h4("3. Modify Parameters")),
            column(width = 4,
                   checkboxInput(inputId = "defaults",
                                 label = "Reset?",
                                 value = F))),
          numericInput(inputId = "xlow", 
                       label = "Lower temperature limit (xlow)", 
                       value =  30), #defining numeric inputs 
          numericInput(inputId = "xhigh", 
                       label = "Upper temperature limit (xhigh)", 
                       value = 60),
          numericInput(inputId = "maxthreshold", 
                       label = "Max fluorescence threshold", 
                       value = 0.9,
                       step = 0.05), #moves at smaller increments
            
          h4("4. Add Results to Table", style = "margin-top: 40px;"),
          actionButton(inputId = "save_btn", 
                       label = HTML(paste0("Save T",tags$sub("crit"),"/T",tags$sub("50")," for this sample")), # HTML makes subscripts work properly 
                       class = "btn-primary"),
          
          hr(),
          h4("5. Navigate Samples"),
          actionButton(inputId = "prev_sample", 
                       label = "Previous Sample"), #generating UI buttons
          actionButton(inputId = "next_sample", 
                       label = "Next Sample"),
          br(), br(), #used to create a line break
          uiOutput("sample_dropdown"),
          
        ),
        tabPanel("Instructions",
                 h3("Need help?"),
                 helpText("This is a shortened version of the README on GitHub. Follow this link for more detailed information or examples of what the files should look like: "),
                 a("GitHub Link", href = "https://github.com/memoran3/FC-Processing/tree/main/shiny_app"),
                 
                 h4("1. Select Data File", style = "margin-top: 30px;"),
                 helpText("Upload a raw FluorCam data file (.txt) from your computer"),
                 
                 h4("2. Select Label File", style = "margin-top: 30px;"),
                 helpText("This is an optional step. Upload a labels file (.csv) if you'd like to rename your samples"),
                 
                 h4("3. Modify Parameters", style = "margin-top: 30px;"),
                 helpText("Modify your xlow, xhigh, and max threshold parameters to better trim your samples"),
                 helpText("xlow and xhigh refer to the range of temperatures along the x axis. Max threshold refers to the % Maxmimum Fluorescence that's included in the breakpoint regression (represented by the blue dashed line)"),
                 helpText("If you check the 'Reset?' box, each new sample will have the parameters reset to the defaults when you navigate to a new sample (xlow = 30 °C, xhigh = 60 °C, max threshold = 0.9)"),
                 helpText("If the 'Reset?' box is unchecked, it will maintain the parameters you currently have set when you navigate to a new sample"),
                 
                 h4("4. Add Results to Table", style = "margin-top: 30px;"),
                 helpText("Add your results from the Main Panel to the table that appears under the plot. This is only saving the data from the sample you are currently looking at"),
                 
                 h4("5. Navigate Samples", style = "margin-top: 30px;"),
                 helpText("Click to navigate to the previous or next sample, or use the dropdown menu to select a specific sample"),
                 helpText("Note: At the moment, the dropdown menu doesn't work properly but it will be fixed in a future update. You can use it on the default settings, but it doesn't work if you modify the parameters at this time"),
                 
                 h4("Finishing Up", style = "margin-top: 30px;"),
                 helpText("In the Results Table (below the plot in the main panel), the samples you added in step 4 will populate here"),
                 helpText("You can click on one or multiple samples to delete them if necessary. The row will be highlighted in blue if they are actively selected"),
                 helpText("When you are finished adding data to this table, click 'Download all results as a CSV' and your file will be saved. At this time the CSV automatically downloads with a similar name as the file that's currently showing in step 1, even if you processed multiple files at one time")
        )
      )
    ),
    
    mainPanel(
      plotOutput(outputId = "fluorPlot", height = "500px"),
      hr(),
      h4("Results Table"),
      div(style = "display: flex; gap: 10px; align-items: center; margin-bottom: 10px;",
          actionButton("delete_btn", "Delete Sample", class = "btn-danger"),
          downloadButton("download_csv", "Download all results as CSV")),
      DTOutput("results_table")
    )
  )
)



# SERVER ------------------------------------------------------------------

server <- function(input, output, session){
  
  # Condense and rename raw FC data -------------------------------------
  
  # Load label CSV and handling empty input
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
    rawFC <- read_delim( # switch from original read.table
      input$chosen_file$datapath,
      skip = 2,
      delim = "\t",
      col_names = T,
      locale = locale(encoding = "Latin1")
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
  # this is making sample_index a reactive expression that will be updated through navigation
  
  # navigating to previous sample
  observeEvent(input$prev_sample, {
    idx <- sample_index()
    if(idx > 2) {
      sample_index(idx - 1) #prevents going past first sample column
      
      
      # reset parameter defaults
      if(input$defaults == T){
        updateNumericInput(session, "xlow", value = 30)
        updateNumericInput(session, "xhigh", value = 60)
        updateNumericInput(session, "maxthreshold", value = 0.9)
      }
    }
  })
  
  # navigating to next sample
  observeEvent(input$next_sample, {
    idx <- sample_index()
    max_sample <- ncol(processed())
    if(idx < max_sample) { #prevents going past the last sample 
      sample_index(idx + 1) 
      
      # reset parameter defaults
      if(input$defaults == T){
        updateNumericInput(session, "xlow", value = 30)
        updateNumericInput(session, "xhigh", value = 60)
        updateNumericInput(session, "maxthreshold", value = 0.9)
      }
    }
  })
  
  # dropdown to choose sample directly
  output$sample_dropdown <- renderUI({
    req(processed())
    selectInput("sample_select", "Or choose sample:", 
                choices = colnames(processed())[2:ncol(processed())])
  })
  

  observeEvent(input$sample_select, {
    idx <- which(colnames(processed()) == input$sample_select) # drop-down selection displays sample_index()
    sample_index(idx)
    #### PROBLEM THAT'S HAPPENING: sample_index is reverting to 2 whenever the parameters are changed on a dropdown selected sample
    #### It doesn't change from 2 if you specify the default as a different number
    #### It doesn't happen with the buttons, but is happening here for some reason
    #### Might have to do with line 250
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
  

  # Results table -------------------------------------------------
  
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
  output$results_table <- renderDT({
    restab <- saved_results()
    datatable(restab, options = list(lengthMenu = c(50, 100)))
  })
  
  # Observer to handle deletes (step 1, before confirmation)
  observeEvent(input$delete_btn, {
    selection <- input$results_table_rows_selected
    if(is.null(selection) || length(selection) == 0){
      showNotification("No row selected to delete", type = "warning")
      return()
    }
    
    showModal(
      modalDialog(title = "Confirm delete",
                  "Are you sure you want to delete this sample?",
                  footer = tagList(
                    modalButton("Cancel"),
                    actionButton("confirm_delete", "Delete", class = "btn-danger"))))
    })
  
  # Observer to handle deletes (step 2, after confirmation)
  observeEvent(input$confirm_delete, {
    selection <- input$results_table_rows_selected
    restab <- saved_results()
    
    # remove selected row
    saved_results(restab[-selection, ,drop = F])
    removeModal()
    showNotification("Row deleted", type = "message")
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


## Use the following code in the console to update the app 
## rsconnect::deployApp(appName = "shiny_app", account = "memoran")