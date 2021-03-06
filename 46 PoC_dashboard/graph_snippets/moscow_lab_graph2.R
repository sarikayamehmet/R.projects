# ������������ ��������� ������� ��� ������� (��������������� ������ ��������� + �����������)
#library(tidyr)
library(ggplot2) #load first! (Wickham)
library(lubridate) #load second!
library(dplyr)
library(tidyr)
library(readr)
library(jsonlite)
library(magrittr)
#library(httr)
library(ggthemes)
library(wesanderson) # https://github.com/karthik/wesanderson
#library(ggmap)
library(RColorBrewer) # http://www.cookbook-r.com/Graphs/Colors_(ggplot2)/
library(scales)
library(gtable)
library(grid) # ��� grid.newpage()
library(gridExtra) # ��� grid.arrange()
library(curl)
#library(KernSmooth)
#library(akima)
#library(rdrop2)
#library(rgl)
library(arules)
library(futile.logger)


# source("common_funcs.R", encoding = 'UTF-8') 
# ��� ������ source
# How to source() .R file saved using UTF-8 encoding?
# http://stackoverflow.com/questions/5031630/how-to-source-r-file-saved-using-utf-8-encoding
eval(parse("common_funcs.R", encoding = "UTF-8")) # ���� ������� ��� �������������� � ������������� �������

# main() ===================================================

df <- get_github_field2_data()
if (!is.na(df)) { raw.df <- df}
# .Last.value

06.06 - 18.06

timeframe <- get_timeframe(days_back = 17, days_forward = 0)
p2 <- plot_github_ts4_data(df, timeframe, tbin = 0.5, expand_y = TRUE)

benchplot(p2)
p2



stop()

# ���� �������� �������������� �������
# �������� ���������� �� ��������� �������, ���� ��������� ����������� ��������� ��� � ������� ����� �������
# ��������� ������ �� ������� ��������

# ����������� �� ��������� ����������
# � ������ ��� ������ � NA. ��-�� �������� ������ ��������� ������ ������
# [filter for complete cases in data.frame using dplyr (case-wise deletion)](http://stackoverflow.com/questions/22353633/filter-for-complete-cases-in-data-frame-using-dplyr-case-wise-deletion)
raw.df <- raw.df %>%
  filter(complete.cases(.)) %>%
  mutate(timegroup = hgroup.enum(timestamp, time.bin = 0.5))
  
  
avg.df <- raw.df %>%
  filter(work.status) %>%
  group_by(location, name, timegroup) %>%
  summarise(value.mean = mean(value), value.sd = sd(value)) %>%
  ungroup() # �������� �����������

plot_palette <- brewer.pal(n = 5, name = "Blues")
plot_palette <- wes_palette(name="Moonrise2") # https://github.com/karthik/wesanderson

# levs <- list(step = c(1700, 2210, 2270, 2330, 2390, 2450, 2510), 
#              category = c('WET++', 'WET+', 'WET', 'NORM', 'DRY', 'DRY+', ''))

levs <- get_moisture_levels()
# ����� ������ ����� �����������, ���������� ����������� �����������
df.label <- data.frame(x = min(avg.df$timegroup),
                       y = head(levs$category, -1) + diff(levs$category)/2, # ��������� �������, ������������ -1 ��������� 
                       text = levs$labels)

# -----------------------------------------------------------
# http://www.cookbook-r.com/Graphs/Shapes_and_line_types/
p2 <- ggplot(avg.df, aes(x = timegroup, y = value.mean)) + 
  # http://www.sthda.com/english/wiki/ggplot2-colors-how-to-change-colors-automatically-and-manually
  scale_fill_brewer(palette="Dark2", direction = -1, guide = FALSE) +
  scale_color_brewer(palette="Dark2", direction = -1, name = "������", guide = guide_legend(reverse = FALSE, fill = FALSE)) + 
  
  # scale_fill_manual(values = plot_palette, guide = FALSE) + # ������� �� ���������� ���������
  # scale_color_manual(values = plot_palette, name = "������", guide = guide_legend(reverse = FALSE, fill = FALSE)) +
  
  #scale_fill_manual(values=c("#999999", "#E69F00", "#56B4E9")) +
  # ������ ����������� ��������
  
  # geom_ribbon(aes(x = timegroup, ymin = 70, ymax = 90), linetype = 'blank', fill = "olivedrab3", alpha = 0.4) +
  geom_ribbon(aes(ymin = levs$category[levs$labels == 'NORM'], ymax = levs$category[levs$labels == 'DRY']), 
              linetype = 'blank', fill = "olivedrab3", alpha = 0.4) +
  geom_ribbon(
    aes(ymin = value.mean - value.sd, ymax = value.mean + value.sd, fill = name),
    alpha = 0.3
  ) +
  geom_line(aes(colour = name), lwd = 1.2) +
  # ����� ����� ������
  # geom_point(data = raw.df, aes(x = timestamp, y = value, colour = name), shape = 1, size = 2) +
  geom_point(aes(colour = name), shape = 19, size = 3) + # ����������� �����
  geom_hline(yintercept = levs$category, lwd = 1, linetype = 'dashed') +
  scale_x_datetime(labels = date_format(format = "%d.%m", tz = "Europe/Moscow"),
                   breaks = date_breaks('12 hour') 
                   # minor_breaks = date_breaks('1 hour')
  ) +
  # ��������� ��������� �������
  # geom_point(data = raw.df %>% filter(!work.status), aes(x = timegroup, y = value), 
  #            size = 3, shape = 21, stroke = 0, colour = 'red', fill = 'yellow') +
  # geom_point(data = raw.df %>% filter(!work.status), aes(x = timegroup, y = value), 
  #            size = 3, shape = 13, stroke = 1.1, colour = 'red') +
  
  #theme_igray() +
  geom_label(data = df.label, aes(x = x, y = y, label = text)) +
  # scale_colour_tableau("colorblind10", name = "���������\n�����") +
  # scale_color_brewer(palette = "Set2", name = "���������\n�����") +
  # scale_y_reverse(limits = c(head(levs$step, 1), tail(levs$step, 1))) +
  scale_y_reverse(limits = c(tail(levs$category, 1), head(levs$category, 1))) +
  xlab("����� � ���� ���������") +
  ylab("��������� �����") +
  # theme_solarized() +
  # scale_colour_solarized("blue") +
  # theme(legend.position=c(0.5, .2)) +
  theme(legend.position = "top") +
  # theme(axis.text.x = element_text(angle = 0, hjust = 0.5, vjust = 0.5)) +
  # theme(axis.text.y = element_text(angle = 0)) +
  # ������ �������, ��. stackoverflow.com/questions/21066077/remove-fill-around-legend-key-in-ggplot
  guides(color = guide_legend(override.aes = list(fill = NA)))

benchplot(p2)
p2

