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
2. The hook checks for a marker file at `/tmp/.claude-codereview-<project-hash>`
3. The marker contains the diff hash (SHA-256, 16 chars) from the passing review
4. If the marker exists and the diff hash matches the current diff → push allowed
5. If no marker or hash mismatch → push blocked; Claude is instructed to run `/codereview`

The marker is per-project (project hash = `md5sum` of git root path) so multiple
projects don't share gate state. The marker is consumed on push (deleted after use).

**Flow:**
```
Claude attempts git push
  → PreToolUse hook fires
  → marker present + hash matches? → allow push, delete marker
  → otherwise → block, tell Claude to run /codereview
      → Claude runs /codereview
      → review passes → codereview writes marker with current diff hash
      → Claude retries git push → hook passes
```

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

# Should pass (correct marker)
PROJ_HASH=$(git rev-parse --show-toplevel | md5sum | cut -c1-8)
DIFF_HASH=$(git diff HEAD | sha256sum | cut -c1-16)
echo "${DIFF_HASH}" > "/tmp/.claude-codereview-${PROJ_HASH}"
echo '{}' | bash ~/src/zat.env/hooks/pre-push-codereview.sh; echo "exit: $?"
```

## Adding New Hooks

1. Add the script to this directory (`hooks/`)
2. Make it executable (`chmod +x`)
3. Add the hook config to the `jq` merge block in `zat.env-install.sh`
4. Document it here
5. Re-run `zat.env-install.sh` on each machine
