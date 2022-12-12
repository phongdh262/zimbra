!/bin/bash

# Usage: import_user.sh user.csv
file=$1

while read line; do
Username=`echo $line | cut -d"," -f1 |  tr -d '\r'`
Password=`echo $line | cut -d"," -f2 |  tr -d '\r'`
zmprov ca $Username $Password
echo "Create user $Username"
done < $file
