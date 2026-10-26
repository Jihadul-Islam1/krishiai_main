# KrishiAI — Connections Map

> Last updated: 30 Aug 2026. Auto-generated from `lib/` source. Use this
> when you need to know:
>
> - "Which screen routes to which screen?"
> - "What does this file import? What imports this file?"
> - "When I change X, what else breaks?"

For high-level "where does code live", see [`ARCHITECTURE.md`](./ARCHITECTURE.md).

---

## 1. Bootstrap chain (app start)

```
main.dart
├── dotenv.load()                       ← .env
├── Firebase.initializeApp()            ← firebase_options.dart
├── FirestoreService.boot()             ← core/services/firestore_service.dart
└── runApp(ProviderScope(KrishiAI()))
    └── MaterialApp (bng)
        └── _AppRoot
            ├── first launch  → MarketingOnboardingScreen
            │   └── onGetStarted → flag SharedPreferences → _AuthenticatedApp
            └── thereafter     → _AuthenticatedApp
                └── MaterialApp.router(routerConfig: ref.watch(routerProvider))
                    └── app_router.dart (GoRouter, initialLocation: /splash)
                        └── ShellRoute: MainShell (5-tab BottomNavigationBar)
                            ├── /home      → HomeDashboard
                            ├── /farm      → MyFarmScreen
                            ├── /ai        → AIAssistantScreen
                            ├── /market    → MarketScreen
                            └── /profile   → ProfileScreen
```

`-` The GoRouter `redirect:` watches three providers via `GoRouterRefreshNotifier`:
`onboardingCompleteProvider`, `currentFarmerProvider`, `authSessionProvider`.

---

## 2. Bottom-tab shell

`lib/presentation/widgets/main_shell.dart`

| Tab index | Route      | Screen              | Destination in source                  |
| --------- | ---------- | ------------------- | ------------------------------------- |
| 0         | `/home`    | `HomeDashboard`     | `presentation/screens/home/home_dashboard.dart` |
| 1         | `/farm`    | `MyFarmScreen`      | `presentation/screens/farm/my_farm_screen.dart` |
| 2         | `/ai`      | `AIAssistantScreen` | `presentation/screens/ai/ai_assistant_screen.dart` |
| 3         | `/market`  | `MarketScreen`      | `presentation/screens/market/market_screen.dart` |
| 4         | `/profile` | `ProfileScreen`     | `presentation/screens/profile/profile_screen.dart` |

`-` When the user is on tab `/farm`, a **floating action button** appears:
`context.push(''/ai/scan'')` → `CropDoctorScreen` (the camera/scan flow).

---

## 3. Routes — complete table

Every entry below is a `GoRoute` in `lib/presentation/router/app_router.dart`.
Routes outside `ShellRoute` render full-screen, hiding the bottom bar.

