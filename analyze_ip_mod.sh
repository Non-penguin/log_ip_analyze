#!/bin/bash
# analyze_ip_mod.sh - SSH Failed Login Analyzer
#
# Usage: ./analyze_ip_mod.sh [OPTIONS]
# See -h / --help for details.

set -uo pipefail

# ============================================================
# Default Settings
# ============================================================
DEFAULT_INPUT_LOG="/var/log/application.log"
DEFAULT_OUTPUT_DIR="/ip_logs"
DEFAULT_THRESHOLD=10

INPUT_LOG="$DEFAULT_INPUT_LOG"
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
THRESHOLD="$DEFAULT_THRESHOLD"
DISCORD_WEBHOOK_URL=""

# ============================================================
# Functions
# ============================================================

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Analyze failed SSH login attempts from a log file.
Outputs IP/country CSV, IP/date CSV, iptables blocklist, and a report.

Options:
  -l, --log       <path>   Log file to analyze       (default: $DEFAULT_INPUT_LOG)
  -w, --webhook   <url>    Discord webhook URL for notifications
  -t, --threshold <count>  Fail count threshold for blocklist (default: $DEFAULT_THRESHOLD)
  -h, --help               Show this help message

Output files (saved to $DEFAULT_OUTPUT_DIR/):
  ip_country_list.csv  - IP address with resolved country
  ip_date_list.csv     - IP address with access date/time
  blocklist.sh         - iptables commands to block high-risk IPs
  report.txt           - Hourly distribution of failed attempts
EOF
    exit 0
}

send_discord() {
    local ip="$1"
    local country="$2"
    local payload="{\"content\": \"Suspicious access detected from IP: **${ip}** (Country: ${country})\"}"
    curl -s -H "Content-Type: application/json" -X POST -d "$payload" "$DISCORD_WEBHOOK_URL" > /dev/null
}

# ============================================================
# Parse Arguments
# ============================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--log)       INPUT_LOG="$2";          shift 2 ;;
        -w|--webhook)   DISCORD_WEBHOOK_URL="$2"; shift 2 ;;
        -t|--threshold) THRESHOLD="$2";          shift 2 ;;
        -h|--help)      usage ;;
        *) echo "Error: Unknown option '$1'" >&2; usage ;;
    esac
done

# ============================================================
# Validation
# ============================================================

if [ ! -f "$INPUT_LOG" ]; then
    echo "Error: Log file '$INPUT_LOG' not found." >&2
    exit 1
fi

