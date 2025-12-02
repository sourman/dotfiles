#!/bin/bash

# Supabase Edge Function Logs Query Tool
# Usage: ./get-function-logs.sh [OPTIONS] <function-name-or-id>
#
# Examples:
#   ./get-function-logs.sh amplitude-sync-worker
#   ./get-function-logs.sh -t 7d -e Log amplitude-sync-worker
#   ./get-function-logs.sh -t 24h -s "error" -l 50 amplitude-sync-worker
#   ./get-function-logs.sh -f e3015d5d-0e92-4c89-924d-de9836b2ebfd -t 1d

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
TIME_RANGE="24h"
EVENT_TYPE="all"
SEARCH_TERM=""
LIMIT=100
FUNCTION_ID=""
FUNCTION_NAMES=()
OUTPUT_FORMAT="pretty"
SHOW_METADATA=false

# Help function
show_help() {
    echo -e "$(cat << EOF
${GREEN}Supabase Edge Function Logs Query Tool${NC}

${BLUE}Usage:${NC}
  $0 [OPTIONS] <function-name-or-id> [function-name-or-id ...]

${BLUE}Options:${NC}
  -t, --time-range TIME     Time range (e.g., 24h, 7d, 30d) [default: 24h]
  -e, --event-type TYPE      Event type filter (Log, Shutdown, Invocation, Error) [default: all]
                             Use 'all' to get all event types
  -s, --search TERM          Search term for filtering log messages
  -l, --limit NUM            Maximum number of logs to return [default: 100]
  -f, --function-id ID       Use function ID directly (skips lookup)
  -m, --metadata             Include metadata fields in output
  -j, --json                 Output raw JSON instead of formatted
  -h, --help                 Show this help message

${BLUE}Examples:${NC}
  # Get console logs for last 24 hours
  $0 amplitude-sync-worker

  # Get logs for last 7 days
  $0 -t 7d amplitude-sync-worker

  # Search for errors in last 24 hours
  $0 -s "error" amplitude-sync-worker

  # Get logs event types (exclude system logs like CPU Timeout, Memory Limit Exceeded)
  $0 -e Log amplitude-sync-worker

  # Use function ID directly
  $0 -f e3015d5d-0e92-4c89-924d-de9836b2ebfd -t 1d

  # Get logs with metadata
  $0 -m amplitude-sync-worker

  # Get logs for multiple functions (sorted by timestamp)
  $0 -t 1h amplitude-sync-worker amplitude-sync-planner

EOF
)"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--time-range)
            TIME_RANGE="$2"
            shift 2
            ;;
        -e|--event-type)
            EVENT_TYPE="$2"
            shift 2
            ;;
        -s|--search)
            SEARCH_TERM="$2"
            shift 2
            ;;
        -l|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -f|--function-id)
            FUNCTION_ID="$2"
            shift 2
            ;;
        -m|--metadata)
            SHOW_METADATA=true
            shift
            ;;
        -j|--json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            show_help
            exit 1
            ;;
        *)
            FUNCTION_NAMES+=("$1")
            shift
            ;;
    esac
done

