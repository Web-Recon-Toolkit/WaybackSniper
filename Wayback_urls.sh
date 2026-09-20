#!/usr/bin/env bash

# Color codes
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Banner function
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
           Tool By
         ____ ___ _  _ _  _    _    ____
        |  _ \_ _| |/ / |/ /  / \  |  _ \
        | |_) | || ' /| ' /  / _ \ | |_) |
        |  __/| || . \| . \ / ___ \|  __/
        |_|  |___|_|\_\_|\_/_/   \_\_|
EOF
    echo -e "${RESET}"
}

# Flags parsing
DOMAIN=""
FILE=""
OUT_DIR="archive_output"
COOKIE_FILE=""

usage() {
    echo -e "Usage: $0 [-d domain.com] [-f domains_list.txt] [-c cookie_file.txt] [-o output_directory]"
    echo -e "  -d    Single target domain (e.g. target.com)"
    echo -e "  -f    File containing list of domains"
    echo -e "  -c    Netscape Cookie file (Optional, e.g. cookies.txt)"
    echo -e "  -o    Output directory (Default: archive_output)"
    exit 1
}

# Print banner at the start
print_banner

# Added 'c:' back to getopts so it accepts the cookie flag
while getopts "d:f:c:o:h" opt; do
    case "$opt" in
        d) DOMAIN="$OPTARG" ;;
        f) FILE="$OPTARG" ;;
        c) COOKIE_FILE="$OPTARG" ;;
        o) OUT_DIR="$OPTARG" ;;
        h|*) usage ;;
    esac
done

# Ensure at least one target is provided
if [[ -z "$DOMAIN" && -z "$FILE" ]]; then
    echo -e "${RED}[-] Error: You must provide either the -d or -f flag.${RESET}"
    usage
fi

# Setup output directories
mkdir -p "$OUT_DIR"
EXT_DIR="$OUT_DIR/extensions"
mkdir -p "$EXT_DIR"

RAW_URLS="$OUT_DIR/raw_archive_urls.txt"
FILTERED_HTTPX="$OUT_DIR/httpx_live_urls.txt"
CLEAN_URLS="$OUT_DIR/clean_urls_no_ext.txt"

# Temporary domains list
TARGETS_FILE=$(mktemp)

if [[ -n "$DOMAIN" ]]; then
    echo "$DOMAIN" > "$TARGETS_FILE"
    echo -e "${BLUE}[*] Target Domain: $DOMAIN${RESET}"
else
    if [[ ! -f "$FILE" ]]; then
        echo -e "${RED}[-] Error: File '$FILE' not found!${RESET}"
        exit 1
    fi
    cp "$FILE" "$TARGETS_FILE"
    echo -e "${BLUE}[*] Targets loaded from: $FILE ($(wc -l < "$TARGETS_FILE") domains)${RESET}"
fi

# Step 1: Run GAU & Waybackurls
echo -e "${BLUE}[*] Running GAU and Waybackurls...${RESET}"
TEMP_ARCHIVE=$(mktemp)

while IFS= read -r target || [[ -n "$target" ]]; do
    [[ -z "$target" ]] && continue
    echo -e "    -> Fetching for: $target"
    echo "$target" | gau --subs --threads 10 2>/dev/null >> "$TEMP_ARCHIVE"
    echo "$target" | waybackurls 2>/dev/null >> "$TEMP_ARCHIVE"
done < "$TARGETS_FILE"

# Deduplicate raw archives
sort -u "$TEMP_ARCHIVE" > "$RAW_URLS"
rm -f "$TEMP_ARCHIVE" "$TARGETS_FILE"

TOTAL_RAW=$(wc -l < "$RAW_URLS")
echo -e "${GREEN}[+] Total unique archive URLs collected: $TOTAL_RAW${RESET}"
echo -e "    Saved to: $RAW_URLS"

# Stop script if no archive URLs were found
if [[ "$TOTAL_RAW" -eq 0 ]]; then
    echo -e "${RED}[-] No archive URLs found. Exiting.${RESET}"
    exit 1
fi

# Step 2: Run httpx for 200, 301, 302, 403
echo -e "${BLUE}[*] Running httpx (Status codes: 200, 301, 302, 403)...${RESET}"

# HTTPX arguments safely stored in an array to avoid breaking syntax
HTTPX_ARGS=(-l "$RAW_URLS" -mc 200,301,302,403 -silent -threads 150 -rl 1500 -follow-redirects=false -o "$FILTERED_HTTPX")

# Check if cookie file is passed and exists, then parse it and add to array
if [[ -n "$COOKIE_FILE" && -f "$COOKIE_FILE" ]]; then
    COOKIE_DATA=$(grep -v '^#' "$COOKIE_FILE" | grep -v '^\s*$' | awk '{print $6"="$7}' | paste -sd "; " -)
    HTTPX_ARGS+=(-H "Cookie: $COOKIE_DATA")
    echo -e "${GREEN}[+] Cookie file loaded: $COOKIE_FILE${RESET}"
elif [[ -n "$COOKIE_FILE" ]]; then
    echo -e "${RED}[-] Error: Cookie file '$COOKIE_FILE' not found!${RESET}"
    exit 1
fi

# Safely execute httpx
httpx "${HTTPX_ARGS[@]}"

# Prevent Python FileNotFoundError by ensuring the file exists
if [[ ! -f "$FILTERED_HTTPX" ]]; then
    touch "$FILTERED_HTTPX"
fi

TOTAL_LIVE=$(wc -l < "$FILTERED_HTTPX")
echo -e "${GREEN}[+] Total live URLs matched: $TOTAL_LIVE${RESET}"
echo -e "    Saved to: $FILTERED_HTTPX"

# Skip Python block if httpx yields no results
if [[ "$TOTAL_LIVE" -eq 0 ]]; then
    echo -e "${YELLOW}[!] No live URLs found! Skipping the Python processing step.${RESET}"
    exit 0
fi

# Step 3: Parse extensions and clean URLs using Python
echo -e "${BLUE}[*] Sorting extensions and separating clean URLs...${RESET}"

python3 - <<EOF
import os
from urllib.parse import urlparse

live_file = "$FILTERED_HTTPX"
clean_file = "$CLEAN_URLS"
ext_dir = "$EXT_DIR"

clean_urls = []
ext_buckets = {}

with open(live_file, "r") as f:
    for line in f:
        url = line.strip()
        if not url:
            continue
        
        parsed = urlparse(url)
        path = parsed.path.lower()
        
        basename = os.path.basename(path)
        
        if "." in basename:
            ext = basename.rsplit(".", 1)[-1]
            if ext.isalnum() and len(ext) <= 6:
                ext_buckets.setdefault(ext, []).append(url)
            else:
                clean_urls.append(url)
        else:
            clean_urls.append(url)

with open(clean_file, "w") as f:
    for u in sorted(set(clean_urls)):
        f.write(u + "\n")

for ext, urls in ext_buckets.items():
    ext_file = os.path.join(ext_dir, f"{ext}_files.txt")
    with open(ext_file, "w") as f:
        for u in sorted(set(urls)):
            f.write(u + "\n")

print(f"[*] Processed {len(ext_buckets)} distinct extension categories.")
EOF

echo -e "${GREEN}[+] Workflow Complete!${RESET}"
echo -e "    Clean endpoints: $CLEAN_URLS"
echo -e "    Extension files: $EXT_DIR/"
