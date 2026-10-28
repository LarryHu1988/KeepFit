# KeepFit 1.1.1（38）TestFlight

2026-10-24：通过 ASC CLI 上传，Apple 处理状态 VALID，Pilot 内部组已进入 IN_BETA_TESTING。中英文 What to Test 已回读匹配。

本版包含 MiMo 饮食识别接入：打字、语音转写、照片入口，补问、纠正、接受估算后确认导入。服务端已完成3次真实 MiMo 合成餐食验证；App 合成流程测试此前通过，Release 归档和发行签名 IPA 校验本次通过。真机 Apple 登录、录音、食物照片及完整入账仍需在此测试版本验收。全服务及每用户每天各10次模型调用。

构建ID：`914c96db-24aa-4f14-8748-6dee312fdb38`。仅分发 TestFlight，未提交 App Store 审核。

发布中更新了匹配现有发行证书的 App Store 描述文件，并使用现有受保护签名备份完成临时钥匙串签名；临时钥匙串已移除，原搜索列表已恢复。没有撤销原证书。

证据：[发布回执](receipt.json)、[Apple 构建状态](app-store-connect.json)、[测试组](testflight-groups.json)、[测试说明](test-notes.json)、[打包源码校验和](source-manifest.json)。
