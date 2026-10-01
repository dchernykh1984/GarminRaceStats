---
name: shipping-a-change
description: Branch, commit, open a pull request, and drive CI to green in this repo. Use whenever you are about to commit, push, open a PR, or check CI status.
---

# Shipping a change

## Branch

- Never commit to `main`. `git fetch origin && git switch -c <type>/<slug> origin/main`.
- Stage only files you changed (`git add <path>`), never `git add -A`.

## Commit

- One line, Conventional Commits: `git commit -m "type(scope): summary"`. No body and no
  `Co-Authored-By` trailer. `cz check --rev-range origin/main..HEAD` runs in CI, and
  release-please builds CHANGELOG from these subjects (`feat`/`fix` release;
  `chore`/`docs`/`test`/`style` do not).

## Before pushing

- `npx prettier --check .` formats `.mc` via prettier-monkeyc.
- Keep localized resources in sync: `resources/strings/strings.xml` must equal
  `resources-eng/strings/strings.xml` (english-resources-in-sync), and
  `python3 scripts/check_locale_strings.py` must pass (locales-complete).
- `connectiq-test` runs the Connect IQ unit tests in Docker. pre-commit runs all of these
  on commit.
- ASCII only in tracked source, resources and docs.

## Pull request

- `git push -u origin <branch>` then `gh pr create --base main --title "..." --body "..."`.
- PR body is real content only: no "Generated with Claude Code" line and no co-author
  footer.

## Watch CI to green

- Poll the authoritative rollup, not `gh pr checks` (its per-check status lags):

  ```
  gh pr view <n> --json statusCheckRollup \
    --jq '[.statusCheckRollup[] | {name:(.name//.context), s:(.conclusion//.state)}]'
  ```

- Every check must be SUCCESS before requesting review.
