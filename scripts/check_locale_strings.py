#!/usr/bin/env python3
"""Check every shipped locale is a complete, on-device-safe translation.

A Connect IQ data field renders a metric's label with WatchUi.loadResource, which
returns the string for the *device* language. If a language file is missing a
key, the device silently falls back to the default (English) string - so a rider
with a Russian watch would see an English label. Nothing at build time catches
that, so this does:

  - every locale must define exactly the same string ids as the default resources
    (a missing id would fall back to English; an unexpected id is dead weight);
  - no translated value may be empty;
  - every metric label must fit the 12-char on-device budget in every language,
    the same limit the RaceStatsView draws to and the Run No Evil test asserts for
    the simulator's language.

Run from anywhere; paths are resolved relative to the repository root.
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# The on-device budget for a field header, matched to RaceStatsView's layout and
# the allMetricLabelsWithinTwelveChars Run No Evil test.
MAX_METRIC_LABEL = 12


def load_strings(path: Path) -> dict[str, str]:
    """id -> value for every <string> in a strings.xml resource file."""
    root = ET.parse(path).getroot()
    return {s.get("id"): (s.text or "").strip() for s in root.findall("string")}


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    default = load_strings(repo / "resources" / "strings" / "strings.xml")
    default_ids = set(default)

    locale_files = sorted(repo.glob("resources-*/strings/strings.xml"))
    if not locale_files:
        print("error: no resources-*/strings/strings.xml found", file=sys.stderr)
        return 1

    problems: list[str] = []
    for path in locale_files:
        locale = path.parent.parent.name  # e.g. resources-rus
        strings = load_strings(path)
        ids = set(strings)

        for missing in sorted(default_ids - ids):
            problems.append(f"{locale}: missing '{missing}' (would fall back to English)")
        for extra in sorted(ids - default_ids):
            problems.append(f"{locale}: unexpected '{extra}' (not in default resources)")

        for id_, value in strings.items():
            if value == "":
                problems.append(f"{locale}: '{id_}' is empty")
            if id_.startswith("Metric") and len(value) > MAX_METRIC_LABEL:
                problems.append(
                    f"{locale}: '{id_}' = '{value}' is {len(value)} chars, over the "
                    f"{MAX_METRIC_LABEL}-char label budget"
                )

    if problems:
        print("Locale string problems found:", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    print(
        f"OK: {len(locale_files)} locales complete and within budget "
        f"against {len(default_ids)} default strings"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
