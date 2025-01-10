library(shiny)
library(echarts4r)
library(dplyr)
library(tidyr)
library(bslib)
library(reactable)


# 欢迎关注微信公众号： R语言与可视化
# 如需shiny应用开发可加微信: shinydev



# 数据导入和处理函数
df_pop <- readRDS('data/df_pop.rds') %>%
  filter(year<2050)

getByCountry <- function(area) {
  df_pop %>%
    filter(region_subregion_country_or_area == area) %>%
    select(year, region_subregion_country_or_area, x0:x100) %>%
    mutate(across(starts_with('x'), ~round(as.numeric(.x))))
}

ui <- page_navbar(
  theme = bs_theme(version = 5),
  title = "World Population-1950-2050 ",
  sidebar = sidebar(
    selectInput("country", "Select Region or Country",
                choices = unique(df_pop$region_subregion_country_or_area),
                selected = 'China'),
    selectInput("age", "Select Age", multiple = TRUE, selected = c('0','18','30'), choices = c('All',as.character(0:100))),
    sliderInput("year_range", "Select Year Range",
                min = min(df_pop$year, na.rm = TRUE),
                max = max(df_pop$year, na.rm = TRUE),
                value = c(min(df_pop$year, na.rm = TRUE),
                          max(df_pop$year, na.rm = TRUE)),
                step = 1,
                ticks = TRUE,
                sep = ""),
    downloadButton("download_data", "Download")
  ),
  nav_panel(
    "Population Pyramid",
    layout_columns(min_width = c(300, 300),
                   card(echarts4rOutput("pyramid1"), full_screen = TRUE),
                   card(echarts4rOutput("pyramid2"), full_screen = TRUE)
    )
  ),
  nav_panel(
    "Population Trend",
    layout_sidebar(border = F,
                   fillable = TRUE,
                   sidebar = sidebar(position = 'right', open = FALSE,
                                     input_switch('trans_2','Trans', FALSE)
                   ),
                   echarts4rOutput("trend")
    )
  ),
  nav_panel(
    "Data Table",
    layout_sidebar(border = F,
      fillable = TRUE,
      sidebar = sidebar(position = 'right', open = FALSE,
                        input_switch('trans','Trans', FALSE),
                        tags$button("Download as CSV", onclick = "Reactable.downloadDataCSV('data_table')")
      ),
      reactableOutput("data_table")
    )
  )
)

