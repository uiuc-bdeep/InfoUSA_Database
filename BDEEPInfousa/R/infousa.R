# This file contains functions for data transfer between R and PostgreSQL infousa_2018 database
# For more information about package PostgreSQL, see https://cran.r-project.org/web/packages/RPostgreSQL/RPostgreSQL.pdf

#' get_infousa_location
#' @description This function gets a data.frame including all data from the given location in a single year.
#' @param single_year   An integer indicating a single year
#' @param loc           A vector of integers indicating fips ("fips" method) or a data.frame with first 2
#'                      columns being state abbr. & county name ("names" method).
#'                      If the entire state is needed, set county code to 000 ("fips") or set county name to "*" ("names").
#' @param tract         A vector of integers or chars indicating tract in the county.
#'                      Note that tracts are unique only in the current county. Default to all tracts.
#' @param columns       A vector of column names to export. Default to all columns (i.e. "*").
#' @param method        Method for input. Choose between "fips" and "names". Default to "fips".
#' @param append        If append is true, return a single data.frame with rows appended, otherwise a
#'                      list of data.frames from each state.
#' @examples  # Using fips
#' @examples  test <- get_infousa_location(2006, "01001")
#' @examples  test <- get_infousa_location(2006, "02020", tract=c(001802,002900))
#'
#' @examples  # Using state and county names
#' @examples  x <- data.frame(state=c('il'), county=c('champaign'))
#' @examples  test <- get_infousa_location(2017, x, method="names")
#' @return A data.frame including all data from the given year, fips and tract
#' @import RPostgreSQL DBI
#' @export
get_infousa_location <- function(single_year, loc, tract="*", columns="*", method="fips", append=TRUE){
  # Check valid input
  if (length(single_year) > 1) {
    print("Input must be a single year!")
    return(NULL)
  }
  if (method=="fips") {
    if (any(nchar(loc)!=5)){
      print("Invalid fips codes! Try entering fips code as characters.")
      return(NULL)
    }
    state_county <- get_state_county_by_fips(loc)[, c("state", "county", "county_code")]
  } else if (method=="names"){
    if (ncol(loc)!=2){
      print("Invalid input data.frame!")
      return(NULL)
    }
    state_county <- get_state_county_by_names(loc)[, c("state", "county", "county_code")]
  } else {
    print("Invalid method!")
    return(NULL)
  }

  # state_county$county_code <- as.integer(state_county$county_code)

  # Initialize tract specification
  if(length(tract)>1 || tract[1]!="*"){
    if(nrow(state_county) > 1){
      print("WARNING: Tracts are unique only in one county!")
    }
    tract_spec <- paste0("(\"GE_ALS_CENSUS_TRACT_2010\"=", paste0(tract, collapse = " OR \"GE_ALS_CENSUS_TRACT_2010\"="), ")")
  }

  # Initialize list for return
  result <- list()

  # Initialize connection
  drv <- DBI::dbDriver("PostgreSQL")
  con <- RPostgreSQL::dbConnect(drv,
                                dbname = "infousa_2018",
                                host = "141.142.209.139",
                                port = 5432,
                                user = "postgres",
                                password = "bdeep")

  # Process state-county sequentially
  for(i in 1:nrow(state_county)){
    print(paste("Processing YEAR:", single_year,
                "STATE:", toupper(state_county[i, 1]),
                "COUNTY:", state_county[i, 2],
                "GE_ALS_CENSUS_TRACT_2010:", paste0(tract, collapse = ", ")))
    if(state_county[i, 3] == "000"){
      result[[i]] <- RPostgreSQL::dbGetQuery(con, paste0("SELECT ",
                                                           paste(columns, collapse = ","),
                                                           " FROM year", single_year, "part.", state_county[i, 1]))
    } else if (length(tract)==1 && tract=="*") {
      result[[i]] <- RPostgreSQL::dbGetQuery(con, paste0("SELECT ",
                                                           paste(columns, collapse = ","),
                                                           " FROM year", single_year, "part.", state_county[i, 1],
                                                           " WHERE \"GE_ALS_COUNTY_CODE_2010\"=", state_county[i, 3]))
    } else {
      result[[i]] <- RPostgreSQL::dbGetQuery(con, paste0("SELECT ",
                                                           paste(columns, collapse = ","),
                                                           " FROM year", single_year, "part.", state_county[i, 1],
                                                           " WHERE \"GE_ALS_COUNTY_CODE_2010\"=", state_county[i, 3],
                                                           " AND ", tract_spec))
    }
    gc()
  }
  # close the connection
  RPostgreSQL::dbDisconnect(con)
  RPostgreSQL::dbUnloadDriver(drv)

  # Construct final result
  print("Finished!")
  if(append){
    return(do.call("rbind", result))
  } else {
    return(result)
  }
}


