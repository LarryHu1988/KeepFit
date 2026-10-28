#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
qa_root="$(mktemp -d /tmp/keepfit-settings-qa.XXXXXX)"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
: "${KEEPFIT_QA_DEVICE:?Set KEEPFIT_QA_DEVICE to a dedicated iOS Simulator UDID}"
cp -R "$repo_root/KeepFitApp" "$qa_root/KeepFitApp"
cp "$repo_root/project.yml" "$qa_root/project.yml"
mkdir "$qa_root/UITests"
cp "$repo_root/Tests/SettingsVerifiedFlows.swift" "$qa_root/UITests/"
cat >> "$qa_root/project.yml" <<'YAML'
  KeepFitUIQA:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: UITests
    dependencies:
      - target: KeepFit
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.larry.keepfit.settingsqa
schemes:
  SettingsQA:
    build:
      targets:
        KeepFit: all
        KeepFitUIQA: [test]
    test:
      targets:
        - KeepFitUIQA
YAML
(cd "$qa_root" && xcodegen generate)
xcodebuild test -project "$qa_root/KeepFit.xcodeproj" -scheme SettingsQA \
  -destination "platform=iOS Simulator,id=$KEEPFIT_QA_DEVICE" \
  -derivedDataPath "$qa_root/DerivedData" -resultBundlePath "$qa_root/SettingsQA.xcresult" \
  -jobs 1 OTHER_SWIFT_FLAGS=-j1 CODE_SIGNING_ALLOWED=NO
printf 'QA project and results: %s\n' "$qa_root"
