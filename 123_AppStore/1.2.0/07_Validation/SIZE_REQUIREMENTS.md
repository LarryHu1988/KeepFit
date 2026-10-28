# 上架素材尺寸与要求

核对日期：2026-10-28。依据 Apple 当前官方规范，并读取 SimpleWorth `AppStore/Final` 实际成品的分辨率、编码、首帧与目录分类。机器读取结果见 `apple-screenshot-sizes.json`、`simpleworth-final-reference.json`。

## 宣传截图

常规尺寸、中英文各 **7 张**：三Tab组合总览；饮食概览、饮食记录；运动概览、运动记录；热量平衡、身体趋势。**Duo内屏横屏每种语言4张**：三Tab总览、管住嘴、迈开腿、减个肥，每Tab只保留一张完整双栏画面。全部 PNG、RGB、sRGB、无透明通道，不包含选择食物、选择运动或设置页面。设置入口图标属于真实页面的一部分。

| App Store 显示组 | 本地提供的竖屏像素（宽×高） |
|---|---|
| iPhone 6.9 / 6.7 | 1320×2868、1290×2796、1260×2736 |
| iPhone 6.5 | 1284×2778、1242×2688 |
| iPhone 6.3 / 6.1 | 1206×2622、1179×2556 |
| iPhone 6.1 / 5.8 Face ID | 1170×2532、1125×2436、1080×2340 |
| iPhone 5.5 Home 键 | 1242×2208 |
| iPhone 4.7 Home 键 | 750×1334 |
| iPhone 4.0 / 3.5 历史格式参考 | 640×1136、640×960 |
| iPad 13 | 2064×2752 |
| iPad 12.9 | 2048×2732 |
| iPad 11 / Air / mini | 1668×2420、1668×2388、1640×2360、1488×2266 |
| iPad 10.5 | 1668×2224 |
| iPad 9.7 | 1536×2048 |
| iPhone Duo 外屏 | 1398×2034、2034×1398 |
| iPhone Duo 内屏 | 2007×2853、2853×2007 |

共26个不同画布尺寸：17个 iPhone/Duo 常规尺寸×7张×2语言，8个 iPad 尺寸及1个 Duo 内屏横屏尺寸×4张×2语言，合计310张。iPad 顺序为总览、饮食、运动、身体趋势，每个 Tab 的两段宣传文案合并到一张中。全部界面使用与总览相同的真实设备外框，保持原始 UI 比例。一个显示组中的多个分辨率为可选规格，并非必须一起上传。Apple 对适用显示组可以自动缩放；本地额外保留规格，便于人工挑选。实际 App 最低系统为 iOS 17，历史格式成品不能证明旧硬件支持。

真实 UI 来源：iPhone 17 Pro Max（1320×2868）、Home 键机型（750×1334）、iPad Pro 13（2064×2752）、Duo 外屏收起竖屏、Duo 内屏展开横屏。UI 保持原始比例放入营销画布；其他尺寸不把等比例派生图描述为对应设备的原生截图。Duo 内屏竖版画布包含真实展开横屏 UI，外屏横版画布包含真实收起竖屏 UI，均不旋转或拉伸 UI，也不据此宣称已验证其他折叠姿态。

## App 预览视频与封面

| 对应显示组 | 视频像素 | 文件名 |
|---|---|---|
| 现代 iPhone 各 Face ID / Dynamic Island 组 | 886×1920 | `iphone-modern.mp4` |
| Home 键 5.5 / 4.0 参考 | 1080×1920 | `iphone-home-large.mp4` |
| Home 键 4.7 | 750×1334 | `iphone-home-medium.mp4` |
| Duo 外屏 / 内屏 | 886×1920 / 1920×886 | `duo-outer.mp4` / `duo-inner.mp4` |
| iPad 13、12.9、11、10.5 | 1200×1600 | `ipad.mp4` |
| iPad 9.7 | 900×1200 | `ipad-legacy.mp4` |

中英文各7个编码文件，共14段；同一视频可映射多个相同规格的显示组，避免复制大文件。3.5英寸没有单独预览视频。此映射与 SimpleWorth 最终9个手机组、5个iPad组保持一致；其中Duo分内外屏，3.5组仅截图。

视频28秒：0–2.5秒为展示三个Tab的组合封面；其后依次为管住嘴、迈开腿、减个肥，每页8.5秒。只展示真实示例数据、切Tab与上下滚动；按页调整播放速度以适配总时长。没有选择器、设置页或模型生成的假界面。录屏嵌入对应的Apple DeviceKit设备边框，在真实屏幕遮罩内完整显示；Duo外屏有实际折叠外框，内屏有展开框架。未裁切或拉伸App内容。封面 PNG 位于 `05_Sources/covers`，海报取帧时间为 **00:00:00:00**。

交付目标：H.264 High Profile、Level 4.0、yuv420p、30fps、视频10Mbps（上限12Mbps）；AAC 256kbps、48kHz、双声道；MP4 faststart，每段小于500MB。Apple允许15–30秒及最高30fps。本地验证读取最终文件实际参数，而非仅检查导出配置。

轻音乐使用 Yoiyami 的 CC0 原始 WAV《First Light Particles》，取12–40秒，淡入淡出并降低音量。授权原文与下载来源保留在 `05_Sources/music/LICENSE.md`。

## 搜索与推荐创意

| 用途 | 像素 |
|---|---|
| 顶部 Header Banner | 3840×1646 |
| Search Artwork | 3840×2560（3:2） |
| Universal Artwork | 5244×2950 |

每类提供中文、英文、无文字品牌版，共9张。最高规范尺寸、无透明PNG；标题Banner采用品牌图标、KeepFit字标与简短标语，不含界面截图；全部主体位于Apple官方PSD的中央安全区。搜索图采用三个Tab并排展示，标签下沿至手机外框顶部统一保留64px距离。无文字版保留图标与三色圆环，供专题推荐裁切。它们属于创意素材，不是普通版本截图字段；本次已上传素材库并将中英文Banner与搜索图关联至1.2.0；不能把关联完成当成已获推荐资格。

## 文案字段

名称／副标题最多30字符，推广文本170字符，介绍和更新内容4000字符；关键词按UTF-8 **100字节**核验，中英文当前分别99与96字节。文本、listing与canonical文件保持一致。依据 [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)。

## 官方依据

- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
- [Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/)

素材已上传，服务器处理与读回记录位于 `08_AppStoreConnect`；未提交审核或发布。素材参数通过不代表 Apple 内容审核通过，也不代表 Duo 真机验收。

2026-10-28 上传核对：使用实时 `/v1/appAssetLibraryRefData`，172张选定截图全部为各自显示组最高像素；Duo内屏2853×2007、外屏1398×2034分别按实际姿态核对。9张创意图达到各自比例规格上限。所有319张交付PNG为8bit不透明RGB。其他本地规格为备用选项，未混入上传序列。
