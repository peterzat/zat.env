## Spec -- 2026-04-09 -- Local GPU reviewer integration (qwen)

**Goal:** Add the qwen-2.5-localreview project as an optional local reviewer in `review-external.sh`, running as a peer alongside the existing OpenAI and Google providers. Users who have not cloned the qwen project should experience zero side effects.

### Acceptance Criteria

- [x] `bin/review-external.sh` contains a `call_local` function that invokes `review.py` via the project's venv Python, using the same `--system` / `--input` file interface the existing providers use (`SYSTEM_FILE`, `USER_FILE`). Findings are tagged `(qwen)` and follow the same `[SEVERITY] (provider) file:line -- description` format as openai and google.
- [x] The local provider is gated on two `.env` variables: `LOCAL_REVIEW_SCRIPT` and `LOCAL_REVIEW_VENV`. When both are set and the script file exists, the provider runs. When either is missing, empty, or the script file does not exist on disk, the provider is skipped silently (no stderr noise, no exit code change).
- [x] The local provider runs in parallel with the other providers (same background-job + wait pattern). It respects the same `REVIEW_TIMEOUT` as the cloud providers. Timeout or crash produces a `[qwen]` message on stderr and returns 0 (fail-open, identical to openai/google failure handling).
- [x] `~/.config/claude-reviewers/.env` gains a commented-out `# --- Local (qwen) ---` section with `LOCAL_REVIEW_SCRIPT`, `LOCAL_REVIEW_VENV`, and `LOCAL_MODEL` entries, following the same pattern as the OpenAI and Google sections. The installer (`zat.env-install.sh`) creates or updates this section idempotently.
- [x] When `~/src/qwen-2.5-localreview/` does not exist (directory absent, venv absent, or `review.py` missing), all of the following produce identical behavior to today: (a) `review-external.sh` with no `.env` file, (b) `review-external.sh` with the local section commented out, (c) `review-external.sh` with the local section uncommented but pointing at a nonexistent path. No errors, no warnings, exit 0.
- [x] `tests/test-review-external.sh` gains tests covering the local provider's absence scenarios: (a) `LOCAL_REVIEW_SCRIPT` set but file does not exist on disk, (b) `LOCAL_REVIEW_SCRIPT` and `LOCAL_REVIEW_VENV` both empty, (c) only `LOCAL_REVIEW_SCRIPT` set (missing `LOCAL_REVIEW_VENV`). All must exit 0 with no stdout and no stderr.
- [x] README.md mentions the local reviewer in three places: (a) the "External reviewers (optional)" paragraph in the codereview section, noting the local option and its limitations (14B model produces more false positives than cloud models, useful as a second opinion), (b) the "Review pipeline sequencing" paragraph acknowledging local runs in parallel with cloud providers, (c) the directory overview, if the install script or repo structure changes. The roadmap "Done" section for the current version includes a line item.
- [x] The codereview skill's SKILL.md does not need changes (it calls `review-external.sh` generically), but the existing `review-external.sh` header comment is updated to document the `LOCAL_REVIEW_SCRIPT`, `LOCAL_REVIEW_VENV`, and `LOCAL_MODEL` variables alongside the existing ones.

### Context

The qwen-2.5-localreview project (`~/src/qwen-2.5-localreview/`) provides a `review.py` script that runs Qwen2.5-Coder-14B-Instruct-AWQ via vLLM offline inference. It accepts `--system <file> --input <file>` arguments (same prompt files `review-external.sh` already creates as `SYSTEM_FILE` and `USER_FILE`), writes findings to stdout and status/timing to stderr, and exits 0 on all error paths (fail-open). The integration guide is at `~/src/qwen-2.5-localreview/integration/integration-guide.md` and includes a ready-to-paste `call_local` function in `integration/call_local.sh`.

Key design points from the qwen project:
- The script path and venv path are the two required config variables. `LOCAL_MODEL` is optional (defaults to the AWQ model in `review.py`).
- The local provider does not need an "effort" knob analogous to `OPENAI_EFFORT` or `GEMINI_EFFORT`. The model runs a single inference pass with fixed sampling parameters (temperature 0.2, max_tokens 4096). The only tunable is `LOCAL_MODEL` itself (swap to a different model if desired). Keeping the `.env` section to three lines (script, venv, model) is appropriate.
- The `call_local` function captures stderr separately, forwards it after completion (same as cloud providers), and uses the existing `TIMEOUT` variable with the `timeout` command.
- Unlike the cloud providers which check for a non-empty API key, the local provider should also verify the script file actually exists on disk before launching. This prevents confusing errors when the `.env` points at a path that was deleted or never set up.

The installer change creates the `.env` file if absent and appends the local section if not already present. This follows the pattern requested by the user: pre-populated but commented out, so uncommenting is all a user needs to do after running `setup.sh` in the qwen project.

Relevant zat.env practices: shell scripts must be idempotent, use `set -euo pipefail`, guard with existence checks. Tests should follow the existing `pass()`/`fail()` pattern in `test-review-external.sh`. The installer must have no side effects for users who do not have the qwen project.

---
*Prior spec (2026-04-08): External multi-model code review. 9/9 criteria met.*

<!-- SPEC_META: {"date":"2026-04-09","title":"Local GPU reviewer integration (qwen)","criteria_total":8,"criteria_met":8} -->
