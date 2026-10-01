---
name: race-stats-contract
description: The server contract this data field speaks to show a rider their live race standing. Use when working on the polling, the JSON-to-display mapping, or which metrics to show. Contains no secrets.
---

# Live race stats contract

This data field polls the UniversalBicycleTeam timing site by competition id and bib
number and shows one rider their live standing. The Garmin (GarminRaceStats) and Amazfit
(AmazfitRaceStats) apps speak the SAME server contract, so a race timed for one works for
the other - keep the two in sync when the contract changes.

## The contract

- The referee tools compute the classification and PUSH a small per-rider stats snapshot
  to the site. The field polls a public GET endpoint (by competition id + bib) and renders
  one metric per field.
- All values are strings, pre-formatted by the server: place `"17"`, gaps `"+0:12"` /
  `"-0:12"`, laps `"3/7"`, `"DSQ"`. Gap sign is from the reader's point of view: a rider
  ahead is `+`, a rider behind is `-`.
- The client is deliberately dumb: it maps known JSON keys to a display value, IGNORES
  unknown keys, and shows blank for missing ones. New stats can be added server-side
  without breaking older installs, so never hard-fail on an unknown or missing key.
- Known keys include place, quantity, the gaps to the riders ahead/behind and to the
  leader plus their per-lap deltas, and laps. Treat every value as an opaque display
  string.

## Polling limits

- Garmin: a Connect IQ data field may only web-request from a background temporal process,
  at most every 5 minutes. Cache the result in `Application.Storage` and render every field
  read from that cache.
- Amazfit: the watch has no internet; a phone-side service issues the single GET and hands
  the result to the device app.