| Route                | Screen file                                                 | Route key                         |
| -------------------- | ----------------------------------------------------------- | --------------------------------- |
| `/splash`            | `presentation/screens/onboarding/splash_screen.dart`        | public                            |
| `/onboarding`        | `presentation/screens/onboarding/onboarding_screen.dart`    | public                            |
| `/profile-setup`     | `presentation/screens/onboarding/profile_setup_screen.dart` | public                            |
| `/permissions`       | `presentation/screens/onboarding/permissions_screen.dart`   | public                            |
| `/login`             | `presentation/screens/auth/login_screen.dart`              | public                            |
| `/home`              | `presentation/screens/home/home_dashboard.dart`             | tab 0                             |
| `/farm`              | `presentation/screens/farm/my_farm_screen.dart`             | tab 1                             |
| `/ai`                | `presentation/screens/ai/ai_assistant_screen.dart`          | tab 2                             |
| `/market`            | `presentation/screens/market/market_screen.dart`            | tab 3                             |
| `/profile`           | `presentation/screens/profile/profile_screen.dart`          | tab 4                             |
| `/farm/crops`        | `presentation/screens/farm/my_crops_screen.dart`            | full-screen                       |
| `/farm/crops/:id`    | `MyCropsScreen(farmId: …)`                                  | full-screen                       |
| `/farm/:id`          | `FarmDetailScreen(farmId: …)`                               | full-screen                       |
| `/farm/crop/:id`     | `CropDetailScreen(cropId: …)`                               | full-screen                       |
| `/farm/add`          | `presentation/screens/farm/add_farm_screen.dart`            | full-screen                       |
| `/farm/add-crop`     | `AddCropScreen(farmId: … from state.extra)`                 | full-screen                       |
| `/ai/scan`           | `presentation/screens/ai/crop_doctor_screen.dart`           | full-screen                       |
| `/ai/history`        | `presentation/screens/ai/scan_history_screen.dart`          | full-screen                       |
| `/ai/scan/result`    | `ScanResultScreen(cropName, notes, diagnosis from state.extra)` | full-screen                   |
| `/weather`           | `presentation/screens/weather/weather_screen.dart`          | full-screen                       |
| `/library`           | `presentation/screens/library/disease_library_screen.dart`  | full-screen                       |
| `/library/:id`       | `DiseaseDetailScreen(id: …)`                                | full-screen                       |
| `/market/:id`        | `MarketDetailScreen(priceId: …)`                            | full-screen                       |
| `/expenses`          | `presentation/screens/finance/expense_tracker_screen.dart`  | full-screen                       |
| `/profit`            | `presentation/screens/finance/profit_calculator_screen.dart`| full-screen (uses root navigator) |
| `/analytics`         | `presentation/screens/finance/analytics_screen.dart`        | full-screen                       |
| `/irrigation`        | `presentation/screens/tools/irrigation_screen.dart`          | full-screen                       |
| `/fertilizer`        | `presentation/screens/tools/fertilizer_screen.dart`          | full-screen                       |
| `/notifications`     | `presentation/screens/notifications/notifications_screen.dart` | full-screen                    |
| `/subscription`      | `presentation/screens/subscription/subscription_screen.dart`| full-screen                       |
| `/settings`          | `presentation/screens/settings/settings_screen.dart`        | full-screen                       |
| `/profile/edit`      | `presentation/screens/profile/edit_profile_screen.dart`    | full-screen                       |
| `/help`              | `presentation/screens/settings/help_screen.dart`            | full-screen                       |
| `/about`             | `presentation/screens/settings/about_screen.dart`           | full-screen                       |
| `/privacy`           | `presentation/screens/settings/privacy_screen.dart`         | full-screen                       |

> Legacy fallback: `presentation/screens/home/legacy_agro_dashboard.dart` is
> NOT in the router. It is only mounted from `main.dart`''s `HomeFallback`
> class for tests/error states.

---

## 4. Screen-to-screen navigation map

Each box = one screen. Arrows = `context.push` / `context.go` / `context.pop`
found in source (see `getNav()` calls below). Every arrow''s label is the
target path.

