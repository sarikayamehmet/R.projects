rm(list=ls()) # ������� ��� ����������
library(ggplot2) #load first! (Wickham)
library(lubridate) #load second!
library(dplyr)
library(tidyr)
library(tibble)
library(readr)
library(stringi)
library(stringr)
library(purrr)
library(jsonlite)
library(magrittr)
library(curl)
library(httr)
library(jsonlite)
library(xml2)
library(rvest)
library(iterators)
library(foreach)
library(doParallel)
library(future)
library(RSelenium)
library(microbenchmark)
library(futile.logger)

common_log_name <- "FIPS.log"
# ��������� ����� ��������� ������ ��������
# patents <- read_csv("patents_list_test.csv")
patents <- read_csv("patents_list.csv")
output_fname <- "patents_ext2_G06F.csv"
  
  

# ==== functions definition
enreach_patent <- function(docID) {
  
  # ��������� url �������
  req_str1 <- "http://www1.fips.ru/wps/portal/!ut/p/c5/jY7LDoIwFES_hS-4l2dhWYhpC4hgYhA2pCENYngYVBZ-vbByJTqznJyZgRIWD3JuG_lox0F2cIbSqYSgKY-Yjij2LlIvC0Pqu8h2-pIXThUwyi0SI7LkGKCwfMvgzDdQmP_Q-EUUf9D5-nZ7fc03-hM-9goKKMhn55AQD2lsRzpPXJN5NuSTuo_PqVaQ1bK-qFjNqktlo-DWn854JS9KNe0NbQg1dw!!/?beanMethod=getDocument&queryId="
  req_str3 <- "&documId="
  req_str4 <- "&checkBoxes=&fromUserId=514"
  
  # ��������� ��� = G05B
  req_str2 <- "2760601"
  # ��������� ��� = G06Q
  req_str2 <- "2772556"
  # ��������� ��� = H04W (2933 ���������� �� 14.11.2016, ���. 1-59), ��� ��������� ����������� �����������
  req_str2 <- "2787248"
  # ��������� ��� = H04W (3032 ���������� �� 14.11.2016, ���. 1-61), ������ �������� ����������� �����������
  req_str2 <- "2787104"
  # ��������� ��� = G06K (3690 ���������� �� 14.11.2016, ���. 1-74)
  req_str2 <- "2788648"
  # ��������� ��� = H03M (2436 ���������� �� 14.11.2016, ���. 1-49)
  req_str2 <- "2789999"
  # ��������� ��� = G06F3/00 or G06F13/00 or G06F12/00 or G06F5/00 or G06F9/00 or G06F11/00 or G06F21/00
  # (3045 ���������� �� 14.11.2016, ���. 1-61)
  req_str2 <- "2790898"
  # ��������� ��� = G06F1/00 or G06F7/00 or G06F15/00 or G06F19/00
  # (2667 ���������� �� 16.11.2016, ���. 1-54)
  req_str2 <- "2813445"
  
  
  
  ur1 <- str_c(req_str1, req_str2, req_str3, docID, req_str4, collapse = "")
  # browser()
  # resp <- try(curl_fetch_memory(url))
  # ��������� �� httr: https://cran.r-project.org/web/packages/httr/vignettes/quickstart.html
  # ��������� exception ���� �� ��������
  resp <- GET(ur1)
  resp_status <- resp$status_code
  
  # �������� ��������� ��������
  flog.info(paste0("Parsing documentId = ", docID, " HTTP Status Code = ", resp_status))
  
  htext <- fromJSON(content(resp, "text"))
  # browser()
  
  ht <- htext$result$html
  # j3 <- stri_encode(ht, from = "UTF-8", to = "cp1251")
  # browser()
  m <- read_html(ht, encoding = "UTF-8")
  # m2 <- read_html(ht, encoding = "windows-1251")
  # guess_encoding(m)
  # browser()
  
  
  # ��������� ��������� � �����������������
  # IPR <- html_nodes(m, xpath="//*[@id='bibl']/p[2]/b") %>% html_text()
  tmp <- html_nodes(m, xpath="//*[@id='bibl']") %>% html_text()
  applicant <- stri_match_first_regex(tmp, "\\(72\\) �����\\(�\\):(.+?)\r\n")[[2]]
  owner <- stri_match_first_regex(tmp, "\\(73\\) �����������������\\(�\\):(.+?)\r\n")[[2]]
  # browser()
  flog.info(paste0("��������� = ", applicant))
  flog.info(paste0("����������������� = ", owner))
    
  # ��������� ������
  tmp <- html_nodes(m, xpath="//*[@id='bib']") %>% html_text()
  claim_n <- stri_match_first_regex(tmp, "\\(21\\)\\(22\\) ������: ?(.+?)\r\n")[[2]]
  pub_date <- stri_match_first_regex(tmp, "\\(45\\) ������������:\\s*([.0-9]+)")[[2]]
  flog.info(paste0("������ = ", claim_n))
  flog.info(paste0("���� ���������� = ", pub_date))
  #browser()
  
  # ��������� ����������������� ������
  cindex <- html_nodes(m, xpath="//*[@class='i']") %>% 
    html_text() %>% 
    paste0(collapse="; ")
  flog.info(paste0("����������������� ������(�) = ", cindex)) # ������� �������� �����
  
  # ��������� ������
  tmp <- html_nodes(m, xpath="//*[@id='StatusR']/text()[1]") %>% html_text()
    tmp2 <- stri_replace_all_regex(tmp, "\\s+", " ")
    claim_status <- ifelse(identical(tmp2, character(0)), NA_character_, tmp2) # �� character(0) tibble() �������!!!
    flog.info(paste0("������ ������� = <", claim_status, ">"))

  # ��������� ������
  tmp <- html_nodes(m, xpath="//*[@id='td1']") %>% html_text()
  country <- stri_replace_all_regex(tmp, "\\s+", " ")
  flog.info(paste0("������ = ", country))
  
  elem <- tibble(
    docID=docID,
    resp_status=resp_status,
    country=country,
    applicant=applicant,
    owner=owner,
    claim_n=claim_n,
    pub_date=pub_date,
      claim_status=claim_status,
    cindex=cindex
  )
  
    flog.info(capture.output(print(elem)))
    # browser()

  elem
}

