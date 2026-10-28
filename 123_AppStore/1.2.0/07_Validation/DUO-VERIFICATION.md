# DUO 展开横屏核验 · 2026-10-27

使用 KeepFit 1.2.0 (0) 最新源码对应的模拟器构建，iOS 27.1「KeepFit Duo Layout QA」，在用户切换为展开横屏后验证。不是普通 iPhone 图的放大，也不代表真实设备验收。

- 系统实际窗口为 951 × 669 pt。概览栏 x=16、宽 407.7 pt；记录栏 x=527.7、宽 323.3 pt。两栏之间留出约 104 pt 的空间，避开系统提供的分隔区域及其边距。
- 概览和记录分别是独立 ScrollView，已从运行时辅助功能树确认 `keepfit.overview` 与 `keepfit.records`。
- 只滚动右栏：左栏像素平均变化为 0，右栏变化为 15.654。
- 再滚动左栏：左栏变化为 13.613，右栏变化约 0.000247，属于极小的渲染差异。说明两栏没有联动滚动。
- 栏宽通过环境传入卡片和图表；系统 TabView 保留右侧导航和安全区。素材使用真实内屏显示源，默认外屏黑帧已排除。

证据：`duo-independent-scroll.json`、`DuoEvidence/qa-before-ax.txt`、`DuoEvidence/qa-before.png`、`DuoEvidence/qa-right.png`、`DuoEvidence/qa-left.png`。

内屏录屏/截图源为展开横屏。其余方向的营销画布会保持这份真实 UI 的比例并明确标注来源方向，不据此宣称其他折叠姿态已经完成真机验收。

## 收起竖屏回归

随后在真实外屏收起竖屏状态启动 App，运行时确认 `keepfit.singleColumn` 存在、`keepfit.overview` 不存在，外屏恢复单列。中英文外屏重新采集由 UI 测试等待界面加载后执行，排除命令行启动过程中出现的空白画面。
