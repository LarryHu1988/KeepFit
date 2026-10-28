# KeepFit 本地食物营养数据库

本目录是独立的本地数据工程，可逐步扩充，支持 SQLite 查询、CSV 查看、Python 查询接口和 Swift 离线查询。采集与计算均不依赖大模型或付费 API。

## App 接入与后续维护（2026-10-26）

KeepFit 的进食记录已接上图谱导出包：与锻炼记录一致的时间、食物选择框、数量和添加按钮；点击食物后有常显搜索框，支持名称、中英文名和别名。选择项仅显示图标和名称；默认选取常用100项，优先按本人历史进食记录的使用次数筛选，再按图谱中的常见食物清单补足。数量框自动使用该条目的基准单位。

从项目根目录运行：

```bash
python3 121_FoodAtlas/export_app.py
```

此命令直接读取当前 `.data/foods.sqlite` 主库，生成 `120_App/KeepFitApp/Resources/KeepFitFoodAtlas.json`。当前输出13,535条可商用且四项营养齐全的记录，跳过53条营养不完整的记录，并继续过滤未授权来源。缺失营养值不填0；来源记录即使同名也保留独立稳定ID。现有数据库的归一化营养按100g保存，所以饮料也使用g，不因分类是饮料就擅自改成mL。

日后更新主库后重新执行导出即可。App按稳定ID读取新的名称、图标、基准单位和营养值，无需逐项修改Swift代码。**当前采用随App打包的离线数据，不是远程实时更新；导出后需构建并分发新版本，已安装的旧App不会因为Mac主库变更而自动更新。** 尚未配置远程图谱地址或云端同步。

图谱面向App的人工整理层为 `app-foods.json`：

- `overrides`：按现有授权食物ID整理 `name`、`nameEnglish`、`icon`、`category`、`aliases`、`basis`、`sourceName`、`sourceURL`；名称与图标修改不改变食物身份。
- `commonFoodIDs`：默认常见100项的稳定ID清单，按优先级排序；每项必须是完整且已授权的条目，不能重复，最多100项。导出后通过 `commonFoodRank` 传给App。用户实际记录的高频食物可以进入常用100项；搜索仍覆盖完整图谱。
- `foods`：增加用户维护的完整食物记录，ID以 `custom:` 开头且保持稳定，来源需有明确的 `commercialUseAuthorized: true`。不要将未授权源数据通过自定义记录转入App。
- `icon` 支持emoji或 `sf:carrot` 形式的系统图标；无逐项整理图标时，导出器先使用来源分类的通用图标，未分类使用餐盘。
- `category` 可用 `staple`、`protein`、`vegetable`、`fruit`、`dairy`、`nuts`、`drink`、`snack`、`other`。

数据合同中每条记录的 `basis` 完整包含：

```json
{
  "amount": 100,
  "unit": "mL",
  "calories": 64,
  "protein": 3,
  "fat": 4,
  "carbs": 4
}
```

以上仅用于说明合同，不会写入正式库。它表示每100mL的热量为64kcal，蛋白质、脂肪和碳水分别为3g、4g、4g；输入250mL后乘以2.5。`amount` 必须大于0；四项营养必须齐全且为非负有限数。`unit` 也支持g、个、碗等，数量允许小数。`basis` 的所有营养值必须对应同一个基准量，修改单位时需一起核对，不可只改单位文本。

若来源确实提供质量换算，可加 `gramsPerUnit`（每1单位的克重）。例如基准1个、每个50g，则填50；没有密度或克重依据时省略，App直接用该单位计算营养，不把mL或个当作g。g对应的换算固定为1。

自定义记录完整形状如下（所有值仅为合同示例）：

```json
{
  "schemaVersion": 1,
  "overrides": {},
  "foods": [{
    "id": "custom:my-food",
    "name": "我的食物",
    "nameEnglish": "My food",
    "icon": "🍽️",
    "category": "other",
    "aliases": ["我的别名"],
    "basis": {"amount": 1, "unit": "份", "calories": 100, "protein": 5, "fat": 4, "carbs": 11},
    "sourceName": "已核对的自有营养资料",
    "sourceURL": null,
    "commercialUseAuthorized": true
  }]
}
```

