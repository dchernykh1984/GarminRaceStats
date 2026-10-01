# Working in GarminRaceStats

A Garmin Connect IQ data field for bike computers that shows a rider their live race
standing - place, gaps to the riders ahead and behind, and laps - by polling the
UniversalBicycleTeam site by competition id and bib number. It is the Garmin companion to
the Amazfit AmazfitRaceStats app and speaks the same server contract. Written in Monkey C.

## Architecture

Connect IQ only lets a data field make web requests from a background temporal process,
and never more often than every 5 minutes. Once per cycle the background service issues a
single GET and caches the result in `Application.Storage`; every field read renders from
that cache. All server values are pre-formatted strings, so the field stays deliberately
dumb.

## Conventions

- Monkey C / Connect IQ. Source in `source/`, per-locale resources in `resources-*`, build
  described by `monkey.jungle` and `manifest.xml`.
- Never commit to `main`. Branch off `origin/main`, one logical change per commit.
- Commit messages: one-line Conventional Commits, no body, no `Co-Authored-By` trailer and
  no co-author line. `cz check --rev-range origin/main..HEAD` runs on every PR, and
  release-please builds `CHANGELOG.md` from these subjects, so the type matters (`fix` and
  `feat` are released; `chore`/`docs`/`test`/`style` are not).
- ASCII only in tracked source, resources and docs. A `no-non-ascii` pre-commit hook and
  the `.codex` PostToolUse guard both enforce it (`CHANGELOG.md` is exempt).
- Localized strings must stay in sync: `english-resources-in-sync` keeps
  `resources/strings/strings.xml` equal to `resources-eng/strings/strings.xml`, and
  `locales-complete` (`scripts/check_locale_strings.py`) checks that every locale has every
  key. Update all locales when you add or change a string.
- `.mc` files are prettier-formatted (prettier-monkeyc); `connectiq-test` runs the CIQ unit
  tests in Docker. pre-commit runs all of these on commit.

## Skills

- `shipping-a-change` - branch, commit, open the PR, watch CI to green.
- `review-cycle` - review a branch or PR and land the fixes.
- `race-stats-contract` - the server contract shared with AmazfitRaceStats.

## Codex context and hooks

Codex reads this `AGENTS.md` at startup and discovers project skills under
`.agents/skills/`. Read the relevant skill before starting its workflow. Claude
keeps its own `CLAUDE.md`, `.claude/skills/` and `.claude/settings.json`; maintain
both sets when a shared convention changes.

`.codex/hooks.json` runs the ASCII check after `apply_patch` edits, including
multi-file patches and moves. It uses the same file and exemption patterns as
the pre-commit gate. Run `python3 .codex/hooks/test_post_edit.py` to verify the
handler. A post-edit hook reports completed edits; it does not undo them, and
shell writes are still checked by pre-commit.

Project hooks require a trusted project and review of the current hook definition
in `/hooks`. Changed definitions require renewed review. Hooks must also remain
enabled in the local Codex configuration. These PR files do not grant trust or
change user-level configuration.

Claude permission allowlists, attribution settings and confirmation prompts are
not Codex settings. Codex uses its own permissions and approvals; keep explicit
user authorization rules in these instructions. The Claude hooks remain intact.
