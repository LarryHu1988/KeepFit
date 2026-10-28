# Food selector simplification — 2026-10-27

The selection list now shows only each food icon and name. Calories, P/F/C and reference subtitles are removed from the picker; the full nutrition values remain available for logging and totals.

The default selection is limited to 100 foods. Matching logged foods are prioritized by usage count; the versioned `commonFoodIDs` list supplies the initial/fallback ordering. All 100 starter foods have Chinese display names. Search still covers all 13,535 records, prioritizes exact names/aliases and displays at most 100 results.

Checks: 36 Python tests, 10 Swift tests and 1 simulator UI flow passed. The tests cover the 100-item limit, usage-based selection, searching outside the starter list, exact-match priority, name-only button labels, units and saving. All 13,535 food IDs and nutritional bases match the previously distributed atlas; only display curation/ranking metadata changed.

Screenshot uses the existing screenshot-mode sample history. Result bundle: `/tmp/keepfit-food-atlas-qa.Oc020I/FoodAtlasQA.xcresult`. This is local development work after TestFlight 1.1.2 (39); no new upload or release was performed.
