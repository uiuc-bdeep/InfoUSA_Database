from sqlalchemy import create_engine

def partition_table(column, partition, conn):
    yearlist = ['2013', '2014']

    for year in yearlist:
        cmd = "CREATE TABLE temp%s.%s AS SELECT * FROM temp%s WHERE \"%s\" = '%s';" % (year, partition, year, column, partition)
        ret = conn.execute(cmd);
        print('%s.%s Finished')

def main():
	# column that you would like to partition
    column = "STATE"

    # partition value
    partition = ['AK', 'AL', 'AR', 'AZ', 'CA', 'CO', 'CT', 'DC', 'DE', 'FL', 'GA',
                'HI', 'IA', 'ID', 'IL', 'IN', 'KS', 'KY', 'LA', 'MA', 'MD', 'ME',
                'MI', 'MN', 'MO', 'MS', 'MT', 'NC', 'ND', 'NE', 'NH', 'NJ', 'NM',
                'NV', 'NY', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX',
                'UT', 'VA', 'VT', 'WA', 'WI', 'WV', 'WY']

    # connect to the database
    conn = create_engine('postgresql://postgres:bdeep@localhost:5432/infousa_2018')

    # feed zip code to function
    for i in partition:
        partition_table(column, i, conn)


# entry of the script
if __name__ == '__main__':
    main()