导出原子替换数据包；验证失败保留上一份有效文件。每次新包替换整个图谱，删除的食物不会因旧本地目录再次出现。食物记录保存当时的数量、单位、四项营养和来源快照，后续图谱调整不重算已有记录；旧版记录仍按旧数据解码。

2026-10-27：食物选择列表移除热量、P/F/C和营养来源副标题，每行仅保留图标、名称。无搜索时展示常用100项：已记录食物按使用频次优先，再按 `commonFoodIDs` 补足；首次使用的100项均有中文显示名。搜索覆盖完整导出库，精确名称/别名优先，每次最多展示100个匹配项，过多时提示继续搜索。营养数据仍完整保留，用于添加后的数量换算与统计。营养缺失的食物在补齐后重新导出，就会进入可选列表。

验证：

```bash
python3 -m unittest discover -s 121_FoodAtlas/tests -v
KEEPFIT_QA_DEVICE=<专用模拟器UDID> Tests/run-food-atlas-qa.sh
```

后者在 `/tmp` 复制App生成独立测试项目，覆盖真实图谱加载、g/mL/个换算、小数份量、历史快照、旧记录兼容、搜索选择和保存。mL与个的测试条目只写入临时测试副本，不进入正式库。

## 首批数据

2026-10-25 已完整采集下列快照中的有效食物记录：

| 来源 | 来源版本 | 食物记录 | 核心营养齐全的记录 | 使用状态 |
| --- | --- | ---: | ---: | --- |
| USDA Foundation Foods | 2026-04 | 363 | 311 | CC0，可商用 |
| USDA SR Legacy | 2018-04 | 7,793 | 7,793 | CC0，可商用 |
| USDA FNDDS | 2021-2023，2024-10发布 | 5,432 | 5,431 | CC0，可商用 |
| 中国疾控营养与健康所公开查询 | 2026-10-25，170页 | 1,356 | 1,178 | 待取得商业使用许可 |
| 合计 | | 14,944 | 14,713 | |

这些是保留来源和生熟状态的记录数，不代表14,944种去重后的独立食材。同名的不同品种、烹调状态、采样来源不强行合并。另有14,814条官方家庭/餐饮份量记录，以及1,054,369条营养成分记录（包含缺失、未检测和异常标记）。

本批 USDA 尚未导入体量更大的 Branded 包装食品库。USDA 原文保留英文，目前76条常用记录有逐条核对原文的中文名和别名；中国疾控1,356条保留原始中文名称。数据库不依赖将所有英文条目立即翻译完才能使用。

## 2026-10-26补采：明细仍在进行

已保存NLC公开搜索索引快照58,103条，其中58,102条有有效名称，已加入主库；另1条空名称源记录保存在 `.data/raw/china-supplement/quarantined-index.json`，不编造食物名。“我的餐盘”页面内嵌的98条菜品/食物参考记录已全部保留。当前主库合计73,144条来源记录，**不代表73,144条都已经具备可按克计算的营养数据**。

商品索引、原始标签、计量基准核验是三个独立阶段。网页会显示实时覆盖进度，最新审计记录在 `reports/supplement-coverage.json`。公开索引候选不等于全部已发布且有正常详情链接的商品；部分单品详情页返回404，但公开对比页仍提供原始标签。

商品站对比模板只有前4列提供营养值，不能把一次显示几十列商品元数据当作几十份完整标签。采集器每批最多4项、请求最小间隔1秒，支持原始页面缓存和断点续采。同名/同条码造成列身份不明确时，回退到单ID请求核验，绝不按位置猜测。全量原始标签采集需要数小时；结束后自动核验索引中提供了独立详情链接的条目。没有明确基准的仍标为未核验，不通过净含量或饮料类别推断每100g/每100mL。

