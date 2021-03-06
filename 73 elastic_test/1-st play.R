library(tidyverse)
library(tibble)
library(purrr)
library(magrittr)
library(data.tree)
library(rlist)
library(reshape2)
library(pipeR)
library(jsonlite)
library(tidyjson)
library(elastic)
library(parsedate)
library(fasttime)
library(anytime)
library(microbenchmark)

# ����� �� �������� ������� �� �������� ������� ----------------------------
tm <- "2017-05-04T13:55:00.302Z"
anytime(tm, tz="Europe/Moscow")
fastPOSIXct(tm) # �� 5-10% ���������
parse_date(tm) # �� 2 ������� ���������

microbenchmark(anytime(tm, tz="Europe/Moscow"), times=1000, unit="us")
microbenchmark(fastPOSIXct(tm), times=1000, unit="us")
microbenchmark(parse_date(tm), times=1000, unit="us")
# ----------------------------

connect(es_host="89.223.29.108", es_port = 9200)
info() # ���������� ���������� ��� ����������

t1 <- cat_indices(parse=TRUE) # �������� ������ ��������
t2 <- cat_indices(verbose=TRUE, "?format=json&pretty") # ��� ��������, �� JSON ������ �� �����
t3 <- capture.output(cat_indices(verbose=FALSE, "?format=json&pretty")) # ����������� ������ ���� ������ ��������
t4 <- cat_indices(parse=TRUE, "?format=json&pretty") # ��� �� �������, ������ ���������� � data.frame

# ������� ������� � ��������
# http://89.223.29.108:9200/_cat/indices?v

m <- Search(index="packetbeat-*", size=100)$hits$hits


# ------------ ������ ������� ���������� ���� �� source.ip �� �������� ���������� �������

# https://www.elastic.co/guide/en/elasticsearch/reference/5.3/common-options.html#date-math
body <- list(query=list(range=list(start_time=list(gte="now-1d/d", lte="now"))))
Search(index="packetbeat-*", body=body)$hits$total
m <- Search(index="packetbeat-*", body=body)$hits$hits # �������� ������ 10 ��������� ������ Total=129k (default size=10)

# ------------- ����� ������ ������ ����� ��������� json

# ��� �������� ����� ����� ����������� (>10K, ���� ������ scroll)
body <- '{
  "query": {
    "bool": {
      "must": [ 
        {"match": { "source.ip": "10.0.0.232"}} 
      ],
      "filter":  [
        { "range": { "start_time": { "gte": "now-1d", "lte": "now" }}}
      ] 
    }
  }
}'
Search(index="packetbeat-*", body=body, source="source.stats.net_bytes_total")$hits$total
# ������� ������ ������������ ����, �������� ����� ������ ���� �� ������
m <- Search(index="packetbeat-*", body=body, size=10000, sort="source.stats.net_bytes_total:desc",
            source="start_time,source.port,source.ip,source.stats.net_bytes_total")$hits$hits



# --------------------------------------------------------------------------
# ������ scroll, ����� �������� ��� ��������, ������ ����� JSON ------------
body <- '{
  "query": {
    "bool": {
      "must": [ 
        {"match": { "source.ip": "10.0.0.232"}} 
      ],
      "filter":  [
        { "range": { "start_time": { "gte": "now-1d", "lte": "now" }}}
      ] 
    }
  }
}'

# ���� �������������� ������ size ������ �� ����������� ������� ���������� �������� + �������
req_size <- 1000
res <- Search(index="packetbeat-*", body=body, scroll="1m", size=req_size)

# �������� �� ����� ������ � ����� ������
res$hits$total
#length(scroll(scroll_id = res$`_scroll_id`)$hits$hits)
req_list <- seq(from=1, by=1, length.out=res$hits$total/req_size)

scroll_json <- scroll(scroll_id = res$`_scroll_id`, raw=TRUE, size=req_size)
lres_df <- jsonlite::fromJSON(scroll_json, simplifyDataFrame=TRUE)
m <- lres_df$hits$hits

