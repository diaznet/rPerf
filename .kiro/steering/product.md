# rPerf — Product Overview

## Purpose
rPerf is a mobile/desktop aviation app that calculates landing and take-off performance for general aviation aircraft. Pilots enter performance data from their Pilot's Operating Handbook (POH) and the app interpolates distances for any given set of conditions (weight, pressure altitude, temperature, wind, slope, runway surface).

## Key Features
- **Aircraft Management**: Create, edit, import/export aircraft profiles with performance data points (weight, pressure altitude, delta ISA → distances)
- **Performance Computation**: Multi-dimensional interpolation (weight × pressure altitude × delta ISA) to compute takeoff ground roll, takeoff over 50 ft, landing ground roll, and landing over 50 ft distances
- **Correction Factors**: Wind (headwind/tailwind) and slope corrections per aircraft, plus grass penalty when no grass-specific data exists
- **Airport & Runway Lookup**: On-demand airport data from OpenAIP API with AIRAC-cycle-aware caching; includes declared distances (TORA, TODA, LDA) per runway direction
- **Runway Visualization**: Custom-painted runway diagram showing computed distance vs available distance with green/red go/no-go overlay
- **Import/Export**: JSON and CSV import/export with share and save-to-file options
- **Safety Margin**: Configurable margin slider (0–100%) applied on top of computed distances
- **Extrapolation Warning**: Visual alert when inputs fall outside the POH data envelope

## Target Users
General aviation pilots who need quick, reliable takeoff and landing distance calculations based on their specific aircraft's POH performance tables.

## Status
Work in progress.
