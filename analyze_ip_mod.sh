#!/bin/bash

mkdir -p /ip_logs

#INPUT_LOG="<path/to/your/logfile.log>"
INPUT_LOG="/var/log/application.log"

OUTPUT_CSV="/ip_logs/ip_country_list.csv"
OUTPUT_CSV_DATE="/ip_logs/ip_date_list.csv"

echo "IP_ADDRESS,COUNTRY" > "$OUTPUT_CSV"
echo "IP_ADDRESS,DATE" > "$OUTPUT_CSV_DATE"

echo "Extracting IP addresses and dates from <$INPUT_LOG>..."

grep Failed "$INPUT_LOG" | while read -r line; do
    date=$(echo "$line" | awk '{print $1, $2, $3}')
    ip=$(echo "$line" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -n 1)

    if [ -n "$ip" ]; then
        echo "$ip,\"$date\"" >> "$OUTPUT_CSV_DATE"
    fi
done

echo "IP and date logging complete. Results in <$OUTPUT_CSV_DATE>"

echo "Extracting unique IP addresses from <$INPUT_LOG>..."

ip_list=$(grep Failed "$INPUT_LOG" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u)

if [ -z "$ip_list" ]; then
    echo "No IP addresses found in the log file."
    exit 0
fi

echo "Checking country for each unique IP address..."

for ip in $ip_list; do
    country=$(whois "$ip" | grep -iE '^country:' | head -n 1 | awk '{print $2}')
    
    if [ -z "$country" ]; then
        country="Unknown"
    fi

    echo "Checking IP: $ip - Country: $country"
    echo "$ip,$country" >> "$OUTPUT_CSV"

    sleep 0.5
done

echo "Completed! Country lookup results were saved to <$OUTPUT_CSV>"