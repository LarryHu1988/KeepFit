# Trend date axis regression checks

Compile and run the production tick selector directly (no simulator required):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  KeepFitApp/Components/TrendAxisTickLayout.swift Tests/TrendAxisTickLayoutTests.swift \
  -o /tmp/keepfit-axis-tests
/tmp/keepfit-axis-tests
```

Checks cover the seven-point missing-date regression, removing the fixed seven-label
limit on wide plots, collision spacing, first/last dates, and balanced sampling for
12,768 combinations of data counts, plot widths, and scaled text widths.

For screenshot verification, use a Debug build on a dedicated KeepFit simulator:

```sh
xcrun simctl launch DEVICE_ID com.larry.keepfit \
  -keepfit-screenshot-mode -keepfit-selected-tab lose \
  -keepfit-screenshot-date 2026-10-20 -keepfit-chart-qa-count 7 \
  -keepfit-screenshot-focus lose-trends
```

Use `7` and `80` records. The count override is compiled only in Debug and applies
only to the existing screenshot fixture; it never loads user records. Focus values
`lose-weight-trend` and `lose-body-fat-trend` show the other charts. Terminate the
app before relaunching with different arguments. Check normal and small phones,
and change `simctl ui DEVICE_ID content_size extra-extra-extra-large` while running
to verify that live tick updates keep the correct first and last labels. Restore
`content_size large` afterward. These checks do not certify DUO pose transitions.

## Settings interaction regression

`SettingsVerifiedFlows.swift` checks the first tap on the native share sheet, the About developer label, and both related-app cards with their store/home actions. The script creates an isolated XcodeGen QA project in `/tmp` without changing the app project or signing settings:

```sh
KEEPFIT_QA_DEVICE=<dedicated-simulator-UDID> ./Tests/run-settings-ui.sh
```

Requires Xcode and XcodeGen. App Store review presentation still requires a real device with the App Store; the app opens the fixed official `action=write-review` URL directly.

## Exercise selection interaction

```sh
KEEPFIT_QA_DEVICE=<dedicated-simulator-UDID> ./Tests/run-exercise-selection-ui.sh
```

The temporary QA project checks that search is visible immediately, rows expose only the exercise name, Chinese and English searches work (including surrounding whitespace), selecting an exercise still saves a workout, and clearing an unmatched query restores the list. MET values remain in the calculation model and are hidden only in the picker.
