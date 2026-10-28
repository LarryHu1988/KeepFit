# Food Atlas integration verification — 2026-10-26

- Production iOS Simulator Debug build (arm64 and x86_64): `BUILD SUCCEEDED`, version remains 1.1.1 (38).
- Python database/export suite: 34 tests, zero failures.
- Swift model/contract tests: 7 tests, zero failures.
- iPhone simulator UI flow: 1 test, zero failures; opens selector, searches real USDA egg, selects and saves g; uses temporary QA entries to select/save 250mL and 1个; checks empty search.
- Source catalog: 13,535 complete authorized records. The exporter excludes 53 records with missing core nutrition and excludes unauthorized sources. The production JSON contains no custom QA fixtures.
- 250mL of the temporary 64kcal/100mL fixture produces a 160kcal log; no density is inferred. Swift tests also cover a half egg, explicit gram conversion, invalid input, old log decoding, and nutrition/unit snapshots surviving catalog changes.

Screenshots use the app's existing screenshot-mode sample history. `volume-saved-qa-fixture.png` includes a temporary test food and is not production nutrition data. These artifacts certify simulator behavior, not real-device acceptance or TestFlight distribution.

The final build also verifies the small post-test change that preserves fractional default amounts without rounding them to one decimal and rejects non-finite entered amounts. No signing, upload or publication was performed.

The temporary test result bundle is `/tmp/keepfit-food-atlas-qa.JS8Own/FoodAtlasQA.xcresult`. Xcode also logged an auxiliary simulator diagnostics collection warning; it did not fail the unit/UI tests (`TEST SUCCEEDED`).

For maintenance and data schema, see `nutrition-database/README.md` and `nutrition-database/app-foods.json`. Graph changes are exported into the bundled JSON and require a new app build/distribution to reach installed devices; no remote updater is configured.
