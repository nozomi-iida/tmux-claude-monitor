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
  local now pane state at target wname path cmd icon rank ago short_path
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
    # runs inside a long-lived pane that outlives it — and a headless `claude -p`
    # (e.g. lazygit's commit-message command) tags whatever pane it ran in,
    # including editor panes. Either way a stale state lingers on a pane that is
    # no longer interactive Claude. Show only panes whose foreground command is
    # still Claude; any other command means Claude is gone, whatever it was.
    [ "$cmd" = claude ] || continue
    at=$(tmux show-options -pqv -t "$pane" @claude_state_at 2>/dev/null)
    case "$state" in
    waiting) icon=$'\033[33m●\033[0m waiting' rank=0 ;; # yellow - needs input
    idle) icon=$'\033[32m●\033[0m idle   ' rank=1 ;;    # green  - done, your turn
    working) icon=$'\033[31m●\033[0m working' rank=3 ;; # red    - busy, leave it
    *) icon=$'\033[90m●\033[0m   ?    ' rank=2 ;;       # grey   - unknown
    esac
    if [ -n "$at" ]; then ago="$(((now - at) / 60))m"; else ago='-'; fi
    # Show only the last path segment (leaf directory) to keep rows short.
    short_path="$(basename "$path")"
    # rank \t pane \t target \t icon \t age \t window \t path
    # (rank/pane/target hidden via --with-nth)
    printf '%s\t%s\t%s\t%s\t%5s\t%s\t%s\n' \
      "$rank" "$pane" "$target" "$icon" "$ago" "$wname" "$short_path"
    # rank asc (attention-needed floats up), then age asc so the pane that
    # finished just now sits at the top of its group. -k5,5n reads the leading
    # number of the age field ("5m" -> 5; "-" -> 0).
  done | sort -t$'\t' -k1,1n -k5,5n
}

# Re-entrant mode: fzf's periodic reload calls back into this script with
# `--emit` to regenerate the row list without spawning a second fzf.
if [ "${1:-}" = --emit ]; then
  emit_rows
  exit 0
fi

if ! command -v fzf >/dev/null 2>&1; then
  tmux display-message "tmux-claude-monitor: fzf is required for the picker"
  exit 0
fi

export FZF_DEFAULT_OPTS=''
# Refresh the list (and the focused preview) every $interval seconds while the
# popup is open, so a pane that flips working->idle updates live. fzf has no
# native timer, so we self-loop: the `load` event fires whenever the result
# list finishes loading, and we answer it by sleeping then reloading — which
# triggers `load` again. reload-sync keeps the old rows on screen until the new
# ones are ready (no flicker), and --track keeps the cursor on the same pane
# even when sorting moves it between groups.
interval=$(tmux show-options -gqv @claude_picker_interval 2>/dev/null)
[ -z "$interval" ] && interval=2
sel=$(emit_rows | fzf --ansi --delimiter='\t' --with-nth=4,5,6,7 \
  --reverse --cycle --track --header='Claude panes · enter: jump' \
  --bind="load:reload-sync(sleep $interval; '$DIR/picker.sh' --emit)+refresh-preview" \
  --preview="tmux capture-pane -ept {2}" --preview-window='right,62%,wrap')

[ -z "$sel" ] && exit 0
pane=$(printf '%s' "$sel" | cut -f2)    # %id
target=$(printf '%s' "$sel" | cut -f3)  # session:window

# Move the current client to the pane's window, then focus the pane. switch-client
# targets the client that opened this popup, so the jump lands after it closes.
tmux switch-client -t "$target" 2>/dev/null
tmux select-pane -t "$pane" 2>/dev/null
