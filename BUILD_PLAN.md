# Krishi AI — Build Plan

> Self-contained plan you can open in any window. Keep `BUILD_CHECKLIST.md`
> open alongside this file to tick items off as you go.

---

## 1. Goal

Ship a clean, Bangla-first, **demo-grade** Flutter agriculture app per the
47-section spec. **No fabricated live data**: every screen must clearly label
demo/seed values via an `isDemo` flag or an in-screen disclaimer banner.

## 2. Brand & design tokens (locked)

- App name: `Krishi AI` (English) / `কৃষি AI` (Bangla).
- Primary green: `#2E7D32`. Accent orange: `#FF9800`.
- Dark weather card: `#2E3B2E`. Field card: `#1B4D22`.
- Bangla-first strings live in `lib/core/constants/app_strings.dart`.
- Preserve the existing `assets/agro.png` splash look — referenced from the
  new `SplashScreen`.

## 3. Status of every layer (this session)

| Layer | Status | Notes |
| --- | --- | --- |
| `pubspec.yaml` | ✅ done | `flutter pub get` succeeded. |
| Theme (`lib/core/theme/*`) | ✅ done | `app_colors.dart`, `app_text_styles.dart`, `app_spacing.dart`, `app_theme.dart`. |
| Widgets (`lib/core/widgets/*`) | ✅ done | `AppCard`, `PrimaryButton`, `AppTextField`, `LoadingState`/`EmptyState`/`ErrorState`/`OfflineBanner`, `AppChip`, `AppImage`/`AppAvatar`. |
| Constants + utils | ✅ done | `AppStrings`, `AppDate`, `AppNumber`. |
| Models (`lib/data/models/*`) | ✅ done | All 13 immutable models with `toJson/fromJson/copyWith`. |
| Repositories (`lib/data/repositories/*`) | ✅ done | 11 repos wrapping `LocalStore` + `DemoData`. |
| Mock seed (`lib/data/mock/demo_data.dart`) | ✅ done | Rahim/Khulna dataset. |
| Services | ✅ done | `PermissionService`, `SpeechService`. |
| Providers (`lib/presentation/providers/app_providers.dart`) | ✅ done | All repos + async data providers. |
| Router (`lib/presentation/router/app_router.dart`) | ✅ done | Full route table + `MainShell`. |
| Onboarding screens | ✅ done | splash / onboarding / profile-setup / permissions. |
| **Home dashboard** | ⏭ next | First screen to build this session. |
| My Farm + Crops | ⬜ pending | |
| AI Crop Doctor | ⬜ pending | |
| AI Assistant chat | ⬜ pending | |
| Weather | ⬜ pending | |
| Disease library | ⬜ pending | |
| Market | ⬜ pending | |
| Finance (expense / profit / analytics) | ⬜ pending | |
| Tools (irrigation / fertilizer / recs) | ⬜ pending | |
| Notifications / Profile / Subscription / Settings | ⬜ pending | |
| Wire `main.dart` | ⬜ pending | |
| `flutter analyze` clean | ⬜ pending | |

## 4. Build order (next sessions)

```
1. Home dashboard          (keep original look + glass weather card)
2. My Farm + Crops         (list / add / detail with timeline)
3. AI Crop Doctor          (camera/gallery → analyze → result → history)
4. AI Assistant chat       (text + voice mic)
5. Weather                 (hourly + 7-day + agronomy insight)
6. Disease library         (search + categories + detail)
7. Market                  (search + favorites + trends)
8. Farm Finance            (expense / profit calc / analytics charts)
9. Tools                   (irrigation / fertilizer / recs aggregator)
10. Notifications / Profile / Subscription / Settings / Help / About / Privacy
11. Wire `lib/main.dart`   (ProviderScope + MaterialApp.router)
12. `flutter analyze`      (resolve all warnings/errors)
13. `flutter build apk --debug`
```

## 5. Conventions

- **Files**: `lib/presentation/screens/<feature>/<name>_screen.dart`.
- **Riverpod**: read repos via `ref.watch(repoProvider.future)`; invalidate
  after writes with `ref.invalidate(correspondingDataProvider)`.
- **Routing**: always use `context.go(...)` for tabs, `context.push(...)` for
  detail screens, and pass extras through `state.extra as Map<String, dynamic>`.
- **Disclaimer**: every screen showing demo data MUST include the relevant
  `AppStrings.aiDisclaimer|weatherDisclaimer|marketDisclaimer|profitDisclaimer`.
- **Bangla strings**: new strings go into `app_strings.dart` — no inline Bangla
  copy in widgets.

## 6. Reusable building blocks

```dart
// Read farmer / farm / crops everywhere via:
final farmer   = await ref.watch(currentFarmerProvider.future);
final farms    = await ref.watch(farmsProvider.future);
final crops    = await ref.watch(cropsProvider.future);
final weather  = await ref.watch(weatherProvider.future);
```

```dart
// Navigate:
context.go('/home');                // tab
context.push('/farm/crop/${id}');   // detail
context.push('/ai/scan');           // AI scanner
```

```dart
// Demo banner:
import '../../widgets/demo_banner.dart';
DemoBanner(message: AppStrings.weatherDisclaimer),
```

## 7. Resumption prompt (copy/paste this each switch)

> "Continue Krishi AI per `BUILD_PLAN.md`. Pick up from step **N** in
> `BUILD_CHECKLIST.md`. Preserve the original splash agro.png and dashboard
> look. Use `create_file` for new screens, `replace_string_in_file` for
> AppStrings edits and main.dart wiring. Update both `BUILD_PLAN.md` (status
> column) and `BUILD_CHECKLIST.md` (tick items) at the end of each batch.
> Run `flutter analyze` and fix all errors before stopping."

## 8. Out of scope for this build

- Real ML inference (mock with rule-based disease lookup).
- bdapps / SSLCommerz integration (subscription is a stub flag flip).
- Live weather API (demo data only).
- Real auth (profile stored locally).
