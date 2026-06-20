# rPerf — Aircraft Data Format (CSV)

rPerf uses **CSV** as its single data format for importing and exporting aircraft performance data. One file can contain multiple aircraft. The app uses this data to interpolate takeoff and landing distances for any combination of weight, pressure altitude, and temperature.

## File Structure

- One header row with column names
- One data row per performance point
- Aircraft metadata and correction factors are repeated on every row
- Rows with the same `aircraftId` (or `registration` if no `aircraftId`) are grouped into one aircraft
- Fields can be left empty when not applicable (defaults to `0` for distances)

## Columns

| Column | Required | Description |
|--------|----------|-------------|
| `aircraftId` | No | Unique ID (rows with same ID grouped into one aircraft) |
| `registration` | Yes | Aircraft registration (e.g. `F-RPRF`) |
| `name` | Yes | Aircraft type name |
| `mtowKg` | Yes | Maximum takeoff weight in kg |
| `grassPenaltyPercentIfNoGrassData` | No | Grass penalty % when no grass-specific data exists |
| `runwayType` | Yes | `concrete` or `grass` |
| `weightKg` | Yes | Weight for this data point in kg |
| `pressureAltitudeFt` | Yes | Pressure altitude in feet |
| `temperatureC` | Yes | Outside Air Temperature (OAT) in °C |
| `takeoffGroundRollM` | No | Takeoff ground roll in meters |
| `takeoffOver50M` | No | Takeoff distance over 50 ft (15 m) obstacle in meters |
| `landingGroundRollM` | No | Landing ground roll in meters |
| `landingOver50M` | No | Landing distance over 50 ft (15 m) obstacle in meters |
| `headwindTO%/kt` | No | Headwind takeoff correction %/kt |
| `tailwindTO%/kt` | No | Tailwind takeoff correction %/kt |
| `headwindLDG%/kt` | No | Headwind landing correction %/kt |
| `tailwindLDG%/kt` | No | Tailwind landing correction %/kt |
| `slopeTO%/%` | No | Slope takeoff correction %/% |
| `slopeLDG%/%` | No | Slope landing correction %/% |

## Temperature

The `temperatureC` column contains the absolute OAT in °C as found in POH performance tables. The app internally converts to delta ISA for interpolation:

```
deltaISA = temperatureC - (15.0 - 1.9812 × pressureAltitudeFt / 1000)
```

## Distances

All distances are in meters. You only need to fill in the distances you have — leave others empty. The app supports four distance types:

- `takeoffGroundRollM` — takeoff ground roll
- `takeoffOver50M` — takeoff distance to clear 50 ft / 15 m obstacle
- `landingGroundRollM` — landing ground roll
- `landingOver50M` — landing distance from 50 ft / 15 m obstacle

## Runway Types

`runwayType` accepts `concrete` or `grass`. If only concrete data is provided, a configurable grass penalty percentage is applied automatically when grass is selected in the compute page.

## Correction Factors

Correction factors define how wind and slope affect distances. They can vary per data point — the interpolation engine interpolates them alongside distances.

| Column | Unit | Description |
|--------|------|-------------|
| `headwindTO%/kt` | %/kt | Takeoff distance reduction per knot of headwind |
| `tailwindTO%/kt` | %/kt | Takeoff distance increase per knot of tailwind |
| `headwindLDG%/kt` | %/kt | Landing distance reduction per knot of headwind |
| `tailwindLDG%/kt` | %/kt | Landing distance increase per knot of tailwind |
| `slopeTO%/%` | %/% | Takeoff distance increase per percent uphill slope |
| `slopeLDG%/%` | %/% | Landing distance decrease per percent uphill slope |

If correction factors are the same for all points, just repeat the same values on every row. The first row's values are used as the aircraft-level default.

## Data Grid Guidelines

The interpolation engine performs trilinear interpolation across **weight × pressure altitude × temperature**:

- Provide a **complete grid**: every combination of your chosen weight, altitude, and temperature values
- Multiple weights supported (e.g., 800, 900, 1000 kg)
- Temperature grids do not need to be aligned across altitude levels
- More points = more accurate. Typical POH tables: 3–4 weights × 4–6 altitudes × 5–13 temperatures
- Inputs outside the data envelope are clamped with an extrapolation warning

