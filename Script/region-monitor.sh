#!/bin/bash
# region_monitor.sh - Enhanced real-time region monitoring with failover detection
# Version 2.0 - Added error handling, rate limiting, and AWS metadata verification

echo "🌍 Enhanced Region Monitoring for app.coreservetest.co.uk"
echo "============================================================="
echo "ℹ️  Tip: Run 'sudo apt install jq dnsutils' if missing dependencies"
echo ""

# Configuration
CHECK_INTERVAL=5  
IP_API_LIMIT=45   

# Initialize counters
request_count=0
start_time=$(date +%s)

monitor_region() {
    while true; do
        # Rate limiting for ip-api.com
        current_time=$(date +%s)
        if (( request_count >= IP_API_LIMIT && (current_time - start_time) < 60 )); then
            echo -e "\033[0;33m[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  Rate limit reached for IP geolocation API\033[0m"
            sleep $((60 - (current_time - start_time)))
            request_count=0
            start_time=$(date +%s)
            continue
        fi

        # Get current timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Enhanced DNS resolution with timeout
        raw_output=$(timeout 5 dig +short app.coreservetest.co.uk 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo -e "\r\033[K[\033[0;31m$timestamp\033[0m] ❌ DNS QUERY TIMED OUT"
            sleep $CHECK_INTERVAL
            continue
        fi
        
        ips=$(echo "$raw_output" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort | tr '\n' ' ')
        
        # If no direct IPs, follow CNAME chain (max 2 hops)
        if [ -z "$ips" ]; then
            cname=$(echo "$raw_output" | grep -E '\.' | head -1)
            if [ ! -z "$cname" ]; then
                ips=$(timeout 5 dig +short "$cname" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort | tr '\n' ' ')
                # Second level CNAME check if needed
                if [ -z "$ips" ]; then
                    second_cname=$(timeout 5 dig +short "$cname" 2>/dev/null | grep -E '\.' | head -1)
                    if [ ! -z "$second_cname" ]; then
                        ips=$(timeout 5 dig +short "$second_cname" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort | tr '\n' ' ')
                    fi
                fi
            fi
        fi
        
        # Get geolocation for first IP
        first_ip=$(echo $ips | awk '{print $1}')
        if [ ! -z "$first_ip" ]; then
            # Get location with timeout and error handling
            location_data=$(timeout 5 curl -s "http://ip-api.com/json/$first_ip" 2>/dev/null)
            if [ $? -eq 0 ] && [ ! -z "$location_data" ]; then
                ((request_count++))
                country=$(echo "$location_data" | jq -r '.country // "Unknown"')
                region=$(echo "$location_data" | jq -r '.regionName // "Unknown"')
                location="$country - $region"
                
                # Enhanced region detection
                if [[ "$country" == "United Kingdom" ]]; then
                    region="🇬🇧 PRIMARY (eu-west-2)"
                    status="✅ ACTIVE"
                    color='\033[0;32m' # Green
                elif [[ "$country" == "United States" ]]; then
                    region="🇺🇸 DISASTER RECOVERY (us-east-1)"  
                    status="🔄 FAILOVER"
                    color='\033[0;33m' # Yellow
                else
                    region="🌎 UNEXPECTED REGION"
                    status="⚠️  UNKNOWN"
                    color='\033[0;35m' # Purple
                fi
                
                # Get ALB health from Route53 (if AWS CLI available)
                if command -v aws &>/dev/null; then
                    health_check=$(aws route53 get-health-check-status --health-check-id 33076d25-93af-4e5e-a4f3-1a1e35074182 2>/dev/null | jq -r '.HealthCheckObservations[0].StatusReport.Status')
                    [ ! -z "$health_check" ] && health_status=" | Route53 Health: $health_check"
                fi
                
                # Clear line and print status
                echo -ne "\r\033[K"
                echo -e "${color}[$timestamp] $status | $region | IPs: $ips | Location: $location$health_status\033[0m"
            else
                echo -e "\r\033[K[\033[0;33m$timestamp\033[0m] ⚠️  IP LOCATION SERVICE UNAVAILABLE | IPs: $ips"
            fi
        else
            echo -e "\r\033[K[\033[0;31m$timestamp\033[0m] ❌ DNS RESOLUTION FAILED: No IP addresses found"
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Trap Ctrl+C for clean exit
trap 'echo -e "\n\033[0;36mMonitoring stopped. Goodbye!\033[0m"; exit' INT

echo "Starting monitoring... (Press Ctrl+C to stop)"
echo "Checking every $CHECK_INTERVAL seconds"
echo ""

monitor_region