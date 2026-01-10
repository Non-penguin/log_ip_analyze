#!/bin/bash

mkdir -p /ip_logs

#INPUT_LOG="<path/to/your/logfile.log>"
INPUT_LOG="/var/log/application.log"

if [ ! -f "$INPUT_LOG" ]; then
    echo "Error: Log file '$INPUT_LOG' not found."
    exit 1
fi

OUTPUT_CSV="/ip_logs/ip_country_list.csv"
OUTPUT_CSV_DATE="/ip_logs/ip_date_list.csv"

echo "IP_ADDRESS,COUNTRY" > "$OUTPUT_CSV"
echo "IP_ADDRESS,DATE" > "$OUTPUT_CSV_DATE"

echo "Extracting IP addresses and dates from <$INPUT_LOG>..."

# Use awk for faster processing instead of a shell loop
grep "Failed" "$INPUT_LOG" | awk '{
    match($0, /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/);
    if (RSTART > 0) {
        ip = substr($0, RSTART, RLENGTH);
        date = $1 " " $2 " " $3;
        print ip ",\"" date "\""
    }
}' >> "$OUTPUT_CSV_DATE"

echo "IP and date logging complete. Results in <$OUTPUT_CSV_DATE>"

echo "Extracting unique IP addresses from <$INPUT_LOG>..."

# Process unique IPs directly via pipe to handle large datasets
grep "Failed" "$INPUT_LOG" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u | while read -r ip; do
    country=$(whois "$ip" | grep -iE '^country:' | head -n 1 | awk '{print $2}')
    
    # Default to Unknown if empty
    country=${country:-Unknown}

    echo "Checking IP: $ip - Country: $country"
    echo "$ip,$country" >> "$OUTPUT_CSV"

    sleep 0.5
done

echo "Completed! Country lookup results were saved to <$OUTPUT_CSV>"