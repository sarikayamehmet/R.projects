# rm(list=ls()) # ������� ��� ����������

library(dplyr)
library(magrittr)
library(ggplot2) #load first! (Wickham)
library(lubridate) #load second!
library(scales)
library(readr) #Hadley Wickham, http://blog.rstudio.org/2015/04/09/readr-0-1-0/
library(sp)       # spatial operations library
library(leaflet)
library(KernSmooth)
library(akima)
library(rgl)
library(RColorBrewer)

options(warn=1) # http://stackoverflow.com/questions/11239428/how-to-change-warn-setting-in-r
# options(viewer = NULL) # send output directly to browser


load_sensors_list <- function() {
  ifilename <- ".\\data\\sensors_zoo.csv"
  ifilename <- ".\\data\\sensors_calc.csv"
  ifilename <- ".\\data\\sensors_manual.csv"
  # ���������� ������ �� ��������
  s.df <- read_delim(ifilename, delim = ",", quote = "\"",
                       col_names = TRUE,
                       locale = locale("ru", encoding = "windows-1251", tz = "Europe/Moscow"), # ��������, � ��������, ����� ���������� �����
                       # col_types = list(date = col_datetime(format = "%d.%m.%Y %H:%M")), 
                       progress = interactive()
  ) # http://barryrowlingson.github.io/hadleyverse/#5
  
  ## Load the sensor positions.
  # s.df <- read.csv(ifilename, header=T, stringsAsFactors = FALSE)
  # ������ ������ ���� � ������� data.frame
  # ����� SpatialPointsDataFrame ��������: unable to find an inherited method 
  # for function �coordinates� for signature �"tbl_df"�
  
  s.df <- as.data.frame(s.df)
  # ������� ������� �������������. ��������� ��� �������� ��������� ������� ��������
  s.df$val <- runif(nrow(s.df), 10, 90) # ���������� ��������� � ���������
  
  s.df
}

mydata <- load_sensors_list()

plot_GIS_map <- function(){
  # ������� ���� ������������� � Spatial Data
  # 1. ���������� CRS
  dCRS <- CRS("+init=epsg:4326")
  # http://www.r-tutor.com/r-introduction/data-frame/data-frame-column-slice
  mydataSp <-
    SpatialPointsDataFrame(mydata[c('lon', 'lat')], mydata, proj4string = dCRS)
  
  # plot spatial object
  plot(mydataSp, main = '������� �� ����')
  
  
  
  # =================== leaflet ==================
  # ��� leaflet ������������� ������ � Spatial Objects
  #build the map without "pipes"
  # m <- leaflet(mydata, base.map="osm") #setup map
  m <- leaflet(mydata) %>% #setup map
    addTiles() %>% #add open street map data
    setView(lng = 37.58, lat = 55.76, zoom = 15) %>%
    addMarkers(lng = ~ lon, lat = ~ lat)
  # map$tileLayer(provider = 'Stamen.Watercolor') # https://github.com/ramnathv/rMaps
  #m$tileLayer(provider = 'Stamen.Watercolor')
  
  #m <- addCircleMarkers(radius = ~size, color = ~color, fill = FALSE)
  # ����� ����������� ������� � �.�. �����: http://leaflet-extras.github.io/leaflet-providers/preview/
  # m <- addProviderTiles(m, "CartoDB.Positron")
  #m <- addProviderTiles(m, "Stamen.Watercolor")
  # m <- addProviderTiles(m, "OpenWeatherMap.RainClassic")
  
  m
}
# =============================================
# ��� ����������� ��������� ���������� ������������� �������
# https://github.com/dkahle/ggmap
# www.unomaha.edu/mahbubulmajumder/data-science/fall-2014/lectures/06-display-spatial-data/06-display-spatial-data.html

library(ggmap)

fmap <-
  get_map(
    enc2utf8("������, ������������� 2"),
    language = "ru-RU",
    # source = "stamen", maptype = "watercolor", 
    # source = "stamen", maptype = "toner-hybrid",
    source = "stamen", maptype = "toner-2011",
    # source = "stamen", maptype = "toner-lite",
    # source = "google", maptype = "terrain",
    # source = "osm", maptype = "terrain-background",
    # source = "google", maptype = "hybrid",
    zoom = 16
  )
ggmap(fmap, extent = "normal", legend = "topleft")

mydata$val <- runif(nrow(mydata), 30, 80) # ���������� ��������� � ���������

