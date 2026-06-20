# rPerf — Development Guidelines

## Code Style & Formatting

### Dart Conventions
- **Linter**: Uses `package:flutter_lints/flutter.yaml` (default Flutter lint rules, no custom overrides active)
- **Naming**: camelCase for variables/methods, PascalCase for classes, underscore prefix for private members (`_parse`, `_bracket`, `_RunwayPainter`)
- **Class naming exception**: The app widget is `rPerfApp` (lowercase start) — matches the product name branding
- **Imports**: Relative imports within `lib/` (e.g., `'../models/aircraft.dart'`), package imports for external deps
- **Line style**: Compact — multiple short statements on one line when simple (e.g., `if (mounted) setState(() {});`)

### File Organization
- One primary class per file, named to match the class (e.g., `aircraft.dart` → `Aircraft`)
- Generated Hive adapter files use `.g.dart` suffix with `part` directive
- Widgets are self-contained: each widget file includes its own imports and has no cross-widget dependencies

## Architectural Patterns

### Service Layer (Static Singletons)
All services use **static-only classes** — no instantiation, no dependency injection:
```dart
class HiveService {
  static const aircraftBoxName = 'aircraft_box';
  static Future<void> init() async { ... }
  static Box<Aircraft> aircraftBox() => Hive.box<Aircraft>(aircraftBoxName);
  static Future<void> addAircraft(Aircraft a) async { ... }
}
```
This pattern is consistent across `HiveService`, `AirportService`, `ImportExportService`, `Calc`, and `Interpolator`.

### State Management
- **No state management library** — uses Flutter's built-in `StatefulWidget`
- **Hive reactivity**: `ValueListenableBuilder` on `box.listenable()` for automatic UI updates when Hive data changes
- **ValueNotifier**: `AirportService.status` uses `ValueNotifier<AirportDataStatus>` for status propagation
- **Local state**: `TextEditingController` instances for form fields, initialized in `initState`, disposed in `dispose`

### Data Persistence (Hive)
- Models that need persistence extend `HiveObject` and use `@HiveType`/`@HiveField` annotations
- TypeAdapter registration checks `Hive.isAdapterRegistered(typeId)` before registering
- TypeIds: Aircraft=0, PerformancePoint=1, CorrectionFactors=2
- Airport/Runway data cached as raw Maps in separate Hive boxes (not as HiveObjects)

### JSON Serialization
Every model implements manual `toJson()` and `fromJson()` factory constructors (no code generation for JSON):
```dart
factory Aircraft.fromJson(Map<String, dynamic> j) => Aircraft(
  id: (j['id'] ?? '').toString(),
  registration: (j['registration'] ?? '').toString(),
  mtowKg: (j['mtowKg'] ?? 0).toDouble(),
  // ...
);
```
- Defensive: always provides fallback defaults (`?? ''`, `?? 0`)
- Casts via `.toDouble()` and `.toString()` for type safety from dynamic JSON

## UI Patterns

### Page Structure
- Pages are `StatelessWidget` (list page) or `StatefulWidget` (edit/compute pages)
- `Scaffold` with `AppBar` containing action buttons (save, import, export, settings)
- Form inputs use `Wrap` with fixed-width `SizedBox` containers for responsive layout
- Dialogs via `showDialog<T>` returning typed results

### Custom Widgets
- `StepperField`: TextField with +/- buttons, configurable step/min/max/precision
- `LabeledTextField`: Thin wrapper around TextField with label
- `PerformancePointEditor`: AlertDialog-based form for data point CRUD
- `RunwayVisualization`: CustomPaint widget with dedicated `CustomPainter`

### Navigation
Simple imperative navigation — no named routes:
```dart
Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComputePage(aircraftId: a.id)));
```

## Computation Patterns

### Interpolation
- Trilinear interpolation across weight × pressure altitude × delta ISA
- Uses bracket-finding (`_bracket`) to locate surrounding data points
- Bilinear interpolation at each weight level, then linear interpolation between weights
- Returns `InterpolatedResult` with `isExtrapolated` flag when inputs exceed data envelope

### Aviation Calculations
- Pressure altitude: `fieldElevation + (1013.25 - QNH) × 27.0` (hPa) or `× 1000.0` (inHg)
- ISA temperature: `15.0 - 1.9812 × (PA / 1000)`
- Corrections applied multiplicatively with floor clamping (`factor < 0.1 → 0.1`)

## Error Handling
- `main()` wraps Hive init in try/catch, shows error screen on failure
- API calls use try/catch with `debugPrint` for logging
- Null-safe field access throughout (`??` operators, null checks before use)
- No crash analytics or formal error reporting

## Platform Code
- **Android**: Minimal — default `FlutterActivity` in Kotlin, generated plugin registrant in Java
- **iOS**: Minimal — default `AppDelegate.swift`, generated plugin registrant in Obj-C
- All platform files are Flutter-generated boilerplate; no custom native code

## Steering File Maintenance
When creating or significantly modifying a Dart source file, the corresponding conditional steering file must be updated:
- **Services** (`lib/services/*.dart`) → update `rPerf/.kiro/steering/code-services.md`
- **Pages** (`lib/pages/*.dart`) → update `rPerf/.kiro/steering/code-pages.md`
- **Widgets** (`lib/widgets/*.dart`) → create/update `rPerf/.kiro/steering/code-widgets.md` (fileMatch: `**/widgets/*.dart`)
- **Models** (`lib/models/*.dart`) → create/update `rPerf/.kiro/steering/code-models.md` (fileMatch: `**/models/*.dart`) if model structure changes

Each entry should document: class purpose, key methods/properties with one-line descriptions, important state, and relationships to other files. Keep it concise — this is a code map, not full documentation.
