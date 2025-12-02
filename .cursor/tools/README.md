# Cursor Tools

Collection of helpful development tools for this project.

## get-function-logs.sh

Query Supabase Edge Function console logs via the Management API.

### Setup

The script automatically sources `.env.local` for:
- `SUPABASE_ACCESS_TOKEN` (required)
- `SUPABASE_PROJECT_REF` (required)

### Quick Start

```bash
# Get logs for a function (last 24 hours)
.cursor/tools/get-function-logs.sh amplitude-sync-worker

# Get logs for last 7 days
.cursor/tools/get-function-logs.sh -t 7d amplitude-sync-worker

# Search for errors
.cursor/tools/get-function-logs.sh -s "error" amplitude-sync-worker

# Get all event types (not just console logs)
.cursor/tools/get-function-logs.sh -e all amplitude-sync-worker

# Use function ID directly
.cursor/tools/get-function-logs.sh -f e3015d5d-0e92-4c89-924d-de9836b2ebfd
```

### Options

- `-t, --time-range`: Time range (e.g., `24h`, `7d`, `30d`) [default: 24h]
- `-e, --event-type`: Event type filter (`Log`, `Shutdown`, `Invocation`, `Error`, or `all`) [default: all]
- `-s, --search`: Search term for filtering log messages
- `-l, --limit`: Maximum number of logs [default: 100]
- `-f, --function-id`: Use function ID directly (skips lookup)
- `-m, --metadata`: Include metadata fields (level, execution_id, version)
- `-j, --json`: Output raw JSON instead of formatted
- `-h, --help`: Show help message

### Examples

```bash
# Get last 50 error logs
.cursor/tools/get-function-logs.sh -l 50 -s "error" amplitude-sync-worker

# Get logs with metadata for debugging
.cursor/tools/get-function-logs.sh -m -t 1d amplitude-sync-worker

# Get raw JSON output for scripting
.cursor/tools/get-function-logs.sh -j amplitude-sync-worker | jq '.result[0]'

# Get log events only. Exclude system logs like `CPU Timeout` `Memory Limit Exceeded` 
.cursor/tools/get-function-logs.sh -e Log -t 7d amplitude-sync-worker
```

