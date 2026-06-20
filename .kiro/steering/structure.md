# rPerf — Project Structure

## Directory Layout
```
rPerf/
├── lib/                          # Dart/Flutter application source
│   ├── main.dart                 # App entry point, Hive init, MaterialApp
│   ├── models/                   # Data models (Hive-persisted)
│   │   ├── aircraft.dart         # Aircraft profile with points & correction factors
│   │   ├── aircraft.g.dart       # Hive TypeAdapter (generated)
│   │   ├── airport.dart          # Airport, Runway, RunwayDirection (plain classes)
│   │   ├── correction_factors.dart       # Wind/slope correction factors
│   │   ├── correction_factors.g.dart     # Hive TypeAdapter (generated)
│   │   ├── performance_point.dart        # Single POH data point
│   │   └── performance_point.g.dart      # Hive TypeAdapter (generated)
│   ├── pages/                    # Full-screen pages
│   │   ├── aircraft_list_page.dart       # Home: list aircraft, import/export, settings
│   │   ├── aircraft_edit_page.dart       # Edit aircraft details & performance points
│   │   └── compute_page.dart             # Performance calculator with airport/runway
│   ├── services/                 # Business logic & data access
│   │   ├── airport_service.dart          # OpenAIP API client + Hive cache + AIRAC cycle
│   │   ├── calculations.dart             # Pressure altitude, ISA, wind/slope corrections
│   │   ├── hive_service.dart             # Hive initialization & aircraft CRUD
│   │   ├── import_export_service.dart    # JSON/CSV import & export (share + save)
│   │   └── interpolation.dart            # Trilinear interpolation engine
│   └── widgets/                  # Reusable UI components
│       ├── labeled_text_field.dart        # Simple labeled TextField wrapper
│       ├── performance_point_editor.dart  # Dialog for adding/editing a data point
│       ├── runway_visualization.dart      # CustomPaint runway diagram
│       └── stepper_field.dart            # TextField with +/- increment buttons
├── android/                      # Android platform project (Kotlin + Gradle KTS)
├── ios/                          # iOS platform project (Swift + Xcode)
├── assets/images/                # App logo
├── plane_samples/                # Example aircraft data files (CSV, JSON)
├── test/                         # Flutter widget tests
├── pubspec.yaml                  # Flutter dependencies & assets
└── analysis_options.yaml         # Dart linter config (flutter_lints)
```

## Core Architecture
- **Pattern**: Service-oriented with Hive for local persistence; no state management library (uses StatefulWidget + ValueListenableBuilder on Hive boxes)
- **Data Flow**: Pages → Services → Hive boxes. Airport data fetched on-demand from OpenAIP REST API and cached in Hive.
- **Navigation**: Simple imperative Navigator.push between 3 pages (list → edit, list → compute)
- **Models**: Aircraft, PerformancePoint, CorrectionFactors are Hive objects (with generated adapters). Airport/Runway/RunwayDirection are plain Dart classes with JSON serialization.

## Key Relationships
- `AircraftListPage` → `AircraftEditPage` (edit) / `ComputePage` (calculate)
- `ComputePage` uses `Interpolator` + `Calc` + `AirportService` to produce results
- `HiveService` initializes all Hive boxes and delegates airport init to `AirportService`
- `ImportExportService` reads/writes aircraft data via `HiveService.aircraftBox()`
