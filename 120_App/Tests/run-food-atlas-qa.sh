#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
qa_root="$(mktemp -d /tmp/keepfit-food-atlas-qa.XXXXXX)"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
: "${KEEPFIT_QA_DEVICE:?Set KEEPFIT_QA_DEVICE to a dedicated iOS Simulator UDID}"
cp -R "$repo_root/KeepFitApp" "$qa_root/KeepFitApp"
cp "$repo_root/project.yml" "$qa_root/project.yml"
mkdir "$qa_root/UnitTests" "$qa_root/UITests"
cp "$repo_root/Tests/FoodAtlasTests.swift" "$qa_root/UnitTests/"
cp "$repo_root/Tests/FoodAtlasVerifiedFlows.swift" "$qa_root/UITests/"
# Fixtures live only in the temporary QA copy, never in the production catalog.
python3 - "$qa_root/KeepFitApp/Resources/KeepFitFoodAtlas.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1]); data = json.loads(path.read_text())
for food_id, name, unit, amount, kcal, grams in [
    ('qa-milk', '图谱测试牛奶', 'mL', 100, 64, None),
    ('qa-egg', '图谱测试鸡蛋', '个', 1, 70, 50),
]:
    data['foods'].append(dict(id='custom:' + food_id, name=name, nameEnglish=name, icon='🍽️',
        category='other', aliases=[], sourceName='QA fixture', sourceURL=None,
        basis=dict(amount=amount, unit=unit, calories=kcal, protein=3, fat=4, carbs=4, gramsPerUnit=grams)))
path.write_text(json.dumps(data, ensure_ascii=False))
PY
cat >> "$qa_root/project.yml" <<'YAML'
  FoodAtlasUnitTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources: [UnitTests]
    dependencies:
      - target: KeepFit
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.larry.keepfit.foodatlasunittests
  FoodAtlasUIQA:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "17.0"
    sources: [UITests]
    dependencies:
      - target: KeepFit
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.larry.keepfit.foodatlasuiqa
schemes:
  FoodAtlasQA:
    build:
      targets:
        KeepFit: all
        FoodAtlasUnitTests: [test]
        FoodAtlasUIQA: [test]
    test:
      targets:
        - FoodAtlasUnitTests
        - FoodAtlasUIQA
YAML
(cd "$qa_root" && xcodegen generate)
printf '%s\n' "$qa_root" > /tmp/keepfit-food-atlas-qa-latest
xcodebuild test -project "$qa_root/KeepFit.xcodeproj" -scheme FoodAtlasQA \
  -destination "platform=iOS Simulator,id=$KEEPFIT_QA_DEVICE" \
  -derivedDataPath "$qa_root/DerivedData" -resultBundlePath "$qa_root/FoodAtlasQA.xcresult" \
  -parallel-testing-enabled NO -jobs 2 CODE_SIGNING_ALLOWED=NO
printf 'QA project and results: %s\n' "$qa_root"