#' get_infousa_multiyear
#' @description This function gets a data.frame including all data from the given location from all years.
#' @param startyear     The first year to get data
#' @param endyear       The last year to get data
#' @param loc           A vector of integers indicating fips ("fips" method) or a data.frame with first 2
#'                      columns being state abbr. & county name ("names" method).
#'                      If the entire state is needed, set county code to 000 ("fips") or set county name to "*" ("names").
#' @param tract         A vector of integers or chars indicating tract in the county.
#'                      Note that tracts are unique only in the current county. Default to all tracts.
#' @param columns       A vector of column names to export. Default to all columns (i.e. "*").
#' @param method        Method for input. Choose between "fips" and "names". Default to "fips".
#' @examples  test <- get_infousa_multiyear(2017, 2017, "01001")
#' @examples  test <- get_infousa_multiyear(2006, 2016, "02020", tract=c(001802,002900))
#' @return A data.frame including data from all years, fips and tract
#' @import RPostgreSQL DBI
#' @export
get_infousa_multiyear <- function(startyear, endyear, loc, tract="*", columns="*", method="fips"){
  # Check valid input
  if(startyear < 2006 || startyear > 2017 || endyear < 2006 || endyear > 2017 || endyear < startyear){
    print("Invalid year range! Please ensure startyear <= endyear and both in [2006,2017].")
    return(NULL)
  }
  if (method=="fips") {
    if (any(nchar(loc)!=5)){
      print("Invalid fips codes! Try entering fips code as characters.")
      return(NULL)
    }
    state_county <- get_state_county_by_fips(loc)[, c("state", "county", "county_code")]
  } else if (method=="names"){
    if (ncol(loc)!=2){
      print("Invalid input data.frame!")
      return(NULL)
    }
    state_county <- get_state_county_by_names(loc)[, c("state", "county", "county_code")]
  } else {
    print("Invalid method!")
    return(NULL)
  }
  # state_county$county_code <- as.integer(state_county$county_code)

  # Initialize tract specification
  if(length(tract)>1 || tract[1]!="*"){
    if(nrow(state_county) > 1){
      print("WARNING: Tracts are unique only in one county!")
    }
    tract_spec <- paste0("(\"GE_ALS_CENSUS_TRACT_2010\"=", paste0(tract, collapse = " OR \"GE_ALS_CENSUS_TRACT_2010\"="), ")")
  }

  # Initialize connection
  drv <- DBI::dbDriver("PostgreSQL")
  con <- RPostgreSQL::dbConnect(drv,
                                dbname = "infousa_2018",
                                host = "141.142.209.139",
                                port = 5432,
                                user = "postgres",
                                password = "bdeep")

  first <- TRUE
  # Iterate over years
  for(yr in startyear:endyear){
    # Process state-county sequentially
    for(i in 1:nrow(state_county)){
      print(paste("Processing YEAR:", yr,
                  "STATE:", toupper(state_county[i, 1]),
                  "COUNTY:", state_county[i, 2],
                  "GE_ALS_CENSUS_TRACT_2010:", paste0(tract, collapse = ", ")))
      if(state_county[i, 3] == "000"){
        res_oneyear <- RPostgreSQL::dbGetQuery(con, paste0("SELECT ",
                                                                paste(columns, collapse = ","),
                                                                " FROM year", yr, "part.", state_county[i, 1]))
      } else if (length(tract)==1 && tract=="*") {
        res_oneyear <- RPostgreSQL::dbGetQuery(con, paste0("SELECT ",
                                                           paste(columns, collapse = ","),
                                                           " FROM year", yr, "part.", state_county[i, 1],
                                                           " WHERE \"GE_ALS_COUNTY_CODE_2010\"=", state_county[i, 3]))
      } else {
        res_oneyear <- RPostgreSQL::dbGetQuery(con, paste0("SELECT ",
                                                           paste(columns, collapse = ","),
                                                           " FROM year", yr, "part.", state_county[i, 1],
                                                           " WHERE \"GE_ALS_COUNTY_CODE_2010\"=", state_county[i, 3],
                                                           " AND ", tract_spec))
      }
      if(nrow(res_oneyear)>0){
        res_oneyear$"YEAR" <- yr
      }
      gc()
    }
    # Append to final result list
    if(nrow(res_oneyear)>0){
      if(first){
        res <- res_oneyear
        first <- FALSE
      } else {
        res <- rbind(res, res_oneyear)
      }
    }
  }

  # close the connection
  RPostgreSQL::dbDisconnect(con)
  RPostgreSQL::dbUnloadDriver(drv)
  print("Finished!")

  return(res)
}


