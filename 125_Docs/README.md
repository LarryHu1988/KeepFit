# KeepFit

当前 App 版本：**1.2.0（0）**。上架素材已上传并完成核验，版本保留在待提交审核草稿，发布方式为手动。未提交 App Review、未发布至 App Store。GitHub 源码版本与 App Store 分发状态分别记录。

本说明位于 `125_Docs`；下文命令均从 KeepFit 项目根目录执行。

| 目录 | 用途 |
|---|---|
| [120_App](../120_App/) | iOS/iPadOS App、Xcode 工程、构建配置、测试 |
| [121_FoodAtlas](../121_FoodAtlas/) | 食物成分图谱、SQLite 主库、原始来源、人工整理层与离线导出 |
| [122_Backend](../122_Backend/) | 识别服务及账户相关后端、部署说明、测试 |
| [123_AppStore/1.2.0](../123_AppStore/1.2.0/) | 当前待审阅的截图、预览、搜索/推荐图、文案、可重制源文件与验证 |
| [124_Design](../124_Design/) | 原始图标、设计母版与设计资料 |
| [125_Docs](../125_Docs/) | 说明、历史 QA、发布凭据、支持与隐私网页源码 |
| [126_Tools](../126_Tools/) | 素材生成所需的 Node 运行依赖 |

## 打开与构建

打开 `120_App/KeepFit.xcodeproj`，使用 KeepFit scheme。修改工程生成配置时，在 `120_App` 中运行 `xcodegen generate`。

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 120_App/KeepFit.xcodeproj -scheme KeepFit \
  -sdk iphonesimulator -derivedDataPath /tmp/keepfit-build \
  CODE_SIGNING_ALLOWED=NO build
```

## 更新食物图谱

在 `121_FoodAtlas/app-foods.json` 中维护名称、图标、基准单位与营养数据；主库位于 `121_FoodAtlas/.data/foods.sqlite`。从根目录运行：

```sh
python3 121_FoodAtlas/export_app.py
python3 -m unittest discover -s 121_FoodAtlas/tests -v
```

导出目标为 `120_App/KeepFitApp/Resources/KeepFitFoodAtlas.json`。当前是随 App 打包的离线图谱，更新后需要重新构建、分发，才会到达已安装的设备。详细字段与来源授权规则见[食物图谱说明](../121_FoodAtlas/README.md)。

## 工作台与测试

双击 `121_FoodAtlas/Open Food Atlas.command` 打开食物图谱；双击 `122_Backend/keepfit-model/打开 KeepFit 工作台.command` 打开后端工作台。两者均使用所在目录，不依赖旧目录名称。

App 测试说明位于 `120_App/Tests/README.md`；脚本从 `120_App` 中运行。后端测试在 `122_Backend/keepfit-model` 中运行 `python -m unittest discover -s tests -v`。

## 素材审阅与清理

打开 `123_AppStore/1.2.0/index.html` 的本地服务预览。尺寸规则、素材清单和验证结果位于该目录的 `07_Validation`。

旧版上架素材、旧素材生成工程、重复 Xcode 工程与可重建缓存已移入可恢复废纸篓；位置见 `125_Docs/reorganization-trash-location.txt`。食物数据库、原始来源、设计母版、后端数据、历史发布凭据与 Git 历史均保留。历史发布记录里的旧路径代表当时状态，不重写凭据。网站源码现在位于 `125_Docs`；GitHub Pages 通过 `.github/workflows/pages.yml` 仅发布首页、支持与隐私页面。旧 `/KeepFit/` 首页转至正式产品主页 `https://larryhu.com/keepfit/`。开发与发布凭据不会作为网站内容部署。
