# convert-json-csv
Converts json and csv rules files for use with json-integrated platforms (ie. cloud armory dashboard) or csv-compatible software (ie. excel and google sheets)

## convert to CSV
*Pass the --input parameter with the full filepath as an absolute path*
*Pass the --output parameter with your desired file format [csv|json]*
*Uses python, so this could easily just be a python script*
./convert-json-csv.sh --output csv --input "/path/to/your/filename.json" > filename.csv
./convert-json-csv.sh --output json --input "/path/to/your/filename.json" > filename.json
