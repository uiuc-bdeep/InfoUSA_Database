##
# Author: Yuchen Liang
# Date: Apr 12, 2019
##

rm(list = ls())

require(wru)
require(dplyr)
require(stringr)

# function author: Ignacio Sarmiento-Barbieri
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
# STATES <- c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL",
#             "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME",
#             "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH",
#             "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI",
#             "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI",
#             "WY")

colnames(dat) <- str_to_upper(colnames(dat))
to_pred <- dat %>% select(id = FAMILYID,
                          surname = LAST_NAME_1,
                          state = STATE,
                          county = CENSUS2010COUNTYCODE,
                          tract = CENSUS2010TRACT,
                          block = CENSUS2010BLOCK)
# year = YEAR)
STATES <- unique(to_pred %>% pull(state))
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
cong_all <- NULL


# One-shot, given that the census data is available locally
{
census_data <- list()
i <- 1
for (st in STATES){
  census_data[[i]] <- readRDS(paste0("./census_data_tract/", st, "_census.rds"))[[1]]
  names(census_data)[i] <- st
  i <- i + 1
}

result_c <- predict_race(to_pred,
                         census.geo = "county",
                         census.key = "xxx",
                         census.data = census_data)

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
                                       first_name=FIRST_NAME_1,
                                       last_name=LAST_NAME_1,
                                       eth_code_infousa=Ethnicity_Code_1,
                                       race_infousa=race)
y$year <- 2017
y$race_infousa <- str_sub(y$race_infousa, 1, 1)

get_names <- result_all %>% select(starts_with("pred."))
new_names <- get_names %>% rename(wru_whi=pred.whi,
                                  wru_bla=pred.bla,
                                  wru_his=pred.his,
                                  wru_asi=pred.asi,
                                  wru_oth=pred.oth)
result_all <- cbind(result_all,
                    data.frame(race = colnames(get_names)[max.col(get_names,ties.method="first")],
                               prob = apply(get_names, 1, max)),
                    new_names)
result_all$race_abbr <- str_to_title(str_sub(result_all$race, 6, 6))

# Merge
cong_all <- result_all %>% select(id, year, race_wru=race_abbr, prob_wru=prob, starts_with("wru_")) %>% full_join(y, by=c("id", "year")) %>% mutate(same=(race_wru==race_infousa))
}
'''
# divided by states, if census data not available
for (st in STATES){
  print(paste0("Processing state ", st, "..."))
  # Download census data, or get from local if available
  census_data <- readRDS(paste0("./census_data_tract/", st, "_census.rds"))
  # census_data <- get_census_data(key = "01d35539fab30488330596ef4cb9ecf28968827d",
  #                                states = st,
  #                                census.geo = "tract",
  #                                retry = 5)
  
  # Optional: Save to local for reference
  # saveRDS(census_data, file=paste0("./census_data_tract/", st, "_census.rds"))
  
  # Get at county level
  result_c <- predict_race(to_pred %>% filter(state==st),
                           census.geo = "county",
                           census.key = "xxx",
                           census.data = census_data)
  
  result_t <- predict_race(to_pred %>% filter(state==st),
                           census.geo = "tract",
                           census.key = "xxx",
                           census.data = census_data)
  
  # Combine levels
  naid <- result_t %>% filter(is.na(pred.whi)) %>% select(id, year)
  result_all <- result_t %>% filter(!is.na(pred.whi)) %>% bind_rows(naid %>% left_join(result_c, by=c("id", "year")))
  
  # Test accuracy
  y <- gen_demog_infousa(dat %>% filter(STATE==st)) %>% select(id=FAMILYID,
                                                               # year=YEAR,
                                                               first_name=FIRST_NAME_1,
                                                               last_name=LAST_NAME_1,
                                                               eth_code_infousa=Ethnicity_Code_1,
                                                               race_infousa=race)
  y$year <- 2017
  y$race_infousa <- str_sub(y$race_infousa, 1, 1)
  
  get_names <- result_all %>% select(starts_with("pred."))
  new_names <- get_names %>% rename(wru_whi=pred.whi,
                                    wru_bla=pred.bla,
                                    wru_his=pred.his,
                                    wru_asi=pred.asi,
                                    wru_oth=pred.oth)
  result_all <- cbind(result_all,
                      data.frame(race = colnames(get_names)[max.col(get_names,ties.method="first")],
                                 prob = apply(get_names, 1, max)),
                      new_names)
  result_all$race_abbr <- str_to_title(str_sub(result_all$race, 6, 6))
  
  # Merge
  cong <- result_all %>% select(id, year, race_wru=race_abbr, prob_wru=prob, starts_with("wru_")) %>% full_join(y, by=c("id", "year"))
  cong_all <- rbind(cong_all, cong %>% mutate(same=(race_wru==race_infousa)))
}
'''
# saveRDS(cong_all, file="./info2017pred.rds")
rm(census_data, get_names, naid, cong, result_c, result_t, new_names, result_all, y)