`food_metadata` 保存条码、品牌、生产厂家、配料、净含量、原产地、原始JSON和状态；`label_nutrients` 专门保留来源标签原值。只有独立详情明确给出质量基准时才写入每100g的 `foods`/`nutrients` 字段；每100mL标签不假定密度，不写成每100g数值。源值的0、缺失、微量、不等式、异常值分别保留。

餐盘条目保留 `quantity`、`bzQuantity`、`content` 和18项原始 `foodpb` 向量。该向量不是营养成分表，工具quantity与熟食实际克重也可能不同；**没有为鱼香肉丝等菜品编造热量或三大营养素**。这98条的参考信息采集已完成，但该来源本身未提供完整营养表。

商品不会只因名称相同就被合并。仅当有效GTIN条码、原名、品牌、规格、生产厂家、配料、计量状态和全部标签原值一致时才折叠展示，原始来源ID仍保留；资料不齐全的条目宁可暂不合并。默认商业导出和 `serve.py` 继续排除这两个待授权来源，不改动已上架App。

启动/恢复本次后台补采并打开网页服务：

```bash
python3 launch_supplement.py
```

这是本次持续执行的后台进程，不是系统自启动或定时任务；机器重启后需再次执行。脚本用PID文件及系统文件锁防止重复采集。中断后可重跑，已有成功数据不会重新请求。进程不运行时网页会明确提示，不会把旧“running”状态冒充活动采集。

手动分步操作与检查：

```bash
python3 supplement.py initialize
python3 supplement.py collect --max-batches 5
python3 supplement.py collect
python3 supplement.py verify-linked
python3 supplement.py report
```

`collect`不限制批次时，在原始标签采集后自动进行独立详情基准核验。访问限制401/403/429或疑似登录页会停止，不切换身份、不绕过限制；连续失败也会停止并保留进度。后台日志为 `.data/supplement-collector.log`，名称辅助翻译日志为 `.data/supplement-translations.log`，原件保存在 `.data/raw/china-supplement/`。协调请求的锁存放在本机临时目录，避免在iCloud目录频繁同步锁文件。

网页新增 `GET /api/progress` 和 `GET /api/export-labels.csv`。普通CSV继续导出每100g基础值，不把原始标签值误填进去；原始标签CSV单列记录核验状态、基准量及单位。所有新来源只供本地参考，商业授权未确认，不公开部署。

## 可视化本地网页

双击本目录的 `Open Food Atlas.command`，或在本目录运行：

```bash
python3 browser.py
```

打开 <http://127.0.0.1:8768>。关闭服务终端后网页会停止查询，下次双击启动器即可重新打开。网页直接读取完整主库，包含全部14,944条来源记录、1,054,369条营养项及14,814条官方份量，不读取App精简库，也不需要付费服务。

支持中英文名称和别名搜索、按来源/原始分类/营养完整度筛选、热量和三大营养素排序、分页、CSV导出，以及食物详情中的全部营养素、原始值、来源链接和份量换算。未分类的来源仍归入“来源未分类”，不会编造来源分类。CSV为当前去重列表的每100克基础营养；全部微量营养和每一条原始记录在详情中查看。

同名折叠规则：只对原始名称做Unicode NFKC、大小写和空白规范化，14,944条记录折叠为14,742个名称组，202条同名记录保留在详情的来源选择器中。各来源的数值不平均，不通过机器译名合并，不强行匹配生熟、部位或配方不同的食物；这不是已经完成跨语言、跨配方实体融合的食物本体库。

网页补齐的双语显示名保存在 `.data/display-translations.json`，与主库原文和76条已整理译名隔离。缺失语言用本地OPUS-MT模型生成，页面明确标注“机器译名 · 待校对”，不能视为官方中文/英文名称；尤其部位、品牌和地方菜名应逐步人工校对。搜索同时保留原文。翻译不会改动营养值、来源ID、商业导出或App内名称。