# Check if function name or ID provided
if [[ -z "$FUNCTION_ID" && ${#FUNCTION_NAMES[@]} -eq 0 ]]; then
    echo -e "${RED}Error: Function name or ID required${NC}" >&2
    show_help
    exit 1
fi

# Source .env.local if it exists
if [[ -f ".env.local" ]]; then
    set -a
    source .env.local
    set +a
else
    echo -e "${YELLOW}Warning: .env.local not found. Make sure SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_REF are set.${NC}" >&2
fi

# Check required environment variables
if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
    echo -e "${RED}Error: SUPABASE_ACCESS_TOKEN not set${NC}" >&2
    exit 1
fi

if [[ -z "${SUPABASE_PROJECT_REF:-}" ]]; then
    echo -e "${RED}Error: SUPABASE_PROJECT_REF not set${NC}" >&2
    exit 1
fi

# Get function IDs and build function name mapping
declare -A FUNCTION_ID_TO_NAME
FUNCTION_IDS=()

if [[ -n "$FUNCTION_ID" ]]; then
    echo -e "${BLUE}Looking up function name for ID: ${FUNCTION_ID}${NC}" >&2
    FUNCTION_DATA=$(curl -s -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
        "https://api.supabase.com/v1/projects/${SUPABASE_PROJECT_REF}/functions" 2>/dev/null)
    FUNCTION_NAME=$(echo "$FUNCTION_DATA" | python3 -c "import sys, json; data = json.load(sys.stdin); funcs = data.get('functions', []); found = [f.get('name', '') for f in funcs if f.get('id') == sys.argv[1]]; print(found[0] if found else '')" "$FUNCTION_ID" 2>/dev/null || echo "")
    
    if [[ -z "$FUNCTION_NAME" ]]; then
        FUNCTION_NAME="unknown"
    fi
    FUNCTION_IDS+=("$FUNCTION_ID")
    FUNCTION_ID_TO_NAME["$FUNCTION_ID"]="$FUNCTION_NAME"
    echo -e "${GREEN}Found function: ${FUNCTION_NAME} (${FUNCTION_ID})${NC}" >&2
else
    for FUNC_NAME in "${FUNCTION_NAMES[@]}"; do
        echo -e "${BLUE}Looking up function ID for: ${FUNC_NAME}${NC}" >&2
        FUNCTION_DATA=$(curl -s -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
            "https://api.supabase.com/v1/projects/${SUPABASE_PROJECT_REF}/functions/${FUNC_NAME}" 2>/dev/null)
        FUNC_ID=$(echo "$FUNCTION_DATA" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('id', ''))" 2>/dev/null || echo "")
        
        if [[ -z "$FUNC_ID" ]]; then
            echo -e "${RED}Error: Could not find function '${FUNC_NAME}'${NC}" >&2
            exit 1
        fi
        FUNCTION_IDS+=("$FUNC_ID")
        FUNCTION_ID_TO_NAME["$FUNC_ID"]="$FUNC_NAME"
        echo -e "${GREEN}Found function: ${FUNC_NAME} (${FUNC_ID})${NC}" >&2
    done
fi

# Build function ID list for SQL IN clause
FUNCTION_ID_LIST=""
for ID in "${FUNCTION_IDS[@]}"; do
    if [[ -z "$FUNCTION_ID_LIST" ]]; then
        FUNCTION_ID_LIST="'${ID}'"
    else
        FUNCTION_ID_LIST="${FUNCTION_ID_LIST}, '${ID}'"
    fi
done

# Parse time range
parse_time_range() {
    local time_str="$1"
    local amount="${time_str%[hd]}"
    local unit="${time_str: -1}"
    
    case "$unit" in
        h)
            echo "$(date -u -d "${amount} hours ago" +"%Y-%m-%dT%H:%M:%SZ")"
            ;;
        d)
            echo "$(date -u -d "${amount} days ago" +"%Y-%m-%dT%H:%M:%SZ")"
            ;;
        *)
            echo -e "${RED}Error: Invalid time unit. Use 'h' for hours or 'd' for days${NC}" >&2
            exit 1
            ;;
    esac
}

# Calculate time range
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(parse_time_range "$TIME_RANGE")

# Build SQL query
SQL_SELECT="SELECT id, timestamp, event_message, metadata, metadata[OFFSET(0)].function_id as function_id"
if [[ "$SHOW_METADATA" == true ]]; then
    SQL_SELECT="${SQL_SELECT}, metadata[OFFSET(0)].level as level, metadata[OFFSET(0)].execution_id as execution_id, metadata[OFFSET(0)].version as version, metadata[OFFSET(0)].event_type as event_type"
fi

SQL_WHERE="metadata[OFFSET(0)].function_id IN (${FUNCTION_ID_LIST})"

# Add event type filter
if [[ "$EVENT_TYPE" != "all" ]]; then
    SQL_WHERE="${SQL_WHERE} AND metadata[OFFSET(0)].event_type = '${EVENT_TYPE}'"
fi

# Add search term filter
if [[ -n "$SEARCH_TERM" ]]; then
    SQL_WHERE="${SQL_WHERE} AND event_message LIKE '%${SEARCH_TERM}%'"
fi

SQL_QUERY="${SQL_SELECT} FROM function_logs WHERE ${SQL_WHERE} ORDER BY timestamp DESC LIMIT ${LIMIT}"

# URL encode the SQL query
ENCODED_SQL=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$SQL_QUERY")

# Build API URL
API_URL="https://api.supabase.com/v1/projects/${SUPABASE_PROJECT_REF}/analytics/endpoints/logs.all?sql=${ENCODED_SQL}&iso_timestamp_start=${START_TIME}&iso_timestamp_end=${END_TIME}"

