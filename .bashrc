# System-wide .bashrc file for interactive bash(1) shells.

# To enable the settings / commands in this file for login shells as well,
# this file has to be sourced in /etc/profile.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# ============================================================================
# BASH HISTORY CONFIGURATION
# ============================================================================
# Keep a large history
export HISTSIZE=10000                    # Commands in memory
export HISTFILESIZE=20000                # Commands in history file

# Append to history file instead of overwriting (critical for multiple terminals)
shopt -s histappend

# Avoid duplicates and commands starting with space
export HISTCONTROL=ignoreboth:erasedups

# Add timestamps to history
export HISTTIMEFORMAT='%F %T  '

# Save history after each command (prevents loss on crashes/forced closures)
# This is crucial for Cursor/IDE terminals that may close unexpectedly
PROMPT_COMMAND='history -a'

# ============================================================================

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, overwrite the one in /etc/profile)
# but only if not SUDOing and have SUDO_PS1 set; then assume smart user.
if ! [ -n "${SUDO_USER}" -a -n "${SUDO_PS1}" ]; then
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

# Commented out, don't overwrite xterm -T "title" -n "icontitle" by default.
# If this is an xterm set the title to user@host:dir
#case "$TERM" in
#xterm*|rxvt*)
#    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"'
#    ;;
#*)
#    ;;
#esac

# enable bash completion in interactive shells
#if ! shopt -oq posix; then
#  if [ -f /usr/share/bash-completion/bash_completion ]; then
#    . /usr/share/bash-completion/bash_completion
#  elif [ -f /etc/bash_completion ]; then
#    . /etc/bash_completion
#  fi
#fi

# sudo hint
if [ ! -e "$HOME/.sudo_as_admin_successful" ] && [ ! -e "$HOME/.hushlogin" ] ; then
    case " $(groups) " in *\ admin\ *|*\ sudo\ *)
    if [ -x /usr/bin/sudo ]; then
	cat <<-EOF
	To run a command as administrator (user "root"), use "sudo <command>".
	See "man sudo_root" for details.
	
	EOF
    fi
    esac
fi

# if the command-not-found package is installed, use it
if [ -x /usr/lib/command-not-found -o -x /usr/share/command-not-found/command-not-found ]; then
	function command_not_found_handle {
	        # check because c-n-f could've been removed in the meantime
                if [ -x /usr/lib/command-not-found ]; then
		   /usr/lib/command-not-found -- "$1"
                   return $?
                elif [ -x /usr/share/command-not-found/command-not-found ]; then
		   /usr/share/command-not-found/command-not-found -- "$1"
                   return $?
		else
		   printf "%s: command not found\n" "$1" >&2
		   return 127
		fi
	}
fi
gsutil-tree() { local bucket_path="$1"; bucket_path="${bucket_path#gs://}"; gsutil ls -r "gs://$bucket_path" | awk 'BEGIN { path[0] = "" } /:$/ { dir = substr($0, 1, length($0)-1); if (dir == ".") { depth = 0; path[0] = "" } else { depth = gsub(/\//, "/", dir); path[depth] = dir } if (depth > 0) { for (i = 1; i < depth; i++) printf "| "; printf "|____" dir; gsub(/.*\//, "", dir); print dir } } /^$/ { next } !/^[[:space:]]*$/ && !/:$/ { for (i = 0; i < depth; i++) printf "| "; print "|____" $0 }'; }

source /usr/share/bash-completion/completions/git

# Source bash aliases if file exists
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Source bash functions if file exists
if [ -f ~/.bash_functions ]; then
    . ~/.bash_functions
fi

# ============================================================================
# PATH CONFIGURATION
# All PATH modifications live here so they work in both login and non-login
# shells. WSL-native tools are prepended so they always beat Windows paths.
# ============================================================================

# bun (package manager / runtime)
if [ -d "$HOME/.bun/bin" ] ; then
    PATH="$HOME/.bun/bin:$PATH"
fi

# bun global bin — where `bun install -g` drops executables (e.g. mcporter).
# bun resolves this to $XDG_CACHE_HOME/.bun/bin (defaults to ~/.cache/.bun/bin).
if [ -d "${XDG_CACHE_HOME:-$HOME/.cache}/.bun/bin" ] ; then
    PATH="${XDG_CACHE_HOME:-$HOME/.cache}/.bun/bin:$PATH"
fi

# nvm (Node.js version manager)
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# pnpm
if [ -d "$HOME/.local/share/pnpm/bin" ] ; then
    PATH="$HOME/.local/share/pnpm/bin:$PATH"
fi

# AWS CLI
if [ -d "$HOME/.local/aws-cli/v2/current/dist" ] ; then
    PATH="$HOME/.local/aws-cli/v2/current/dist:$PATH"
elif [ -d "$HOME/.local/aws-cli/v2/2.32.23/dist" ] ; then
    PATH="$HOME/.local/aws-cli/v2/2.32.23/dist:$PATH"
fi

# Snap binaries
if [ -d "/snap/bin" ] ; then
    PATH="/snap/bin:$PATH"
fi

# Android SDK
export ANDROID_HOME=$HOME/Android/sdk
PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0"

# Go packages
if [ -d "$HOME/go/bin" ] ; then
    PATH="$HOME/go/bin:$PATH"
fi

# ~/.local/bin (agent-browser wrapper, user bins)
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Scripts dir (version-controlled text scripts, tracked in dotfiles repo).
if [ -d "$HOME/.local/scripts" ] ; then
    PATH="$HOME/.local/scripts:$PATH"
fi

export PATH

# Starship prompt (git-aware, nerd-font powerline) — overrides PS1 above
eval "$(starship init bash)"
