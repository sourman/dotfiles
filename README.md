# dotfiles

Machine-level config and scripts, tracked in-place at `~` (home directory git repo).

## Structure

```
.bashrc, .bash_aliases, .bash_functions   # shell config
.profile, .gitconfig, .tmux.conf, .vimrc  # other home dotfiles
.cursor/                                   # Cursor rules, commands, tools
.local/scripts/                            # text scripts (on PATH via .bashrc)
```

## `.local/scripts/` vs `~/.local/bin/`

`~/.local/bin/` holds three kinds of things; only the scripts are tracked here:

| Type | Tracked? | Examples |
| --- | --- | --- |
| Text scripts (`~/.local/scripts/`) | yes | `new-worktree`, `rofi-*`, `display-*` |
| Installed tool symlinks | no (install-managed) | `claude`, `cursor-agent`, `cursor-cdp` |
| True binaries | no (downloaded tools) | `uv`, `uvx` |

`.local/scripts/` is added to PATH in `.bashrc`, so scripts are live straight from the repo — no deploy step.

## Notable scripts

- **`new-worktree`** — git worktree with isolated Supabase (unique `project_id` + ports via `git skip-worktree`) and mcporter MCP baseline. Works on any repo with `supabase/config.toml` and/or `.cursor/mcp.json`.