# ������ ������ ����, ����� �� ���� ������� ��������� ������������� ��������� 
# �� ��������� �������������� ������� � ����������� ��������� ���������. (�� ��� �� ��������)
local({
  dlon <- (max(mydata$lon) - min(mydata$lon)) * 0.2
  dlat <- (max(mydata$lat) - min(mydata$lat)) * 0.2
  
  hdata <- data.frame(expand.grid(
    lon = seq(min(mydata$lon) - dlon, max(mydata$lon) + dlon, length = 10),
    lat = c(min(mydata$lat) - dlat, max(mydata$lat) + dlat),
    val = min(mydata$val)
  ))
  
  vdata <- data.frame(expand.grid(
    lon = c(min(mydata$lon) - dlon, max(mydata$lon) + dlon),
    lat = seq(min(mydata$lat) - dlat, max(mydata$lat) + dlat, length = 10),
    val = min(mydata$val)
  ))
})

# ������� �������� �� ������� �������������� ����������� �����
hdata <- data.frame(expand.grid(
  lon = seq(attr(fmap,"bb")$ll.lon, attr(fmap,"bb")$ur.lon, length = 10),
  lat = c(attr(fmap,"bb")$ll.lat, attr(fmap,"bb")$ur.lat),
  val = min(mydata$val)
))

vdata <- data.frame(expand.grid(
  lon = c(attr(fmap,"bb")$ll.lon, attr(fmap,"bb")$ur.lon),
  lat = seq(attr(fmap,"bb")$ll.lat, attr(fmap,"bb")$ur.lat, length = 10),
  val = min(mydata$val)
))


tdata <- rbind(mydata, hdata, vdata)
# mydata <- tdata
# ������ ������� ������� ��� ����������� �������
# ����� ���� ������: http://stackoverflow.com/questions/24410292/how-to-improve-interp-with-akima
# � ������: http://www.kevjohnson.org/making-maps-in-r-part-2/
fld <- interp(tdata$lon, tdata$lat, tdata$val,
              xo = seq(min(tdata$lon), max(tdata$lon), length = 20),
              yo = seq(min(tdata$lat), max(tdata$lat), length = 20),
              duplicate = "mean", # ��������� ��������� �� ����� ������������� ��������������
              #linear = TRUE, #FALSE (����� ����, ��� �������� ������� �������������, �����)
              linear = FALSE,
              extrap = TRUE)

# ���������� � ������� �������� ��� ���������� (x, y)
# �������� ����������� ����, ��������� (x, y) 
# ������� ��� �������� ������ ��������� -- ������� x �������������� �� ������������� y, ��� ��� ��������
dInterp <- data.frame(expand.grid(x = fld$x, y = fld$y), z = c(fld$z)) 
# ��� ������������� ���������, 
# � ������ ������ ����������� ������ ����� ���� ������ �� ������� ������� ���������������
# dInterp$z[dInterp$z < min(mydata$val)] <- min(mydata$val)
# dInterp$z[dInterp$z > max(mydata$val)] <- max(mydata$val)
dInterp$z[is.nan(dInterp$z)] <- min(mydata$val)


tt <- fld$z
# http://stackoverflow.com/questions/32679844/r-isotherms-as-isolines-using-ggplot2

#filter(dInterp, z<0)
ggplot(data = mydata) +
  geom_tile(data = dInterp, aes(x, y, fill = z), alpha = 0.5, colour = NA) +
  # geom_raster(data = dInterp, aes(x, y, fill = z), alpha = 0.5) + 
  # theme(legend.position = "top") +
  scale_fill_distiller(palette = "Spectral") + #color -- ���� �����
  stat_contour(data = dInterp, aes(x, y, z = z), bins = 4, color="black", size=0.5) +
  geom_point(size = 4, alpha = 1/2, aes(x = lon, y = lat), color = "red") +
  geom_text(aes(lon, lat, label = round(val, digits = 1)), hjust = 0.5, vjust = -1) +
  theme_bw()



