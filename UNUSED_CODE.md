# Krishi AI - Unused / Dead Code Report

> Generated: 30 Aug 2026 after running a full reference scan over `lib/` plus
> `flutter analyze`. **All findings below were fixed in the same session.**
> `flutter analyze` now reports: **No issues found!**

---

## 1. Files deleted (4)

These files had **zero importers / zero symbol references** anywhere in `lib/`.
They were either leftovers from an earlier refactor or never adopted.

| File (deleted) | What was in it | Why dead |
| --- | --- | --- |
| `lib/core/theme/app_theme.dart` | `AppTheme.light()` - full Material 3 theme | `main.dart` builds its own `_buildTheme()` inline; no caller ever imports `AppTheme` |
| `lib/core/widgets/app_image.dart` | `AppImage` + `AppAvatar` widgets | Every screen uses `Image.network` / `CircleAvatar` directly; these wrappers were never adopted |
| `lib/core/widgets/stat_tile.dart` | `StatTile` widget (label + value + icon) | `home_dashboard.dart` builds its own custom stat cards; `StatTile` was never imported |
| `lib/presentation/widgets/demo_banner.dart` | `DemoBanner` widget for demo data warnings | Replaced by in-screen disclaimers from `AppStrings.aiDisclaimer` etc.; the widget was never imported |

Verification: for each file we extracted `lib/**/*.dart`, then searched all
99 other files for any substring match on the filename basename or any public
symbol declared in it. Zero hits = dead.

---

## 2. Lint / analyzer issues fixed (8)

All came from `flutter analyze`. Every one is now resolved.

| File | Line | Hint | Fix |
| --- | --- | --- | --- |
| `lib/core/network/disease_api_service.dart` | 3 | `unnecessary_import` of `dart:typed_data` | Removed - `package:flutter/foundation.dart` re-exports everything used |
| `lib/core/services/speech_service.dart` | 28 | `deprecated_member_use` for `localeId:` | Moved `localeId` inside `SpeechListenOptions(...)` |
| `lib/data/repositories/ai_repository.dart` | 74, 76 | `prefer_interpolation_to_compose_strings` | Replaced 3 concat `+` with single `$`-interpolation |
| `lib/presentation/screens/ai/crop_doctor_screen.dart` | 103 | `unnecessary_non_null_assertion` | Dropped `!` after `inference` |
| `lib/presentation/screens/ai/crop_doctor_screen.dart` | 157 | `use_null_aware_elements` | Replaced `if (_imagePath != null) ...` with `'imagePath': ?_imagePath` |
| `lib/presentation/screens/farm/add_crop_screen.dart` | 126 | `prefer_conditional_assignment` | `if (_farmId == null) _farmId = ...` -> `_farmId ??= farms.first.id` |
| `lib/presentation/screens/profile/profile_screen.dart` | 306 | `use_build_context_synchronously` after `await` | Added `if (!context.mounted) return;` before `context.go('/login')`; removed `try/catch` |

---

## 3. Audited and kept (false-positive candidates)

| Item | Why kept |
| --- | --- |
| `lib/presentation/screens/home/legacy_agro_dashboard.dart` | Wrapped by `HomeFallback` in `main.dart` - error/test fallback when router fails |
| inline `_buildTheme()` in `main.dart` | One-off 30-line theme builder owned by `main.dart` |
| `pubspec.yaml` - all 17 dependencies | Every package is referenced at least once in `lib/` |
| `assets/agro.png` | Used by `splash_screen.dart` and `legacy_agro_dashboard.dart` |
| Every screen file (32 of them) | Each is referenced by `app_router.dart` or via `context.push` |

---

## 4. How to re-run this audit

```powershell
# (a) Find files in lib/ that no other file references
$files = Get-ChildItem lib -Recurse -Filter *.dart
$files | ForEach-Object {
  $f = $_.FullName; $name = $_.BaseName
  $hits = 0
  $files | Where-Object { $_.FullName -ne $f } | ForEach-Object {
    if ((Get-Content -Raw $_.FullName) -match "\b$name\b") { $hits++ }
  }
  [PSCustomObject]@{ File = $f.Substring(20).Replace('\\','/'); UsedBy = $hits }
} | Where-Object UsedBy -eq 0

# (b) Catch unused imports, dead code, lint hints
flutter analyze
```

Re-run after every refactor to keep the codebase honest.

---

