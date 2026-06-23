# tmux-claude-monitor

Run [Claude Code](https://claude.com/claude-code) in ordinary tmux panes across
your projects, then **see which are working, waiting, or done — and jump to one**
from a single popup.

When you have Claude running in several windows/panes at once, you can't tell
which need you without visiting each. This plugin gives you:

- 🔢 **A central picker** (`prefix` + `u`) listing every pane running Claude.
- 🟢 **Live status** per pane — `working` / `waiting` / `idle` — driven by
  Claude Code hooks, so you instantly see which need you.
- 👁️ **A live preview** of each pane's screen right in the picker.
- 🎯 **Jump** — selecting a pane switches your client to its window and focuses
  the pane.

Unlike a session launcher, this does not start Claude for you — you run Claude
in your panes as usual, and the picker monitors them. Status is optional:
without the hooks the picker still lists, previews, and jumps — panes just show
`?` instead of a color (they only appear once they have a state, though, so the
hooks are recommended).

> Based on [craftzdog/tmux-claude-session-manager](https://github.com/craftzdog/tmux-claude-session-manager).
> That plugin launches and manages one Claude **session per directory**; this
> fork instead monitors Claude state **per pane** in your normal windows and
> jumps to them.

## Prerequisites

- **tmux ≥ 3.2** (for `display-popup`; pane-scoped options need ≥ 3.0)
- **[fzf](https://github.com/junegunn/fzf)** — the picker UI
- **[Claude Code](https://claude.com/claude-code)** CLI (the `claude` command)
- bash; macOS or Linux

## Install (tpm)

Add to `~/.tmux.conf` (or `~/.config/tmux/tmux.conf`):

```tmux
set -g @plugin 'nozomi-iida/tmux-claude-monitor'
```

Then hit `prefix` + <kbd>I</kbd> to install.

> **Keybinding note:** by default the plugin binds `prefix` + `u` (picker). If
> your config binds that elsewhere, either change the option below, or make sure
> the plugin loads **after** your own bindings (put `run '~/.tmux/plugins/tpm/tpm'`
> _after_ them) so the one you want wins.

### Manual install

```sh
git clone https://github.com/nozomi-iida/tmux-claude-monitor ~/clone/path
```

Add to `~/.tmux.conf`, then reload (`prefix` + <kbd>r</kbd> or `tmux source ~/.tmux.conf`):

```tmux
run-shell ~/clone/path/claude_monitor.tmux
```

## Usage

| Key            | Action             |
| -------------- | ------------------ |
| `prefix` + `u` | Open the picker    |

Inside the picker:

| Key                       | Action                                              |
| ------------------------- | --------------------------------------------------- |
| `enter`                   | Jump to the pane (switch to its window, focus pane) |
| `↑` / `↓`, type to filter | fzf navigation                                      |

Panes needing your attention (`waiting`, `idle`) sort to the top.

## Status setup (recommended)

Status comes from [Claude Code hooks](https://code.claude.com/docs/en/hooks)
that stamp each pane's state onto its tmux pane. Add the following to your Claude
Code settings (`~/.claude/settings.json`), merging into any existing `hooks`
block. Adjust the path if your plugins live elsewhere (e.g. `~/.tmux/plugins/...`):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-monitor/scripts/state.sh working"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-monitor/scripts/state.sh waiting"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-monitor/scripts/state.sh waiting"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-monitor/scripts/state.sh idle"
          }
        ]
      }
    ]
  }
}
```

The state machine:

| Event                            | State        | Meaning                   |
| -------------------------------- | ------------ | ------------------------- |
| `UserPromptSubmit`               | 🔴 `working` | Busy — leave it           |
| `Notification` (permission)      | 🟡 `waiting` | Needs permission          |
| `PreToolUse` (`AskUserQuestion`) | 🟡 `waiting` | Asking you a question     |
| `Stop`                           | 🟢 `idle`    | Turn finished — your move |

> Claude Code reloads `hooks` dynamically — no restart needed. A pane starts
> appearing in the picker on its next event once the hooks are added. To make a
> pane show up the moment Claude starts (before the first prompt), also add a
> `SessionStart` hook running `state.sh idle`.

## Options

Set any of these before the plugin loads (defaults shown):

```tmux
set -g @claude_list_key      'u'    # prefix key: open the picker
set -g @claude_popup_width   '90%'  # popup width
set -g @claude_popup_height  '90%'  # popup height
```

## How it works

- The **hooks** set `@claude_state` / `@claude_state_at` as a **pane-scoped**
  option on each pane running Claude. Because the option lives on the pane, it
  disappears automatically when the pane closes — no stale state to clean up.
- The **picker** lists every pane, reads each pane's own state with
  `show-options -p` (not a `#{@claude_state}` format, which would inherit the
  value from the window/session and tag unrelated panes), shows a live
  `capture-pane` preview, and on selection switches your client to the pane's
  window and focuses it.

## License

[MIT](LICENSE) © Takuya Matsuyama (original), nozomi-iida (modifications)
