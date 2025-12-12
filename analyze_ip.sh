#!/bin/bash

mkdir -p /ip_logs

#INPUT_LOG="<path/to/your/logfile.log>"
INPUT_LOG="/var/log/application.log"

OUTPUT_CSV="/ip_logs/ip_country_list.csv"

echo "IP_ADDRESS,COUNTRY" > "$OUTPUT_CSV"

echo "Extracting IP addresses form <$INPUT_LOG>..."

#ip_list=$(grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$INPUT_LOG" | sort -u)
ip_list=$( grep Failed "$INPUT_LOG" | awk '{print $NF}' | sort | uniq -c | sort -nr)

if [ -z "$ip_list" ]; then
    echo "No IP addresses found in the log file."
    exit 1
fi

echo "Checking country for each IP address..."

for ip in $ip_list; do
    country=$(whois "ip" | grep -iE '^country:' | head -n 1 | awk '{print $2}')
    
    if [ -z "&country" ]; then
        country ="Unknown"
    fi

    echo "Checking IP: $ip - Country: $country"
    echo "$ip"","$country"" >> "$OUTPUT_CSV"

    sleep 0.5
done

echo "Completed! Results were saved to <$OUTPUT_CSV>"