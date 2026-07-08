#!/usr/bin/env python3
"""Set NumLock ON when returning to the session (after lock/unlock or wake),
WITHOUT forcing it on while you work — so you can still toggle it off.

History: this used to re-assert `numlockx on` every 2s unconditionally, which
left NumLock perma-enabled (turning it off was overridden within 2s). The
lock/login GREETER still runs numlockx via lightdm's greeter-setup-script
(/etc/lightdm/lightdm.conf.d/), so password entry is covered there. This script
only covers the logged-in session, and now fires `numlockx on` exactly once on
each transition back into the session VT.

Detection: light-locker's DBus unlock signal is dead on this build (verified),
so we detect the return-to-session as a VT edge — the active VT
(/sys/class/tty/tty0/active) switching from the greeter's VT back to the
session's VT (captured at startup). Re-asserting on that edge also clears the
LED/numpad desync that can leave the modifier "on" in X but the physical LED off
after returning from the greeter VT.

Pure stdlib; no gi.
"""
import logging
import subprocess
import sys
import time

SESSION_VT_PATH = "/sys/class/tty/tty0/active"
NUMLOCK_ON = ["numlockx", "on"]
POLL_SEC = 1.5


def active_vt():
    """Read the currently-active VT, e.g. 'tty7'."""
    try:
        with open(SESSION_VT_PATH) as fh:
            return fh.read().strip()
    except Exception as exc:                  # never crash the loop
        logging.error("read %s failed: %s", SESSION_VT_PATH, exc)
        return None


def numlock_on():
    try:
        subprocess.run(NUMLOCK_ON, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
    except Exception as exc:
        logging.error("numlockx failed: %s", exc)


def main():
    logging.basicConfig(
        filename="/tmp/numlock-on-unlock.log",
        level=logging.INFO,
        format="%(asctime)s %(message)s",
    )
    session_vt = active_vt()
    if not session_vt:
        logging.error("could not determine session VT; exiting")
        sys.exit(1)

    numlock_on()                              # default ON at login
    prev = session_vt
    logging.info(
        "guarding NumLock on return-to-session (session VT=%s); "
        "no longer forced continuously — manual toggles are respected",
        session_vt,
    )

    while True:
        time.sleep(POLL_SEC)
        vt = active_vt()
        if not vt:
            continue
        if vt == session_vt and prev != session_vt:
            # we just returned to the session (unlock / wake) -> ON, once
            numlock_on()
            logging.info("returned to session VT %s -> NumLock ON", vt)
        prev = vt


if __name__ == "__main__":
    main()
