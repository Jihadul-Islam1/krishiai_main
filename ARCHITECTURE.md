# KrishiAI — Project Architecture

> Last updated: 30 Aug 2026. This document is the single source of truth for
> "where does X live in this codebase?" If you rename or move a file, update
> this file in the same commit.

---

## TL;DR (30-second tour)

- Entry point: **`lib/main.dart`**
- 5-tab shell: **`lib/presentation/widgets/main_shell.dart`**
- Router: **`lib/presentation/router/app_router.dart`**
- All screens: **`lib/presentation/screens/<feature>/<feature>_screen.dart`**
- Data plumbing: **`lib/data/{models,repositories,services}/`** + **`lib/core/services/`**
- Shared UI kit: **`lib/core/{theme,widgets,utils,constants}/`**

If you only have time to read two files, read `main.dart` (entry) and
`app_providers.dart` (Riverpod graph). That pair unlocks everything else.

---

## 1. Directory map

```
lib/
├── main.dart                    ← App bootstrap (.env → Firebase → ProviderScope → MaterialApp)
├── firebase_options.dart        ← Auto-generated Firebase config
│
├── core/                        ← App-wide building blocks (no business logic)
│   ├── config/                  ← API endpoints, keys, runtime config
│   │   └── api_config.dart
│   ├── constants/               ← User-facing strings, enums
│   │   └── app_strings.dart
│   ├── network/                 ← External HTTP clients (disease detection API)
│   │   └── disease_api_service.dart
│   ├── services/                ← Singletons: Firestore, FS paths, image upload,
│   │   │                           permission requests, speech-to-text
│   │   ├── firestore_service.dart
│   │   ├── fs_paths.dart
│   │   ├── permission_service.dart
│   │   ├── remote_image_storage.dart
│   │   └── speech_service.dart
│   ├── theme/                   ← Color palette, spacing, text styles, ThemeData
│   │   ├── app_colors.dart
│   │   ├── app_spacing.dart
│   │   ├── app_text_styles.dart
│   │   └── app_theme.dart
│   ├── utils/                   ← Pure helpers (dates, phone key formatting)
│   │   ├── date_utils.dart
│   │   └── phone_key.dart
│   └── widgets/                 ← Shared UI kit — every screen imports from here
│       ├── app_card.dart
│       ├── app_chip.dart
│       ├── app_divider.dart
│       ├── app_image.dart
│       ├── app_text_field.dart
│       ├── icon_badge.dart
│       ├── location_picker.dart
│       ├── primary_button.dart
│       ├── screen_header.dart
│       ├── section_header.dart
│       ├── states.dart          ← loading/empty/error widgets
│       └── stat_tile.dart
│
├── data/                        ← Domain layer
│   ├── models/                  ← Plain Dart data classes (no Flutter imports)
│   │   ├── ai_chat.dart
│   │   ├── app_notification.dart
│   │   ├── crop.dart
│   │   ├── diagnosis.dart
│   │   ├── disease.dart
│   │   ├── expense.dart
│   │   ├── farm.dart
│   │   ├── farmer.dart
│   │   ├── market_price.dart
│   │   ├── profit_estimate.dart
│   │   ├── recommendation.dart
│   │   ├── subscription.dart
│   │   ├── weather.dart
│   │   └── weather_location.dart
│   ├── repositories/            ← Single-source-of-truth per entity. Screens
│   │   │                            call these; never touch Firestore directly.
│   │   ├── local_store.dart     ← SharedPreferences wrapper (the canonical
│   │   │                            user-scoped cache)
│   │   ├── ai_repository.dart
│   │   ├── crop_repository.dart
│   │   ├── disease_repository.dart
│   │   ├── expense_repository.dart
│   │   ├── farmer_repository.dart
│   │   ├── farm_repository.dart
│   │   ├── market_repository.dart
│   │   ├── notification_repository.dart
│   │   ├── recommendation_repository.dart
│   │   ├── subscription_repository.dart
│   │   ├── weather_location_repository.dart
│   │   └── weather_repository.dart
│   ├── services/                ← External APIs (location, weather, OSM)
│   │   ├── location_service.dart
│   │   ├── open_meteo_api.dart
│   │   ├── osm_service.dart
│   │   └── weather_api.dart
│   └── mock/
│       └── demo_data.dart       ← Hard-coded demo payloads for offline mode
│
└── presentation/                ← All UI lives here
    ├── providers/
    │   └── app_providers.dart   ← Every Riverpod provider in the app
    ├── router/
    │   └── app_router.dart      ← GoRouter config (all routes + redirects)
    ├── widgets/
    │   ├── demo_banner.dart     ← "You are viewing demo data" banner
    │   └── main_shell.dart      ← The 5-tab BottomNavigationBar shell
    └── screens/                 ← One folder per feature; one file per screen
        ├── ai/
        │   ├── ai_assistant_screen.dart
        │   ├── crop_doctor_screen.dart
        │   ├── scan_history_screen.dart
        │   └── scan_result_screen.dart
        ├── auth/
        │   └── login_screen.dart
        ├── farm/
        │   ├── add_crop_screen.dart
        │   ├── add_farm_screen.dart
        │   ├── crop_detail_screen.dart
        │   ├── farm_detail_screen.dart
        │   ├── my_crops_screen.dart
        │   └── my_farm_screen.dart
        ├── finance/
        │   ├── analytics_screen.dart
        │   ├── expense_tracker_screen.dart
        │   └── profit_calculator_screen.dart
        ├── home/
        │   ├── home_dashboard.dart         ← Active 5-tab home (Riverpod)
        │   └── legacy_agro_dashboard.dart  ← Old agro.png header (test
        │                                     fallback only; do not extend)
        ├── library/
        │   ├── disease_detail_screen.dart
        │   └── disease_library_screen.dart
        ├── market/
        │   ├── market_detail_screen.dart
        │   └── market_screen.dart
        ├── notifications/
        │   └── notifications_screen.dart
        ├── onboarding/
        │   ├── marketing_onboarding_screen.dart  ← First-launch splash
        │   ├── onboarding_screen.dart            ← Profile/permissions flow
        │   ├── permissions_screen.dart
        │   ├── profile_setup_screen.dart
        │   └── splash_screen.dart                ← App launch screen
        ├── profile/
        │   ├── edit_profile_screen.dart
        │   └── profile_screen.dart
        ├── settings/
        │   ├── about_screen.dart
        │   ├── help_screen.dart
        │   ├── privacy_screen.dart
        │   └── settings_screen.dart
        ├── subscription/
        │   └── subscription_screen.dart
        ├── tools/
        │   ├── fertilizer_screen.dart
        │   └── irrigation_screen.dart
        └── weather/
            └── weather_screen.dart
```