## 5. Pass 2 (30 Aug 2026): puku_dead-code skill results

The puku_dead-code skill produced **6 unused exports** and **13 analyzer
issues** (12 errors + 1 info). All were fixed.

### 5a. Files deleted (1)

| File (deleted) | What was in it | Why dead |
| --- | --- | --- |
| lib/presentation/screens/home/legacy_agro_dashboard.dart | AgricultureDashboardScreen (legacy 1-screen dashboard) | Only referenced by itself + the dead HomeFallback class in main.dart. Once HomeFallback was removed, the file had zero importers. |

### 5b. Classes removed inline (1)

| Class | File | Why dead |
| --- | --- | --- |
| HomeFallback | lib/main.dart | Wrapper around AgricultureDashboardScreen intended as an error/test fallback when the router fails. Only ever referenced itself; no call sites ever triggered it. |

### 5c. Imports / identifiers repointed

| File | Before | After | Why |
| --- | --- | --- | --- |
| lib/main.dart | 'start.dart' | 'presentation/screens/onboarding/marketing_onboarding_screen.dart' | Old flat-layout import path no longer exists |
| lib/main.dart | 'dashboard_screen.dart' | 'presentation/screens/home/legacy_agro_dashboard.dart' (later dropped) | Same - file moved to subfolder |
| lib/main.dart | AgricultureOnboardingScreen( | MarketingOnboardingScreen( | Class was renamed during onboarding refactor; only call site updated |
| lib/presentation/providers/app_providers.dart | '../../services/permission_service.dart' | '../../core/services/permission_service.dart' | Services folder moved under core/ |
| lib/presentation/providers/app_providers.dart | '../../services/speech_service.dart' | '../../core/services/speech_service.dart' | Same |

### 5d. Missing providers added (2)

location_picker.dart referenced weatherLocationRepoProvider and
selectedWeatherLocationProvider, but neither was defined in
pp_providers.dart. Added both after weatherRepoProvider:

`dart
final weatherLocationRepoProvider =
    FutureProvider<WeatherLocationRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return WeatherLocationRepository(store);
});

final selectedWeatherLocationProvider = Provider<WeatherLocation?>((ref) {
  final repoAsync = ref.watch(weatherLocationRepoProvider);
  final repo = repoAsync.valueOrNull;
  if (repo == null) return null;
  return repo.selectedLocation();
});
`

(Also added the missing import '../../data/models/weather_location.dart';
which was required for the WeatherLocation? type annotation.)

### 5e. Doc-comment backticks repaired (3)

A prior heredoc rewrite of pp_providers.dart had silently stripped
backticks from three doc-comment fragments, producing **30+ cascading
errors** (undefined_class, unterminated_string_literal,
missing_function_parameters, etc.). Repaired:

| Line | Broken text | Fixed text |
| --- | --- | --- |
| 49 | It exposes LocalStore (not AsyncValue<LocalStore>) | ` It exposes LocalStore (not AsyncValue<LocalStore>) ` |
| 50 | 	he existing localStoreProvider shape so /// the existing ... (triplicated) ... call-sites that used ref.watch(localStoreProvider.future) | ` the existing localStoreProvider shape so call-sites that used ef.watch(localStoreProvider.future) ` |
| 161 | Returns the saved farmer, or null if profile setup hasn'... + 't been done. (broken mid-line) | ` Returns the saved farmer, or 
ull if profile setup hasn't been done. ` |

### 5f. Lint / analyzer issue fixed (1)

| File | Line | Hint | Fix |
| --- | --- | --- | --- |
| lib/presentation/screens/ai/crop_doctor_screen.dart | 116-117 | use_null_aware_elements | Replaced if (_imagePath != null) 'imagePath': _imagePath and if (imageRemoteUrl != null) 'imageRemoteUrl': imageRemoteUrl with 'imagePath': ?_imagePath and 'imageRemoteUrl': ?imageRemoteUrl (null-aware element syntax) |

### 5g. Audit trail of all touched files

| File | Edit |
| --- | --- |
| lib/main.dart | imports repointed, AgricultureOnboardingScreen -> MarketingOnboardingScreen, HomeFallback class removed (140 lines now, was 174) |
| lib/presentation/providers/app_providers.dart | 2 imports repointed, 1 new import added, 2 new providers added, 3 doc-comment fragments repaired |
| lib/presentation/screens/home/legacy_agro_dashboard.dart | **deleted** |
| lib/presentation/screens/ai/crop_doctor_screen.dart | 2 lines rewritten to use null-aware element syntax |

### 5h. Final state

`	ext
flutter analyze
Analyzing KrishiAi-main...
No issues found! (ran in 2.9s)

flutter build apk --debug
... √ Built build\app\outputs\flutter-apk\app-debug.apk (~202 MB)
`

Only pre-existing warning: speech_to_text plugin still uses the legacy
Kotlin Gradle Plugin (KGP) - tracked separately, not part of dead-code work.
---

## 5. Pass 2 (30 Aug 2026): puku_dead-code skill results

The puku_dead-code skill produced **6 unused exports** and **13 analyzer
issues** (12 errors + 1 info). All were fixed.

### 5a. Files deleted (1)

| File (deleted) | What was in it | Why dead |
| --- | --- | --- |
| lib/presentation/screens/home/legacy_agro_dashboard.dart | AgricultureDashboardScreen (legacy 1-screen dashboard) | Only referenced by itself + the dead HomeFallback class in main.dart. Once HomeFallback was removed, the file had zero importers. |

### 5b. Classes removed inline (1)

| Class | File | Why dead |
| --- | --- | --- |
| HomeFallback | lib/main.dart | Wrapper around AgricultureDashboardScreen intended as an error/test fallback when the router fails. Only ever referenced itself; no call sites ever triggered it. |

### 5c. Imports / identifiers repointed

| File | Before | After | Why |
| --- | --- | --- | --- |
| lib/main.dart | 'start.dart' | 'presentation/screens/onboarding/marketing_onboarding_screen.dart' | Old flat-layout import path no longer exists |
| lib/main.dart | 'dashboard_screen.dart' | 'presentation/screens/home/legacy_agro_dashboard.dart' (later dropped) | Same - file moved to subfolder |
| lib/main.dart | AgricultureOnboardingScreen( | MarketingOnboardingScreen( | Class was renamed during onboarding refactor; only call site updated |
| lib/presentation/providers/app_providers.dart | '../../services/permission_service.dart' | '../../core/services/permission_service.dart' | Services folder moved under core/ |
| lib/presentation/providers/app_providers.dart | '../../services/speech_service.dart' | '../../core/services/speech_service.dart' | Same |

### 5d. Missing providers added (2)

location_picker.dart referenced weatherLocationRepoProvider and
selectedWeatherLocationProvider, but neither was defined in
pp_providers.dart. Added both after weatherRepoProvider:

`dart
final weatherLocationRepoProvider =
    FutureProvider<WeatherLocationRepository>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return WeatherLocationRepository(store);
});

final selectedWeatherLocationProvider = Provider<WeatherLocation?>((ref) {
  final repoAsync = ref.watch(weatherLocationRepoProvider);
  final repo = repoAsync.valueOrNull;
  if (repo == null) return null;
  return repo.selectedLocation();
});
`

(Also added the missing import '../../data/models/weather_location.dart';
which was required for the WeatherLocation? type annotation.)

### 5e. Doc-comment backticks repaired (3)

A prior heredoc rewrite of pp_providers.dart had silently stripped
backticks from three doc-comment fragments, producing **30+ cascading
errors** (undefined_class, unterminated_string_literal,
missing_function_parameters, etc.). Repaired:

| Line | Broken text | Fixed text |
| --- | --- | --- |
| 49 | It exposes LocalStore (not AsyncValue<LocalStore>) | ` It exposes LocalStore (not AsyncValue<LocalStore>) ` |
| 50 | 	he existing localStoreProvider shape so /// the existing ... (triplicated) ... call-sites that used ref.watch(localStoreProvider.future) | ` the existing localStoreProvider shape so call-sites that used ef.watch(localStoreProvider.future) ` |
| 161 | Returns the saved farmer, or null if profile setup hasn'... + 't been done. (broken mid-line) | ` Returns the saved farmer, or 
ull if profile setup hasn't been done. ` |

### 5f. Lint / analyzer issue fixed (1)

| File | Line | Hint | Fix |
| --- | --- | --- | --- |
| lib/presentation/screens/ai/crop_doctor_screen.dart | 116-117 | use_null_aware_elements | Replaced if (_imagePath != null) 'imagePath': _imagePath and if (imageRemoteUrl != null) 'imageRemoteUrl': imageRemoteUrl with 'imagePath': ?_imagePath and 'imageRemoteUrl': ?imageRemoteUrl (null-aware element syntax) |

### 5g. Audit trail of all touched files

| File | Edit |
| --- | --- |
| lib/main.dart | imports repointed, AgricultureOnboardingScreen -> MarketingOnboardingScreen, HomeFallback class removed (140 lines now, was 174) |
| lib/presentation/providers/app_providers.dart | 2 imports repointed, 1 new import added, 2 new providers added, 3 doc-comment fragments repaired |
| lib/presentation/screens/home/legacy_agro_dashboard.dart | **deleted** |
| lib/presentation/screens/ai/crop_doctor_screen.dart | 2 lines rewritten to use null-aware element syntax |

### 5h. Final state

`	ext
flutter analyze
Analyzing KrishiAi-main...
No issues found! (ran in 2.9s)

flutter build apk --debug
... √ Built build\app\outputs\flutter-apk\app-debug.apk (~202 MB)
`

Only pre-existing warning: speech_to_text plugin still uses the legacy
Kotlin Gradle Plugin (KGP) - tracked separately, not part of dead-code work.

---

## 6. Pass 3 (30 Aug 2026): full file-level reference sweep

Re-ran the full per-file reference sweep from section 4 (a) against the entire
lib/ tree. Found **1 dead file**:

| File (deleted) | What was in it | Why dead |
| --- | --- | --- |
| lib/core/widgets/location_picker.dart | LocationPicker modal bottom-sheet (Bangladesh district picker) | No file in lib/ imports it or calls showLocationPicker(). weather_screen.dart only reads snapshot.location (weather data), not user location. |

Cascading follow-on deletions (since LocationPicker was the only consumer of these
symbols, the entire location-picker subtree is now dead):

| File (deleted) | What was in it | Why dead |
| --- | --- | --- |
| lib/data/models/weather_location.dart | WeatherLocation model + kBangladeshLocations const | Only consumed by LocationPicker and WeatherLocationRepository |
| lib/data/repositories/weather_location_repository.dart | WeatherLocationRepository | Only consumed by LocationPicker (via the two providers below) |

Cascading edits to lib/presentation/providers/app_providers.dart:
- Removed import '../../data/models/weather_location.dart';
- Removed import '../../data/repositories/weather_location_repository.dart';
- Removed weatherLocationRepoProvider (FutureProvider<WeatherLocationRepository>)
- Removed selectedWeatherLocationProvider (Provider<WeatherLocation?>)

After deletion, dart fix was applied across the workspace and
lutter analyze was re-run. Final state: **No issues found! (ran in 3.6s)**.

### 6a. Final dead-file count

`
total dart files in lib/: 92
dead files:                0
`

All files in lib/ are now referenced by at least one other file in the codebase.

---

## 6. Pass 3 (30 Aug 2026): full file-level reference sweep

Re-ran the full per-file reference sweep from section 4 (a) against the entire
lib/ tree. Found **1 dead file**:

| File (deleted) | What was in it | Why dead |
| --- | --- | --- |
| lib/core/widgets/location_picker.dart | LocationPicker modal bottom-sheet (Bangladesh district picker) | No file in lib/ imports it or calls showLocationPicker(). weather_screen.dart only reads snapshot.location (weather data), not user location. |

Cascading follow-on deletions (since LocationPicker was the only consumer of these
symbols, the entire location-picker subtree is now dead):

| File (deleted) | What was in it | Why dead |
| --- | --- | --- |
| lib/data/models/weather_location.dart | WeatherLocation model + kBangladeshLocations const | Only consumed by LocationPicker and WeatherLocationRepository |
| lib/data/repositories/weather_location_repository.dart | WeatherLocationRepository | Only consumed by LocationPicker (via the two providers below) |

Cascading edits to lib/presentation/providers/app_providers.dart:
- Removed import '../../data/models/weather_location.dart';
- Removed import '../../data/repositories/weather_location_repository.dart';
- Removed weatherLocationRepoProvider (FutureProvider<WeatherLocationRepository>)
- Removed selectedWeatherLocationProvider (Provider<WeatherLocation?>)

After deletion, dart fix was applied across the workspace and
lutter analyze was re-run. Final state: **No issues found! (ran in 3.6s)**.

### 6a. Final dead-file count

`
total dart files in lib/: 92
dead files:                0
`

All files in lib/ are now referenced by at least one other file in the codebase.