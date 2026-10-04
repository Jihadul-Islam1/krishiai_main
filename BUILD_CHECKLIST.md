# Krishi AI — Build Checklist

Tick as you go. Keep this open alongside `BUILD_PLAN.md`.

## Phase A — Foundations (✅ complete)

- [x] `pubspec.yaml` updated + `flutter pub get` clean
- [x] Theme tokens (`AppColors`, `AppTextStyles`, `AppSpacing`, `AppTheme`)
- [x] Reusable widgets (`AppCard`, buttons, fields, states, chips, image)
- [x] Centralized Bangla strings (`AppStrings`)
- [x] Date / number utilities (`AppDate`, `AppNumber`)
- [x] All 13 data models
- [x] All repositories wrapping `LocalStore`
- [x] `DemoData` seed dataset (Rahim/Khulna)
- [x] `PermissionService`, `SpeechService`
- [x] Riverpod providers (`app_providers.dart`)
- [x] GoRouter with `MainShell` + 5 tabs
- [x] Onboarding flow (splash, 4-slide, profile, permissions)

## Phase B — Core feature screens (✅ complete)

### 1. Home dashboard
- [x] `lib/presentation/screens/home/home_dashboard.dart`
- [x] Greeting + weather hero (dark glass look)
- [x] "আজকের কৃষি পরামর্শ" recommendation row
- [x] My-crop summary cards
- [x] AI Crop Doctor CTA
- [x] Farm health + quick actions
- [x] Demo banner (`AppStrings.weatherDisclaimer`)

### 2. My Farm + Crops
- [x] `my_farm_screen.dart` (list farms + summary)
- [x] `my_crops_screen.dart` (grouped by farm)
- [x] `crop_detail_screen.dart` (timeline + stage + irrigation)
- [x] `add_farm_screen.dart`, `add_crop_screen.dart` (forms)

### 3. AI Crop Doctor
- [x] `crop_doctor_screen.dart` (camera/gallery/take-photo flow)
- [x] `scan_result_screen.dart` (severity, confidence, symptoms…)
- [x] Save diagnosis to history

### 4. AI Assistant chat
- [x] `ai_assistant_screen.dart` (chat bubbles, voice mic)
- [x] Wire `SpeechService.listen(...)` with locale `bn_BD`
- [x] Suggestion chips (সেচ, সার, রোগ)

### 5. Weather
- [x] `weather_screen.dart` (current + hourly strip + 7-day cards)
- [x] Agronomy insight section
- [x] Demo banner

### 6. Disease library
- [x] `disease_library_screen.dart` (search + categories)
- [x] `disease_detail_screen.dart` (symptoms/causes/prevention/management)

### 7. Market
- [x] `market_screen.dart` (search + favorites + trend chips)
- [x] `market_detail_screen.dart` (price history placeholder + disclaimer)

### 8. Farm Finance
- [x] `expense_tracker_screen.dart` (list + add modal)
- [x] `profit_calculator_screen.dart` (input form → results)
- [x] `analytics_screen.dart` (fl_chart: category pie + monthly bars)

### 9. Tools
- [x] `irrigation_screen.dart` (form + tip card)
- [x] `fertilizer_screen.dart` (form + tip card)
- [x] Recommendations aggregator inside home/dashboard

## Phase C — System screens (✅ complete)

### 10. Notifications + Profile + Subscription + Settings
- [x] `notifications_screen.dart`
- [x] `profile_screen.dart` (farmer + farm list, links)
- [x] `edit_profile_screen.dart`
- [x] `subscription_screen.dart` (Free / Premium tiers)
- [x] `settings_screen.dart` (theme, language, about, sign out)
- [x] `help_screen.dart`, `about_screen.dart`, `privacy_screen.dart`

## Phase D — Wire & verify (✅ complete)

- [x] `lib/main.dart`: `ProviderScope` + `MaterialApp.router` + theme
- [x] Update `assets/agro.png` reference if needed
- [x] `flutter analyze` returns 0 errors (warnings reviewed)
- [x] `flutter build apk --debug` builds
- [x] Update `BUILD_PLAN.md` "Status" column
- [x] Tick the boxes above

---

### Resumption copy/paste

> "Continue Krishi AI per `BUILD_PLAN.md`. Pick up from the next unchecked
> item in `BUILD_CHECKLIST.md`. Preserve the original splash agro.png and
> dashboard look. Use `create_file` for new screens,
> `replace_string_in_file` for `AppStrings` edits and `main.dart` wiring.
> Update both files at the end of each batch. Run `flutter analyze` and fix
> all errors before stopping."

- [x] lib/presentation/screens/settings/help_screen.dart (Phase 4 step 10/13)
- [x] lib/presentation/screens/settings/privacy_screen.dart (Phase 4 step 10/13)
- [x] lib/presentation/screens/subscription/subscription_screen.dart (Phase 4 step 10/13)

- [x] lib/presentation/screens/settings/help_screen.dart (Phase 4 step 10/13)
- [x] lib/presentation/screens/settings/privacy_screen.dart (Phase 4 step 10/13)
- [x] lib/presentation/screens/subscription/subscription_screen.dart (Phase 4 step 10/13)

- [x] lib/presentation/screens/settings/about_screen.dart (Phase 4 step 11/13)

- [x] lib/presentation/screens/profile/profile_screen.dart (Phase 4 step 12/13)

- [x] lib/presentation/screens/profile/edit_profile_screen.dart (Phase 4 step 13/13)
- [x] **Phase 4 complete (13/13)**

- [x] **Phase 5 step 1** — visual QA pass + P0/P1 fixes landed (F-01/F-02/F-04/F-05); see QA_FINDINGS.md. lutter analyze 0/0/24, APK rebuilt.

- [x] **Phase 5b** — P2 backlog complete (F-03/F-06/F-07/F-08). F-03/F-06/F-08 already shipped in prior sessions; F-07 landed via typed providers in pp_providers.dart + non-nullable currentSubscriptionProvider. lutter analyze 0/0/24, APK rebuilt.
- [x] **Phase 6 — Full Firestore sync (all user data → server)**
  - [x] Every repo now hydrates from Firestore on first read (when LocalStore cache is empty) and mirrors writes per-doc via `FsPaths.*` helpers.
  - [x] Repos wired: `farmer`, `farm`, `crop`, `disease/DiagnosisRepository`, `expense`, `notification`, `subscription`, `ai/chat`, `market` (cache + favorites), `weather` (snapshot cache).
  - [x] `firestore.rules`: opened `meta/*` writes so subscription/AI chat/weather cache/market cache docs sync (previously blocked).
  - [x] `app_providers.dart`: added `firestoreHydrationProvider` that warms all data providers after login.
  - [x] `main.dart`: triggers hydration once user reaches the authenticated app.
  - [x] `flutter analyze` — 0 errors / 0 warnings / 4 pre-existing infos.