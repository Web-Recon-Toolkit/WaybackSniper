# Wayback_urls.sh - Historical URL Scraper & Sorter

## 🎯 Purpose of the Tool
When bug hunting, exploring the historical footprint of a target is crucial. Developers often hide or deprecate old endpoints (like `api/v1/`) but leave them running on the backend. 

`Wayback_urls.sh` is an automated wrapper script designed to streamline this process. It eliminates the manual work of scraping archives, removing dead links, and sorting through the noise. Instead of staring at millions of raw, dead URLs, this tool hands you a clean, organized list of **only the endpoints that are actively alive right now**, neatly categorized by file type.

## ✨ What It Can Do
1.  **Aggressive Scraping:** It runs both `gau` (GetAllUrls) and `waybackurls` simultaneously against your target(s) to pull every historical URL indexed by the Wayback Machine, AlienVault, and CommonCrawl.
2.  **Liveness Verification:** It automatically pipes the massive raw list into `httpx` to verify which URLs are still alive and returning valid status codes (`200`, `301`, `302`, `403`, `500`), stripping out all the dead `404` noise.
3.  **Authenticated Probing:** It supports passing a Netscape Cookie file, allowing `httpx` to probe the endpoints as a logged-in user, uncovering endpoints hidden behind authentication walls.
4.  **Smart Categorization (Python):** It parses the final live URLs and sorts them into a dedicated `extensions/` folder based on their file type (e.g., all `.js` files go into `js_files.txt`, all `.php` files go into `php_files.txt`). Clean API endpoints without extensions are saved separately.

---

## 🛠️ Installation Process

### Dependencies & Tools Required
This script acts as a conductor for three powerful Go-based hacking tools. You must have them installed and accessible in your system's `$PATH`:
*   **gau** (`github.com/lc/gau/v2/cmd/gau`)
*   **waybackurls** (`github.com/tomnomnom/waybackurls`)
*   **httpx** (`github.com/projectdiscovery/httpx/cmd/httpx`)
*   **Python 3** (Pre-installed on almost all Linux distributions)

### Easy Beginner Installation Steps

**1. Install Go (If you haven't already)**
```bash
sudo apt update
sudo apt install golang -y
```

**2. Install the Required Go Tools**
Run the following commands to download and install the tools. (Make sure `~/go/bin` is added to your `$PATH`!).
```bash
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/waybackurls@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
```

**3. Make the Script Executable**
Navigate to the folder containing `Wayback_urls.sh` and give it execute permissions:
```bash
chmod +x Wayback_urls.sh
```

---

## 🚀 Usage & Example Output

### How to Run
You can scan a single domain using `-d` or a list of domains using `-f`. 

**Basic Scan (Single Domain):**
```bash
./Wayback_urls.sh -d target.com
```

**Advanced Scan (List of domains + Authenticated Cookies):**
```bash
./Wayback_urls.sh -f subdomains.txt -c cookies.txt -o my_custom_output
```

### Example Output
When you run the tool, you will see a clean, colorized output guiding you through the steps:

```text
           Tool By
         ____ ___ _  _ _  _    _    ____
        |  _ \_ _| |/ / |/ /  / \  |  _ \
        | |_) | || ' /| ' /  / _ \ | |_) |
        |  __/| || . \| . \ / ___ \|  __/
        |_|  |___|_|\_\_|\_/_/   \_\_|

[*] Target Domain: target.com
[*] Running GAU and Waybackurls...
    -> Fetching for: target.com
[+] Total unique archive URLs collected: 14502
    Saved to: archive_output/raw_archive_urls.txt
[*] Running httpx (Status codes: 200, 301, 302, 403)...
[+] Total live URLs matched: 421
    Saved to: archive_output/httpx_live_urls.txt
[*] Sorting extensions and separating clean URLs...
[*] Processed 5 distinct extension categories.
[+] Workflow Complete!
    Clean endpoints: archive_output/clean_urls_no_ext.txt
    Extension files: archive_output/extensions/
```

### Navigating the Results
After the script finishes, check the `archive_output/` folder (or the custom folder you defined with `-o`). 
*   **`clean_urls_no_ext.txt`**: Open this to find pure API routes (e.g., `https://target.com/api/v1/user/details`).
*   **`extensions/js_files.txt`**: Open this to find all the JavaScript files you can download and analyze for hidden secrets. 
*   **`extensions/php_files.txt`**: Open this to look for parameters vulnerable to SQL Injection!
