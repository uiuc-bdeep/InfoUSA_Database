# BDEEPInfoUSA R package

## Installation
First, to install the package dependencies, execute the following in R terminal:
```
install.packages("devtools", dependencies=T)
install.packages("DBI")
install.packages("RPostgreSQL")
```

Finally, to install (only for the first time) or update the package, use:
```
devtools::install_github("uiuc-bdeep/InfoUSA_Database/BDEEPInfousa")
```

In some cases, you might need to restart the server to get rid of all errors and warnings before loading the library. After this, use command to load the BDEEPZillow library.
```
library(BDEEPInfousa)
```

## Content
The current available data & functions are as followed. All of them have been tested on infousa_2018 database. Function `get_infousa_usr` can also be used in other databases (not recommended).

### Main functions
* [get_infousa_location](./R/infousa.R)
```
@description This function gets a data.frame including all data from the given location in a single year.
@param single_year   An integer indicating a single year
@param loc           A vector of integers indicating fips ("fips" method) or a data.frame with first 2
                     columns being state abbr. & county name ("names" method).
                     If the entire state is needed, set county code to 000 ("fips") or set county name to "*" ("names").
@param tract         A vector of integers or chars indicating tract in the county.
                     Note that tracts are unique only in the current county. Default to all tracts.
@param columns       A vector of column names to export. Default to all columns (i.e. "*").
@param method        Method for input. Choose between "fips" and "names". Default to "fips".
@param append        If append is true, return a single data.frame with rows appended, otherwise a
                     list of data.frames from each state.
@examples  # Using fips
@examples  test <- get_infousa_location(2006, "01001")
@examples  test <- get_infousa_location(2006, "02020", tract=c(001802,002900))

@examples  # Using state and county names
@examples  x <- data.frame(state=c('il'), county=c('champaign'))
@examples  test <- get_infousa_location(2017, x, method="names")
@return A data.frame including all data from the given year, fips and tract
```
* [get_infousa_multiyear](./R/infousa.R)
```
@description This function gets a data.frame including all data from the given location from all years.
@param startyear     The first year to get data
@param endyear       The last year to get data
@param loc           A vector of integers indicating fips ("fips" method) or a data.frame with first 2
                     columns being state abbr. & county name ("names" method).
                     If the entire state is needed, set county code to 000 ("fips") or set county name to "*" ("names").
@param tract         A vector of integers or chars indicating tract in the county.
                     Note that tracts are unique only in the current county. Default to all tracts.
@param columns       A vector of column names to export. Default to all columns (i.e. "*").
@param method        Method for input. Choose between "fips" and "names". Default to "fips".
@examples  test <- get_infousa_multiyear(2017, 2017, "01001")
@examples  test <- get_infousa_multiyear(2006, 2016, "02020", tract=c(001802,002900))
@return A data.frame including data from all years, fips and tract
```
* [get_infousa_zip](./R/infousa.R)
```
@description This function gets a data.frame including all data from the given location from all years.
@param startyear     The first year to get data
@param endyear       The last year to get data
@param zip           A vector of characters indicating zipcodes to get data from.
@param columns       A vector of column names to export. Default to all columns (i.e. "*").
@examples  test <- get_infousa_zip(2016, 2017, c("61801", "61820"))
@return A data.frame including data from all years, fips and tract
```
* [get_infousa_fid](./R/infousa.R)
```
#' @description This function gets a data.frame including all data from the given vector of familyid from given years.
#' @param startyear     The first year to get data
#' @param endyear       The last year to get data
#' @param fid           A vector of characters indicating familyids to get data from.
#' @param columns       A vector of column names to export. Default to all columns (i.e. "*").
#' @examples  test <- get_infousa_fid(2006, 2007, c("54299524", "54320129"))
#' @return A data.frame
```
* [get_infousa_usr](./R/infousa.R)
This function is similar to other `get_*_usr` functions available in other BDEEP R packages. For detailed examples, see the one in the BDEEPZillow package.

```
@description This function gets from database according to a user-specified query.
@param query         A string specifying the query sent to database
@param database_name A string indicating the database name
@param host_ip       A string indicating the ip address of the database VM
@examples # Select single field from a given table
@examples data <- get_infousa_usr("SELECT year2006part.total limit 50")
@return A data.frame returned by the given query.
```

### Helper functions
* [get_state_county](./R/county_state_fips_table.R)
```
@description This function convert a vector of fips to corresponding state-county pairs
@param fips  A vector of fips numbers stored as TEXT (characters)
@return A data.frame with first column as state abbreviation, second column as county name,
        both in lower case, and third column fips.
```

* [db_type_converter](./R/converter.R)
```
@description This function converts the type to align with the requirement. See requirement online.
@param data    The actual data.frame to convert.
@param dbname  The name of the database. Used to distinguish data.
@return The modified data.frame
```
## Notes
### Data Type
Please refer to [this table](./InfoUSA Columns & Type Reference.xlsx) to check for InfoUSA data type compatibility for each column (missing fields from the original description also included).
