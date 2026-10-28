# KeepFit 1.1.2（39）TestFlight

2026-10-26（Asia/Shanghai）：已完成Release归档、发行签名、上传、Apple处理及远端回读。处理状态VALID，Pilot内部测试状态IN_BETA_TESTING；中英文What to Test已回读，与本地说明完全一致。

构建ID：`1235611b-a121-4af8-8000-6211b162fd37`。现有Pilot组对该构建的关系已确认，查询完整无遗漏。

发布回执：[receipt.json](receipt.json)；包校验：[artifact-verification.json](artifact-verification.json)；Apple状态：[app-store-connect.json](app-store-connect.json)、[beta-detail.json](beta-detail.json)；测试组：[testflight-groups.json](testflight-groups.json)；测试说明：[test-notes.json](test-notes.json)。

本版包含当前工作区的最新App改动，重点是恢复与锻炼记录一致的进食选择框、常显食物搜索、基于图谱的单位与四项营养计算，以及历史记录的数量/单位/营养/来源快照。数据包包含13,535条完整授权来源记录，不含模拟器测试食物；图谱更新方式为重新导出并随App版本分发。

验证依据：本次Release归档、发行签名及安装包内容校验；此前34项数据库测试、7项Swift合同测试和模拟器完整搜索/选择/保存流程通过，详见[图谱接入QA](../../qa/2026-10-26-food-atlas/README.md)。尚未作本次真机交互验收。

包路径：`/Users/larry/Library/Developer/Xcode/Archives/2026-10-26/KeepFit-1.1.2-39.ipa`。

证据包括版本编辑、源码SHA-256清单、签名及包内容校验、归档/导出日志、上传回执和中英文测试说明。发布沿用已有发行证书及匹配的有效App Store描述文件；临时签名钥匙串已删除，原钥匙串搜索列表已恢复。

仅执行TestFlight发布，没有提交App Store审核或正式发布。
