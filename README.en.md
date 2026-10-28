<p align="center">
  <img src="120_App/KeepFitApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="96" alt="KeepFit icon">
</p>

<h1 align="center">KeepFit</h1>
<p align="center"><strong>Eat well. Move more. See your everyday progress.</strong></p>
<p align="center">Log your meals, workouts, and changes in your body.<br>Bring intake, activity, and long-term trends together to understand your own rhythm.</p>

<p align="center">
  <a href="https://apps.apple.com/app/id6759662867">Download on the App Store</a> ·
  <a href="https://larryhu.com/keepfit/">Website</a> ·
  <a href="https://larryhu.com/keepfit/support/">Support</a> ·
  <a href="README.md">简体中文</a>
</p>
<p align="center">iPhone and iPad · iOS / iPadOS 17 or later · SwiftUI</p>

## Connect your everyday moments

From what you ate today to changes over time, three familiar pages help you build a continuous record.

| Eat Well | Move More | Lose Weight |
|:---:|:---:|:---:|
| <img src="125_Docs/branding/en-eat-overview.png" width="250" alt="KeepFit food overview"> | <img src="125_Docs/branding/en-move-overview.png" width="250" alt="KeepFit exercise overview"> | <img src="125_Docs/branding/en-lose-overview.png" width="250" alt="KeepFit calorie balance and body trends"> |
| Log foods and portions, review estimated calories and macros, and look back through your calendar. | Record activities and duration, review estimated energy use, and track your daily movement. | Bring calorie balance, weight, and body-fat trends together to see changes over time. |

Real app screens with demonstration data.

## Keep going, your way

- **Keep a food record.** Search the built-in offline food atlas by Chinese or English names and aliases. Frequently used foods come first, with portions entered in each food's reference unit.
- **Give movement a place.** Search activities, record duration, and review progress toward your goals.
- **See changes over time.** Explore calorie-balance calendars, weight charts, and body-fat trends.
- **Find your reminder rhythm.** Set meal, exercise, and daily-summary reminders alongside personal goals and preferred units.
- **Feel comfortable, day and night.** Light and dark appearances, Chinese and English interfaces, and layouts that adapt to available width.

## Your records, your choice

Data is primarily stored on your device by default. Apple Health and iCloud sync are optional and require you to enable and authorize them.

When you use cloud meal recognition, the meal text or photo you choose to submit is sent to KeepFit and its model provider. Results are estimates for you to review and confirm. See the [privacy policy](https://larryhu.com/keepfit/privacy/).

Calorie estimates, energy expenditure, and suggestions are for everyday reference. They are not medical diagnosis or treatment advice. Consult a qualified professional about health concerns.

## Build from source

Open `120_App/KeepFit.xcodeproj` in Xcode and select the **KeepFit** scheme. To build for the simulator without signing:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 120_App/KeepFit.xcodeproj -scheme KeepFit \
  -sdk iphonesimulator -derivedDataPath /tmp/keepfit-build \
  CODE_SIGNING_ALLOWED=NO build
```

| Directory | Contents |
|---|---|
| [120_App](120_App/) | SwiftUI app, Xcode project, and tests |
| [121_FoodAtlas](121_FoodAtlas/) | Food-atlas curation, provenance, and offline export tools |
| [122_Backend](122_Backend/) | Meal-recognition backend, workbench, and deployment documentation |
| [123_AppStore](123_AppStore/) | Store copy, media sources, and reproduction tools |
| [124_Design](124_Design/) | Design references and icon mappings |
| [125_Docs](125_Docs/) | Development, support, privacy, and release records |
| [126_Tools](126_Tools/) | Media-tool dependency manifests |

See the [maintenance guide](125_Docs/README.md), [app tests](120_App/Tests/README.md), and [food-atlas guide](121_FoodAtlas/README.md). Private databases, credentials, signing material, review contacts, and large media intermediates are excluded. The app includes a ready-to-load offline food data bundle.

Source versions and changes are listed in [GitHub Releases](https://github.com/LarryHu1988/KeepFit/releases). Check the App Store for the version available to download.

## Get in touch

Open an [issue](https://github.com/LarryHu1988/KeepFit/issues) or email [keepfit@larryhu.com](mailto:keepfit@larryhu.com). Include your device, OS and app versions, and reproduction steps. Keep personal health records and credentials private.

© 2026 Larry Hu. This repository is public for inspection; no repository-wide open-source license has been granted. Third-party materials remain subject to their respective licenses and terms.
