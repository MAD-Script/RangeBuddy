# RangeBuddy: multi-bike virtual-battery platform

## Summary

Evolve the current F52-focused app into **RangeBuddy**, an offline-first range and charging companion for “dumb” EV bikes with no phone-accessible telemetry. The F52 remains a bundled, verified starter profile; all other supported bikes use the same virtual-battery and manual-calibration workflow. Original product requirements remain grounded in :codex-file-citation{path="C:\Users\ADMRo\Downloads\EV App Development and Features.pdf" purpose="source"}.

## Product and data model

- Rename user-facing app name, Android label, package metadata, release naming, and repository documentation to RangeBuddy.
- Replace the static single-bike catalog with:
  - Verified official profiles: make, model, battery voltage/Ah, motor power, bike weight, rated top speed, baseline consumption/range, charger defaults, and catalog version.
  - Local unverified profiles: manually entered specs and known full-range, available immediately while a bike request is pending.
  - A selected-bike profile per user, with independent virtual battery state, calibration state, chargers, charge sessions, and trip history.
- Add a public GitHub Issue form for missing-bike requests. The app opens a prefilled form containing make/model, country/market, optional claimed specifications, and an explicit user consent note; no GitHub credential is embedded in the app.
- Publish approved profiles as a versioned GitHub catalog asset. RangeBuddy checks, validates, and downloads catalog-only updates independently of APK updates; users can also refresh the catalog manually.

## Core battery, charging, and location workflows

- Persist virtual battery energy, last full-charge event, calibration confidence, and calibration-event history so predictions survive restarts.
- First use: select a verified bike or create an unverified manual profile, confirm a full charge, optionally enter known real-world full range, and begin with a clearly labeled prediction confidence.
- Improve calibration only through explicit user-confirmed events: full charge, partial charge, bike-dashboard bar drop, low-battery warning, and completed rides. Do not infer voltage or battery chemistry from GPS.
- Add charger profiles: a bike’s default charger plus user-created chargers with voltage, current/wattage, efficiency, and label. Charge sessions record charger, duration, recovered Wh/range, and before/after predicted state; paid locations are categorized only, without price tracking in v1.
- Add saved charging places: Home/free and Paid, with coordinates, optional charger profile, and user-editable label. During rides, show reachable saved places and warn if none is safely reachable using `(straight-line distance × 1.35) + 5 km reserve`, clearly marked as an offline estimate.
- Add manual pause/resume and a stopped-for-two-minutes notification prompt without terminating background GPS logging.

## History, sharing, backup, and updates

- Expand History into trip summaries, graphs/details, calibration-event timeline, and a separate charging-history view.
- Add encrypted local backup/restore for all profiles, battery states, rides, charging places, chargers, and catalog selections.
- Add an opt-in anonymized calibration export containing verified/unverified bike specs, energy/range observations, and calibration events. Exclude raw GPS routes, saved-place coordinates, names, and other identifying data.
- Use public GitHub Releases for Android updates: compare app versions, display changelog notes, download the correct signed APK, verify a published checksum, and open Android’s system installer. Installation always requires user confirmation.
- Add GitHub Actions for tests, signed APK builds, checksums, catalog validation/publishing, and release-asset generation.

## Technical boundaries

- Move catalog profiles from hardcoded Dart data to a versioned local JSON cache with a bundled fallback; validate catalog schema and reject malformed downloads without replacing the current cache.
- Add Hive models/adapters for bike profiles, manual profiles, battery/calibration state, chargers, charge sessions, saved places, and app/catalog update metadata.
- Keep the range engine independent of Flutter/Hive. It receives a selected profile and persisted battery state, emits predictions plus confidence, and remains unit-testable.
- Continue to use offline map tiles and local geodesic calculations; offline routing/navigation is explicitly deferred.

## Test plan

- Verify profile selection/switching isolates each bike’s battery state, history, chargers, and places.
- Test verified catalog migration, catalog refresh, malformed/older catalog rejection, and fallback to bundled profiles.
- Test manual-profile creation, missing-bike issue URL generation, and calibration exports with no GPS or personal-location fields.
- Test full/partial charge, bar-drop, low-battery, known-range calibration, clamping, restart persistence, and confidence status.
- Test charging-place reachability at the conservative threshold and no-place/no-location conditions.
- Test pause/resume and two-minute stopped prompts without duplicate GPS subscriptions.
- Test encrypted backup/restore round trips.
- Test GitHub release states: no update, changelog shown, checksum failure, network failure, Android installer permission denial, and catalog-only updates.

## Assumptions

- Android is the initial supported platform; iOS distribution/update mechanics are deferred.
- GitHub Releases and the bike-request issue tracker are public.
- Users may track immediately with an unverified manual profile while awaiting catalog approval.
- The F52 has a 55 km/h rated Sport speed, while the speed UI may display up to 60 km/h as an over-speed range.