```
                        ┌──────────────────────────┐
                        │ SplashScreen /splash     │
                        └─────────┬────────────────┘
                                  │ router redirect
            first-launch  ────────┼───────  after onboarding
                                  ▼                          ▼
            ┌──────────────────────────┐      ┌──────────────────────────┐
            │  OnboardingScreen         │      │  LoginScreen  /login    │
            │  /onboarding              │      └────────────┬─────────────┘
            │  ─ profile-setup           │                   │ go /home
            │  ─ permissions             │                   │ pop
            └──────────────────────────┘                    ▼
            ┌──────────────────────────────────── MainShell (5 tabs) ─────────┐
            │  HomeDashboard   MyFarmScreen    AIAssistant    Market    Profile │
            │  /home          /farm           /ai            /market   /profile │
            └────┬────────────────┬────────────────┬────────────┬──────────┬───┘
                 │                │                │            │          │
                 ▼                ▼                ▼            ▼          ▼
        ┌──────────────┐  ┌──────────────┐ ┌──────────────┐ ┌───────┐ ┌───────┐
        │ Weather      │  │ MyFarms  ───► │ │ ScanHistory  │ │ ...   │ │ Edit  │
        │ /weather     │  │  /farm/:id    │ │ /ai/history  │ │       │ │ /help │
        │ AddFarm      │  │  /farm/add    │ │              │ │       │ │ /about│
        │ /farm/add    │  │  /farm/crops  │ │              │ │       │ │ /priv │
        │ Crops        │  │  /farm/crop/: │ │              │ │       │ │ /sub  │
        │ /farm/crops  │  │  /farm/add-   │ │              │ │       │ │ /sett │
        │ CropDetail   │  │   crop        │ │              │ │       │ │ /notif│
        │ /farm/crop/: │  │  /expenses    │ │              │ │       │ │       │
        │ Expenses     │  │  /weather     │ │              │ │       │ │       │
        │ /expenses    │  │  /ai/scan     │ │              │ │       │ │       │
        │ Profit       │  │               │ │              │ │       │ │       │
        │ /profit      │  │               │ │              │ │       │ │       │
        │ Analytics    │  │               │ │              │ │       │ │       │
        │ /analytics   │  │               │ │              │ │       │ │       │
        │ Irrigation   │  │               │ │              │ │       │ │       │
        │ /irrigation  │  │               │ │              │ │       │ │       │
        │ Fertilizer   │  │               │ │              │ │       │ │       │
        │ /fertilizer  │  │               │ │              │ │       │ │       │
        │ Library      │  │               │ │              │ │       │ │       │
        │ /library     │  │               │ │              │ │       │ │       │
        │ DiseaseDet   │  │               │ │              │ │       │ │       │
        │ /library/:id │  │               │ │              │ │       │ │       │
        │ Notify       │  │               │ │              │ │       │ │       │
        │ /notifications│ │               │ │              │ │       │ │       │
        └──────────────┘  └──────────────┘ └──────────────┘ └───────┘ └───────┘
```

### 4.1 Onboarding flow (cold start)

| # | From → To                                  | Trigger                              | File                    |
| - | ------------------------------------------ | ------------------------------------ | ----------------------- |
| 1 | `/splash` → `/onboarding`                  | `onboardingCompleteProvider == false` | `app_router.dart`       |
| 2 | `OnboardingScreen` → `/profile-setup`       | "Next" button                        | `onboarding_screen.dart`|
| 3 | `ProfileSetupScreen` → `/permissions`      | "Continue"                           | `profile_setup_screen.dart`|
| 4 | `PermissionsScreen` → `/home`              | "Continue" after permissions         | `permissions_screen.dart`|
| 5 | `LoginScreen` → `/home`                    | successful login                     | `login_screen.dart`     |

### 4.2 Home dashboard quick actions

`lib/presentation/screens/home/home_dashboard.dart`

| Action tile                              | Destination                |
| ---------------------------------------- | -------------------------- |
| Weather card / button                    | `/weather`                 |
| "My Farm" / "My Crops" tile (×4)         | `/farm/crops`              |
| "AI Scan" tile                           | `/ai/scan`                 |
| "AI Chat" / "AI Assistant" tile          | `/ai` (tab switch)         |
| "Market" tile                            | `/market` (tab switch)     |
| "Disease Library" tile                   | `/library`                 |
| "Expenses" tile                          | `/expenses`                |
| "Profit Calculator" tile                 | `/profit`                  |
| "Analytics" tile                         | `/analytics`               |
| "Irrigation" tile                        | `/irrigation`              |
| "Fertilizer" tile                        | `/fertilizer`              |
| "Scan History" tile                      | `/ai/history`              |
| "Notifications" tile                     | `/notifications`           |
| Farm card → farm detail                  | `/farm/{id}`               |
| "Add farm" FAB on empty state            | `/farm/add`                |

### 4.3 My Farm (`/farm`)