常见名称及抽查纠错放在 `display-name-overrides.json`，按确切原始名称匹配，优先于机器译名。可继续在这里补充中文或英文显示名，重启服务后生效；它不用于合并食物身份。

常见USDA食物另优先使用 `english-food-terms.json` 的食物/部位/加工状态词表，避免通用模型把lean等词误译。未覆盖的限定词保留原文，标为“词表译名 · 含原文待校对”。双语覆盖率是有双语显示名的记录比例，不代表已经完成全部专业翻译校对。新增或纠正词表也不会改变去重身份。

重新生成/补齐显示名（仅此步骤需要额外安装翻译依赖，网页服务本身仅依赖Python标准库）：

```bash
python3 -m venv .venv
.venv/bin/pip install ctranslate2 sentencepiece
.venv/bin/python translate_names.py
```

翻译首次下载模型，随后完全离线运行；缓存可中断续跑，执行后重启网页服务。权重固定到 `translate_names.py` 中的提交版本。原始模型：[Helsinki-NLP en→zh](https://huggingface.co/Helsinki-NLP/opus-mt-en-zh)（Apache-2.0）、[Helsinki-NLP zh→en](https://huggingface.co/Helsinki-NLP/opus-mt-zh-en)（CC-BY-4.0）；使用gaudi的CTranslate2转换版。`.data/`、模型及虚拟环境不进入Git。

网页只监听127.0.0.1并校验本机Host，不开放CORS。由于展示待授权的中国疾控数据，**不要将此完整网页和主库发布到公网**。面向App/商业网站的接口仍使用原 `serve.py`，默认过滤待授权来源。

## 已生成的文件

| 文件 | 内容 |
| --- | --- |
| `.data/foods.sqlite` | 完整主库，包含四个来源及所有营养字段；中国疾控记录被标记为待授权 |
| `.data/exports/KeepFitFoods.sqlite` | 约18 MiB，面向App的精简库，仅含13,588条USDA食物、全部官方份量和常用营养字段 |
| `.data/exports/foods-per-100g.csv` | 可商用食物营养表，中文表头，每100克热量/蛋白质/脂肪/碳水、来源和原文链接 |
| `.data/exports/food-portions.csv` | 各官方份量的克重、每份及每单位的热量和三大营养素 |
| `.data/reference-only/china-cdc-per-100g.csv` | 中国疾控本地参考表，不能直接用于已上架App或商业网站 |
| `.data/raw/` | 官方ZIP、原始列表JSON、字段定义页及许可说明，供核查和重新导入 |
| `reports/latest.json` | 本批数量、来源版本、SHA-256、异常与完整性检查 |

下载原件和生成数据库在 `.gitignore` 中；脚本、结构、中文映射和报告可版本管理。App现已通过 `export_app.py` 导出的JSON合同接入图谱；SQLite主库和原始采集数据不会直接加入App资源包。

## 单位与营养口径

`foods` 统一保存每100克可食用部分的热量（kcal）、蛋白质/脂肪/碳水（g）。`nutrients` 保留所有来源营养素、单位、原始文本及测定/计算方法。不同定义的营养素仍保持来源ID，不把维生素A、碳水、脂肪酸等不同口径硬合并。

每个食物都有明确的100克计量基准；来源另外提供的“杯、片、大号1个”等克重保存在 `portions`。中国疾控列表没有家庭份量重量，因此只提供100克基准，不自行生成“1碗=200克”之类数据。家庭份量的中文化和本地实测可作为后续独立来源扩充。

`portion_nutrition` 视图同时提供 `amount`、`unit`、`gram_weight`、`grams_per_unit`，以及该份量的宏量营养值和每单位营养值。例如来源记录若为“2个=100克”，视图中每单位为50克，不能把100克当成1个。

计算方式为每份营养 = 每100克营养 × 份量克重 / 100。kJ到kcal使用除以4.184，并保存转换依据；优先使用来源直接给出的kcal，不依据蛋白质/脂肪/碳水重新猜测热量。USDA Foundation同时提供两类Atwater能量时，使用Specific Factors值，并保留两项原文值。

缺失、未检测、未检出不能当成0。USDA源文件中的10条负值/异常值保留原始文本，在计算列中设为NULL；32个空食物记录不导入。53条USDA食物的核心营养字段不完整，不能直接转成App当前四项均非可空的 `FoodItem`，需要提示缺失或选择数据齐全的对应条目。

## 重新采集和增量扩充

在本目录执行，Python 3.9以上即可，无第三方依赖：

```bash
python3 catalog.py import-usda
python3 catalog.py crawl-china
python3 catalog.py build
```

下载文件和已采集列表支持缓存重用，中断后可续跑；重跑使用稳定来源ID更新，不重复增加同一条食物。`crawl-china --refresh` 会另存一份新快照再导入，保留旧原件。请求间隔至少1秒，遇403/访问限制停止，不使用绕过验证或代理轮换。

USDA数据版本固定在 `catalog.py` 的 `USDA_RELEASES`，发布新版本后先核对[官方下载页](https://fdc.nal.usda.gov/download-datasets/)，再修改版本、文件名并重建。可用 `--datasets foundation` 单独更新某个来源。增加中文名时在 `chinese-names.json` 使用确切USDA ID与原始描述；导入会核对原文是否一致。

不带 `--compact` 的 `export` 会保留全部USDA营养字段。精简版保留能量、蛋白质、脂肪、碳水、膳食纤维、糖、饱和脂肪和钠；主库保留全部微量营养素。也可以 `csv --table nutrients` 导出所有营养字段长表。

## 查询方式

```bash
python3 catalog.py search 米饭
python3 catalog.py search chicken --limit 10
python3 catalog.py get usda:173424
python3 catalog.py search 挂面 --include-restricted
python3 serve.py
```

`serve.py` 仅监听本机127.0.0.1:8767，默认读取App精简库，提供 `GET /health`、`GET /foods?q=rice&limit=10`、`GET /foods/usda:173424`，详情包含营养表与每份营养计算。即使指定主库，接口仍会过滤待授权来源。

Swift客户端见 `clients/swift/LocalFoodDatabase.swift`。接入App时，将导出库加入资源包并添加该Swift源文件、链接系统SQLite3，然后：

```swift
let url = Bundle.main.url(forResource: "KeepFitFoods", withExtension: "sqlite")!
let database = try LocalFoodDatabase(url: url)
let foods = try database.search("水煮鸡蛋")
let portions = try database.portions(for: "usda:173424")
```

客户端只读打开数据库，查询不需要联网；营养缺失仍返回nil。数据库保留来源URL，可用于详情页展示引用。网站后端可使用相同SQLite或导入服务器数据库；这里的localhost接口用于本地查询验证。

## 来源与许可

- [USDA FoodData Central许可与API文档](https://fdc.nal.usda.gov/api-guide/)：Public Domain / CC0-1.0；支持下载和商用，保留来源署名。
- [中国疾控平台说明](https://www.chinanutri.cn/yyzyxxpt/sjzx/swcfsjk/201911/t20191128_207183.html)及[每条食品页的商业使用声明](https://nlc.chinanutri.cn/fq/foodinfo/261.html)：未经营养与健康所允许不得用于商业目的。当前来源标记为 `commercial_use_authorized=0`，商业导出及API会排除它。取得书面许可后需记录许可范围和凭据，再建立授权版本。
- [CyberScraper-2077](https://github.com/itsOwen/CyberScraper-2077)采用大模型提取网页；本批来源已经提供结构化ZIP/JSON，直接解析更适合保留营养数值、原始单位和可重复核查的依据，因此无需安装该工具。

## 验证

```bash
python3 -m unittest discover -s tests -v
```

测试覆盖每单位换算、kJ换算、缺失值、负源值、重导入、字段变动、字面搜索以及待授权数据的查询/API/商业导出隔离。另有 `tests/LocalFoodDatabaseSmoke.swift`，已在真实导出库上验证中文食物查询和官方份量计算。
