# KeepFit 1.2.0 · 上架材料

**状态：1.2.0 (0) 全部材料已上传、处理并核验完成，审核草稿可供提交；最终“提交以供审核”按钮留给用户，尚未提交或发布。**

从项目根目录启动本地预览：

```sh
python3 -m http.server 3212 --bind 127.0.0.1 --directory 123_AppStore/1.2.0
```

打开 <http://127.0.0.1:3212/>。可切换语言、设备和全部26个画布尺寸；图片点击可查看原文件，视频可直接播放与下载。

| 目录 | 内容 |
|---|---|
| `01_Screenshots` | 中英文，iPhone常规尺寸7张，iPad及Duo内屏横屏4张，文件编号就是上传顺序 |
| `02_Previews` | 中英文各7段，三Tab组合封面+真实比例设备框架+上下滚动+轻音乐 |
| `03_Creatives` | Header、Search、Universal的中文、英文、无文字品牌版 |
| `04_Metadata` | 中英文介绍、副标题、关键词、推广文本、更新摘要、审核备注及canonical文件 |
| `05_Sources` | 真实原始截图/录屏、品牌图标、封面、原始WAV、授权及可编辑HTML |
| `06_Tools` | 原生UI录制测试、录屏控制器、图片/视频导出、验证脚本 |
| `07_Validation` | 尺寸依据、最终清单、文件参数、Duo布局证据、QA报告 |
| `08_AppStoreConnect` | 上传计划、服务器回执、逐项核验、封面读回；含审核联系人，已排除 Git |

图片与视频的 `en` 目录对应 App Store Connect 的 `en-US`；`zh-Hans` 对应简体中文。

iPhone常规截图顺序：1三Tab组合总览；2饮食概览；3饮食记录；4运动概览；5运动记录；6热量平衡；7身体趋势。iPad和Duo内屏横屏只保留三Tab总览、管住嘴、迈开腿、减个肥四张，移除各Tab重复画面。禁止选择器和设置页面。总览与封面采用三个Tab一大两小的错落布局，搜索推荐图采用三屏并排，均无重叠遮挡。

预览视频共28秒，前2.5秒封面，后续每个Tab各8.5秒；海报取帧位于前2.5秒静态封面区间。不同显示组复用相同规格视频，完整映射见 `07_Validation/SIZE_REQUIREMENTS.md`。每个文件只有一种规范编码，不额外复制大文件。

## 重制

项目根目录安装工具依赖：`npm ci --prefix 126_Tools/MediaRenderer`。本地预览服务启动后：

```sh
python3 123_AppStore/1.2.0/06_Tools/prepare-device-frames.py
node 123_AppStore/1.2.0/06_Tools/export-images.mjs
python3 123_AppStore/1.2.0/06_Tools/export-previews.py --force
python3 123_AppStore/1.2.0/06_Tools/validate-delivery.py
```

视频使用 FFmpeg 处理真实原生UI录屏，嵌入Apple Xcode DeviceKit对应的真实设备边框。保留原始矢量PDF、屏幕遮罩、帧几何位置和时间线，可重新剪辑。照片/界面没有生成式修改、拉伸或虚构数据。轻音乐为 CC0 原作，来源及授权位于 `05_Sources/music/LICENSE.md`。

`05_Sources/recordings` 保存原生采集的 `timeline.json`、录屏起始时间 `ack`、`source.mov` 与完成标记。其余 `.png` 是原生画面或明确的营销画布；导出参数与源方向均在清单中记录。模拟器素材不能代替真机适配验收。

## 本次上传

中英文各14个显示组，选用各组最高像素规格，共172张截图、28个视频位置（复用14个唯一文件）。Duo内外屏共用一组，依照最多10张的限制选用内屏总览、外屏六张Tab展示、内屏三张Tab展示；两个姿态各有预览视频。9张创意图已进入素材库，其中中英文各1张Banner和1张搜索图已关联1.2.0。