`lib/presentation/screens/farm/my_farm_screen.dart`

| Action                                          | Destination                |
| ----------------------------------------------- | -------------------------- |
| Empty-state "Add"                               | `/farm/add`                |
| Card "Add farm"                                 | `/farm/add`                |
| Quick actions → "Add crop"                      | `/farm/add-crop`           |
| Quick actions → "Scan"                          | `/ai/scan`                 |
| Quick actions → "Expense"                       | `/expenses`                |
| Card tap (open farm)                            | `/farm/{id}`               |
| Card → "Add crop"                               | `/farm/add-crop`           |
| "See all" crops                                 | `/farm/crops`              |
| Weather strip                                   | `/weather`                 |

`lib/presentation/screens/farm/my_crops_screen.dart`

| Action                                | Destination                |
| ------------------------------------- | -------------------------- |
| Empty "Add"                           | `/farm/add-crop`           |
| Header "Add"                          | `/farm/add-crop`           |
| Crop card tap                         | `/farm/crop/{id}`          |

`lib/presentation/screens/farm/farm_detail_screen.dart`

| Action                                | Destination                |
| ------------------------------------- | -------------------------- |
| Section header → "Add crop"           | `/farm/add-crop` (extra: farmId) |
| Crop card tap                         | `/farm/crop/{id}`          |
| AppBar back                           | `pop`                      |

`lib/presentation/screens/farm/crop_detail_screen.dart` — exits via `pop`.

### 4.4 AI flow (`/ai` tab → sub-routes)

| Trigger                                                  | Goes to                  | File                            |
| -------------------------------------------------------- | ------------------------ | ------------------------------- |
| AI tab main → "Scan now" CTA                            | `/ai/scan`               | `ai_assistant_screen.dart`      |
| FAB on `/farm` tab                                      | `/ai/scan`               | `main_shell.dart`               |
| `crop_doctor_screen.dart` analyzes image                | `/ai/scan/result` (extra: cropName, notes, diagnosis) | `crop_doctor_screen.dart`     |
| After scan → "View history" CTA                          | `/ai/history`            | `crop_doctor_screen.dart`       |
| `scan_history_screen.dart` empty-state CTA               | `/ai/scan`               | `scan_history_screen.dart`      |
| Scan card tap                                           | `/ai/scan/result`        | `scan_history_screen.dart`      |
| `scan_result_screen.dart` "Scan another"                | `/ai/scan`               | `scan_result_screen.dart`       |
| `disease_detail_screen.dart` → "Scan yours" CTA          | `/ai/scan`               | `disease_detail_screen.dart`    |

### 4.5 Market, Library, Tools, Finance

| From                                | Goes to                | Notes                                      |
| ----------------------------------- | ---------------------- | ------------------------------------------ |
| `market_screen.dart` price row      | `/market/{price.id}`   | → `market_detail_screen.dart`              |
| `market_detail_screen.dart` row     | `/market/{price.id}`   | self-open from detail of related item      |
| `disease_library_screen.dart` tile  | `/library/{id}`        | → `disease_detail_screen.dart`             |
| Profit calculator tile on Home      | `/profit`              | uses root navigator (hides tab bar)        |

### 4.6 Profile + Settings

`lib/presentation/screens/profile/profile_screen.dart`

| Tile                 | Destination        |
| -------------------- | ------------------ |
| Edit profile         | `/profile/edit`    |
| Notifications        | `/notifications`   |
| Subscription         | `/subscription`    |
| Help                 | `/help`            |
| Privacy              | `/privacy`         |
| About                | `/about`           |
| Logout               | `go /login`        |
| Replay onboarding    | `go /onboarding`   |

`lib/presentation/screens/settings/settings_screen.dart`

| Tile                 | Destination        |
| -------------------- | ------------------ |
| Edit profile         | `/profile/edit`    |
| Notifications        | `/notifications`   |
| Subscription         | `/subscription`    |
| Help                 | `/help`            |
| Privacy              | `/privacy`         |
| About                | `/about`           |
| Replay onboarding    | `go /onboarding`   |