# jsonlite::prettify(scroll_res)

# http://stackoverflow.com/questions/35198991/tidyjson-is-there-an-exit-object-equivalent
# ������ � ��� ����
df <-
  scroll_json %>% enter_object("hits") %>% enter_object("hits") %>%
  gather_array %>% enter_object("_source") %>%
  spread_values(
    start_time=jstring("start_time")
    ) %>%
  enter_object("source") %>%
  spread_values(
    src_ip=jstring("ip"),
    src_port=jnumber("port")
    ) %>%
  enter_object("stats") %>%
  spread_values(
    bytes_total=jnumber("net_bytes_total")
  ) %>%
  select(-document.id)


df

# then enter an object and get something from inside, merging it as a new column
df <- merge(df, 
            scroll_json %>% enter_object("hits") %>% enter_object("hits") %>%
              gather_array %>% 
              enter_object("_source") %>%
              enter_object("dest") %>%
              spread_values(
                dst_ip=jstring("ip"),
                dst_port=jnumber("port")
              ) %>% select(-document.id),
              by = c('array.index'))

df

# ������ scroll, ����� �������� ��� ��������, �������� ������� ����� ������ ------------- 
body <- '{
  "query": {
    "bool": {
      "must": [ 
        {"match": { "source.ip": "10.0.0.232"}} 
      ],
      "filter":  [
        { "range": { "start_time": { "gte": "now-1d", "lte": "now" }}}
      ] 
    }
  }
}'

# ���� �������������� ������ size ������ �� ����������� ������� ���������� �������� + �������
req_size <- 2
res <- Search(index="packetbeat-*", body=body, scroll="1m", size=req_size)
m <- res$hits$hits


jl <- as.Node(m)
list.names(m)
rl <- list.select(m, type=`_type`, timestamp=`_source`$`@timestamp`) # ��� ��������� � ������� rlist
rl <- list.select(m, start_time=`_source`$`start_time`, 
                  src_ip=`_source`$source$ip,
                  src_port=`_source`$source$port,
                  bytes_sent=`_source`$source$stats$net_bytes_total) # ��� ��������� � ������� rlist

# df <- list.stack(rl) # ������ ������, ���� ���� NULL: Error in data.table::rbindlist(.data, ...) : Column 3 of item 1 is length 0, inconsistent 

rl2 <- map(rl, function(x){str(x); cat("--"); map(x, function(z) ifelse(is.null(z), NA, z))})

dplyr::bind_rows(rl) # ����� ��� ����� NULL, �� ��� �����������
dplyr::bind_rows(rl2) # ����� ��� ����� NULL, �� ��� �����������
# melt(rl) # ����� � ��� + gather

map_val_list <- list(c("start_time", "start_time"),
                     c("src_port", "source$port"))

# ��. ������� get_tsdf_from_SW_json
df <- map(m, 
          function(x){
            str(x)
            tibble(start_time=x$`_source`$start_time,
                   src_port=x$`_source`$source$port)
          }
          )

# ���� ����������� �� ����� ������, ������� ������ ��������� � ������������ �� �� ���� data.frame) 

# �������� �� ����� ������ � ����� ������
res$hits$total
length(scroll(scroll_id = res$`_scroll_id`)$hits$hits)
req_list <- seq(from=1, by=1, length.out=res$hits$total/req_size)


processScroll <- function(n){
  cat("iteration", n, "\n")
}
  
# ��������� ��� �������
df <- req_list %>%
  purrr::map_df(processScroll, .id = NULL)

# ========
Search(index="packetbeat-*", body=body)$hits$total
m <- Search(index="packetbeat-*", body=body)$hits$hits # �������� ������ 10 ��������� ������ Total=129k (default size=10)



body <-
  list(query = list(range = list(start_time = list(
    gte = "now-1d/d", 
    lte = "now"
  ))))
