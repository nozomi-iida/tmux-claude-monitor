#!/usr/bin/env bash
# Record a Claude Code session's state on its tmux pane, for the picker.
# Wire this into Claude Code hooks (see README):  state.sh <working|waiting|idle>
#
# Claude Code hooks inherit the Claude process environment, so $TMUX_PANE is set
# whenever Claude runs inside tmux. Outside tmux this is a no-op.
#
# The state is stored as a pane-scoped option, so each pane running Claude is
# tracked independently. When the pane goes away, the option goes with it — no
# stale state to clean up.
[ -z "$TMUX_PANE" ] && exit 0

tmux set-option -p -t "$TMUX_PANE" @claude_state "${1:-idle}"
tmux set-option -p -t "$TMUX_PANE" @claude_state_at "$(date +%s)"
exit 0
