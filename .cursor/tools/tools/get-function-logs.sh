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
TIME_RANGE="5m"
EVENT_TYPE="all"
SEARCH_TERM=""
LIMIT=100
FUNCTION_ID=""
FUNCTION_NAMES=()
OUTPUT_FORMAT="pretty"
SHOW_METADATA=false
NO_COLOR=false

# Help function
show_help() {
    echo -e "$(cat << EOF
${GREEN}Supabase Edge Function Logs Query Tool${NC}

${BLUE}Usage:${NC}
  $0 [OPTIONS] <function-name-or-id> [function-name-or-id ...]

${BLUE}Options:${NC}
  -t, --time-range TIME     Time range (e.g., 5m, 30m, 24h, 7d, 30d) [default: 5m]
  -e, --event-type TYPE      Event type filter (Log, Shutdown, Invocation, Error) [default: all]
                             Use 'all' to get all event types
  -s, --search TERM          Search term for filtering log messages
  -l, --limit NUM            Maximum number of logs to return [default: 100]
  -f, --function-id ID       Use function ID directly (skips lookup)
  -m, --metadata             Include metadata fields in output
  -j, --json                 Output raw JSON instead of formatted
  -n, --no-color             Disable colorized output
  -h, --help                 Show this help message

${BLUE}Examples:${NC}
  # Get console logs for last 5 minutes
  $0 amplitude-sync-worker

  # Get logs for last 30 minutes
  $0 -t 30m amplitude-sync-worker

  # Search for errors in last 5 minutes
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
        -n|--no-color)
            NO_COLOR=true
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

# Disable colors if --no-color flag is set
if [[ "$NO_COLOR" == true ]]; then
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    PURPLE=""
    CYAN=""
    NC=""
fi

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

# Activate venv for python3 if it is not already activated
if [ -d ".venv" ] && [ -z "${VIRTUAL_ENV:-}" ]; then
    source .venv/bin/activate
    echo "✓ Activated python environment in .venv" >&2
    echo "✓ Using Python: $(which python3)" >&2
fi

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
    local amount="${time_str%[mhd]}"
    local unit="${time_str: -1}"
    
    case "$unit" in
        m)
            echo "$(date -u -d "${amount} minutes ago" +"%Y-%m-%dT%H:%M:%SZ")"
            ;;
        h)
            echo "$(date -u -d "${amount} hours ago" +"%Y-%m-%dT%H:%M:%SZ")"
            ;;
        d)
            echo "$(date -u -d "${amount} days ago" +"%Y-%m-%dT%H:%M:%SZ")"
            ;;
        *)
            echo -e "${RED}Error: Invalid time unit. Use 'm' for minutes, 'h' for hours, or 'd' for days${NC}" >&2
            exit 1
            ;;
    esac
}

# Calculate time range
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(parse_time_range "$TIME_RANGE")

# Validate that START_TIME was parsed correctly
if [[ -z "$START_TIME" ]] || [[ "$START_TIME" == *"Error"* ]]; then
    echo -e "${RED}Error: Failed to parse time range '${TIME_RANGE}'${NC}" >&2
    exit 1
fi

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

# Build base API URL
BASE_URL="https://api.supabase.com/v1/projects/${SUPABASE_PROJECT_REF}/analytics/endpoints/logs.all"

# Calculate time range in hours to detect if we need chunking
# Supabase API has a bug where URL timestamp params fail for ranges > ~46 hours
# We'll query in 46-hour chunks and combine results
START_TIMESTAMP=$(python3 -c "from datetime import datetime; dt = datetime.fromisoformat('${START_TIME}'.replace('Z', '+00:00')); print(int(dt.timestamp()))" 2>/dev/null || echo "0")
END_TIMESTAMP=$(python3 -c "from datetime import datetime; dt = datetime.fromisoformat('${END_TIME}'.replace('Z', '+00:00')); print(int(dt.timestamp()))" 2>/dev/null || echo "0")
RANGE_HOURS=$(( (END_TIMESTAMP - START_TIMESTAMP) / 3600 ))

# Make API request using curl with --get and --data-urlencode for proper parameter encoding
echo -e "${BLUE}Querying logs (${TIME_RANGE} range)...${NC}" >&2
echo -e "${CYAN}Time range: ${START_TIME} to ${END_TIME}${NC}" >&2
if [[ "${DEBUG:-}" == "1" ]]; then
    echo -e "${CYAN}SQL Query: ${SQL_QUERY}${NC}" >&2
    echo -e "${CYAN}Range: ${RANGE_HOURS} hours${NC}" >&2
fi

