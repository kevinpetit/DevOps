#!/bin/bash

# This script will backup all mysql databases into the $outDir directory, as separate files.
# One file per database.

# Retrieve all database names except information schemas. Use sudo here to skip root password.
dbs=$(sudo mysql --batch --skip-column-names -e "SHOW DATABASES;" | grep -E -v "(information|performance)_schema")
outDir="/srv/www/db_backups"

# Check if output directory exists
if [ ! -d "$outDir" ];then
  # Create directory with parent ("-p" option) directories
  sudo mkdir -p "$outDir"
fi

# Loop through all databases
for db in $dbs; do
 # Dump database to directory with file name same as database name + sql suffix
  sudo mysqldump --databases "$db" > "$outDir/$db.sql"
done

rm $outDir/mysql.sql