mm <- ggmap(fmap, extent = "normal", legend = "topleft") +
  # geom_raster(data = dInterp, aes(x, y, fill = z), alpha = 0.5) + 
  geom_tile(data = dInterp, aes(x, y, fill = z), alpha = 0.5, colour = NA) +
  # theme(legend.position = "top") +
  scale_fill_distiller(palette = "Spectral") + #color -- ���� �����
  stat_contour(data = dInterp, aes(x, y, z = z), bins = 4, color="white", size=0.5) +
  geom_point(data = mydata, size = 4, alpha = 1/2, aes(x = lon, y = lat), color = "red") +
  geom_text(data = mydata, aes(lon, lat, label = round(val, digits = 1)), hjust = 0.5, vjust = -1) +
  theme_bw() +
  theme(axis.line=element_blank(),
        axis.text.x=element_blank(),
        axis.text.y=element_blank(),
        axis.ticks=element_blank(),
        axis.title.x=element_blank(),
        axis.title.y=element_blank(),
        legend.position="none",
        panel.background=element_blank(),
        panel.border=element_blank(),
        panel.grid.major=element_blank(),
        panel.grid.minor=element_blank(),
        plot.background=element_blank())

# mm


cfpalette <- colorRampPalette(c("white", "blue"))

                               
# � ������ ��������� ���������� �������, ������� ��� ������������� ��������
# �������� ������ ������� �����: https://groups.google.com/forum/embed/#!topic/ggplot2/nqzBX22MeAQ
mm3 <- ggmap(fmap, extent = "normal", legend = "topleft") +
  geom_raster(data = dInterp, aes(x, y, fill = z), alpha = 0.5) +
  coord_cartesian() +
  # scale_fill_distiller(palette = "Spectral") + # http://docs.ggplot2.org/current/scale_brewer.html
  # scale_fill_distiller(palette = "YlOrRd", breaks = pretty_breaks(n = 10))+ #, labels = percent) +
  # scale_fill_gradientn(colours = brewer.pal(9,"YlOrRd"), guide="colorbar") +
  scale_fill_gradientn(colours = c("#FFFFFF", "#FFFFFF", "#FFFFFF", "#0571B0", "#1A9641", "#D7191C"), 
                       limits = c(0, 100), breaks = c(25, 40, 55, 70, 85), guide="colorbar") +
  # scale_fill_manual(values=c("#CC6666", "#9999CC", "#66CC99")) + # ������� -- �����
  stat_contour(data = dInterp, aes(x, y, z = z), bins = 4, color="white", size=0.5) +
  geom_point(data = mydata, size = 4, alpha = 1/2, aes(x = lon, y = lat), color = "red") +
  geom_text(data = mydata, aes(lon, lat, label = round(val, digits = 1)), hjust = 0.5, vjust = -1) +
  theme_bw()

mm3
stop()

start.time <- Sys.time()
# ggsave("plot.png", mm, width = 200, height = 200, units = "mm", dpi = 300)
print(paste0("����� ������ ", 
             round(as.numeric(difftime(Sys.time(), start.time, unit = "sec")), digits = 0), 
             " ���"))



# ======================
# Google Maps Geocoding API Usage Limits(https://developers.google.com/maps/documentation/geocoding/usage-limits)
# Users of the standard API: 2,500 free requests per day; 10 requests per second 

tile_map <-
  get_map(
    enc2utf8("������, ������������� 2"),
    language = "ru-RU",
    maptype = "terrain",
    zoom = 16
  )

ggmap(tile_map)

mm2 <- ggmap(tile_map, extent = "normal", legend = "topleft") +
  #geom_tile(data = dInterp, aes(x, y, fill = z), alpha = 0.5) +
  geom_raster(data = dInterp, aes(x, y, fill = z), alpha = 0.5) + 
  coord_cartesian() +
  # scale_fill_distiller(palette = "Spectral") + #color -- ���� �����
  geom_point(data = mydata, size = 4, alpha = 1/2, aes(x = lon, y = lat), color = "red") +
  geom_text(data = mydata, aes(lon, lat, label = round(val, digits = 1)), hjust = 0.5, vjust = -1) +
  theme_bw()


mm2

start.time <- Sys.time()
ggsave("plot2.png", mm2, width = 200, height = 200, units = "mm", dpi = 300)
print(paste0("����� ������ ", 
             round(as.numeric(difftime(Sys.time(), start.time, unit = "sec")), digits = 0), 
             " ���"))

stop()

us <- c(left = -125, bottom = 25.75, right = -67, top = 49)
map <- get_stamenmap(us, zoom = 5, maptype = "toner-lite")
ggmap(map)
downtown <- subset(crime,
                   -95.39681 <= lon & lon <= -95.34188 &
                     29.73631 <= lat & lat <=  29.78400
)