---

## 5. File-level dependency map

Only files in `lib/`. Format: `A → B` means A imports B (relative path).

### 5.1 Entry point

```
main.dart
  → firebase_options.dart
  → core/services/firestore_service.dart
  → presentation/providers/app_providers.dart
  → presentation/screens/onboarding/marketing_onboarding_screen.dart
  → presentation/screens/home/legacy_agro_dashboard.dart  (test fallback)
```

### 5.2 Router / shell / providers

```
presentation/router/app_router.dart
  → every presentation/screens/<feature>/*_screen.dart
  → presentation/widgets/main_shell.dart
  → presentation/providers/app_providers.dart
  → data/models/diagnosis.dart   (for ScanResultScreen extra)

presentation/widgets/main_shell.dart
  → core/constants/app_strings.dart
  → core/theme/app_colors.dart

presentation/widgets/demo_banner.dart
  → (no relative imports; uses Flutter only)
```

### 5.3 Provider graph (`presentation/providers/app_providers.dart`)

This is the single biggest cross-cut file. Below is the dependency order it
*wires up* — follow the arrows to see what each provider depends on, but
also what is exposed to screens.

```
                  ┌────────────────────────────────────────┐
                  │  app_providers.dart exposes            │
                  └────────────────────────────────────────┘
                                  │
   sharedPreferencesProvider ◄──┐ depends on: nothing (FutureProvider)
                                  │
   authPhoneProvider            ◄──┘ depends on: LocalStore key check
                                  │
   localStoreProvider           ◄──┐
       (LocalStore)                  ├─ depends on sharedPreferences + authPhone
                                     │
   ┌─────────────────────────────────┘
   ▼
   farmerRepoProvider, farmRepoProvider, cropRepoProvider,
   diseaseRepoProvider, aiRepoProvider, expenseRepoProvider,
   marketRepoProvider, notificationRepoProvider, recommendationRepoProvider,
   subscriptionRepoProvider, weatherRepoProvider, weatherLocationRepoProvider
     each → constructor(LocalStore)

   imageStorageProvider       → ImgbbImageStorage
                                (in core/services/remote_image_storage.dart)

   diseaseApiProvider         → DiseaseApiService
                                (in core/network/disease_api_service.dart)

   permissionServiceProvider  → PermissionService
                                (in core/services/permission_service.dart)

   speechServiceProvider      → SpeechService
                                (in core/services/speech_service.dart)

   onboardingCompleteProvider, currentFarmerProvider,
   authSessionProvider, firestoreHydrationProvider
                                → computed from the above + FirestoreService
```

What every screen actually pulls from `app_providers.dart`:

| Screen                              | Providers read                                                                            |
| ----------------------------------- | ----------------------------------------------------------------------------------------- |
| `home_dashboard.dart`               | `currentFarmerProvider`, `farmRepoProvider`, `weatherRepoProvider`, `weatherLocationRepoProvider`, `imageStorageProvider` |
| `my_farm_screen.dart`               | `currentFarmerProvider`, `farmRepoProvider`, `cropRepoProvider`, `weatherRepoProvider`, `weatherLocationRepoProvider` |
| `farm_detail_screen.dart`           | `farmRepoProvider`, `cropRepoProvider`                                                    |
| `my_crops_screen.dart`              | `currentFarmerProvider`, `farmRepoProvider`, `cropRepoProvider`                           |
| `crop_detail_screen.dart`           | `cropRepoProvider`                                                                        |
| `add_farm_screen.dart`              | `currentFarmerProvider`, `farmRepoProvider`                                               |
| `add_crop_screen.dart`              | `farmRepoProvider`, `cropRepoProvider`                                                    |
| `ai_assistant_screen.dart`          | `currentFarmerProvider`, `permissionServiceProvider`, `aiRepoProvider`                   |
| `crop_doctor_screen.dart`           | `cropRepoProvider`, `diseaseRepoProvider`, `diseaseApiProvider`, `imageStorageProvider`, `speechServiceProvider` |
| `scan_history_screen.dart`          | `diseaseRepoProvider`                                                                     |
| `scan_result_screen.dart`           | `diseaseRepoProvider`                                                                     |
| `market_screen.dart`                | `marketRepoProvider`                                                                      |
| `market_detail_screen.dart`         | `marketRepoProvider`                                                                      |
| `disease_library_screen.dart`       | `diseaseRepoProvider`                                                                     |
| `disease_detail_screen.dart`        | `diseaseRepoProvider`                                                                     |
| `expense_tracker_screen.dart`       | `expenseRepoProvider`, `cropRepoProvider`, `currentFarmerProvider`                        |
| `profit_calculator_screen.dart`     | `cropRepoProvider`, `currentFarmerProvider`                                               |
| `analytics_screen.dart`             | `expenseRepoProvider`, `cropRepoProvider`, `currentFarmerProvider`                        |
| `weather_screen.dart`               | `weatherRepoProvider`, `weatherLocationRepoProvider`                                      |
| `irrigation_screen.dart`            | `weatherRepoProvider`                                                                     |
| `fertilizer_screen.dart`            | `cropRepoProvider`, `currentFarmerProvider`                                               |
| `notifications_screen.dart`         | `notificationRepoProvider`                                                                |
| `subscription_screen.dart`          | `subscriptionRepoProvider`                                                                |
| `profile_screen.dart`               | `currentFarmerProvider`, `authSessionProvider`                                            |
| `edit_profile_screen.dart`          | `currentFarmerProvider`, `farmerRepoProvider`                                             |
| `login_screen.dart`                 | `authSessionProvider`                                                                     |
| `splash_screen.dart`                | (listens to `onboardingCompleteProvider` + `authSessionProvider`)                         |

### 5.4 Repository wiring (`lib/data/repositories/*.dart`)

Every repository is constructed with `LocalStore` + (where applicable) an
external service. The wiring happens *only* in `app_providers.dart`.

| Repository                          | Local model pulled by | Uses core services | Uses data services | External HTTP  |
| ----------------------------------- | --------------------- | ------------------ | ------------------ | -------------- |
| `local_store.dart`                  | —                     | `fs_paths`         | —                  | —              |
| `farmer_repository.dart`            | `farmer.dart`         | `fs_paths`         | —                  | —              |
| `farm_repository.dart`              | `farm.dart`           | `firestore_service`, `fs_paths` | —      | —              |
| `crop_repository.dart`              | `crop.dart`           | `firestore_service`, `fs_paths` | —      | —              |
| `disease_repository.dart`           | `diagnosis.dart`, `disease.dart` | `firestore_service`, `fs_paths` | —    | —              |
| `ai_repository.dart`                | `ai_chat.dart`, `diagnosis.dart`, `disease.dart` | `fs_paths` | — | — (uses `disease_repository.dart`)  |
| `expense_repository.dart`           | `expense.dart`        | `firestore_service`, `fs_paths` | —      | —              |
| `market_repository.dart`            | `market_price.dart`   | `fs_paths`         | —                  | http GET (raw) |
| `notification_repository.dart`      | `app_notification.dart` | `fs_paths`       | —                  | —              |
| `recommendation_repository.dart`    | `recommendation.dart` | `fs_paths`         | —                  | —              |
| `subscription_repository.dart`      | `subscription.dart`   | `fs_paths`         | —                  | —              |
| `weather_repository.dart`           | `weather.dart`        | `fs_paths`         | `location_service.dart`, `osm_service.dart`, `open_meteo_api.dart`, `weather_api.dart` | — (via services) |
| `weather_location_repository.dart`  | `weather_location.dart` | `fs_paths`       | —                  | —              |

### 5.5 Service wiring (`lib/data/services/*.dart` + `lib/core/services/*.dart`)

