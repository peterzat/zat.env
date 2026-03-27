# Git Hooks

Future home for reusable git hooks, starting with adversarial review.

## Planned: Adversarial Review Hook

A `pre-push` or `pre-commit` hook that runs Claude Code as an adversarial reviewer of its own work — checking for regressions, design issues, security problems, and divergence from stated intent before code is committed or pushed.

## Installing a hook into a project

```bash
ln -s ~/src/zat.env/hooks/<hook-name> ~/src/<project>/.git/hooks/<hook-name>
```

## Status

Not yet implemented. See roadmap in README.md.
