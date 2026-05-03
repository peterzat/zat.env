# Hooks

Reusable Claude Code hooks, installed globally via `zat.env-install.sh`.

Hooks are shell scripts registered in `~/.claude/settings.json` that fire at
specific points in the Claude Code lifecycle. Unlike skills (which are prompts),
hooks are deterministic — they always run regardless of Claude's judgment.

## pre-push-codereview.sh

Blocks `git push` commands unless `/codereview` has been run and passed on the
current diff.

**How it works:**
1. When Claude attempts a `git push`, the `PreToolUse` hook fires (filtered by `"if": "Bash(git push*)"` in the hook config, so it only runs for push commands)
2. The hook resolves the marker path via `codereview-marker path` (single source of truth). Markers live under `${XDG_CACHE_HOME:-${HOME}/.cache}/claude-codereview/marker-<project-hash>` (per-user, mode 0700)
3. The marker contains the diff hash (SHA-256, 16 chars) from the passing review
4. If the marker exists and the diff hash matches the current diff → push allowed
5. If no marker or hash mismatch → push blocked; Claude is instructed to run `/codereview`

The marker is per-project (project hash = `md5sum` of git root path) so multiple
projects don't share gate state. The codereview marker is content-addressed by
diff hash and persists across pushes (a failed network push or remote rejection
does not force a re-review; the next push of the same diff still passes the
gate). Only the one-shot bypass marker created by `codereview-skip` is consumed
on use. If `codereview-marker` is missing from PATH or otherwise broken, the
hook fails closed (exits 2) rather than silently allowing the push.

**Flow:**
```
Claude attempts git push
  → PreToolUse hook fires
  → marker present + hash matches? → allow push (marker preserved)
  → otherwise → block, tell Claude to run /codereview
      → Claude runs /codereview
      → review passes → codereview writes marker with current diff hash
      → Claude retries git push → hook passes
```

## allow-venv-source.sh

Auto-approves `source .venv/bin/activate` and `. .venv/bin/activate` commands
(with optional `&& <next command>` chaining) that would otherwise trigger the
eval-like builtin safety prompt.

**How it works:**
1. Fires on every `Bash` tool invocation (no `"if"` filter, broad matcher)
2. Extracts the command string from the hook input JSON
3. If the command is an exact venv activation or a `venv activate && ...` chain, returns `permissionDecision: allow`
4. For any other command, produces no output (pass-through to normal permission handling)

The settings.json `permissions.allow` list covers `. .venv/bin/activate && *` but
not the `source` synonym. This hook fills that gap.

## post-tool-exit-plan-mode.sh

Injects a reminder about `/spec plan` into the main conversation context
immediately after the user exits Claude Code's built-in plan mode.

**How it works:**
1. Fires as a `PostToolUse` hook scoped to `matcher: "ExitPlanMode"`
2. Reads the hook input JSON from stdin, double-checks `tool_name == ExitPlanMode`
3. Writes a plain-text reminder to stdout; plain stdout on `PostToolUse` is
   surfaced as additional context the next-turn model sees
4. Always exits 0 — the hook never blocks anything, it only reminds

**Why it exists:** Plan mode is built into Claude Code and its prompt cannot be
modified. Users who realize mid-plan-mode that their work is non-trivial need
a clear path to convert the saved plan into a persistent SPEC.md. This hook is
the deterministic reminder; the consumer is `/spec plan` (see the spec skill's
Step 3e). Without it, users would have to remember the handoff themselves.

**Why always-fires (not size-gated):** The reminder is one paragraph, and the
judgment about whether the work is "non-trivial enough" to spec belongs to the
user and the main-context Claude, not to a shell script trying to measure plan
size. Always-firing keeps the contract simple.

## Installing Hooks

Hooks are installed automatically by `zat.env-install.sh`. The install script
merges hook config into `~/.claude/settings.json` using `jq` (idempotent).

To verify the hook is registered:
```bash
jq '.hooks' ~/.claude/settings.json
```

To test the hook script directly:
```bash
# Should block (no marker)
echo '{}' | bash ~/src/zat.env/hooks/pre-push-codereview.sh 2>&1; echo "exit: $?"

# Should pass (correct marker). The path comes from codereview-marker so
# the test stays consistent with whatever the script computes.
codereview-marker write
echo '{}' | bash ~/src/zat.env/hooks/pre-push-codereview.sh; echo "exit: $?"
```

## Adding New Hooks

1. Add the script to this directory (`hooks/`)
2. Make it executable (`chmod +x`)
3. Add the hook config to the `jq` merge block in `zat.env-install.sh`
4. Document it here
5. Re-run `zat.env-install.sh` on each machine