qmplot(lon, lat, data = downtown, maptype = "toner-background", color = I("red"))
stop()
# =============================================
# ������ �� �����, ����� ���� ������: http://stackoverflow.com/questions/24410292/how-to-improve-interp-with-akima

fld <- with(mydata, interp(lon, lat, val,
    xo = seq(min(lon), max(lon), length = 500),
    yo = seq(min(lat), max(lat), length = 500), 
    linear = FALSE, 
    extrap = TRUE
  )) # http://www.statmethods.net/stats/withby.html

filled.contour(x=fld$x, y=fld$y, z=fld$z,
               color.palette=colorRampPalette(c("white", "blue")))

stop()
# =============================================
# http://docs.ggplot2.org/0.9.3.1/stat_contour.html
# Basic plot
v <- ggplot(mydata, aes(x = lon, y = lat, z = val))
# v + stat_contour(bins = 5)
v

qplot(lon, lat, z = val, data = mydata, geom = "contour")

stop()
# =============================================

s <-  interp(mydata$lon, mydata$lat, mydata$val, linear = FALSE, extrap = TRUE) #from akima
# If linear is TRUE (default), linear interpolation is used in the triangles bounded by data points.
# Cubic interpolation is done if linear is set to FALSE. If extrap is FALSE, z-values for points outside
# the convex hull are returned as NA. No extrapolation can be performed for the linear case.
mm <- s$z
# contour(s$x, s$y, s$z)
contour(s)

CL <- contourLines(s$x, s$y, s$z, nlevels = 9)
# nlevels ��������� ���������, �� ������� ������� ����� ���� ������ (��������� ���)


# http://technocyclist.blogspot.ru/2014/10/plot-contour-polygons-in-leaflet-using-r.html
# Create linestrings
lines <- contourLines(s$x, s$y, s$z, nlevels = 9)
# Create independent polygons within a list
dd1 <- sapply(1:length(lines), function(i) Polygon(as.matrix(cbind(lines[[i]]$x, lines[[i]]$y))))
# Merge all independent polygons into a Polygons object (this contains multiple polygons)
dd2 <- sapply(1:length(lines), function(i) Polygons(list(dd1[[i]]), i))
# Don't forget to remember the contour value for each polygon - we store it into a dataframe for use in the next step
poly_data <- data.frame(Value = sapply(1:length(lines), function(i) lines[[i]]$level))
# Merge the Polygons object dd2 with the dataframe containing the contour level data, poly_data.
dd3 <- SpatialPolygonsDataFrame(SpatialPolygons(dd2), data = poly_data)

# Convert our dd3 SpatialPolygonDataFrame object to JSON
dd_json <- toGeoJSON(dd3, name="MelbourneTree")
# Store the unique levels of the contours, this will come in handy for colouring
values <- unique(sapply(1:length(lines), function(i) lines[[i]]$level))

# Create a style for the Leaflet map
sty <- styleCat(prop="Value", val=values, style.val=brewer.pal(length(values),"Greens"), leg = "Tree Cover")

m <- leaflet() %>% addTiles() %>%
  # setView(lng = 37.58, lat = 55.76, zoom = 14) %>%
  addPolygons(CL[[1]]$x,CL[[1]]$y,fillColor = "red", stroke = FALSE) %>%
  addPolygons(CL[[3]]$x,CL[[3]]$y,fillColor = "green", stroke = FALSE) %>%
  addPolygons(CL[[5]]$x,CL[[5]]$y,fillColor = "blue", stroke = FALSE) %>%
  addPolygons(CL[[7]]$x,CL[[7]]$y,fillColor = "red", stroke = FALSE) %>%
  addPolygons(CL[[9]]$x,CL[[9]]$y,fillColor = "red", stroke = FALSE)

w <- s$z

m

stop()
# =============================================
# http://freakonometrics.hypotheses.org/19473
# http://gis.stackexchange.com/questions/168886/r-how-to-build-heatmap-with-the-leaflet-package
X <- mydata[c("lat", "lon")]
# bw.ucv -- Bandwidth Selectors for Kernel Density Estimation
kde2d <- bkde2D(X, bandwidth = c(bw.ucv(X[,1]), bw.ucv(X[,2])))
# bkde2d �� ����� �������, ��������� ��� density estimate

t <- kde2d$fhat

contour(x=kde2d$x1, y=kde2d$x2, z=kde2d$fhat)
stop()
data(quakes)