postclean <- function(x){
  x %>% stri_replace_all_regex("\\s+;", ";") %>%
    stri_replace_all_regex("^\\s+", "") %>%
    stri_replace_all_regex("\\s+$", "") %>%
    stri_replace_all_regex(",\\([^\\s]\\)", ", \\1") %>%
    stri_replace_all_regex(",(?!\\s)", ", ") %>%
    stri_replace_all_regex("(���������� ���������)\\s", "$1; ")
  
}
# ======
flog.appender(appender.file(common_log_name))
flog.threshold(TRACE)
flog.info("============= Enreachment started ===============")


# ���������� url ��� ���������� ������ �������� ��������� �� ���������� ����� ������ � ��� = G05B ����� �� ������ � �������� � �������� ��������� �������:
# http://www1.fips.ru/wps/portal/!ut/p/c5/jY7LDoIwFES_hS-4l2dhWYhpC4hgYhA2pCENYngYVBZ-vbByJTqznJyZgRIWD3JuG_lox0F2cIbSqYSgKY-Yjij2LlIvC0Pqu8h2-pIXThUwyi0SI7LkGKCwfMvgzDdQmP_Q-EUUf9D5-nZ7fc03-hM-9goKKMhn55AQD2lsRzpPXJN5NuSTuo_PqVaQ1bK-qFjNqktlo-DWn854JS9KNe0NbQg1dw!!/?beanMethod=getDocument&queryId=2760601&documId=6b45832227654a2686e278babf036537&checkBoxes=&fromUserId=514
# ��� documId ����� �� ����������� ���� ������� (����� ������� ���������� 3743)
# � ����� �������� json, � �������� � ���� result -> hitlist ����� html �� ������� ����� ����������
# http://www.jsoneditoronline.org/
# http://codebeautify.org/jsonviewer

# ���������� � ������������� �������
nworkers <- detectCores() - 1
registerDoParallel(nworkers)
getDoParWorkers()

# ������������ ��������� ������ �� �����������
# http://stackoverflow.com/questions/38828344/how-to-log-when-using-foreach-print-or-futile-logger
loginit <- function(logfile) flog.appender(appender.file(logfile))
foreach(input=rep(common_log_name, nworkers),
        .packages='futile.logger') %dopar% loginit(input)

# --- ������� ������� ��� �������
# patents %<>%
#   mutate(thread = row_number() %% nworkers) %>%
#   mutate(workerID = thread)

