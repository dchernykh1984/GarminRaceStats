# GarminRaceStats

A Garmin Connect IQ **data field** for bike computers that shows a rider their
live standing during a race - place, gaps to the riders ahead and behind, and
laps - by polling the [UniversalBicycleTeam](https://universalbicycle.team) site
by competition id and bib number.

The referee tools compute the classification and push a small per-rider stats
snapshot to the site; the watch polls the public endpoint and renders one metric
per field. The field is deliberately "dumb": it maps known JSON keys to a display
value, ignores unknown keys, and shows blank for missing ones, so new stats can
be added server-side without breaking older installs.

## How it works

- Connect IQ only lets a data field make web requests from a **background
  temporal process**, and never more often than every **5 minutes**. That is
  fine here: standings only change when a rider crosses a lap finish. Once per
  cycle the background service issues a single `GET` and caches the result in
  `Application.Storage`; every field read renders from that cache.
- The rider configures the site URL, competition id, bib, and which metric the
  field shows in the phone's Connect IQ / Garmin Connect app.
- All values are strings, pre-formatted by the server (`"17"`, `"+0:12"`,
  `"3/7"`, `"DSQ"`), so the watch stays trivial. See the source and the design
  notes for the full data dictionary.

## Repository layout

```
manifest.xml                 Connect IQ app manifest (data field, Edge products)
monkey.jungle                Build configuration
source/
  GarminRaceStatsApp.mc      App entry; registers the 5-min background fetch
  BackgroundService.mc       Temporal process; the single web request
  StatsStore.mc              Storage + settings glue (shared with background)
  StatsFormatter.mc          Pure key -> value / label helpers (unit tested)
  RaceStatsView.mc           The SimpleDataField that renders one metric
  StatsFormatterTest.mc      Run No Evil unit tests for StatsFormatter
resources/                   Strings, settings, and the launcher icon
```

## Setup

### 1. Clone the project

```bash
git clone https://github.com/dchernykh1984/GarminRaceStats.git
cd GarminRaceStats
```

### 2. Build and run the unit tests

**Recommended - no local SDK install (Docker).** The
[connectiq-tester](https://github.com/matco/connectiq-tester) image bundles the
Connect IQ SDK, compiles the app for a device, and runs the "Run No Evil" unit
tests. It generates a throwaway developer certificate automatically:

```bash
docker run --rm -v "$PWD":/app -w /app ghcr.io/matco/connectiq-tester:latest edge1040
```

A green run ends with `BUILD SUCCESSFUL` and `PASSED (...)`.

**Full development (device/simulator runs).** Install the
[Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and the **Monkey
C** VS Code extension. From there you can build, run in the simulator, and
side-load onto a real Edge for on-the-bike testing.

### 3. Format the Monkey C sources

Formatting uses [Prettier](https://prettier.io/) with the
[prettier-plugin-monkeyc](https://github.com/markw65/prettier-plugin-monkeyc)
plugin. Install the tooling once, then format or check:

```bash
npm install
npm run format         # rewrite files in place
npm run format:check   # verify formatting (used by CI)
```

### 4. Set up pre-commit hooks (contributors)

Install [pre-commit](https://pre-commit.com/) (`brew install pre-commit`, or
`pipx install pre-commit`), then register the hooks:

```bash
pre-commit install
```

After that the hooks run automatically:

- **on commit** - file/format checks, a non-ASCII guard, and Prettier;
- **on the commit message** - Conventional Commits validation (commitizen);
- **on push** - the Connect IQ build and unit tests in Docker.

Run everything manually across the repo with:

```bash
pre-commit run --all-files
```

## Configuration

The rider edits these in the Connect IQ / Garmin Connect app on the phone:

- **Site URL** - defaults to `https://universalbicycle.team` (editable in case
  the site moves).
- **Competition ID** - the numeric id from the race page URL.
- **Bib number** - the rider's race number.
- **Metric** - which value this field shows (place, gaps, riders, or laps, in
  overall or group scope).

To show several metrics at once, place the field in several data slots - a
future version will ship independently configurable clone fields.

## Continuous integration and releases

Every pull request must pass the required checks before review: the Connect IQ
build and unit tests, `pre-commit` (formatting and the non-ASCII guard),
commitizen (Conventional Commits), `actionlint`, and an OSV dependency scan.

Releases are automated with `release-please`: it maintains a version-bump PR from
the Conventional Commits and, when merged, tags a GitHub Release and updates the
changelog. The **Build and Distribute** workflow then builds the signed `.iq`
store package (using the `DEVELOPER_KEY_BASE64` secret) and attaches it to that
release. Uploading the attached `.iq` to the Connect IQ Store - with the
description, screenshots and release notes - stays manual, because Garmin has no
public publish API.

A separate **beta** app is available for on-device testing without touching the
public listing. A beta must use a different Connect IQ app id, so the manual
**Build Beta** workflow (`workflow_dispatch`) runs `scripts/make_beta_manifest.py`
to swap the manifest to the beta id and the `RaceStats Beta` name, builds a signed
`.iq`, and uploads it as a workflow artifact. Download that artifact and upload it
to the beta listing with "Upload New Version". Public builds are unaffected.

## Contributing

Use Conventional Commit messages, keep each commit atomic, and cover new logic
with unit tests. Make sure CI is green, then request a review from
[@dchernykh1984](https://github.com/dchernykh1984).

## License

Released under the [MIT License](LICENSE).
