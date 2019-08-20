##
# Author: Yuchen Liang
##

require(wru)
require(dplyr)
require(stringr)

# author: Ignacio Sarmiento-Barbieri
gen_demog_infousa<-function(dta) {
  # Generate Demog. variables -----------------------------------------------
  Black_codes<-c("B5", "Q6", "Q7", "Q8", "Q9","AO","A8","BJ","BW","BF","BI","CM","C3","CF","TD","KM","CG",
                 "DJ","GQ","ET","GA","GM","GH","GW","GN","H2","CI","KE","LS", "LR","MG","MW","ML","MR","MZ","NA",
                 "NE","NG","RW","SN","SC","SL","SO","ZA","SD","S9","SZ","TZ","TG","UG","X5","CD","ZM","ZW","Z8")
  Native_American_codes<-c("A4", "N3")
  Pacific_Islander_codes<-c("FJ", "PH", "H3", "NR", "PG", "P5", "TO", "VU", "WS")
  Middle_Eastern_codes<-c("DZ", "A7", "BH", "EG", "IQ", "JO", "KW", "LB", "LY", "MA", "OM", "P4", "QA", "SA",
                          "SY", "TN", "AE", "YE")
  Jewish_codes<-c("J4")
  Hispanic_codes<-c("B3","H5","PT")
  Far_Eastern_codes<-c("CN", "ID", "JP", "KH", "K5", "LA", "MY", "MN", "MM", "TH", "T5", "VN") 
  Central_Southwest_Asian_codes<-c("AM", "AZ", "C5", "GE", "KZ", "KG", "TJ", "TM", "UZ")
  South_Asian_codes<-c("AF", "BD", "BT", "IN", "NP", "O8", "PK", "LK", "T4")
  Western_European_codes<-c("AT", "BE", "NL", "E5", "FR", "DE",  "IE", "K8", "LI", "LU", "IM", "S3", "CH", "TR", "W4")
  Mediterranean_codes<-c( "CY", "GR","IT", "MT")
  Eastern_European_codes<-c("AL", "BA", "BG", "BY", "HR", "CZ", "EE", "HU", "LV", "LT", "MK", "MD", "PL", "RO", "RU", "CS", "SK", "SI", "UA")
  Scandinavian_codes<-c("NO", "IS", "FI", "DK", "SE")
  Other_codes<-c("AU", "GY", "MV", "NZ", "SR", "ZZ")
  
  Asian_codes<-c(Far_Eastern_codes, Central_Southwest_Asian_codes, South_Asian_codes)
  White_codes<-c(Western_European_codes,Mediterranean_codes,Eastern_European_codes,Scandinavian_codes)
  
  dta <- dta %>% mutate(ethnicity=ifelse(Ethnicity_Code_1%in%Black_codes,"Black",
                                         ifelse(Ethnicity_Code_1%in%Hispanic_codes,"Hispanic",
                                                ifelse(Ethnicity_Code_1%in%Western_European_codes,"Western_European",
                                                       ifelse(Ethnicity_Code_1%in%Mediterranean_codes,"Mediterranean",
                                                              ifelse(Ethnicity_Code_1%in%Eastern_European_codes,"Eastern_European",
                                                                     ifelse(Ethnicity_Code_1%in%Scandinavian_codes,"Scandinavian",
                                                                            ifelse(Ethnicity_Code_1%in%c(00),"Unknown",
                                                                                   "Other"))))))),
                        race=ifelse(Ethnicity_Code_1%in%Black_codes,"Black",
                                    ifelse(Ethnicity_Code_1%in%Hispanic_codes,"Hispanic",
                                           ifelse(Ethnicity_Code_1%in%White_codes,"White",
                                                  ifelse(Ethnicity_Code_1%in%Asian_codes,"Asian","Other")))))
  return(dta)
}


# Parameters
dat <- readRDS("/home/bdeep/share/projects/InfoUSA/shp_merging/p2/p2result_2017.rds")
ST <- c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", 
        "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", 
        "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", 
        "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", 
        "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", 
        "WY", "AS", "GU", "MP", "PR", "VI", "UM")

