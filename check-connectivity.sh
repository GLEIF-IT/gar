#!/bin/bash

##################################################################
##                                                              ##
##          Connectivity check for QARs and Witnesses           ##
##                                                              ##
##################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

check_url() {
    local label=$1
    local url=$2
    local http_code

    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url")
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
        echo -e "${GREEN}[OK]${NC}   $label ($http_code) - $url"
    else
        echo -e "${RED}[FAIL]${NC} $label ($http_code) - $url"
    fi
}

echo "=== QAR Connectivity ==="
check_url "QAR1" "http://103.145.42.173:3902/oobi/EKOxfxc96O3-NToaQcPczVKT8pyvXAMK7pb6zLDmJcRj/agent/EIfjEczKc-Wtey_Atamo9yq1O8XkpdK9hhQMLsScmmYz"
check_url "QAR2" "http://103.145.42.173:3902/oobi/EFglXcQgeEBidw5Xr_QZfqAbvb0Mjxs-nBs40rixU0u7/agent/EGlPJGNFSTv7_t6VuPuXguYrIgPTFI9IGYH9aO4Ysdma"
check_url "QAR3" "http://103.145.42.173:3902/oobi/ELJvHKGl6c13SoM-WaKOgVx9U7SbL4kEjGAu6PDddjC5/agent/EHC2xaMNirQZXnUBETisbxRcfSW0euHDpY2nxHR_XuDL"

echo ""
echo "=== Witness Pool Connectivity ==="
check_url "Witness 1 (115.172.32.109:5642)" "http://115.172.32.109:5642/oobi"
check_url "Witness 2 (115.172.32.112:5643)" "http://115.172.32.112:5643/oobi"
check_url "Witness 3 (115.172.32.118:5644)" "http://115.172.32.118:5644/oobi"
check_url "Witness 4 (103.145.42.160:5646)" "http://103.145.42.160:5646/oobi"
check_url "Witness 5 (115.172.32.43:5645)"  "http://115.172.32.43:5645/oobi"