#' get_infousa_zip
#' @description This function gets a data.frame including all data from the given location from all years.
#' @param startyear     The first year to get data
#' @param endyear       The last year to get data
#' @param zip           A vector of characters indicating zipcodes to get data from.
#' @param columns       A vector of column names to export. Default to all columns (i.e. "*").
#' @examples  test <- get_infousa_zip(2016, 2017, c("61801", "61820"))
#' @return A data.frame including data from all years, fips and tract
#' @import RPostgreSQL DBI
#' @export
get_infousa_zip <- function(startyear, endyear, zip, columns="*"){
  # Check valid input
  if(startyear < 2006 || startyear > 2017 || endyear < 2006 || endyear > 2017 || endyear < startyear){
    print("Invalid year range! Please ensure startyear <= endyear and both in [2006,2017].")
    return(NULL)
  }
  if (any(nchar(zip)!=5)){
    print("Invalid fips codes! Try entering fips code as characters.")
    return(NULL)
  }
  sc_zip <- get_state_city_zipcode(zip)[, c("state", "zip", "city")]

  # Initialize connection
  drv <- DBI::dbDriver("PostgreSQL")
  con <- RPostgreSQL::dbConnect(drv,
                                dbname = "infousa_2018",
                                host = "141.142.209.139",
                                port = 5432,
                                user = "postgres",
                                password = "bdeep")

  first <- TRUE
  # Iterate over years
  for(yr in startyear:endyear){
    # Process state-county sequentially
    for(i in 1:nrow(sc_zip)){
      print(paste("Processing YEAR:", yr,
                  "STATE:", toupper(sc_zip[i, 1]),
                  "CITY:", sc_zip[i, 3],
                  "ZIPCODE:", sc_zip[i, 2]))
      res_oneyear <- RPostgreSQL::dbGetQuery(con, paste0("SELECT ",
                                                         paste(columns, collapse = ","),
                                                         " FROM year", yr, "part.", sc_zip[i, 1],
                                                         " WHERE \"ZIP \"=", sc_zip[i, 2]))
      if(nrow(res_oneyear)>0){
        res_oneyear$"YEAR" <- yr
      }
      gc()
    }
    # Append to final result list
    if(nrow(res_oneyear)>0){
      if(first){
        res <- res_oneyear
        first <- FALSE
      } else {
        res <- rbind(res, res_oneyear)
      }
    }
  }

  # close the connection
  RPostgreSQL::dbDisconnect(con)
  RPostgreSQL::dbUnloadDriver(drv)
  print("Finished!")

  return(res)
}

