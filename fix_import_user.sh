#!/bin/bash
# Usage: ./import_users.sh users.csv

file="$1"

if [ ! -f "$file" ]; then
    echo "Error: File '$file' not found."
    echo "Usage: $0 <csv_file>"
    exit 1
fi

while IFS=',' read -r Username Password DisplayName Department GivenName Surname; do
    # Xóa ký tự xuống dòng và khoảng trắng thừa
    Username=$(echo "$Username" | tr -d '\r' | xargs)
    Password=$(echo "$Password" | tr -d '\r' | xargs)
    DisplayName=$(echo "$DisplayName" | tr -d '\r' | xargs)
    Department=$(echo "$Department" | tr -d '\r' | xargs)
    GivenName=$(echo "$GivenName" | tr -d '\r' | xargs)
    Surname=$(echo "$Surname" | tr -d '\r' | xargs)

    # Tạo người dùng với các thông tin bổ sung
    zmprov ca "$Username" "$Password" displayName "$DisplayName" \
                                      zimbraCOSId "default" \
                                      departmentNumber "$Department" \
                                      givenName "$GivenName" \
                                      sn "$Surname"

    # Kiểm tra kết quả của lệnh zmprov
    if [ $? -eq 0 ]; then
        echo "Successfully created user: $Username"
    else
        echo "Failed to create user: $Username"
    fi
done < "$file"

echo "User import process completed."