| Service file                                                | Wraps                                             | Used by                                                                |
| ----------------------------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------- |
| `lib/data/services/location_service.dart`                   | `geolocator`                                      | `weather_repository.dart`                                              |
| `lib/data/services/open_meteo_api.dart`                     | `http` → open-meteo.org                           | `weather_repository.dart`                                              |
| `lib/data/services/osm_service.dart`                        | `http` → nominatim.openstreetmap.org              | `weather_repository.dart`                                              |
| `lib/data/services/weather_api.dart`                        | `http` → OpenWeatherMap                           | `weather_repository.dart`                                              |
| `lib/core/services/firestore_service.dart`                 | `cloud_firestore` (low-level ops)                 | `main.dart`, every `*_repository.dart`                                 |
| `lib/core/services/fs_paths.dart`                          | pure string helpers (`/users/{phone}/...`)        | `local_store.dart`, every repository                                   |
| `lib/core/services/remote_image_storage.dart`               | `http` upload to ImgBB                       | `crop_doctor_screen.dart` (via `imageStorageProvider`)                 |
| `lib/core/services/permission_service.dart`                 | `permission_handler`                              | `app_providers.dart` (via `permissionServiceProvider`)                 |
| `lib/core/services/speech_service.dart`                     | `speech_to_text`                                  | `app_providers.dart` (via `speechServiceProvider`)                     |
| `lib/core/network/disease_api_service.dart`                 | `http` → ML backend                               | `app_providers.dart` (via `diseaseApiProvider`)                        |

### 5.6 Shared UI kit dependencies

Every screen pulls a slice of these — search for `../core/widgets/` in any
screen file. Cross-references:

| Widget file                                 | Used heavily by                                                                   |
| ------------------------------------------- | --------------------------------------------------------------------------------- |
| `lib/core/widgets/app_card.dart`            | most list screens (home, farm, market, library, finance)                          |
| `lib/core/widgets/app_chip.dart`            | filter chips (market, disease library, weather)                                  |
| `lib/core/widgets/app_divider.dart`         | list separators                                                                   |
| `lib/core/widgets/app_image.dart`           | any screen with avatars / cover photos                                            |
| `lib/core/widgets/app_text_field.dart`      | form screens (add_farm, add_crop, edit_profile, profile_setup)                    |
| `lib/core/widgets/icon_badge.dart`          | dashboard quick actions, notification rows                                        |
| `lib/core/widgets/location_picker.dart`     | `add_farm_screen`, profile_setup, edit_profile                                    |
| `lib/core/widgets/primary_button.dart`      | almost every form action button                                                   |
| `lib/core/widgets/screen_header.dart`       | top of every screen outside `Scaffold(''s defaultAppBar)`                         |
| `lib/core/widgets/section_header.dart`      | in-page section titles with optional CTA                                          |
| `lib/core/widgets/states.dart`              | `loadingView()`, `emptyView()`, `errorView()` — used everywhere                   |
| `lib/core/widgets/stat_tile.dart`           | KPI cards in analytics, farm detail                                               |

### 5.7 Theme + utility references

| Theme file                          | Imported by                                                                    |
| ----------------------------------- | ------------------------------------------------------------------------------ |
| `core/theme/app_colors.dart`        | almost every screen, `main_shell`, core widgets                                 |
| `core/theme/app_spacing.dart`       | every screen                                                                   |
| `core/theme/app_text_styles.dart`   | every screen                                                                   |
| `core/theme/app_theme.dart`         | `main.dart` (only consumer of `app_theme`)                                     |
| `core/constants/app_strings.dart`   | every screen + `main_shell` (for tab labels)                                   |
| `core/utils/date_utils.dart`        | expense, analytics, farm history rows                                           |
| `core/utils/phone_key.dart`         | `local_store.dart` (key normalization)                                         |
| `core/config/api_config.dart`       | services that read base URL or API keys                                         |

---

## 6. "What depends on this file" cheat sheet

