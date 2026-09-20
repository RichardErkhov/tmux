#!/bin/sh

# When the client attached to a session goes away because its tty closes -
# which is what a dropped ssh connection looks like to the server - the session
# must survive for the next attach.  The outer server gives the inner client a
# real tty, the way "ssh host -t tmux attach" does.

PATH=/bin:/usr/bin
TERM=screen
SHELL=/bin/sh
LC_ALL=C.UTF-8
export PATH TERM SHELL LC_ALL

[ -z "$TEST_TMUX" ] && TEST_TMUX=$(readlink -f ../tmux)

TMUX="$TEST_TMUX -Linner$$ -f/dev/null"
TMUX2="$TEST_TMUX -Louter$$ -f/dev/null"

fail()
{
	echo "$*" >&2
	cleanup
	exit 1
}

cleanup()
{
	$TMUX kill-server 2>/dev/null
	$TMUX2 kill-server 2>/dev/null
}
trap cleanup 0 1 15

$TMUX kill-server 2>/dev/null
$TMUX2 kill-server 2>/dev/null

$TMUX new-session -d -s keep 'sleep 1000' || fail "could not create session"

$TMUX2 new-session -d -s outer "$TMUX attach -t keep" ||
    fail "could not start attached client"

i=0
while [ "$i" -lt 50 ]; do
	[ "$($TMUX list-clients 2>/dev/null | wc -l)" -eq 1 ] && break
	sleep 0.2
	i=$((i + 1))
done
[ "$i" -lt 50 ] || fail "client did not attach"

# The tty goes away and the client is killed without detaching.
$TMUX2 kill-server
sleep 1

# The session and its pane must outlive the client that was looking at it.
$TMUX has-session -t keep || fail "session went away with the client"
$TMUX list-panes -t keep -F '#{pane_dead}' | grep -q '^0$' ||
    fail "pane died with the client"

cleanup
exit 0