server <- function(input, output, session) {
  # 响应式数据：根据选择的国家筛选数据
  selected_data <- reactive({
    getByCountry(input$country)
  })

  # 处理金字塔图数据
  pyramid_data <- reactive({
    data <- selected_data() %>%
      select(year,starts_with("x")) %>%
      pivot_longer(cols = -year,
                   names_to = "age",
                   values_to = "population") %>%
      mutate(
        age = as.numeric(gsub("x", "", age)),
        male = -population/2,  # 假设男女各半
        female = population/2
      ) %>%
      arrange(desc(age)) %>%
      na.omit()  # 移除NA值
    return(data)
  })

  # 处理趋势图数据
  trend_data <- reactive({
    age_cols <- paste0("x", input$age)

    if('All' %in% input$age){
      df<-selected_data() %>%
        filter(year >= input$year_range[1],
               year <= input$year_range[2]) %>%
        select(-2)
    } else {
      df<-selected_data() %>%
        filter(year >= input$year_range[1],
               year <= input$year_range[2]) %>%
        select(year, any_of(age_cols))
    }
    return(df)
  })

  # 绘制人口金字塔

  get_pyramid<-function(data,year_range,year_curr){
    data_filtered<- data %>%
      filter(year %in% seq(year_range[1],year_range[2]))

    curr_index<-which(unique(data_filtered$year==year_curr))
    data %>%
      filter(year>=year_range[1],year<=year_range[2]) %>%
      group_by(year) %>%
      e_charts(age,timeline = T) %>%
      e_bar(male, name = "Male", barWidth = "90%", barGap = "-100%") %>%
      e_bar(female, name = "Female", barWidth = "90%") %>%
      e_flip_coords() %>%
      e_legend(top = "top") %>%
      e_grid(
        containLabel = TRUE,
        left = '10%',
        right = '10%'
      ) %>%
      e_y_axis(
        type = "category",
        inverse = F,
        axisLabel = list(
          interval = 4
        )
      ) %>%
      e_x_axis(
        formatter = htmlwidgets::JS("
          function(value) {
            return Math.abs(value).toFixed(0) + '';
          }
        "),
        axisLabel = list(
          margin = 2
        )
      ) %>%
      e_tooltip(
        trigger = "axis",
        formatter = htmlwidgets::JS("
          function(params) {
            console.log(params)
            var age = params[0].name;
            var maleValue = Math.abs(params[0].value[0]);
            return age + ' years old <br/>' +
                   (maleValue*2).toFixed(0) + ' thousands<br/>'
          }
        ")
      ) %>%
      e_color(c("#5470C6", "#EE6666")) %>%
      e_timeline_opts(currentIndex=2)
  }

  output$pyramid1 <- renderEcharts4r({
    year_range<-range(pyramid_data()$year)
    get_pyramid(pyramid_data(),c(year_range[1],2023),year_range[1])
  })
  output$pyramid2 <- renderEcharts4r({
    year_range<-range(pyramid_data()$year)
    get_pyramid(pyramid_data(),c(2024,year_range[2]),year_range[1])
  })

  # 绘制年龄段人口趋势
  output$trend <- renderEcharts4r({
    if(input$trans_2==T){
      trend_data() %>%
        pivot_longer(cols = -1,names_to = 'age',names_prefix = 'x',values_to = 'pop') %>%
        group_by(year) %>%
        e_chart(age) |>
        e_line(pop) |>
        e_tooltip(trigger = 'axis') |>
        e_datazoom(type = "inside") |>
        e_datazoom(type = "slider") |>
        e_x_axis(type='category')
    } else {
      trend_data() %>%
        pivot_longer(cols = -c(1),names_to = 'age',values_to = 'pop') %>%
        group_by(age) %>%
        e_chart(year) |>
        e_line(pop) |>
        e_tooltip(trigger = 'axis') |>
        e_datazoom(type = "inside") |>
        e_datazoom(type = "slider") |>
        e_x_axis(type='category')
    }
  })

  # 显示数据表格
  color_map <- function(value) {
    if (is.numeric(value)) {
      color <- scales::col_numeric(
        palette = c("white", "blue"),
        domain = c(0, max(df[, -1], na.rm = TRUE))
      )(value)
      return(list(background = color))
    }
    return(NULL)
  }
  react_data<-reactive({
    if(input$trans==T) {
      trend_data() %>%
        pivot_longer(cols = -1,names_to = 'age') %>%
        pivot_wider(id_cols = age,names_from = year,names_prefix = 'y')
    } else {
      trend_data()
    }
  })
  output$data_table <- renderReactable({
    # 获取所有数值列
    numeric_cols <- names(react_data())[-1]

    # 计算所有数值列的全局最大最小值
    all_values <- unlist(react_data()[numeric_cols])
    global_min <- min(all_values, na.rm = TRUE)
    global_max <- max(all_values, na.rm = TRUE)

    # Create color scale function with new color scheme
    color_scale <- function(x) {
      normalized_value <- (x - global_min) / (global_max - global_min)
      rgb(colorRamp(c("#F1F8F7", "#9FE7DD", "#4ECDC4", "#45B7AF", "#2D8B85"))(normalized_value),
          maxColorValue = 255)
    }

    # Create style function for numeric columns
    style_numeric <- function(value) {
      color <- color_scale(value)
      list(
        background = color,
        color = if(mean(col2rgb(color)) < 180) "white" else "black"
      )
    }

    # Create column definitions
    col_defs <- lapply(names(react_data()), function(col) {
      if (col %in% numeric_cols) {
        colDef(
          style = style_numeric,
          format = colFormat(digits = 0)
        )
      } else {
        colDef()
      }
    })
    names(col_defs) <- names(react_data())

    reactable(
      react_data(),
      columns = col_defs,
      pagination = FALSE,
      filterable = FALSE,
      striped = FALSE,
      highlight = TRUE,
      compact = TRUE
    )
  })
  # Define the download handler for the CSV download
  output$download_data <- downloadHandler(
    filename = function() {
      paste("population_data_", input$country, ".csv", sep = "")
    },
    content = function(file) {
      write.csv(selected_data(), file, row.names = FALSE)  # Save the reactive data as CSV
    }
  )
}

shinyApp(ui, server)