# Make API request
echo -e "${BLUE}Querying logs (${TIME_RANGE} range)...${NC}" >&2
RESPONSE=$(curl -s -X GET \
    "$API_URL" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json")

# Check for errors
ERROR=$(echo "$RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); err = data.get('error'); print(err if err and err != 'null' else '')" 2>/dev/null || echo "")

if [[ -n "$ERROR" ]]; then
    echo -e "${RED}Error from API:${NC}" >&2
    echo "$RESPONSE" | python3 -m json.tool >&2
    exit 1
fi

# Process output
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo "$RESPONSE" | python3 -m json.tool
else
    # Pretty output
    LOG_COUNT=$(echo "$RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('result', [])))" 2>/dev/null || echo "0")
    
    if [[ "$LOG_COUNT" == "0" ]]; then
        FUNC_LIST=$(IFS=', '; echo "${FUNCTION_NAMES[*]:-${FUNCTION_ID}}")
        echo -e "${YELLOW}No logs found for function(s) ${FUNC_LIST} in the last ${TIME_RANGE}${NC}"
        echo -e "${BLUE}Try:${NC}"
        echo -e "  - Increase time range: -t 7d"
        echo -e "  - Remove event type filter: -e all"
        echo -e "  - Check if function has run recently"
        exit 0
    fi
    
    echo -e "${GREEN}Found ${LOG_COUNT} log(s)${NC}"
    
    # Build function ID to name mapping JSON for Python
    FUNCTION_MAP_JSON="{"
    FIRST=true
    for ID in "${!FUNCTION_ID_TO_NAME[@]}"; do
        if [[ "$FIRST" == true ]]; then
            FUNCTION_MAP_JSON="${FUNCTION_MAP_JSON}\"${ID}\":\"${FUNCTION_ID_TO_NAME[$ID]}\""
            FIRST=false
        else
            FUNCTION_MAP_JSON="${FUNCTION_MAP_JSON},\"${ID}\":\"${FUNCTION_ID_TO_NAME[$ID]}\""
        fi
    done
    FUNCTION_MAP_JSON="${FUNCTION_MAP_JSON}}"
    
    # Print logs
    SHOW_FUNCTION_TAG=$([[ ${#FUNCTION_IDS[@]} -gt 1 ]] && echo "true" || echo "false")
    # Debug: print function map to stderr if multiple functions
    if [[ ${#FUNCTION_IDS[@]} -gt 1 ]]; then
        echo -e "${BLUE}Function map: ${FUNCTION_MAP_JSON}${NC}" >&2
        echo -e "${BLUE}Function IDs: ${FUNCTION_IDS[*]}${NC}" >&2
    fi
    
    # Bash pretty output using echo -e to render colors
    # Get logs as JSON array
    LOGJSON=$(echo "$RESPONSE" | python3 -c "import sys, json; d = json.load(sys.stdin); print(json.dumps(d.get('result', [])))" 2>/dev/null)
    # Get function map for lookup
    declare -A FUNC_MAP
    while read -r pair; do
        key="${pair%%:*}"
        value="${pair#*:}"
        FUNC_MAP["$key"]="$value"
    done < <(echo "$FUNCTION_MAP_JSON" | python3 -c "import sys, json; d=json.load(sys.stdin); print('\n'.join([f'{k}:{v}' for k,v in d.items()]))")
    # Print logs with color using echo -e
    PYTHON_FORMATTER=$(cat <<'PYEOF'
import sys, json
import re
from datetime import datetime
import os

logs = json.loads(sys.argv[1])
func_map = json.loads(sys.argv[2])
show_function_tag = sys.argv[3] == "true"
PURPLE = os.environ.get('COLOR_PURPLE', '')
YELLOW = os.environ.get('COLOR_YELLOW', '')
CYAN = os.environ.get('COLOR_CYAN', '')
NC = os.environ.get('COLOR_NC', '')

total_logs = len(logs)
for i, log in enumerate(logs, 1):
    # Reverse numbering: newest log (first in array) gets highest number
    reverse_index = total_logs - i + 1
    ts = log.get("timestamp", 0)
    if ts:
        dt = datetime.fromtimestamp(ts / 1000000)
        time_str = dt.strftime('%Y-%m-%d %H:%M:%S')
    else:
        time_str = "N/A"
    event_msg = log.get("event_message", "")
    event_msg = re.sub(r'^\s+|\s+$', '', event_msg)
    func_id = log.get("function_id") or log.get("functionId") or ""
    if not func_id:
        meta = log.get("metadata", [])
        if isinstance(meta, list) and len(meta) > 0 and isinstance(meta[0], dict):
            func_id = meta[0].get("function_id") or meta[0].get("functionId") or ""
    func_name = func_map.get(func_id) if func_id in func_map else "unknown"
    # Build line to print
    if show_function_tag:
        func_tag = "[" + func_name + "]"
        line = f"{PURPLE}[{reverse_index}]{NC} {YELLOW}{time_str}{NC} {CYAN}{func_tag}{NC} {event_msg}"
    else:
        line = f"{PURPLE}[{reverse_index}]{NC} {YELLOW}{time_str}{NC} {event_msg}"
    print(line)
PYEOF
)
    # Actually print, line by line, evaluating escapes for color codes
    export COLOR_PURPLE="$PURPLE" COLOR_YELLOW="$YELLOW" COLOR_CYAN="$CYAN" COLOR_NC="$NC"
    while IFS= read -r pline; do
        # Use echo -e to interpret ANSI color escapes
        echo -e "$pline"
    done < <(
        python3 -c "$PYTHON_FORMATTER" \
          "$LOGJSON" \
          "$FUNCTION_MAP_JSON" \
          "$SHOW_FUNCTION_TAG"
    )
fi

