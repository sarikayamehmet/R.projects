rm(list=ls()) # ������� ��� ����������

library(ggplot2) #load first! (Wickham)
library(lubridate) #load second!
library(dplyr)
library(tidyr)
library(readr)
library(reshape2)
library(jsonlite)
library(magrittr)
library(curl)
library(httr)
library(ggthemes)
library(ggdendro) # ��� ������ ����
#library(ggmap)
library(RColorBrewer) # http://www.cookbook-r.com/Graphs/Colors_(ggplot2)/
library(scales)
library(gtable)
library(grid) # ��� grid.newpage()
library(gridExtra) # ��� grid.arrange()

getwd()
source("common_funcs.R") # ���� ������� ��� �������������� � ������������� �������

# main ================================================================

df <- get_weather_df(back_days = 7, forward_days = 3)

min_lim <- ceiling_date(min(df$timegroup), unit = "day")
max_lim <- floor_date(max(df$timegroup), unit = "day")
lims <- c(min_lim, max_lim)

# ������� �������� � json --------------------------------------------------------

# df2 <- data.frame(timestamp = round(as.numeric(outw.df$timegroup), 0), 
#                   air_temp_past = ifelse(outw.df$time.pos == "PAST", round(outw.df$temp, 1), NA),
#                   air_temp_future = ifelse(outw.df$time.pos == "FUTURE", round(outw.df$temp, 1), NA),
#                   air_humidity_past = ifelse(outw.df$time.pos == "PAST", round(outw.df$humidity, 1), NA),
#                   air_humidity_future = ifelse(outw.df$time.pos == "FUTURE", round(outw.df$humidity, 1), NA)) %>%
#   arrange(timestamp)

df3 <- with(df, {
  data.frame(timestamp = round(as.numeric(timegroup), 0), 
                  air_temp_past = ifelse(time.pos == "PAST", round(temp, 1), NA),
                  air_temp_future = ifelse(time.pos == "FUTURE", round(temp, 1), NA),
                  air_humidity_past = ifelse(time.pos == "PAST", round(humidity, 1), NA),
                  air_humidity_future = ifelse(time.pos == "FUTURE", round(humidity, 1), NA)) %>%
  arrange(timestamp)
})

# x <- jsonlite::toJSON(list(results = df3), pretty = TRUE)
# write(x, file="./export/real_weather.json")

# ��������� ��� ���� --------------------------------------------------------

# https://www.datacamp.com/community/tutorials/make-histogram-ggplot2
p1 <- ggplot(df, aes(timegroup, temp, colour = time.pos)) +
  # ggtitle("������ �����������") +
  # scale_fill_brewer(palette="Set1") +
  # scale_fill_brewer(palette = "Paired") +
  scale_color_manual(values = brewer.pal(n = 9, name = "Oranges")[c(3, 7)]) +
  # geom_ribbon(aes(ymin = temp.min, ymax = temp.max, fill = time.pos), alpha = 0.5) +
  # geom_point(shape = 1, size = 3) +
  # geom_line(lwd = 1, linetype = 'dashed', color = "red") +
  scale_x_datetime(labels = date_format("%d.%m %H:%M", tz = "Europe/Moscow"), 
                   breaks = date_breaks("1 days"), 
                   #minor_breaks = date_breaks("6 hours"),
                   limits = lims
  ) +
  geom_line(lwd = 1.2) +
  theme_igray() +
  theme(legend.position="none") +
  xlab("����") +
  ylab("�����������,\n����. C")

## brewer.pal.info
p2 <- ggplot(df, aes(timegroup, humidity, colour = time.pos)) +
  # ggtitle("������ �����������") +
  # scale_fill_brewer(palette="Set1") +
  # scale_fill_brewer(palette = "Paired") +
  # scale_color_brewer(palette = "Purples") +
  # scale_color_manual(values = brewer.pal(n = 3, name = "Spectral")) +
  scale_color_manual(values = brewer.pal(n = 9, name = "Blues")[c(4, 7)]) +
  # scale_color_viridis(discrete=TRUE) +
  # geom_ribbon(aes(ymin = temp.min, ymax = temp.max, fill = time.pos), alpha = 0.5) +
  # geom_point(shape = 1, size = 3) +
  # geom_line(lwd = 1, linetype = 'dashed', color = "red") +
  scale_x_datetime(labels = date_format("%d.%m %H:%M", tz = "Europe/Moscow"), 
                   breaks = date_breaks("1 days"), 
                   #minor_breaks = date_breaks("6 hours"),
                   limits = lims
  ) +
  geom_line(lwd = 1.2) +
  theme_igray() +
  theme(legend.position="none") +
  ylim(0, 100) +
  xlab("����") +
  ylab("���������\n�������, %")


# ������ � ������������ ������ �� ������� (������� � �������) =====================================
weather.df <- prepare_raw_weather_data()
df2 <- calc_rain_per_date(weather.df) %>%
  filter(timestamp >= floor_date(now() - days(7), unit = "day")) %>%
  filter(timestamp <= ceiling_date(now() + days(3), unit = "day")) %>%
  bind_rows(data.frame(date = as.Date(min(df$timegroup)), rain = 0, timestamp = NA))


# http://moderndata.plot.ly/create-colorful-graphs-in-r-with-rcolorbrewer-and-plotly/
plot_palette <- brewer.pal(n = 8, name = "Paired")

p3 <- ggplot(df2, aes(date, rain)) +
  # ggtitle("������ �����������") +
  # scale_fill_brewer(palette="Set1") +
  # scale_fill_brewer(palette = "Paired") +
  # scale_color_brewer(palette = "Set2") +
  # geom_bar(fill = brewer.pal(n = 11, name = "Spectral")[5], alpha = 0.5, stat="identity") +
  geom_bar(fill = brewer.pal(n = 9, name = "Blues")[4], alpha = 0.5, stat="identity") +
  # geom_ribbon(aes(ymin = temp.min, ymax = temp.max, fill = time.pos), alpha = 0.5) +
  # geom_point(shape = 1, size = 3) +
  # geom_line(lwd = 1, linetype = 'dashed', color = "red") +
  scale_x_date(labels = date_format("%d.%m", tz = "Europe/Moscow"), 
               breaks = date_breaks("1 days"),
               limits = as.Date(lims, tz = "Europe/Moscow")
               ) +
  # geom_line(lwd = 1.2) +
  theme_igray() +
  theme(legend.position="none") +
  ylim(0, NA) +
  xlab("����") +
  ylab("������\n(�����), ��")

# grid.arrange(p1, p2, p3, ncol = 1) # ���������� ggplot
grid.newpage()
grid.draw(rbind(ggplotGrob(p1), ggplotGrob(p2), ggplotGrob(p3), size = "first"))
