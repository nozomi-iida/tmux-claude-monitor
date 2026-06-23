#!/usr/bin/env bash
# Interactive picker for panes running Claude Code.
#
# Lists every pane that has reported a Claude state, with a live preview. On
# enter, switches the current client to that pane's window and selects the pane.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

emit_rows() {
  local now pane state at target wname path cmd icon rank ago
  now=$(date +%s)
  # One row per pane across all sessions. The state is read with `show-options -p`
  # rather than a `#{@claude_state}` format, because the format inherits the
  # option from the window/session/global scope — which would tag panes that
  # never ran Claude. `-p` returns only the value set on the pane itself, so
  # panes without a pane-scoped state come back empty and are skipped.
  tmux list-panes -a -F \
    '#{pane_id}	#{session_name}:#{window_index}	#{window_name}	#{pane_current_path}	#{pane_current_command}' \
    2>/dev/null | while IFS=$'\t' read -r pane target wname path cmd; do
    state=$(tmux show-options -pqv -t "$pane" @claude_state 2>/dev/null)
    [ -z "$state" ] && continue
    # The pane-scoped state is never cleared when Claude exits, because Claude
    # runs inside a long-lived shell pane that outlives it. So a pane back at its
    # shell prompt still carries a stale state. Skip it: if the foreground
    # command is a shell, Claude is gone regardless of how it ended.
    case "$cmd" in
    zsh | bash | fish | sh) continue ;;
    esac
    at=$(tmux show-options -pqv -t "$pane" @claude_state_at 2>/dev/null)
    case "$state" in
    waiting) icon=$'\033[33m●\033[0m waiting' rank=0 ;; # yellow - needs input
    idle) icon=$'\033[32m●\033[0m idle   ' rank=1 ;;    # green  - done, your turn
    working) icon=$'\033[31m●\033[0m working' rank=3 ;; # red    - busy, leave it
    *) icon=$'\033[90m●\033[0m   ?    ' rank=2 ;;       # grey   - unknown
    esac
    if [ -n "$at" ]; then ago="$(((now - at) / 60))m"; else ago='-'; fi
    # rank \t pane \t target \t icon \t age \t window \t path
    # (rank/pane/target hidden via --with-nth)
    printf '%s\t%s\t%s\t%s\t%5s\t%s\t%s\n' \
      "$rank" "$pane" "$target" "$icon" "$ago" "$wname" "${path/#$HOME/~}"
    # rank asc (attention-needed floats up), then age asc so the pane that
    # finished just now sits at the top of its group. -k5,5n reads the leading
    # number of the age field ("5m" -> 5; "-" -> 0).
  done | sort -t$'\t' -k1,1n -k5,5n
}

if ! command -v fzf >/dev/null 2>&1; then
  tmux display-message "tmux-claude-monitor: fzf is required for the picker"
  exit 0
fi

export FZF_DEFAULT_OPTS=''
sel=$(emit_rows | fzf --ansi --delimiter='\t' --with-nth=4,5,6,7 \
  --reverse --cycle --header='Claude panes · enter: jump' \
  --preview="tmux capture-pane -ept {2}" --preview-window='right,62%,wrap')

[ -z "$sel" ] && exit 0
pane=$(printf '%s' "$sel" | cut -f2)    # %id
target=$(printf '%s' "$sel" | cut -f3)  # session:window

# Move the current client to the pane's window, then focus the pane. switch-client
# targets the client that opened this popup, so the jump lands after it closes.
tmux switch-client -t "$target" 2>/dev/null
tmux select-pane -t "$pane" 2>/dev/null