If you are about to change a file and want to know who breaks, the answers
below are read from actual imports.

### Changing `app_providers.dart`
- Breaks every screen (36 files) plus `app_router.dart`.
- Always audit providers first; this file is the contract surface.

### Changing any `data/models/<name>.dart`
- Schema changes will cascade to its repository and every screen that
  consumes the model. Use `flutter analyze` to find direct importers.

### Changing `core/services/firestore_service.dart` or `fs_paths.dart`
- Breaks every repository (12 files) plus `local_store.dart` and `main.dart`.

### Changing `core/services/remote_image_storage.dart`
- Only `crop_doctor_screen.dart` and `app_providers.dart` — safe blast radius.

### Changing `core/services/permission_service.dart`
- Only `app_providers.dart`. (Screens use it indirectly via the provider.)

### Changing `core/services/speech_service.dart`
- Only `app_providers.dart`. Used indirectly by screens like `crop_doctor_screen`.

### Changing `core/network/disease_api_service.dart`
- Only `app_providers.dart`; consumed by `ai_repository.dart`, `crop_doctor_screen.dart`, and `scan_history_screen.dart`.

### Changing any screen
- Re-check `app_router.dart` (route path) and `lib/presentation/widgets/main_shell.dart` (only for the 5 tabs).
- Re-check any other screen that pushes to it (search for the route string).

### Changing the router
- Every screen that uses `context.push(path)` or `context.go(path)` must be
  audited for the old path strings. The router has the canonical list.

### Changing `main.dart` routes / onboarding flag
- The `_AppRoot` flag (`krishiai.onboardingDone`) is shared with native code
  via SharedPreferences. Bumping the key forces every user back through
  onboarding.

---

## 7. End-to-end trace — sample scenarios

### A. User opens app for the first time

```
main.dart (runApp)
  └─ _AppRoot reads SharedPreferences (krishiai.onboardingDone = null)
     └─ splash screen shown
GoRouter redirect: returns /onboarding
  └─ OnboardingScreen → context.go /profile-setup
     └─ ProfileSetupScreen (saves farmer → farmers/{phone} via farmerRepoProvider)
        └─ context.go /permissions
           └─ PermissionsScreen (grants cam/mic/location)
              └─ context.go /home  (sets onboardingDone = true)
                 └─ _AuthenticatedApp → MaterialApp.router
                    └─ HomeDashboard (5-tab shell visible)
```

### B. User taps "Scan crop" from `/farm`

```
MyFarmScreen
  └─ FAB onPressed: context.push(/ai/scan)
GoRouter resolves /ai/scan
  └─ CropDoctorScreen
     ├─ user grants camera permission via permissionServiceProvider
     ├─ image picked → imageStorageProvider.upload() (ImgBB)
     ├─ DiseaseApiService.predict(imageUrl) via diseaseApiProvider
     ├─ DiseaseRepository.saveDiagnosis() via diseaseRepoProvider
     └─ context.push(/ai/scan/result, extra: {...})
        └─ ScanResultScreen renders diagnosis
```

### C. User edits a crop

```
FarmDetailScreen
  └─ crop card onTap → context.push(/farm/crop/{id})
     └─ CropDetailScreen
        └─ Edit button → CropRepository.update(crop) via cropRepoProvider
           └─ FirestoreService writes to users/{phone}/crops/{id}
              └─ localStore shadows the change
                 └─ back nav → CropDetailScreen rebuilds with new data
```

### D. User signs out

```
ProfileScreen
  └─ tap "Logout" → authSessionProvider = false
GoRouter redirect: loc == /home → return /login
  └─ LoginScreen
```

---

## 8. Files with **zero internal imports**

These pull only Flutter/`package:` imports — they are leaf modules and
safe to refactor without sweeping the dependency tree (still tests matter):

- `presentation/screens/home/legacy_agro_dashboard.dart` (standalone)
- `presentation/widgets/demo_banner.dart`