## Examples

### All 4 distances, concrete + grass (sample-evss.csv)

```csv
aircraftId,registration,name,mtowKg,grassPenaltyPercentIfNoGrassData,runwayType,weightKg,pressureAltitudeFt,temperatureC,takeoffGroundRollM,takeoffOver50M,landingGroundRollM,landingOver50M,headwindTO%/kt,tailwindTO%/kt,headwindLDG%/kt,tailwindLDG%/kt,slopeTO%/%,slopeLDG%/%
sample-evss,F-RPRF,Evektor Sporstar RTC,600.0,0.0,concrete,600.0,0.0,-5.0,111.0,316.0,157.0,398.0,0.0,4.0,0.0,4.5,8.0,8.0
sample-evss,F-RPRF,Evektor Sporstar RTC,600.0,0.0,concrete,600.0,2000.0,-5.0,124.0,355.0,167.0,422.0,0.0,4.0,0.0,4.5,8.0,8.0
sample-evss,F-RPRF,Evektor Sporstar RTC,600.0,0.0,grass,600.0,0.0,-5.0,173.0,390.0,203.0,444.0,0.0,4.0,0.0,4.5,8.0,8.0
sample-evss,F-RPRF,Evektor Sporstar RTC,600.0,0.0,concrete,600.0,0.0,15.0,128.0,365.0,169.0,428.0,0.0,4.0,0.0,4.5,8.0,8.0
```

### Partial distances, multi-weight (sample-dr40.csv)

Only takeoff and landing over 50 populated:

```csv
aircraftId,registration,name,mtowKg,grassPenaltyPercentIfNoGrassData,runwayType,weightKg,pressureAltitudeFt,temperatureC,takeoffGroundRollM,takeoffOver50M,landingGroundRollM,landingOver50M,headwindTO%/kt,tailwindTO%/kt,headwindLDG%/kt,tailwindLDG%/kt,slopeTO%/%,slopeLDG%/%
sample-dr40,F-DR40,DR400 140b,1000,15,concrete,800,0,-20,,298,,400,2.1,5,2.1,5,,
sample-dr40,F-DR40,DR400 140b,1000,15,concrete,900,0,-20,,370,,437,2.1,5,2.1,5,,
sample-dr40,F-DR40,DR400 140b,1000,15,concrete,1000,0,-20,,465,,475,2.1,5,2.1,5,,
```

### Per-point correction factors (sample-da20.csv)

Different wind corrections at different altitudes/weights:

```csv
aircraftId,registration,name,mtowKg,grassPenaltyPercentIfNoGrassData,runwayType,weightKg,pressureAltitudeFt,temperatureC,takeoffGroundRollM,takeoffOver50M,landingGroundRollM,landingOver50M,headwindTO%/kt,tailwindTO%/kt,headwindLDG%/kt,tailwindLDG%/kt,slopeTO%/%,slopeLDG%/%
sample-da20,F-DA20,DA20 C1,800,15,concrete,800,0,15,331,424,201,415,2.41,2.83,0,0,,
sample-da20,F-DA20,DA20 C1,800,15,concrete,800,2000,15,399,512,214,432,2.48,2.69,0,0,,
sample-da20,F-DA20,DA20 C1,800,15,concrete,800,4000,15,478,628,227,450,2.39,2.53,0,0,,
```

## Sample Files

Available in `plane_samples/` and loadable from the app via Import → Sample aircraft:

| File | Aircraft | Weights | Distances | Runway types |
|------|----------|---------|-----------|--------------|
| `sample-evss.csv` | Evektor SportStar RTC | 600 | All 4 | concrete + grass |
| `sample-dr40.csv` | DR400 140b | 800, 900, 1000 | TO over 50 + LDG over 50 | concrete |
| `sample-da20.csv` | Diamond DA-20 | 600, 640, 700, 740, 800 | TO ground roll + TO over 50 + LDG (partial) | concrete |
