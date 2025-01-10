library(tidyverse)
library(rio)
library(echarts4r)
library(openxlsx)
library(janitor)
library(shiny)
library(bslib)

# df_pre_2023<-read.xlsx("data/WPP2024_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES.xlsx",sheet=1)
# df_pos_2023<-read.xlsx("data/WPP2024_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES.xlsx",sheet=2)
#
# names(df_pre_2023)<-df_pre_2023[10,]
# df_pre_2023<-df_pre_2023[-(1:10),] %>% clean_names()
#
# names(df_pos_2023)<-df_pos_2023[10,]
# df_pos_2023<-df_pos_2023[-(1:10),] %>% clean_names()
#
# df_pop<-bind_rows(pre_2023=df_pre_2023,pos_2023=df_pos_2023,.id = 'from') %>%
#   mutate(year=as.integer(year))
#
# export(df_pop,'data/df_pop.rds')
# export(df_pop,'data/df_pop.xlsx')
# export(df_pop,'data/df_pop.csv')
# export(df_pop,'data/df_pop.json')

df_pop<-import('data/df_pop.rds')

# df_pop_un_2019<-df_pop %>%
#   filter(year==2019,type=='Country/Area') %>%
#   select(year,region_subregion_country_or_area,type,x0,x1,x2,x3,x4,x5) %>%
#   mutate(across(starts_with('x'),~round(as.numeric(.x))))

getByCountry<-function(area){
  df_pop %>%
    filter(region_subregion_country_or_area==area) %>%
    select(year,region_subregion_country_or_area,x0:x100) %>%
    mutate(across(starts_with('x'),~round(as.numeric(.x))))
}
df_china<-getByCountry('China')
names(df_pop)

e<-e_chart(df_china,year) %>%
  e_line(x0,name = 'x0') %>%
  e_line(x1,name = 'x1') %>%
  e_line(x2,name = 'x2') %>%
  e_line(x3,name = 'x3') %>%
  e_line(x4,name = 'x4') %>%
  e_line(x16,name = 'x16') %>%
  e_line(x17,name = 'x17') %>%
  e_line(x18,name = 'x18') %>%
  e_line(x25,name = 'x25') %>%
  e_line(x26,name = 'x26') %>%
  e_line(x27,name = 'x27') %>%
  e_line(x28,name = 'x28') %>%
  e_line(x29,name = 'x29') %>%
  e_line(x30,name = 'x30') %>%
  e_tooltip(trigger = 'axis') %>%
  e_datazoom()

df_china %>%
  pivot_longer(cols = c(4:6),names_to = 'age',values_to = 'pop') %>%
  group_by(age) %>%
  e_chart(year) |>
  e_line(pop) |>
  e_tooltip(trigger = 'axis') |>
  e_datazoom(type = "inside") |>
  e_datazoom(type = "slider") |>
  e_x_axis(type='category') |>
  e_mark_line(
    data = list(
      xAxis = 2023
    )
  )

df_china[,-2] %>%
  pivot_longer(cols = -1,names_to = 'age') %>%
  pivot_wider(id_cols = age,names_from = year,names_prefix = 'y')



df_china %>%
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
  na.omit() %>%
  group_by(year) %>%
  e_charts(age,timeline =T) %>%
  e_bar(male, name = "男性", barWidth = "90%", barGap = "-100%") %>%
  e_bar(female, name = "女性", barWidth = "90%") %>%
  e_flip_coords()

