# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
. "$HOME/.cargo/env"

# Second full-screen desktop on display :1 when you log in on tty8 (Ctrl+Alt+F8).
# Only one VT is visible at a time; :1 starts here, not at boot alongside :0.
case "$(tty 2>/dev/null)" in
/dev/tty8)
  if [ -z "${DISPLAY:-}" ] && [ -x /usr/bin/startx ]; then
    exec startx "$HOME/.local/scripts/xsession-display1" -- :1 -keeptty vt8 -nolisten tcp
  fi
  ;;
esac
