# KeepFit 1.2.0（0）TestFlight

2026-10-27（Asia/Shanghai）：已按用户指定版本号1.2.0、构建号0完成Release归档、发行签名、上传、Apple处理及Pilot分发回读。处理状态VALID，Pilot内部状态IN_BETA_TESTING，中英文What to Test已回读并完全匹配。

构建ID：`3a327c54-a3af-4177-a0ef-3e06fbc43d39`。

证据：[发布回执](receipt.json)、[包校验](artifact-verification.json)、[Apple状态](app-store-connect.json)、[测试状态](beta-detail.json)、[测试组](testflight-groups.json)、[测试说明](test-notes.json)、[源码清单](source-manifest.json)。

本版包含最新食物和运动选择优化：列表仅显示图标与名称，隐藏热量、P/F/C、营养参考及MET副标题；食物默认常用100项，搜索仍覆盖完整13,535条图谱；运动搜索框常显，支持中文和英文名称。营养、单位换算、运动消耗计算与历史兼容保留，并包含现有DUO自适应布局。

验证依据：[食物选择QA](../../qa/2026-10-27-food-selector/README.md)、[运动选择QA](../../qa/2026-10-27-exercise-selector/README.md)、本次Release归档、签名及安装包内容核验。1.2.0（0）的模拟器编译通过，另有36项数据测试及54项服务测试通过；真实DUO折叠、展开和旋转体验仍待验收。

IPA：`/Users/larry/Library/Developer/Xcode/Archives/2026-10-27/KeepFit-1.2.0-0.ipa`。

本地源码提交：`378e290dbfccf8c802d5baae4d650c6a80a978b9`。用户改为优先TestFlight后，GitHub传输已停止，临时传输分支已清理，GitHub main未更新。

签名沿用现有有效发行证书及匹配描述文件；临时签名钥匙串已删除，原搜索列表已恢复。本次仅分发TestFlight，没有提交App Store审核或正式发布。
