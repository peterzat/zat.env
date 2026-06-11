## No active spec

The most recent spec (2026-05-07, v2.0 autonomy foundations: /loop bookkeeping) was
shelved without implementation: 0/6 criteria, no code landed. Run `/spec new`,
`/spec <description>`, or `/spec plan` to start the next unit of work.

---
*Prior spec (2026-05-07): v2.0 autonomy foundations, /loop bookkeeping foundation (deterministic LOOPS.md mutator, /loop start/status/end skill, schema and halt-vocabulary references, tests). Shelved without implementation, 0/6. Full spec text in git at b5bf210.*

*Prior spec (2026-05-01): /codereview external mode. 8/8 criteria met. New Step 0 dispatch on first arg token routes to External-Only Mode (Steps E.1-E.5) which runs configured external reviewers on a resolved diff and prints to terminal without mutating CODEREVIEW.md, the push marker, or invoking /codefix; `bin/review-external.sh` gained `--check` and `--range` flags; hardening landed alongside (marker dir moved to `${XDG_CACHE_HOME}/...`, pre-push hook fail-closed on script error, single-source skip-marker path).*

<!-- SPEC_META: {"date":"2026-05-07","title":"v2.0 /loop foundations (shelved)","criteria_total":6,"criteria_met":0,"status":"shelved"} -->
