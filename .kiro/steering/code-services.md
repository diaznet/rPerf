---
inclusion: fileMatch
fileMatchPattern: "**/services/*.dart"
---

# rPerf — Services Layer Code Map

## hive_service.dart
Static-only class managing Hive initialization and aircraft CRUD.
- `init()` — registers adapters (Aircraft=0, PerformancePoint=1, CorrectionFactors=2), opens aircraft box, delegates to `AirportService.init()`
- `aircraftBox()` — returns the open `Box<Aircraft>`
- `addAircraft(Aircraft a)` — puts by `a.id`
- `deleteAircraft(String id)` — deletes by id

## airport_service.dart
Static-only class wrapping the OpenAIP REST API with Hive caching.
- **State**: `status` (ValueNotifier<AirportDataStatus>), `apiKey`, `hasApiKey`
- **Hive boxes**: `airport_meta` (api key, AIRAC cycle), `airports_box` (Map per ICAO), `runways_box` (List per ICAO)
- `init()` — opens boxes, sets status to ready
- `setApiKey(String key)` — saves to meta box
- `currentAiracCycle()` — computes current AIRAC cycle identifier (e.g. "2605")
- `checkAndUpdate()` — clears cache if AIRAC cycle changed
- `fetchAirport(String icao)` → `Future<Airport?>` — checks cache, fetches from OpenAIP, caches result. Returns null if no API key.
- `getAirport(String icao)` — sync cache lookup
- `getRunways(String icao)` → `List<Runway>` — from cache
- `clearCache()` — clears airports + runways boxes
- `search(String query, {int limit})` → `List<Airport>` — prefix search on cached ICAO keys
- `_parseAirport(item)`, `_parseRunways(item, icao)`, `_parseDirection(...)` — OpenAIP JSON parsing
- `lastUpdateInfo` — string like "AIRAC 2605 • 3 airports cached"
- `statusMessage` — human-readable status text

## calculations.dart
Pure static math — no state, no persistence.
- `pressureAltitudeFt({fieldElevationFt, qnh, qnhUnit})` — PA from field elev + QNH (hPa or inHg)
- `isaTempCAt(pressureAltitudeFt)` — ISA temperature at a given PA
- `deltaIsaC({pressureAltitudeFt, oatC})` — OAT minus ISA
- `applyCorrections({base, windKts, slopePercent, headwindPercentPerKt, tailwindPercentPerKt, slopePercentPerPercent, isTakeoff})` — multiplicative corrections with floor clamping

## interpolation.dart
Trilinear interpolation engine.
- `InterpolatedResult` — data class with toGround, toOver50, ldGround, ldOver50, isExtrapolated, and optional per-point correction factors
- `Interpolator.interpolate(points, runwayType, weightKg, paFt, deltaIsaC)` → `InterpolatedResult`
- Internal: `_bilinearAtWeight(...)`, `_interpDeltaAtAlt(...)`, `_bracket(sorted, value)`, `_lerp`, `_lerpOpt`, `_lerpResults`, `_pointToResult`

## import_export_service.dart
Static-only class for CSV import/export with share and save-to-file.
- **Export**: `exportAllShare()`, `exportSingleShare(Aircraft)`, `exportAllSave()`, `exportSingleSave(Aircraft)`
- **Import**: `importFromFilePicker()`, `importSample(String assetPath)`
- **CSV format**: 19 columns — aircraft metadata repeated per row, uses `temperatureC` (converts to/from deltaISA internally)
- **Sample aircraft**: list of bundled asset paths for demo imports
- Internal: `_buildCsvContent()`, `_importCsvText(String csv)`, `_parseCsvLine(String)`, `_csvEscape(String)`
