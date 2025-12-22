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
waled() {
  local lookback_minutes="${1:-10}"

  if ! [[ "$lookback_minutes" =~ ^[0-9]+$ ]]; then
    echo "Error: Lookback time must be a positive number (minutes)"
    echo "Usage: cdworktree [lookback_minutes]"
    return 1
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

      # Store mapping
      echo "$worktree_name:$dir" >> "$map_file"

      (
        cd "$dir" && npm i && VITE_WORKTREE="$worktree_name" npm run dev
      ) &
      pid=$!
      echo "$pid" >> "$pid_file"
      echo "$pid:$worktree_name" >> "${pid_file%.pid}.details"
      echo "Spawned PID $pid for $worktree_name"
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

      # Also show the mapping before killing
      map_file="${pid_file%.pid}.map"
      if [ -f "$map_file" ]; then
        echo "Killing servers:"
        cat "$map_file" | while IFS=: read -r name dir; do
          echo "  - $name"
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
