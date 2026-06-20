# rPerf — Technology Stack

## Languages & SDK
- **Dart** (SDK ≥3.3.0 <4.0.0) — primary language
- **Flutter** — UI framework (Material 3 enabled)
- **Kotlin** — Android MainActivity
- **Swift** — iOS AppDelegate

## Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| hive | ^2.2.3 | Local NoSQL database |
| hive_flutter | ^1.1.0 | Flutter integration for Hive |
| path_provider | ^2.1.3 | Platform file paths |
| http | ^1.2.1 | HTTP client (OpenAIP API) |
| file_picker | ^10.3.3 | File import dialog |
| share_plus | ^12.0.0 | Share sheet for export |
| uuid | ^4.4.0 | Unique aircraft IDs |
| flutter_file_dialog | ^3.0.0 | Native save-to-file dialog |

## Dev Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| flutter_test | SDK | Widget testing |
| flutter_lints | ^6.0.0 | Lint rules |
| flutter_launcher_icons | ^0.14.4 | App icon generation |

## Build System
- **Flutter CLI** — `flutter run`, `flutter build`
- **Gradle KTS** — Android build (Kotlin DSL)
- **Xcode** — iOS build
- **Hive code generation** — `*.g.dart` files for TypeAdapters (generated via `build_runner`)

## Key Commands
```bash
flutter pub get                    # Install dependencies
flutter run                        # Run debug build
flutter build apk --release        # Android release APK
flutter build ios --release        # iOS release
dart run build_runner build        # Regenerate Hive adapters (*.g.dart)
flutter analyze                    # Run static analysis
flutter test                       # Run tests
```

## External APIs
- **OpenAIP** (`api.core.openaip.net/api`) — Airport and runway data; requires user-provided API key stored in Hive meta box

## Platform Targets
- Android (primary)
- iOS
- Desktop (partial — save-to-downloads fallback)
