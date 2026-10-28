# Exercise selector simplification — 2026-10-27

Exercise rows show only icon and name. MET subtitles are removed from the picker. The search box is always visible, matching the food selector, and matches Chinese/English names case-insensitively after trimming surrounding whitespace. Empty results have a search-empty state.

The temporary Xcode QA build and complete simulator UI test passed. The test verifies the visible search field on first opening, name-only row labels, Chinese partial matching, mixed-case English matching with surrounding whitespace, selection and workout saving, empty results and clearing search. Screenshots use the existing screenshot-mode sample records.

The exercise data, saved-record model and calorie calculation files match TestFlight 1.1.3 (40). MET remains available for energy calculations. This is a local development update; no new TestFlight upload was performed.

Result bundle: `/tmp/keepfit-exercise-selection-qa.9Iq5fU/ExerciseSelectionQA.xcresult`.
