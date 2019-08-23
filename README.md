# InfoUSA_Database Overview

Basic pipeline:
```                                         
                                       store_infousa.py                      BDEEPInfousa R package               
Household_Ethnicity_<year>.txt    --------------------------->   Postgres   ----------------------->     R      ------>    Further   
       (Raw TXT files)            --------------------------->   Database   ----------------------->    Data    ------>    Processing ...
```

## TXT -> Postgres Database
[store_infousa.py](./store_infousa.py) converts InfoUSA raw data from txt file to postgresql database. The script takes year number as an argument. For example, if you want to store year 2006, execute the following in the database machine:
```
python3 store_infousa.py 2006
```

The script uses sqlalchemy ([Reference here](https://docs.sqlalchemy.org/en/13/)) to create and insert into the database table. Different from the Zillow data, the InfoUSA data can be converted into a pandas data frame. Therefore, one can insert into the database by chunks, achieving better performance. Note that variable `DTYPEIN` is the type read by pandas, while variable `DTYPE` is that read by the database engine. These two must be consistent.

## Postgres Database -> R
To transfer data from database into rds files, we use the BDEEPInfousa R package.

[This package](./BDEEPInfousa/) sets up a direct connection to the database and gets the data. The type reference table is also [available](./BDEEPInfousa/InfoUSA%20Columns%20&%20Type%20Reference.xlsx). Details in the package folder.

## An Example using database: Race Prediction Analysis
The InfoUSA data predicts the ethnicity of each of the recorded names and stores them as a separate column. The information is important for some researchers in the field of cultural differences and discrimination. [Here](./Race%20Prediction/), we analyzed the consistency of the InfoUSA prediction with that by another commonly used method, the [R WRU package](https://cran.r-project.org/web/packages/wru/wru.pdf). See the folder for more details.
