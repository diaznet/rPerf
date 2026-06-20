---
inclusion: fileMatch
fileMatchPattern: "**/pages/*.dart"
---

# rPerf — Pages Layer Code Map

## aircraft_list_page.dart
StatelessWidget — home screen showing all aircraft.
- **AppBar actions**: Import button, Settings popup (OpenAIP API key dialog, flush cache, about), Export popup (share/save all)
- **Body**: `ValueListenableBuilder` on aircraft box → ListView of aircraft
- **ListTile tap** → `ComputePage(aircraftId: a.id)`
- **ListTile long-press** → bottom sheet with Edit, Duplicate, Export, Delete
- **FAB** → creates new Aircraft with defaults, navigates to AircraftEditPage
- **Import dialog**: file picker (CSV) + sample aircraft list from bundled assets
- **Settings > OpenAIP API key**: AlertDialog with TextField, saves via `AirportService.setApiKey()`

## aircraft_edit_page.dart
StatefulWidget — edit aircraft metadata, correction factors, and performance points.
- **State**: TextEditingControllers for registration, name, MTOW, grass penalty, 6 correction factor fields
- `_save()` — reads controllers, updates Aircraft object, calls `a.save()`
- `_delete()` — confirm dialog, then `HiveService.deleteAircraft()`
- **Body**: form fields + correction factors section + performance points list
- **Points list**: Card per point showing runway type, weight, PA, ΔISA, distances. Tap → edit dialog, delete icon → remove
- **Add Point**: opens `PerformancePointEditor` dialog

## compute_page.dart
StatefulWidget — main performance calculator with airport/runway integration.
- **Input controllers**: fieldElev, qnh, temp, weight, wind, slope, icao, tora, toda, lda
- **State**: qnhUnit, runwayType, distType, marginPercent, selected airport/runway/direction, results
- `_compute()` — orchestrates: parse inputs → Calc.pressureAltitudeFt → Calc.deltaIsaC → Interpolator.interpolate → Calc.applyCorrections → grass penalty → margin → setState results
- `_onIcaoChanged(value)` — autocomplete from cache, exact match → select, 4-char → fetch from API (checks hasApiKey first, shows SnackBar if missing)
- `_showNoApiKeyMessage()` — SnackBar with "Go to Settings" action that pops back
- `_selectAirport(airport)` — sets airport/runways state, fills elevation + declared distances, recomputes
- `_fillDeclaredDistances()` — populates TORA/TODA/LDA fields from selected direction
- `_activeDirection` — returns le or he RunwayDirection based on toggle
- `_toAvailable` / `_ldAvailable` — reads editable declared distance fields with fallback to model
- **UI sections**: input fields wrap → margin slider → results card → airport/runway section (ICAO field with helper text if no API key, runway dropdown, direction dropdown, declared distances, RunwayVisualization × 2)