colnames(dat) <- str_to_upper(colnames(dat))
to_pred <- dat %>% select(id = FAMILYID,
                          surname = LAST_NAME_1,
                          state = STATE,
                          county = GE_ALS_COUNTY_CODE_2010,
                          tract = GE_ALS_CENSUS_TRACT_2010,
                          block = GE_ALS_CENSUS_BG_2010)
                          # year = YEAR)
dat <- dat %>% rename(Ethnicity_Code_1=ETHNICITY_CODE_1)

## Change this if not in the same state or year
# to_pred$state <- ST
to_pred$year <- 2017

# Prepare data.frame to predict
## county is three chars long
to_pred$county <- str_pad(to_pred$county, 3, side="left", pad="0")
## tract is six characters
to_pred$tract <- str_pad(to_pred$tract, 6, side="left", pad="0")
## block is four characters
to_pred$block <- str_pad(to_pred$block, 4, side="left", pad="0")
to_pred$surname <- str_to_title(to_pred$surname)

# Download census data
if (!exists("census_data")){
  census_data <- get_census_data(key = "01d35539fab30488330596ef4cb9ecf28968827d",
                                 states = ST,
                                 census.geo = "tract",
                                 retry = 2)
  # Consider saving the census_data to local filesystem ...
  # saveRDS(census_data, file="./census_data.rds")
}
# Get at county level
result_c <- predict_race(to_pred,
                         census.geo = "county",
                         census.key = "xxx",
                         census.data = census_data)

# Get at tract level
result_t <- predict_race(to_pred,
                         census.geo = "tract",
                         census.key = "xxx",
                         census.data = census_data)

# Combine levels
naid <- result_t %>% filter(is.na(pred.whi)) %>% select(id, year)
result_all <- result_t %>% filter(!is.na(pred.whi)) %>% bind_rows(naid %>% left_join(result_c, by=c("id", "year")))

# Test accuracy
y <- gen_demog_infousa(dat) %>% select(id=FAMILYID,
                                       # year=YEAR,
                                       fname=FIRST_NAME_1,
                                       lname=LAST_NAME_1,
                                       eth_code=Ethnicity_Code_1,
                                       race_tr=race)
y$year <- 2017
y$race_tr <- str_sub(y$race_tr, 1, 1)

get_names <- result_all %>% select(starts_with("pred."))
result_all <- cbind(result_all, data.frame(race = colnames(get_names)[max.col(get_names,ties.method="first")],
                                           prob = apply(get_names, 1, max)))
result_all$race_abbr <- str_to_title(str_sub(result_all$race, 6, 6))

# Merge
accy <- result_all %>% select(id, year, race_pred=race_abbr, prob_pred=prob) %>% full_join(y, by=c("id", "year"))
accy <- accy %>% mutate(correct=(race_pred==race_tr))
# saveRDS(accy, file="./info2017pred.rds")

# # Evaluation
# ## overall accuracy
# print("Overall Accuracy:")
# mean(accy$correct)
# 
# ## accuracy by group
# print("Accuracy and Avg Prob by group:")
# acbg <- accy %>% group_by(race_tr) %>% summarise(accy=mean(correct),
#                                                  avg_asi=mean(pred.asi),
#                                                  avg_bla=mean(pred.bla),
#                                                  avg_his=mean(pred.his),
#                                                  avg_oth=mean(pred.oth),
#                                                  avg_whi=mean(pred.whi))
# acbg
# 
# ## sensitivity by group
# stvbg <- accy %>% group_by(race_pred) %>% summarise(tr_A=sum(race_tr=='A')/n(),
#                                                     tr_B=sum(race_tr=='B')/n(),
#                                                     tr_H=sum(race_tr=='H')/n(),
#                                                     tr_O=sum(race_tr=='O')/n(),
#                                                     tr_W=sum(race_tr=='W')/n())
# 
# stvbg
# 
# ## confusion matrix
# print("Confusion Matrix:")
# ref <- matrix(accy$race_tr, ncol=1)
# pred <- matrix(accy$race_pred, ncol=1)
# table(ref, pred)