#' get_infousa_fid
#' @description This function gets a data.frame including all data from the given vector of familyid from given years.
#' @param startyear     The first year to get data
#' @param endyear       The last year to get data
#' @param fid           A vector of characters indicating familyids to get data from.
#' @param columns       A vector of column names to export. Default to all columns (i.e. "*").
#' @examples  test <- get_infousa_fid(2006, 2007, c("54299524", "54320129"))
#' @return A data.frame
#' @import RPostgreSQL DBI
#' @export
get_infousa_fid <- function(startyear, endyear, fid, columns="*"){
  # Check valid input
  if(startyear < 2006 || startyear > 2017 || endyear < 2006 || endyear > 2017 || endyear < startyear){
    print("Invalid year range! Please ensure startyear <= endyear and both in [2006,2017].")
    return(NULL)
  }

  # Create placeholder
  if (typeof(fid) == 'list'){
    # flatten list
    fid <- unlist(fid)
  }
  fid <- as.numeric(fid)
  check <- rep(FALSE, length(fid))

  # Initialize connection
  drv <- DBI::dbDriver("PostgreSQL")
  con <- RPostgreSQL::dbConnect(drv,
                                dbname = "infousa_2018",
                                host = "141.142.209.139",
                                port = 5432,
                                user = "postgres",
                                password = "bdeep")

  first <- TRUE
  fid_spec <- paste0("(\"FAMILYID\" IN (", paste(fid, collapse = ","),"))")
  # Iterate over years
  for(yr in startyear:endyear){
    print(paste("Processing YEAR:", yr))
    # Get data
    res_oneyear <- RPostgreSQL::dbGetQuery(con, paste0("SELECT ",
                                                       paste(columns, collapse = ","),
                                                       " FROM year", yr, "fidkey WHERE ", fid_spec))
    if(nrow(res_oneyear)>0){
      res_oneyear$"YEAR" <- yr
    }
    gc()
    # Append to final result list
    if(nrow(res_oneyear)>0){
      if(first){
        res <- res_oneyear
        first <- FALSE
      } else {
        res <- rbind(res, res_oneyear)
      }
    }
  }

  # close the connection
  RPostgreSQL::dbDisconnect(con)
  RPostgreSQL::dbUnloadDriver(drv)

  # Finished!
  print("Finished!")

  return(res)
}


#' get_infousa_usr
#' @description This function gets from database according to a user-specified query.
#' @param query         A string specifying the query sent to database
#' @param database_name A string indicating the database name
#' @param host_ip       A string indicating the ip address of the database VM
#' @examples # Select single field from a given table
#' @examples data <- get_infousa_usr("SELECT year2006part.total limit 50")
#'
#' @examples See similar function in BDEEPZillow package for details.
#' @return A data.frame returned by the given query.
#' @import RPostgreSQL DBI
#' @export
get_from_db_usr <- function(query, database_name="infousa_2018", host_ip="141.142.209.139"){
  # Only one query at a time is supported
  if(length(query)>1){
    print("Only one query at a time is supported!")
    return(NULL)
  }
  # Initialize connection
  drv <- DBI::dbDriver("PostgreSQL")
  con <- RPostgreSQL::dbConnect(drv,
                                dbname = database_name,
                                host = host_ip,
                                port = 5432,
                                user = "postgres",
                                password = "bdeep")
  # Get data
  options(warn = -1)    # suppress warning messages
  hedonics <- RPostgreSQL::dbGetQuery(con, query)
  options(warn = 0)
  gc()
  # Close the connection
  RPostgreSQL::dbDisconnect(con)
  RPostgreSQL::dbUnloadDriver(drv)
  return(db_type_converter(hedonics, dbname=database_name))
}
