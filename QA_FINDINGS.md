# Phase 5 QA Findings — Visual / Behavioural Pass

Scope: visual & behavioural review of every Phase-4 screen + the shared widget contracts
under `lib/core/`. Audit run after Phase 4 close-out; baseline `flutter analyze` is
captured in `_qa_analyze_baseline.txt` (**0 errors / 0 warnings / 24 pre-existing info
lints** — all 24 sit in the legacy `dashboard_screen.dart` and are out of scope here).

## Severity legend
- **P0** — runtime / visible regression. Fix before any new feature work.
- **P1** — visible polish / contrast / i18n gap. Fix in the same pass when cheap.
- **P2** — DRY / refactor candidate. Logged for the next Phase 5b sweep.

---

## P0 — runtime / UX blockers

### F-01 — `help_screen.dart`: FAQ teaser pushes to a broken route
- File: `lib/presentation/screens/settings/help_screen.dart`
- Symptom: tapping the FAQ teaser card crashes (`context.push` against a route that
  doesn't exist). The literal string in the source contains stray escaped quotes
  (`'/'settings/help''`) — clearly a copy/paste artefact.
- Fix: change the route to `'/help'` (which exists in the router) or to whatever
  target the file actually intends.
- Detected: Phase 5 step 1, audit pass.

### F-02 — `privacy_screen.dart`: invisible `_UpdatedRow` IconBadge
- File: `lib/presentation/screens/settings/privacy_screen.dart`
- Symptom: the "last updated" row uses `tint: AppColors.primaryContainer` (a pale
  green) with `color: AppColors.primary` (a strong green) on the icon — the icon
  blends into the badge background and disappears.
- Fix: swap the tint to a non-green family — `AppColors.tintBlue` (info blue) or
  `AppColors.tintSlate` keeps the row visually distinct without competing with the
  section's green palette.
- Detected: Phase 5 step 1, audit pass.

### F-03 — `subscription_screen.dart`: escalation dialog uses the wrong icon
- File: `lib/presentation/screens/subscription/subscription_screen.dart`
- Symptom: the "Upgrade" button in the soft-prompt escalation dialog is decorated
  with `Icons.bar_chart_rounded` (analytics chart) instead of a premium/upgrade
  glyph. Users see a finance chart where they expect a star/rocket.
- Fix: swap to `Icons.workspace_premium_rounded` (or `Icons.rocket_launch_rounded`
  if a more dynamic feel is wanted). Mirrors the icons already used in
  `profile_screen.dart`'s subscription row.
- Detected: Phase 5 step 1, audit pass.

---

## P1 — visible polish gaps

### F-04 — `core/widgets/states.dart`: `ErrorStateView` hard-codes English copy
- File: `lib/core/widgets/states.dart`
- Symptom: `ErrorStateView` renders `Something went wrong` and `Try again` as
  string literals. The app is otherwise fully Bengali.
- Fix: take `title`/`actionLabel` parameters (with Bengali defaults), or pass
  `AppStrings.errorTitle`/`AppStrings.errorRetry` from the call sites. Same fix
  should also localise `EmptyState`'s English titles if any remain.
- Detected: Phase 5 step 1, audit pass.

### F-05 — `my_crops_screen.dart`: identical empty-state copy in both branches
- File: `lib/presentation/screens/farm/my_crops_screen.dart`
- Symptom: `_EmptyCropsBody` shows the same `message` (`AppStrings.addFirstCrop`)
  regardless of whether the screen is scoped to one farm or shows all crops —
  loses the nuance the strings table actually supports (`AppStrings.noCropsOnFarm`).
- Fix: branch the `message` between `AppStrings.noCropsOnFarm` (when `scoped !=
  null`) and `AppStrings.addFirstCrop` (when null). Today the second branch is
  dead code.
- Detected: Phase 5 step 1, audit pass.

---

## P2 — refactor / DRY backlog (logged, not in this pass)

### F-06 — Every screen reimplements `_Header` + `_Blob` + `_RoundIconButton`
- Files: 13 screens — `home_dashboard`, `weather`, `market`, `scan_history`,
  `crop_doctor`, `ai_assistant`, `notifications`, `settings`, `help`, `privacy`,
  `subscription`, `about`, `profile`, `edit_profile`, `my_farm`, `my_crops`.
- Symptom: the gradient `Stack(Container + Positioned(blob) + SafeArea(...))`
  header is duplicated verbatim in every screen. Two visible variants
  ("title + action button" vs. "IconBadge + eyebrow + title") are intermixed.
- Suggested follow-up: extract `lib/core/widgets/screen_header.dart` exposing
  `ScreenHeader({eyebrow, title, iconBadgeIcon, actionIcon, onAction})`. Saves
  ~30-50 lines per screen and centralises the gradient palette.
- Detected: Phase 5 step 1.

### F-07 — `profile_screen.dart`: `_totalLandAcres` uses `dynamic` duck-typing
- File: `lib/presentation/screens/profile/profile_screen.dart`
- Symptom: the helper casts to `dynamic` and swallows all errors with bare
  `try/catch (_) {}`. Should `import '../../../data/models/farm.dart'` and
  type the list properly. Pure cleanup, no behaviour change.
- Detected: Phase 5 step 1.

### F-08 — Multiple screens ignore `RefreshIndicator.onRefresh`
- Files: `my_farm_screen.dart`, `my_crops_screen.dart`
- Symptom: both screens attach a `RefreshIndicator` whose `onRefresh` body is a
  comment-only no-op. Riverpod auto-refreshes, but the gesture should still
  give the user feedback (e.g. `ref.invalidate(farmsProvider)` /
  `ref.invalidate(cropsProvider)`).
- Detected: Phase 5 step 1.

---

## Per-screen audit summary

| Screen | Status | Notes |
|---|---|---|
| `home_dashboard.dart` | ✅ clean | Pattern reference; Riverpod `ref.watch`s. |
| `weather_screen.dart` | ✅ clean | |
| `market_screen.dart` | ✅ clean | |
| `scan_history_screen.dart` | ✅ clean | |
| `crop_doctor_screen.dart` | ✅ clean | Full image-picker + permission flow. |
| `ai_assistant_screen.dart` | ✅ clean | Chat bubbles kept by design. |
| `notifications_screen.dart` | ✅ clean | Proper `Column(Header + Expanded(async.when))`. |
| `settings_screen.dart` | ✅ clean | |
| `help_screen.dart` | ❌ P0 (F-01) | Broken route. |
| `privacy_screen.dart` | ❌ P0 (F-02) | Invisible IconBadge tint. |
| `subscription_screen.dart` | ❌ P0 (F-03) | Wrong icon on Upgrade button. |
| `about_screen.dart` | ✅ clean | |
| `profile_screen.dart` | ⚠️ P2 (F-07) | `dynamic` duck-typing. |
| `edit_profile_screen.dart` | ✅ clean | Form validates, persists via repo. |
| `my_farm_screen.dart` | ⚠️ P2 (F-08) | No-op refresh. |
| `my_crops_screen.dart` | ⚠️ P1 (F-05) + P2 (F-08) | Duplicated empty-state copy + no-op refresh. |

---

## Shared contract verification

- `app_colors.dart`, `app_spacing.dart`, `app_text_styles.dart` — all on token
  surface; no hard-coded hex outside the file.
- `app_card.dart`, `icon_badge.dart`, `section_header.dart`, `app_chip.dart`,
  `primary_button.dart`, `secondary_button.dart`, `app_text_field.dart`,
  `app_divider.dart` — every screen consumes via these contracts; no
  regressions.
- `states.dart` — `LoadingState`/`EmptyState` are clean; `ErrorStateView` has
  the F-04 hard-coded English gap.

## Next pass
1. Apply P0 fixes (F-01, F-02, F-03).
2. Apply P1 cheap fixes (F-04, F-05).
3. Re-run `flutter analyze` (expect 0/0) and `flutter build apk --debug`.
4. Open Phase 5b with F-06 (`ScreenHeader` extraction) as the headline.
