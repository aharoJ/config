#!/bin/bash
# Truncate the path to show only the last two directories

path=$1
truncated_path=$(echo "$path" | awk -F'/' '{print $(NF-1)"/"$(NF)}')
echo "../$truncated_path"
