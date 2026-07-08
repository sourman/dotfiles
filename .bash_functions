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