最高规格核对使用Apple实时AssetLibrary规格，而非仅依赖CLI旧目录。详见 `08_AppStoreConnect/maximum-resolution-audit.json`。官网链接统一使用 `https://larryhu.com/keepfit/`、`privacy/` 与 `support/`。发布方式为手动；用户保留最终提交按钮，App Review通过后仍需手动发布。

最终读回：172张截图的MD5及像素与最高规格原文件一致；28个视频位置均完成转码，28个服务器封面均与本地三Tab总览画面比对通过。Apple海报时间归一化为 `00:00:00:01`，仍位于静态总览封面区间。审核草稿ID为 `95e997f7-274a-4984-b150-a15fb5fa6379`，状态 `READY_FOR_REVIEW`；截图证据、最终明细见 `08_AppStoreConnect/UPLOAD_REPORT.md`。

## 历史：2026-10-28 标题与搜索图修订

标题图已改为纯品牌设计，不含App界面截图。继续使用3840×1646最高规范尺寸；核心图标、字标及标语均位于Apple官方PSD的Art Safe Area `[1097,493,2743,1154]`。中文和英文均已检查iPhone、Duo内外屏及iPad横竖屏实际预览，共12个产品页预览。搜索图保持3840×2560，3个标签下沿到手机外框上沿均为64px；中英文搜索结果实际预览各1份。服务器下载的新图片与本地导出像素完全相同。

上一轮仅更新标题与搜索素材；后续全量间距修订及最终上传结果以下方记录为准。所有改动已回到同一份1.2.0 (0)审核草稿中，尚未提交审核或发布。最新证据位于 `08_AppStoreConnect/CreativeRevision-20261028`。


## 历史：2026-10-28 版式与上传核验

标题图已重做为左侧文字、右侧三色圆环及横向柔和色带，3840×1646，核心内容位于 Apple 安全区，不含界面截图。中英文 iPhone、Duo 内外屏、iPad 横竖屏共12个实际产品页预览已核对。

全部381个图片/封面版式已检查；70个包含三标签的版式均无贴近或碰撞。已修正52张本地总览、14张视频封面和2张通用宣传图；远端更新28个总览位置，174张其他截图保留原素材。

202张截图、28个视频位置均完成服务器处理及文件核验；9张当前创意图的服务器原尺寸像素与本地一致，28个视频海报均通过画面对比。最高规格保持有效。视频只替换前2.5秒封面，后续765帧及音频与原版本解码内容一致。服务器海报取帧为第1或第2帧，均在静态封面区间。

版本1.2.0（0）已恢复到原审核草稿 READY_FOR_REVIEW，submittedDate=null，发布方式 MANUAL。尚未提交审核或发布。最终证据：08_AppStoreConnect/LayoutRevision-20261028、poster-verification.json、review-draft-final.json。


## 当前修订：全功能页套壳与 iPad 四图

所有功能页使用与首张总览一致的真实 DeviceKit iPhone／iPad／Duo 外框，按原生界面比例放入屏幕，不拉伸内容。iPad 的饮食、运动、身体趋势各一张，合并此前每个 Tab 两张的中英文宣传文案，连同总览共4张。全部8种 iPad 画布均已更新。

本地310张宣传截图、52个语言/尺寸组；333个图片与封面版式通过几何检查，无标签贴近或遮挡。172个远端截图位置的数量、顺序、MD5、像素尺寸与当前上传计划一致，均完成处理；iPad两种语言各5个显示组均为4张。全部截图保持各自显示组最高像素规格。28个视频位置保持原资产ID，28个封面已通过上一轮核验。

1.2.0（0）已回到原 READY_FOR_REVIEW 草稿，submittedDate=null，发布方式MANUAL；未提交审核、未发布、未推送GitHub。证据见 08_AppStoreConnect/FrameRevision-20261028、media-verification.json、review-draft-final.json。原截图已保留在本次修订 Before/01_Screenshots。