if ! [[ "$THRESHOLD" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Threshold must be a positive integer." >&2
    exit 1
fi

for cmd in whois awk grep; do
    command -v "$cmd" &>/dev/null || { echo "Error: '$cmd' is not installed." >&2; exit 1; }
done

if [ -n "$DISCORD_WEBHOOK_URL" ] && ! command -v curl &>/dev/null; then
    echo "Error: 'curl' is required for Discord notifications but is not installed." >&2
    exit 1
fi

if ! grep -q "Failed" "$INPUT_LOG"; then
    echo "No failed login attempts found in '$INPUT_LOG'."
    exit 0
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_CSV="$OUTPUT_DIR/ip_country_list.csv"
OUTPUT_CSV_DATE="$OUTPUT_DIR/ip_date_list.csv"
OUTPUT_BLOCKLIST="$OUTPUT_DIR/blocklist.sh"
OUTPUT_REPORT="$OUTPUT_DIR/report.txt"

# ============================================================
# Step 1: Extract IP and Date
# ============================================================

echo "[1/4] Extracting IP addresses and dates from <$INPUT_LOG>..."

echo "IP_ADDRESS,DATE" > "$OUTPUT_CSV_DATE"
grep "Failed" "$INPUT_LOG" | awk '{
    match($0, /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/);
    if (RSTART > 0) {
        ip = substr($0, RSTART, RLENGTH);
        date = $1 " " $2 " " $3;
        print ip ",\"" date "\""
    }
}' >> "$OUTPUT_CSV_DATE"

echo "    -> Saved to <$OUTPUT_CSV_DATE>"

# ============================================================
# Step 2: Country Lookup
# ============================================================

echo "[2/4] Looking up country for each unique IP (this may take a while)..."

echo "IP_ADDRESS,COUNTRY" > "$OUTPUT_CSV"
grep "Failed" "$INPUT_LOG" \
    | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' \
    | sort -u \
    | while read -r ip; do
        country=$(whois "$ip" 2>/dev/null | grep -iE '^country:' | head -n 1 | awk '{print $2}')
        country=${country:-Unknown}

        echo "    $ip -> $country"
        echo "$ip,$country" >> "$OUTPUT_CSV"

        if [ -n "$DISCORD_WEBHOOK_URL" ]; then
            send_discord "$ip" "$country"
        fi

        sleep 0.5
    done

echo "    -> Saved to <$OUTPUT_CSV>"

# ============================================================
# Step 3: Blocklist Generation
# ============================================================

echo "[3/4] Generating blocklist (threshold: >= $THRESHOLD failures)..."

{
    echo "#!/bin/bash"
    echo "# Auto-generated iptables blocklist"
    echo "# Generated : $(date)"
    echo "# Source    : $INPUT_LOG"
    echo "# Threshold : $THRESHOLD failed attempts"
    echo ""
    grep "Failed" "$INPUT_LOG" \
        | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' \
        | sort | uniq -c | sort -nr \
        | awk -v threshold="$THRESHOLD" '
            $1 >= threshold {
                printf "iptables -A INPUT -s %-18s -j DROP  # %d failed attempts\n", $2, $1
            }
        '
} > "$OUTPUT_BLOCKLIST"

chmod +x "$OUTPUT_BLOCKLIST"

blocked_count=$(grep -c "^iptables" "$OUTPUT_BLOCKLIST" 2>/dev/null || echo 0)
echo "    -> $blocked_count IP(s) added to blocklist: <$OUTPUT_BLOCKLIST>"

# ============================================================
# Step 4: Report (Hourly Distribution)
# ============================================================

echo "[4/4] Generating analysis report..."

{
    echo "=============================================="
    echo "  Log Analysis Report"
    echo "  Generated : $(date)"
    echo "  Source    : $INPUT_LOG"
    echo "=============================================="
    echo ""

    total=$(grep -c "Failed" "$INPUT_LOG" || true)
    unique_ips=$(grep "Failed" "$INPUT_LOG" \
        | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' \
        | sort -u | wc -l | tr -d ' ')

    echo "  Total failed attempts : $total"
    echo "  Unique source IPs     : $unique_ips"
    echo ""

    echo "--- Hourly Distribution of Failed Attempts ---"
    echo ""
    grep "Failed" "$INPUT_LOG" \
        | awk '{split($3, t, ":"); print t[1]}' \
        | sort | uniq -c | sort -k2 -n \
        | awk '
            BEGIN { max = 0 }
            { counts[$2] = $1; if ($1 > max) max = $1 }
            END {
                for (h = 0; h < 24; h++) {
                    hour = sprintf("%02d", h)
                    count = (hour in counts) ? counts[hour] : 0
                    bar_len = (max > 0) ? int(count * 30 / max) : 0
                    bar = ""
                    for (i = 0; i < bar_len; i++) bar = bar "#"
                    printf "  %s:00  %-30s  %d\n", hour, bar, count
                }
            }'
    echo ""
} | tee "$OUTPUT_REPORT"

echo "    -> Saved to <$OUTPUT_REPORT>"

# ============================================================
# Summary
# ============================================================

echo ""
echo "Analysis complete! Output files:"
echo "  IP + Date    : $OUTPUT_CSV_DATE"
echo "  IP + Country : $OUTPUT_CSV"
echo "  Blocklist    : $OUTPUT_BLOCKLIST"
echo "  Report       : $OUTPUT_REPORT"
