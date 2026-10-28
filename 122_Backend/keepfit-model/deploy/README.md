# KeepFit 线上部署

目标：现有阿里云上海轻量服务器 OpenClaw-aqco，独立运行 KeepFit，不改动已有 OpenClaw 和 SearxNG。

## 实际部署方式

2026-10-24：服务和 HTTPS 验证通过，未登录访问记录接口为401；MiMo按量密钥验证及3次真实推理已通过。Docker 官方 registry 下载超时，因此采用 Alibaba Cloud Linux 官方源的 Python 3.11 + venv + systemd。系统默认 Python 3.6 保留。

- 源码版本目录：`/opt/keepfit/releases/<release>`，`current` 为当前版本的软链接。
- Python：`/opt/keepfit/venv/bin/python`。
- 数据库：`/opt/keepfit/data/keepfit.sqlite3`，600；目录700，仅 keepfit 运行用户可访问。
- 模型密钥：`/opt/keepfit/secrets/provider-key`，600，keepfit 用户所有。不放入代码、systemd Environment、云助手命令文本或日志。
- 服务单元：[keepfit-model.service](keepfit-model.service)，普通服务用户、只读系统目录、384MB/65% CPU 限制。
- API 先绑定 `127.0.0.1:18765`，由 TLS 反向代理提供 `https://keepfit-api.larryhu.com`。
- [Caddyfile](Caddyfile) 已用于公网代理，使用系统 EPEL 软件源的 Caddy 2.6.4。免费 Let’s Encrypt 证书已签发。现有80/443规则未修改。
- 公网验证保留完整证书校验，以域名和实际服务器IP完成 health200 / 未登录record401检查；本机代理访问曾报SSL错误，绕过本机HTTP代理后正常。不得通过关闭证书验证处理该问题。
- [compose.yaml](compose.yaml) 和 Dockerfile 保留为其它网络环境的可选方式，当前主机并未成功启用容器。

## 运维与发布检查

1. `systemctl status keepfit-model` 与 `curl http://127.0.0.1:18765/health` 检查进程；`provider_ready` 仅说明密钥文件格式和权限可读，不代表账户余额或真实推理通过。
2. 公网 `/health` 检查证书和 HTTPS；未登录请求 `/v1/records` 必须401。生产环境不提供工作台、文档或演示模式。
3. 用户通过 Apple 登录，服务校验签名、audience、issuer、exp 和一次性 nonce，再发24小时不透明会话。Apple账户邮件不采集；会话只存摘要。
4. 默认每用户及全服务每日各10次，UTC自然日，失败的已发出请求也计数。SQLite持久化配额，重启不会重置；不自动重试模型调用。
5. 密钥由所有者在受保护的服务器会话输入，禁用输入回显，写入后仅检查权限和 `/models` 可用性，禁止回显密钥。验证不执行付费推理。
6. `project.yml` 的 `KeepFitModelURL` 已配置生产地址并通过构建；发布前仍须完成真实设备登录、识别、确认和 App 入账验收，不能将服务独立测试视为手机验收。

## 备份与回滚

更新前保留旧 release；服务停止后复制 SQLite 到仅所有者可读的备份目录，或使用 SQLite online backup，勿在写入中直接复制活动数据库。密钥单独保护，不打入发布包。

回滚时停止 KeepFit 服务，把 `current` 软链接指回上一份兼容 release 后重启；如涉及数据库结构变更，先验证备份恢复兼容性。不要停止整台服务器或其它服务。

当前试用版未配置异地自动备份、自动过期清理、支付计费或生产规模并发；公开扩大测试前需补齐。删除云端记录会删除该用户草稿、记录、回放和会话，保留当日用量防止重注册绕过额度。

## 本次部署证据 · 2026-10-24

- 源码初始release `7924e41d9800`；版本说明和未配置模型时的生产提示在安装时补丁更新，与本地对应源文件一致。
- `keepfit-install-aliyun-mirror`（t-sh07106emv3szy8）：退出0，私有health正常，systemd active。
- `keepfit-private-acceptance`（t-sh07106zv1ziccg）：退出0，401访问控制，内存约39MiB，384MiB/65%CPU限制，127.0.0.1:18765；原OpenClaw10020仍监听。
- DNS仅新增 `keepfit-api` A记录，47.103.192.209，默认线路，TTL10分钟；现有根域名、www及邮件记录保留。
- 域名备案：控制台已完成的 KeepFit App 备案包含 larryhu.com；另一个进行中的备案订单未变更。
- Let’s Encrypt日志显示证书签发成功；公网health200、record401经真实TLS验证。
- 服务器准备了 `configure-provider.sh`，由所有者在Shell终端无回显输入密钥。这个步骤不使用Workbench Agent模式，不把密钥粘进云助手持久命令。

## 切换 MiMo · 2026-10-24

按用户选择将线上 systemd 环境和 Compose 配置切换为 `mimo`，模型为 `mimo-v2.6-flash`，使用 `https://api.xiaomimimo.com/v1`。App 源码中的同意说明、隐私说明及使用文档同步改为小米 MiMo。

切换任务 `keepfit-switch-mimo`（t-sh0710agmexxxq8）已回读到 `KEEPFIT_CLOUD_PROVIDER=mimo` 和 ActiveState=active；任务末尾的即时curl赶在监听开始前返回7，随后独立公网健康检查200，服务运行正常。随后所有者通过隐藏输入配置了MiMo按量密钥，模型列表验证成功；公网`provider_ready=true`，3次真实推理通过。

密钥配置脚本先在私有临时文件验证模型列表，通过后才原子替换正式文件；验证失败保留原配置，不将无效密钥标记为服务就绪。明确拒绝Token Plan专用密钥；当前部署使用开放平台按量计费API。

真实验证脚本`scripts/smoke_mimo.py`在服务器隔离进程和临时数据库内运行，最多3次调用，不开放监听器、不修改正式用户数据；完整合成响应见`examples/live-mimo-smoke.json`。早餐排除未吃/他人食物、共餐补问、回答补问、两餐确认及幂等回放通过。仅验证服务流程，真实设备Apple登录、录音和食物照片未验收。全服务及每用户的正式配额仍为每天10次。

依据：[MiMo模型列表接口](https://mimo.mi.com/docs/en-US/api/model/list-models)、[图片输入协议](https://mimo.mi.com/docs/en-US/quick-start/usage-guide/multimodal-understanding/image-understanding)。
