#!/usr/bin/env python3
"""Rewrite manifest.xml in place so the build produces the *beta* store app.

The beta and public apps must have different Connect IQ app ids (Garmin's rule),
and monkeyc has no flag to override the id - it only reads it from manifest.xml.
So the beta build swaps the id (to the pre-existing beta listing's id) and gives
the app a distinct name, then compiles as usual.

This overwrites manifest.xml, so run it ONLY in the beta build workflow on a
throwaway checkout. The public build compiles the committed manifest unchanged.
"""

import re
import sys
from pathlib import Path

# The Connect IQ app id of the existing beta listing in the store. It is fixed:
# once a beta app is created, its id never changes. Different from the public id.
BETA_APP_ID = "3bdb0b5bfb544e4cb9c91bf6c419e1a3"

# A distinct name so the beta and the public app can coexist on one device and
# are told apart in the store. The manifest name must be a resource reference
# (a literal is rejected by the compiler), so this points at a dedicated string.
BETA_NAME = "@Strings.AppNameBeta"


def main() -> int:
    manifest = Path("manifest.xml")
    text = manifest.read_text(encoding="utf-8")

    text, id_count = re.subn(
        r'(<iq:application\b[^>]*\bid=")[0-9a-f]{32}(")',
        rf"\g<1>{BETA_APP_ID}\g<2>",
        text,
    )
    text, name_count = re.subn(
        r'(<iq:application\b[^>]*\bname=")[^"]*(")',
        rf"\g<1>{BETA_NAME}\g<2>",
        text,
    )

    if id_count != 1 or name_count != 1:
        print(
            f"error: expected exactly one id and name, "
            f"replaced id={id_count}, name={name_count}",
            file=sys.stderr,
        )
        return 1

    manifest.write_text(text, encoding="utf-8")
    print(f"manifest.xml rewritten for beta: id={BETA_APP_ID}, name={BETA_NAME!r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