---

## 2. Layer rules (do not break these)

```
       UI  ──►  Riverpod providers  ──►  Repositories  ──►  Services / Firestore
       (screens & widgets)            (app_providers)    (data/repositories)
```

| From                      | May import…                                                 | Must NOT import…                               |
| ------------------------- | ----------------------------------------------------------- | ---------------------------------------------- |
| `presentation/screens/*`  | `presentation/providers`, `core/widgets`, `core/theme`, `data/models` | `data/repositories`, `data/services`, `core/services` directly |
| `presentation/providers`  | `data/repositories`, `data/models`, `core/services`, `data/services` | `presentation/screens`                         |
| `presentation/widgets`    | `core/widgets`, `core/theme`, `data/models`                 | `data/repositories`                            |
| `data/repositories/*`     | `data/models`, `data/services`, `core/services`             | `presentation/*`                              |
| `data/models/*`           | Flutter `foundation` only (no widgets)                      | Anything else                                  |
| `core/widgets/*`          | `core/theme`                                                | `data/*`, `presentation/*`                     |
| `core/services/*`         | External packages                                           | `presentation/*`, `data/*`                     |

If you find yourself wanting to import a repository from a screen directly,
add a provider in `app_providers.dart` instead.

---

## 3. The flow of a screen

Example: tapping **My Farm → Add Crop**.

1. `app_router.dart` matches `/farm/add-crop` → `AddCropScreen`.
2. `AddCropScreen` reads `farmRepoProvider`, `cropRepoProvider` from
   `app_providers.dart` via `ref.watch`.
3. The repo is constructed lazily, depending on `localStoreProvider`
   (which itself depends on `sharedPreferencesProvider` + `authPhoneProvider`).
4. Repo writes to Firestore under `users/{phone}/crops/{id}` and updates
   the local `LocalStore` shadow cache.
5. Screen navigates back via `context.pop()`.

---

## 4. The flow of a service

Example: "Use my location" on Home.

1. UI calls `repo.currentFromGps(...)`.
2. `WeatherRepository` → `LocationService` (gps coords) → `OsmService`
   (reverse-geocode to district) → `OpenMeteoApi` (weather).
3. Result is cached in Firestore + `LocalStore`, exposed via providers.

---

## 5. Where to add new code

| I want to…                                  | Open / create                                                            |
| ------------------------------------------- | ------------------------------------------------------------------------ |
| Add a screen                                | `lib/presentation/screens/<feature>/<thing>_screen.dart`                 |
| Add a reusable widget                       | `lib/core/widgets/<thing>.dart`                                          |
| Add a new domain entity                     | `lib/data/models/<thing>.dart` (plain Dart, no Flutter widgets)          |
| Add Firestore/network logic                 | `lib/data/repositories/<thing>_repository.dart`                          |
| Add a 3rd-party API wrapper                 | `lib/data/services/<thing>.dart` (or `lib/core/services/` if singleton)  |
| Add a new color/spacing/typography token    | `lib/core/theme/<thing>.dart`                                            |
| Add a Riverpod provider                     | `lib/presentation/providers/app_providers.dart`                          |
| Add a route                                 | `lib/presentation/router/app_router.dart`                                |
| Add a tab to the bottom bar                 | `lib/presentation/widgets/main_shell.dart` + `app_router.dart`           |
| Add a new user-facing string                | `lib/core/constants/app_strings.dart`                                    |

---

## 6. Historical cleanup (do not undo)

The codebase used to have a "stray files at lib root" anti-pattern. They
were merged into the proper structure on 30 Aug 2026:

- `lib/start.dart` (legacy `StartApp` + `AgricultureOnboardingScreen`) →
  deleted. The widget body now lives at
  `lib/presentation/screens/onboarding/marketing_onboarding_screen.dart`
  as `MarketingOnboardingScreen`.
- `lib/dashboard_screen.dart` (legacy `AgricultureDashboardScreen`) →
  moved to `lib/presentation/screens/home/legacy_agro_dashboard.dart`.
  It is kept as a test/error fallback only; the active home is
  `home_dashboard.dart`.
- `lib/services/permission_service.dart` →
  `lib/core/services/permission_service.dart`.
- `lib/services/speech_service.dart` →
  `lib/core/services/speech_service.dart`.
- The empty `lib/services/` directory was removed.

If you see an import like `'../services/permission_service.dart'` outside
of `lib/core/`, that is a bug — fix it.
