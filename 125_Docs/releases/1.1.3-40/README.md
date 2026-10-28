# KeepFit 1.1.3（40）TestFlight

2026-10-27（Asia/Shanghai）：Release归档、发行签名、上传和Apple处理均已完成。处理状态VALID，Pilot内部测试状态IN_BETA_TESTING，中英文What to Test已回读并与本地说明完全一致。

构建ID：`ace0e2dd-0fba-439e-a03e-57dec6385763`。Pilot组拥有全构建访问权限，本次成员关系完整回读通过。

证据：[发布回执](receipt.json)、[包校验](artifact-verification.json)、[Apple构建状态](app-store-connect.json)、[测试状态](beta-detail.json)、[测试组](testflight-groups.json)、[测试说明](test-notes.json)、[打包源码清单](source-manifest.json)。

本版更新：

- 食物选择项仅显示图标和名称，移除热量、P/F/C及营养参考副标题。
- 默认常用100项，按已有进食记录使用频次优先，再按100项中文常见食物清单补足。
- 搜索仍覆盖完整13,535条图谱记录，精确名称和别名优先，单次最多展示100项。
- 四项营养数据、选择后的单位换算和历史统计保持完整。
- 保留现有DUO布局适配；MainTabView与1.1.2（39）发行源码一致。真机折叠、展开及旋转体验尚需验收。

验证：36项Python测试、10项Swift合同/排序测试及1项模拟器完整记餐UI流程通过；当前全部Swift源文件与通过QA的副本一致。本次另完成Release归档、发行签名、版本/构建号、App Store描述文件、完整图谱、常用100项和测试数据隔离校验。

相关QA：[食物选择列表优化](../../qa/2026-10-27-food-selector/README.md)。

IPA：`/Users/larry/Library/Developer/Xcode/Archives/2026-10-27/KeepFit-1.1.3-40.ipa`。

沿用现有发行证书与匹配的有效App Store描述文件。签名完成后已删除临时钥匙串并恢复原搜索列表；未修改受保护的签名备份。

仅分发TestFlight，没有提交App Store审核或正式发布。
