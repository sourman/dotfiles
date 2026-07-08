# ============================================================================
# Custom bash functions
# ============================================================================

# Push to all remotes (never forget a mirror)
pushy() {
  git remote | while read remote; do
    echo "Pushing to $remote..."
    git push "$remote" "$@"
  done
}

# Wrap an XML/HTML tag around a file's contents
kayes() {
  local f="$1" tag="$2"
  { echo "<$tag>"; cat "$f"; echo "</$tag>"; } > "$f.tmp" && mv "$f.tmp" "$f"
}

# Peek at the last N supabase migrations (default 5)
rukn() { npx supabase migration list | tail -"${1:-5}"; }

# Trick Cursor's terminal tool into waiting — it skips bare `sleep N` calls
holdon() { sleep "$(($1))"; }

# ============================================================================
# wt — worktree navigator. Jump is the universal default.
#   wt                fzf-pick a worktree → cd
#   wt feat-mcp       substring-match → cd (1 match: instant, N matches: fzf)
#   wt list | wt ls   list worktrees (name + branch + path)
#   wt rm [name]      remove a worktree (fzf if no arg, substring if given)
#   wt prune          prune stale worktree refs
#   wt help           this help
# ============================================================================
_wt_list_porcelain() {
  git worktree list --porcelain 2>/dev/null
}

# Print "name<TAB>branch<TAB>path" per worktree (excludes the bare HEAD/detached)
_wt_entries() {
  local name branch path line
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) path="${line#worktree }"; name="$(basename "$path")";;
      branch\ *)   branch="${line#branch refs/heads/}";;
      "")
        # blank line = end of record; emit if we have a path
        [ -n "$path" ] && printf '%s\t%s\t%s\n' "$name" "${branch:-detached}" "$path"
        name=""; branch=""; path="";;
    esac
  done < <(_wt_list_porcelain)
  # emit the last record if file didn't end with blank line
  [ -n "$path" ] && printf '%s\t%s\t%s\n' "$name" "${branch:-detached}" "$path"
}

# fzf picker over worktree entries → echoes the chosen PATH (nothing if aborted)
# Keep the path in the piped data (3rd tab field) but hide it from display with
# --with-nth so fzf shows only name+branch; the full tab-delimited line is what
# fzf outputs on selection, so we can still extract the path.
_wt_fzf_path() {
  local query="${1:-}"
  _wt_entries \
    | fzf --query="$query" --prompt='worktree> ' --header='NAME  BRANCH' \
          --delimiter='\t' --with-nth=1,2 --preview-window=hidden \
    | awk -F'\t' '{print $3}'
}

wt() {
  local arg="${1:-}"
  [ -z "$arg" ] && arg="go"

  case "$arg" in
    go)
      local fzf_query="$2" target
      # If a query is given, try exact/substring match first (instant cd)
      if [ -n "$fzf_query" ]; then
        local matches path
        matches="$(_wt_entries | awk -F'\t' -v q="$fzf_query" '$1 ~ q')"
        local count; count="$(printf '%s\n' "$matches" | grep -c .)"
        if [ "$count" -eq 1 ]; then
          target="$(printf '%s' "$matches" | awk -F'\t' '{print $3}')"
        elif [ "$count" -gt 1 ]; then
          target="$(_wt_fzf_path "$fzf_query")"
        else
          echo "wt: no worktree matches '$fzf_query'" >&2
          _wt_entries | awk -F'\t' '{print "  "$1}' >&2
          return 1
        fi
      else
        target="$(_wt_fzf_path)"
      fi
      [ -n "$target" ] && cd "$target" || return 1
      ;;
    ls|list)
      _wt_entries | awk -F'\t' '{printf "%-28s %-30s %s\n", $1, $2, $3}'
      ;;
    rm|remove)
      local query="$2" matches count path name
      if [ -n "$query" ]; then
        matches="$(_wt_entries | awk -F'\t' -v q="$query" '$1 ~ q')"
        count="$(printf '%s\n' "$matches" | grep -c .)"
        if [ "$count" -eq 0 ]; then
          echo "wt: no worktree matches '$query'" >&2; return 1
        elif [ "$count" -eq 1 ]; then
          path="$(printf '%s' "$matches" | awk -F'\t' '{print $3}')"
          name="$(printf '%s' "$matches" | awk -F'\t' '{print $1}')"
        else
          path="$(_wt_fzf_path "$query")"
          [ -z "$path" ] && return 1
          name="$(basename "$path")"
        fi
      else
        path="$(_wt_fzf_path)"
        [ -z "$path" ] && return 1
        name="$(basename "$path")"
      fi
      echo "Removing worktree '$name'..."
      git worktree remove "$path" && echo "Removed $path"
      ;;
    prune)
      git worktree prune "$@"
      echo "Pruned stale worktree refs."
      ;;
    help|-h|--help)
      cat <<'HELP'
wt — worktree navigator (jump is the default)

  wt                fzf-pick a worktree → cd
  wt feat-mcp       substring-match → cd (1 match: instant, N: fzf filtered)
  wt list | wt ls   list worktrees (name + branch + path)
  wt rm [name]      remove a worktree (fzf if no arg, substring if given)
  wt prune          prune stale worktree refs

Jump mode is the default — any unrecognized arg is treated as a substring to
match against worktree names. So `wt feat` == `wt go feat`.
HELP
      ;;
    *)
      # Unrecognized arg → treat as substring jump (so `wt feat-mcp` works)
      wt go "$arg"
      ;;
  esac
}

# Print a GCS bucket as a tree
gsutil-tree() {
  local bucket_path="${1#gs://}"
  gsutil ls -r "gs://$bucket_path" | awk '
    BEGIN { path[0] = "" }
    /:$/ {
      dir = substr($0, 1, length($0)-1)
      if (dir == ".") { depth = 0; path[0] = "" }
      else { depth = gsub(/\//, "/", dir); path[depth] = dir }
      if (depth > 0) {
        for (i = 1; i < depth; i++) printf "| "
        printf "|____" dir; gsub(/.*\//, "", dir); print dir
      }
    }
    /^$/ { next }
    !/^[[:space:]]*$/ && !/:$/ {
      for (i = 0; i < depth; i++) printf "| "
      print "|____" $0
    }'
}

# Cursor: prepend anti-throttle flags so background agent/build work isn't
# throttled when the screen locks/blanks (mirrors ~/.local/share/applications/
# cursor.desktop). Delete this function to restore stock terminal behavior.
cursor() {
  command cursor --disable-background-timer-throttling \
                 --disable-renderer-backgrounding \
                 --disable-backgrounding-occluded-windows "$@"
}
