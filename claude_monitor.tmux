#!/usr/bin/env bash
# tmux-claude-monitor
#
# Monitor the status of every pane running Claude Code from a single popup, and
# jump to one. tpm runs this file as an executable on tmux startup; it reads
# user options (with sensible defaults) and installs the key binding.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/scripts/helpers.sh"

list_key="$(get_tmux_option @claude_list_key 'u')"
w="$(get_tmux_option @claude_popup_width '90%')"
h="$(get_tmux_option @claude_popup_height '90%')"

# Open the picker in a popup. Claude runs in ordinary panes (not popups), so there
# is no popup-in-popup to work around — just show it on the current client.
tmux bind-key "$list_key" \
  display-popup -w "$w" -h "$h" -E "$CURRENT_DIR/scripts/picker.sh"
