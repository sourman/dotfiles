# Quicky funciton to psuh to all remotes os we do not forget to update
# a remote

pushy() {
  git remote | while read remote; do
    echo "Pushing to $remote..."
    git push "$remote" "$@"
  done
}
#!/bin/bash

# Function 1: Start dev servers for recently created worktree directories
# Usage: waled [lookback_minutes] [package_manager] [dev_args...]
#   lookback_minutes: minutes to look back (default: 10)
#   package_manager: npm, bun, or auto (default: auto)
#   dev_args: additional arguments to pass to dev command (e.g., "web", "--port 3000")
# Examples:
#   waled 10                    # auto-detect, run "npm run dev" or "bun run dev"
#   waled 10 bun                # use bun, run "bun run dev"
#   waled 10 bun web            # use bun, run "bun run dev web"
#   waled 10 auto web           # auto-detect, run "npm run dev web" or "bun run dev web"
#   waled 10 web                # auto-detect, run "npm run dev web" or "bun run dev web"
waled() {
  local lookback_minutes="${1:-10}"

  if ! [[ "$lookback_minutes" =~ ^[0-9]+$ ]]; then
    echo "Error: Lookback time must be a positive number (minutes)"
    echo "Usage: waled [lookback_minutes] [package_manager] [dev_args...]"
    return 1
  fi

  # Parse package manager and dev args
  local pm="auto"
  local dev_args=()
  
  shift  # Remove lookback_minutes from args
  
  if [ $# -gt 0 ]; then
    # Check if second arg is a package manager
    if [[ "$1" == "npm" || "$1" == "bun" || "$1" == "auto" ]]; then
      pm="$1"
      shift  # Remove package manager from args
    fi
    
    # Remaining args are dev args
    dev_args=("$@")
  fi

  repo="$(basename "$(pwd)")"

  # Support both upper and lower-case conventions
  worktree_dirs=()
  for suffix in "__WSL__ubuntu_" "__WSL__Ubuntu_"; do
    dir="$HOME/.cursor/worktrees/${repo}${suffix}"
    if [ -d "$dir" ]; then
      worktree_dirs+=("$dir")
    fi
  done

  if [ ${#worktree_dirs[@]} -eq 0 ]; then
    echo "No work tree directories found for repo: $repo"
    echo "Tried:"
    echo "    $HOME/.cursor/worktrees/${repo}__WSL__ubuntu_"
    echo "    $HOME/.cursor/worktrees/${repo}__WSL__Ubuntu_"
    return 1
  fi

  found_dirs=()
  for WORK_TREE_DIR in "${worktree_dirs[@]}"; do
    echo "Looking for directories created in the last $lookback_minutes minutes in $WORK_TREE_DIR..."
    # Find directories created in the last N minutes for either naming convention
    recent_dirs=$(find "$WORK_TREE_DIR" -maxdepth 1 -type d -mmin -"$lookback_minutes" ! -path "$WORK_TREE_DIR")
    if [ -n "$recent_dirs" ]; then
      while IFS= read -r d; do
        [ -n "$d" ] && found_dirs+=("$d")
      done <<< "$recent_dirs"
    fi
  done

  if [ ${#found_dirs[@]} -eq 0 ]; then
    echo "No recent directories found in any worktree (last $lookback_minutes minutes)"
    return 0
  fi

  # Create PID tracking file
  pid_file="/tmp/worktree-pids-${repo}-$$.pid"
  map_file="${pid_file%.pid}.map"
  touch "$pid_file"
  touch "$map_file"

  # Spawn bash for each directory found (across all naming conventions)
  for dir in "${found_dirs[@]}"; do
    if [ -n "$dir" ]; then
      worktree_name="$(basename "$dir")"
      echo "Starting dev server for: $dir (worktree: $worktree_name)"

      # Determine package manager for this directory
      local detected_pm="$pm"
      if [[ "$pm" == "auto" ]]; then
        if [ -f "$dir/bun.lock" ] || [ -f "$dir/bun.lockb" ]; then
          detected_pm="bun"
        elif command -v bun >/dev/null 2>&1 && [ -f "$dir/package.json" ]; then
          # Check if package.json has bun-specific scripts or if bun is preferred
          if grep -q '"dev"' "$dir/package.json" 2>/dev/null; then
            detected_pm="bun"
          else
            detected_pm="npm"
          fi
        else
          detected_pm="npm"
        fi
      fi

      echo "Using package manager: $detected_pm"
      if [ ${#dev_args[@]} -gt 0 ]; then
        echo "Dev args: ${dev_args[*]}"
      fi

      # Store mapping
      echo "$worktree_name:$dir" >> "$map_file"

      # Build command based on package manager
      # Properly quote dev args for safe execution
      local quoted_dev_args=""
      if [ ${#dev_args[@]} -gt 0 ]; then
        quoted_dev_args=" $(printf '%q ' "${dev_args[@]}")"
      fi

      if [[ "$detected_pm" == "bun" ]]; then
        cmd="cd \"$dir\" && bun install && VITE_WORKTREE=\"$worktree_name\" bun dev$quoted_dev_args"
      else
        cmd="cd \"$dir\" && npm i && VITE_WORKTREE=\"$worktree_name\" npm run dev$quoted_dev_args"
      fi

      (
        eval "$cmd"
      ) &
      pid=$!
      echo "$pid" >> "$pid_file"
      local dev_args_str="${dev_args[*]}"
      echo "$pid:$worktree_name:$detected_pm:${dev_args_str}" >> "${pid_file%.pid}.details"
      if [ ${#dev_args[@]} -gt 0 ]; then
        echo "Spawned PID $pid for $worktree_name (using $detected_pm, args: ${dev_args[*]})"
      else
        echo "Spawned PID $pid for $worktree_name (using $detected_pm)"
      fi
    fi
  done

  echo ""
  echo "PIDs tracked in: $pid_file"
  echo "Worktree mapping in: $map_file"
  echo ""
  echo "Worktree -> Directory mapping:"
  cat "$map_file"
}

# Function 2: Kill all spawned worktree processes from either naming convention
# Works for both npm and bun processes
mawet() {
  # Find all PID files matching the pattern (regardless of convention)
  pid_files=$(find /tmp -maxdepth 1 -name "worktree-pids-*.pid" -type f 2>/dev/null)

  if [ -z "$pid_files" ]; then
    echo "No worktree PID files found"
    return 0
  fi

  # Will match all possible pids from all conventions
  all_pids=()
  all_pgroups=()
  pm_info=()
  while IFS= read -r pid_file; do
    if [ -f "$pid_file" ]; then
      echo "Reading PIDs from: $pid_file"
      while IFS= read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
          all_pids+=("$pid")
          # Get process group ID
          pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')
          if [ -n "$pgid" ]; then
            all_pgroups+=("$pgid")
          fi
        fi
      done < "$pid_file"

      # Also show the mapping and package manager info before killing
      map_file="${pid_file%.pid}.map"
      details_file="${pid_file%.pid}.details"
      if [ -f "$map_file" ]; then
        echo "Killing servers:"
        cat "$map_file" | while IFS=: read -r name dir; do
          # Try to get package manager and dev args from details file
          pm="unknown"
          dev_args_display=""
          if [ -f "$details_file" ]; then
            pm_line=$(grep ":$name:" "$details_file" 2>/dev/null | head -1)
            if [ -n "$pm_line" ]; then
              pm=$(echo "$pm_line" | cut -d: -f3)
              dev_args_display=$(echo "$pm_line" | cut -d: -f4-)
              if [ -n "$dev_args_display" ]; then
                dev_args_display=" (args: $dev_args_display)"
              fi
            fi
          fi
          echo "  - $name ($pm)$dev_args_display"
        done
      fi
    fi
  done <<< "$pid_files"

  # Kill all process groups (which includes child processes like Vite)
  if [ ${#all_pgroups[@]} -eq 0 ]; then
    echo "No active process groups found"
  else
    # Remove duplicates
    unique_pgroups=($(printf "%s\n" "${all_pgroups[@]}" | sort -u))
    echo "Killing ${#unique_pgroups[@]} process groups: ${unique_pgroups[*]}"

    for pgid in "${unique_pgroups[@]}"; do
      # Kill the entire process group
      if kill -- "-$pgid" 2>/dev/null; then
        echo "Killed process group $pgid"
      else
        echo "Failed to kill process group $pgid, trying individual PIDs"
      fi
    done

    sleep 2

    # Fallback: kill any remaining individual PIDs
    for pid in "${all_pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        echo "Force killing remaining PID $pid"
        kill -9 "$pid" 2>/dev/null
      fi
    done
  fi

  # Clean up PID and map files for both conventions
  echo "Cleaning up PID files..."
  rm -f /tmp/worktree-pids-*.pid
  rm -f /tmp/worktree-pids-*.map
  rm -f /tmp/worktree-pids-*.details
}

kayes() {
  f="$1"; tag="$2"
  { echo "<$tag>"; cat "$f"; echo "</$tag>"; } > "$f.tmp" && mv "$f.tmp" "$f"
}

rukn() { npx supabase migration list | tail -${1:-5}; }

# A sneaky function to trick cursor into sleep waiting
# Cursor auto skips terminal tool calls with `sleep x` but it does not
# detect that holdon is just a sleep so it actually wait until the
# time elapses
holdon() {
  sleep $(($1))
}