# Evaluation
cong <- cong_all
rm(cong_all)
## overall accuracy
print("Overall Congruence:")
mean(cong$same)

## accuracy by group
print("Congrouence and Avg Prob by group:")
cong %>% group_by(race_infousa) %>% summarise(cong=mean(same))


## sensitivity by group
cong %>% group_by(race_wru) %>% summarise(tr_A=sum(race_infousa=='A')/n(),
                                          tr_B=sum(race_infousa=='B')/n(),
                                          tr_H=sum(race_infousa=='H')/n(),
                                          tr_O=sum(race_infousa=='O')/n(),
                                          tr_W=sum(race_infousa=='W')/n())



## confusion matrix
print("Confusion Matrix:")
ref <- matrix(cong$race_infousa, ncol=1)
pred <- matrix(cong$race_wru, ncol=1)
table(ref, pred)
rm(ref, pred)

## plot
x <- cong
ggplot(data=x %>% filter(race_infousa=="W")) + theme_bw() + stat_bin(aes(x=prob_wru, y=..count../sum(..count..), fill=race_wru), geom="bar", binwidth=0.05) + scale_fill_brewer(palette = "Set2") + labs(y="fraction",title="InfoUSA White")
ggplot(data=x %>% filter(race_infousa=="W")) + theme_bw() + stat_bin(aes(x=wru_whi, y=..count../sum(..count..), fill=race_wru), geom="bar", binwidth=0.05) + scale_fill_brewer(palette = "Set2") + labs(y="fraction",title="WRU White")

require(gridExtra)
s <- ggplot(data=x, aes(x=name))
grid.arrange(s+geom_bar(mapping = aes(fill=race_wru), position="fill"), s+geom_bar(mapping = aes(fill=race_infousa), position="fill"), ncol=1)

grid.arrange(ggplot(data=x %>% filter(race_research=='W'), aes(x=name))+geom_bar(mapping = aes(fill=race_wru), position="fill")+labs(x="white names",y="percentage")+scale_fill_manual(values=c("#4E79A7","#F28E2B","#E15759"), name="Race (WRU)"),
             ggplot(data=x %>% filter(race_research=='B'), aes(x=name))+geom_bar(mapping = aes(fill=race_wru), position="fill")+labs(x="black names",y="percentage")+scale_fill_manual(values=c("#4E79A7","#E15759"), name="Race (WRU)"),
             ggplot(data=x %>% filter(race_research=='H'), aes(x=name))+geom_bar(mapping = aes(fill=race_wru), position="fill")+labs(x="hispanic names",y="percentage")+scale_fill_manual(values=c("#4E79A7","#F28E2B","#E15759"), name="Race (WRU)"),
             ncol = 1)

grid.arrange(ggplot(data=x %>% filter(race_research=='W'), aes(x=name))+geom_bar(mapping = aes(fill=race_infousa), position="fill")+labs(x="white names",y="percentage")+scale_fill_manual(values = c("#F778A1", "#79A1F7"), name = "infousa races"),
             ggplot(data=x %>% filter(race_research=='B'), aes(x=name))+geom_bar(mapping = aes(fill=race_infousa), position="fill")+labs(x="black names",y="percentage")+scale_fill_manual(values = c("#F778A1", "#79A1F7"), name = "infousa races"),
             ggplot(data=x %>% filter(race_research=='H'), aes(x=name))+geom_bar(mapping = aes(fill=race_infousa), position="fill")+labs(x="hispanic names",y="percentage")+scale_fill_manual(values = c("#A1F779"), name = "infousa races"),
             ncol = 1)

avg <- x %>% group_by(name) %>% summarise(avg_whi=sum(wru_whi)/n(), avg_bla=sum(wru_bla)/n(), avg_his=sum(wru_his)/n()) %>% left_join(x %>% select(name, race_research) %>% distinct(), by="name")




