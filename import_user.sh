#!/bin/bash
# Usage: import_user.sh user.csv

file="$1"

while IFS=',' read -r Username Password; do
    # Xóa ký tự xuống dòng nếu có
    Username=$(echo "$Username" | tr -d '\r')
    Password=$(echo "$Password" | tr -d '\r')

    # Sử dụng dấu ngoặc kép khi gọi các biến để tránh lỗi khi chứa ký tự đặc biệt
    zmprov ca "$Username" "$Password"
    echo "Create user $Username"
done < "$file"