# If range > 46 hours, query in chunks to work around API bug
if [[ $RANGE_HOURS -gt 46 ]]; then
    echo -e "${YELLOW}Note: Range exceeds 46 hours. Querying in chunks to work around API limitation...${NC}" >&2
    CHUNK_SIZE=46
    ALL_RESULTS=()
    CURRENT_END_TS=$END_TIMESTAMP
    START_TS=$START_TIMESTAMP
    CHUNK_NUM=0
    
    CHUNK_ERRORS=()
    HTTP_CODE="200"
    
    while [[ $CURRENT_END_TS -gt $START_TS ]]; do
        CHUNK_NUM=$((CHUNK_NUM + 1))
        CURRENT_START_TS=$((CURRENT_END_TS - (CHUNK_SIZE * 3600)))
        if [[ $CURRENT_START_TS -lt $START_TS ]]; then
            CURRENT_START_TS=$START_TS
        fi
        
        CURRENT_START=$(date -u -d "@${CURRENT_START_TS}" +"%Y-%m-%dT%H:%M:%SZ")
        CURRENT_END=$(date -u -d "@${CURRENT_END_TS}" +"%Y-%m-%dT%H:%M:%SZ")
        
        echo -e "${CYAN}Chunk ${CHUNK_NUM}: ${CURRENT_START} to ${CURRENT_END}${NC}" >&2
        
        # Query this chunk with timeout, capturing HTTP status code
        CHUNK_HTTP_CODE=$(timeout 30 curl -s -o /tmp/curl_chunk_${CHUNK_NUM}_$$ -w "%{http_code}" -X GET \
            --get \
            --data-urlencode "sql=${SQL_QUERY}" \
            --data-urlencode "iso_timestamp_start=${CURRENT_START}" \
            --data-urlencode "iso_timestamp_end=${CURRENT_END}" \
            "$BASE_URL" \
            -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
            -H "Content-Type: application/json" 2>&1) || CURL_EXIT_CODE=$?
        
        if [[ ${CURL_EXIT_CODE:-0} -ne 0 ]]; then
            echo -e "${RED}Error: curl timeout or failure for chunk ${CHUNK_NUM}${NC}" >&2
            CHUNK_ERRORS+=("Chunk ${CHUNK_NUM}: curl failed with exit code ${CURL_EXIT_CODE}")
            HTTP_CODE="000"
            break
        fi
        
        # Check HTTP status code for this chunk
        if [[ "$CHUNK_HTTP_CODE" != "200" ]]; then
            echo -e "${RED}Error: HTTP ${CHUNK_HTTP_CODE} from API for chunk ${CHUNK_NUM}${NC}" >&2
            CHUNK_RESPONSE=$(cat /tmp/curl_chunk_${CHUNK_NUM}_$$ 2>/dev/null || echo "")
            echo -e "${YELLOW}Response:${NC}" >&2
            echo "$CHUNK_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$CHUNK_RESPONSE" >&2
            CHUNK_ERRORS+=("Chunk ${CHUNK_NUM}: HTTP ${CHUNK_HTTP_CODE}")
            HTTP_CODE="$CHUNK_HTTP_CODE"
            rm -f /tmp/curl_chunk_${CHUNK_NUM}_$$
            break
        fi
        
        CHUNK_RESPONSE=$(cat /tmp/curl_chunk_${CHUNK_NUM}_$$)
        rm -f /tmp/curl_chunk_${CHUNK_NUM}_$$
        
        # Extract results from chunk
        CHUNK_RESULTS=$(echo "$CHUNK_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(json.dumps(d.get('result', [])))" 2>/dev/null || echo "[]")
        CHUNK_COUNT=$(echo "$CHUNK_RESULTS" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
        echo -e "${GREEN}Chunk ${CHUNK_NUM}: Found ${CHUNK_COUNT} logs${NC}" >&2
        
        # Append to results array
        if [[ "$CHUNK_RESULTS" != "[]" ]]; then
            ALL_RESULTS+=("$CHUNK_RESULTS")
        fi
        
        # Move to next chunk
        CURRENT_END_TS=$CURRENT_START_TS
        
        if [[ $CURRENT_START_TS -le $START_TS ]]; then
            break
        fi
    done
    
    # Report chunk errors if any occurred
    if [[ ${#CHUNK_ERRORS[@]} -gt 0 ]]; then
        echo -e "${RED}Errors occurred during chunked query:${NC}" >&2
        for error in "${CHUNK_ERRORS[@]}"; do
            echo -e "${RED}  - ${error}${NC}" >&2
        done
    fi
    
    # Merge all results
    echo -e "${BLUE}Merging ${#ALL_RESULTS[@]} chunks...${NC}" >&2
    if [[ ${#ALL_RESULTS[@]} -eq 0 ]]; then
        RESPONSE='{"result": [], "error": null}'
    else
        MERGE_INPUT=$(printf '%s\n' "${ALL_RESULTS[@]}")
        RESPONSE=$(echo "$MERGE_INPUT" | python3 -c "
import sys, json
all_logs = []
for line in sys.stdin:
    if line.strip():
        try:
            logs = json.loads(line)
            all_logs.extend(logs)
        except:
            pass
# Deduplicate by id
seen = set()
unique_logs = []
for log in all_logs:
    log_id = log.get('id')
    if log_id and log_id not in seen:
        seen.add(log_id)
        unique_logs.append(log)
# Sort by timestamp descending
unique_logs.sort(key=lambda x: x.get('timestamp', 0), reverse=True)
print(json.dumps({'result': unique_logs, 'error': None}))
" 2>/dev/null || echo '{"result": [], "error": null}')
    fi
else
    # Normal query for ranges <= 46 hours
    echo -e "${BLUE}Querying API (single request)...${NC}" >&2
    HTTP_CODE=$(timeout 30 curl -s -o /tmp/curl_response_$$ -w "%{http_code}" -X GET \
        --get \
        --data-urlencode "sql=${SQL_QUERY}" \
        --data-urlencode "iso_timestamp_start=${START_TIME}" \
        --data-urlencode "iso_timestamp_end=${END_TIME}" \
        "$BASE_URL" \
        -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
        -H "Content-Type: application/json" 2>&1) || CURL_EXIT_CODE=$?
    
    if [[ ${CURL_EXIT_CODE:-0} -ne 0 ]]; then
        echo -e "${RED}Error: curl timeout or failure${NC}" >&2
        exit 1
    fi
    
    RESPONSE=$(cat /tmp/curl_response_$$)
    rm -f /tmp/curl_response_$$
fi

# Check HTTP status code
if [[ "$HTTP_CODE" != "200" ]]; then
    echo -e "${RED}Error: HTTP ${HTTP_CODE} from API${NC}" >&2
    echo -e "${YELLOW}Response:${NC}" >&2
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE" >&2
    exit 1
fi

# Check for errors - check both 'error' field and HTTP status codes
ERROR=$(echo "$RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); err = data.get('error'); print(err if err and err != 'null' and err else '')" 2>/dev/null || echo "")

if [[ -n "$ERROR" ]]; then
    echo -e "${RED}Error from API:${NC}" >&2
    echo "$RESPONSE" | python3 -m json.tool >&2
    exit 1
fi

# Check if response is valid JSON and has expected structure
if ! echo "$RESPONSE" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
    echo -e "${RED}Error: Invalid JSON response from API${NC}" >&2
    echo -e "${YELLOW}Response:${NC}" >&2
    echo "$RESPONSE" >&2
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
        
        # Debug: show API response structure and error if present
        RESPONSE_DEBUG=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"Response keys: {list(data.keys())}\")
print(f\"Result length: {len(data.get('result', []))}\")
err = data.get('error')
if err and err != 'null' and err:
    print(f\"Error field: {err}\")
# Print full response if DEBUG is set
import os
if os.environ.get('DEBUG') == '1':
    print(f\"Full response: {json.dumps(data, indent=2)}\")
" 2>/dev/null || echo "Could not parse response")
        echo -e "${CYAN}Debug info: ${RESPONSE_DEBUG}${NC}" >&2
        
        echo -e "${BLUE}Try:${NC}"
        echo -e "  - Increase time range: -t 30m"
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
    # Use stdin for LOGJSON to avoid "Argument list too long" error with large result sets
    PYTHON_FORMATTER=$(cat <<'PYEOF'
import sys, json
import re
from datetime import datetime
import os

# Read logs from stdin (first line), function map and show tag from environment
logs_json = sys.stdin.readline().strip()
func_map_json = os.environ.get('FUNC_MAP_JSON', '{}')
show_function_tag = os.environ.get('SHOW_FUNCTION_TAG', 'false') == 'true'

logs = json.loads(logs_json)
func_map = json.loads(func_map_json)
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
    export FUNC_MAP_JSON="$FUNCTION_MAP_JSON" SHOW_FUNCTION_TAG="$SHOW_FUNCTION_TAG"
    while IFS= read -r pline; do
        # Use echo -e to interpret ANSI color escapes
        echo -e "$pline"
    done < <(
        echo "$LOGJSON" | python3 -c "$PYTHON_FORMATTER"
    )
fi
