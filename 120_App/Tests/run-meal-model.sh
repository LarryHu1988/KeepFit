#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
qa_root="$(mktemp -d /tmp/keepfit-meal-qa.XXXXXX)"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
: "${KEEPFIT_QA_DEVICE:?Set a dedicated disposable iOS Simulator UDID}"
cp -R "$repo_root/KeepFitApp" "$qa_root/KeepFitApp"
cp "$repo_root/project.yml" "$qa_root/project.yml"
mkdir "$qa_root/UITests" "$qa_root/UnitTests"
cp "$repo_root/Tests/MealModelFlowTests.swift" "$qa_root/UITests/"
cp "$repo_root/Tests/MealImportTests.swift" "$qa_root/UnitTests/"
cat >> "$qa_root/project.yml" <<'YAML'
  KeepFitMealUnit:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources: [UnitTests]
    dependencies:
      - target: KeepFit
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.larry.keepfit.mealunit
  KeepFitMealUI:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "17.0"
    sources: [UITests]
    dependencies:
      - target: KeepFit
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.larry.keepfit.mealui
schemes:
  MealQA:
    build:
      targets:
        KeepFit: all
        KeepFitMealUnit: [test]
        KeepFitMealUI: [test]
    test:
      targets: [KeepFitMealUnit, KeepFitMealUI]
YAML
(cd "$qa_root" && xcodegen generate)
KEEPFIT_PROVIDER=demo KEEPFIT_CLIENT_KEYS='{"simulator":"keepfit-isolated-simulator-flow-test-token"}' PYTHONPATH="$repo_root/../122_Backend/keepfit-model" /Users/larry/Library/Caches/KeepFitModel/venv/bin/python -m keepfit_model --demo --port 18766 --data-dir "$qa_root/server-data" > "$qa_root/server.log" 2>&1 &
service_pid=$!
trap 'kill "$service_pid" 2>/dev/null || true' EXIT
printf '%s\n' "$qa_root" > /tmp/keepfit-meal-qa-current
xcodebuild test -project "$qa_root/KeepFit.xcodeproj" -scheme MealQA -destination "platform=iOS Simulator,id=$KEEPFIT_QA_DEVICE" -derivedDataPath "$qa_root/DerivedData" -resultBundlePath "$qa_root/MealQA.xcresult" -jobs 2 CODE_SIGNING_ALLOWED=NO > "$qa_root/test.log" 2>&1
printf 'QA project and results: %s\n' "$qa_root"