# nested_patents <- patents
#   select(thread, docID) %>%
#   group_by(thread) %>%
#   nest()

descriptions <-
    foreach(docID=iter(patents$docID), 
            .packages=c('xml2', 'rvest', 'futile.logger', 'stringi', 'stringr', 'jsonlite', 
                        'tibble', 'magrittr', 'curl', 'httr'), 
            .combine=rbind) %dopar% {
              # browser()
              flog.info(paste0("worker = ", patents[patents$docID == docID, ]$workerID, " docID = ", docID))
              enreach_patent(docID)
            }
# browser()
registerDoSEQ() # http://stackoverflow.com/questions/25097729/un-register-a-doparallel-cluster

# �������� ����������� ����������� ��������� ������
descriptions <- purrr::dmap_at(descriptions, c("cindex", "applicant", "country", "status"), postclean)

# ������ ������ � ������������ �����������. ����� ��� ������� �� ����, ��� ������� �������� �������
res <-  left_join(patents, descriptions, by="docID")
write_excel_csv(res, output_fname, append=FALSE)
flog.info("Output file enreached")

stop()
# ��������
stri_match_first_regex(tmp, "\\(73\\) �����������������\\(�\\):(.+?)\r\n")

html_nodes(m, xpath="//*[@class='i']") %>% html_text()

stri_replace_all_regex("��� ������� ������� (US),�������� ��������� ���� (US)",
                       ",(?!\\s)", ", ")

stri_replace_all_regex(" ���������� ��������� ����������� ������ �� ���������������� �������������, �������� � �������� ������ ",
                       "(���������� ���������)\\s", "$1; ")


stop()

# === ������� �������� �������� ������� �� ��� id
# ������ ��������� �� ������: http://www1.fips.ru/wps/portal/!ut/p/c5/jY7LDoIwFES_hS-4l2dhWYhpC4hgYhA2pCENYngYVBZ-vbByJTqznJyZgRIWD3JuG_lox0F2cIbSqYSgKY-Yjij2LlIvC0Pqu8h2-pIXThUwyi0SI7LkGKCwfMvgzDdQmP_Q-EUUf9D5-nZ7fc03-hM-9goKKMhn55AQD2lsRzpPXJN5NuSTuo_PqVaQ1bK-qFjNqktlo-DWn854JS9KNe0NbQg1dw!!/?beanMethod=getDocument&queryId=2760601&documId=dae8d132a3b82a6abef5bab3de50c234&checkBoxes=&fromUserId=514
write(ht, "resp.txt", append=FALSE)


m <- iconv(dvTitle, from="UTF8", to="windows-1251")
j3 <- stri_encode(j, from="UTF-8", to="cp1251")

# ������� �������������� ����������
id <- html_nodes(m, xpath="//a[@class='hitListRow']") %>% html_attr("id")
# ���� ������ �������� ����� �� ������ url:
# http://www1.fips.ru/wps/portal/IPS_Ru#docNumber=13&docId=dae8d132a3b82a6abef5bab3de50c234
ur <- paste0("http://www1.fips.ru/wps/portal/IPS_Ru#docNumber=13&docId=", id[[1]])
resp <- GET(ur)
cc <- content(resp, "text")
str(content(resp, "text"), nchar.max=5000)
write(cc, "resp.txt", append=FALSE)

# ����� ����� Selenium
remDrv <- remoteDriver()
remDrv$open()
remDr <- remoteDriver(remoteServerAddr = "localhost", port = 5555, browserName = "internet explorer")
remDr <- remoteDriver(remoteServerAddr = "localhost", port = 9515, browserName = "chrome")
remDr <- remoteDriver(browserName = "internet explorer")
remDr <- remoteDriver(browserName = "chrome")
remDr$open()

# === ��������� �������� ����� Selenium
# Selenium ���������� ��������� �������
# remDrv <- remoteDriver()
remDrv <- remoteDriver(browserName = "chrome")
# remDrv <- remoteDriver(browserName = "internet explorer")
remDrv$open()

ur2 <- "http://www1.fips.ru/wps/portal/IPS_Ru#docNumber=13&docId=dae8d132a3b82a6abef5bab3de50c234"

remDrv$navigate(ur1)
Sys.sleep(2)
remDrv$navigate(ur2)

