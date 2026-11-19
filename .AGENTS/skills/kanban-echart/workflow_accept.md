# 看板验收 · 六关 + 漂移比对

> 主入口 ⇒ [SKILL.md](./SKILL.md)；过程骨架 ⇒ [workflow_build.md](./workflow_build.md)；
> 装载写法 ⇒ [workflow_pack.md](./workflow_pack.md)；坑速查 ⇒ [SKILL.md](./SKILL.md) 第七节。

写完 / 改完 / 上线前都要过。**任何一关不通就不许交付**，因为这类过程的失败几乎全是**静默的**：
过程 `RETURN 0`、平台不报错、图位一片空白。

## 六关（顺序不能省）

| # | 关卡 | 判据 | 不过的后果 |
|---|---|---|---|
| 1 | **绑定与尺寸核对** | 图位配置里的 `apiName` 指向的过程在库里存在；**同时读出图位的真实宽高** | 改了过程没人用 / 按错误的尺寸排版 |
| 2 | **静态规则** | `scripts/check_proc.py static` 全 PASS | 交付即错，改一行要重跑 |
| 3 | **编译** | 测试库经受控通道返回码 0，或人工执行回传返回码 0 | 正式库部署直接失败 |
| 4 | **实跑取串** | 明文：`option = {` 开头、`};` 结尾；装载：`(function` 开头、`})();` 结尾；长度 > 200 | 拿到提示串（无数据）或断串 |
| 5 | **JS 语法** | `node scripts/js_syntax_check.js` ⇒ `OK` | 白屏 / 控制台语法错 |
| 6 | **浏览器渲染** | ECharts **v4.9.0** 下 `canvas` 数 ≥ 1 且无 console 错误 | **静默空白**（最坑，见下） |

第 7 关（可选但要紧）：**库内漂移比对** —— 用目标环境的 `<mcp>-procedure` 工具把线上过程定义落盘，
与本地交付件 `diff`，确认线上跑的就是你手上这份。

### 第 1 关怎么查图位

绑定信息在 `dbo.KanBanITEM_Echart.EchartScript`（一整块 JSON），**一行里可能挂多个组件**。
用目标环境的 `<mcp>-query` 工具查：

```sql
SELECT EchartDIVName, DIVX, DIVY, IsActive,
       SUBSTRING(EchartScript, CHARINDEX('apiName', EchartScript), 60)
FROM dbo.KanBanITEM_Echart
WHERE EchartScript LIKE '%<过程名>%';
```

`EchartScript` 是 nvarchar(max)，单列会截断 ⇒ 要按 150~180 字符分块取回再正则提 `apiName` + `width`/`height`。

⚠️ **配置宽高 ≠ 平台实际渲染尺寸**。实例（TH 温湿度看板）：配置 `320×159`，
`canvasStyleData` 是 `1920×1080 / preWidth 1200`，而平台截图形态与 **512×254** 的渲染吻合
（≈1.6 倍）。⇒ 第 6 关必须**同时渲染配置尺寸与平台实际比例尺寸**，再拿平台实机截图去对。
1.6 是那一次的比值，别的图位要自己量，⛔ 不要当常数用。
只按配置尺寸验证会误判「挤压 / 字号过大」。

---

## 第 2 关 · 静态规则（`check_proc.py` 自动判形态）

脚本按过程里有没有 `var B=19968` 判形态，选对应规则表。

### 共有规则（两形态都判）

| 规则 | 判据 | 为什么 |
|---|---|---|
| R1 列名 | 返回列别名必须是 `value` | 平台按 `value` 取值，别的名字取不到 |
| R5 禁 media | 代码里 0 处 `media:` | v4 挂平铺 option 上会整块不渲染 |
| R8 无显式事务 | 0 处 `BEGIN TRAN` / `COMMIT` / `ROLLBACK` | 硬红线：必须 TRY/CATCH |
| R9 返回码 | 有 `BEGIN TRY` / `END CATCH` / `RETURN 0` / `RETURN -1` | 同上；装载形态不豁免 |
| R10 消息前缀 | `ServerMessage:` ≥ 2 处（失败 + 空数据） | 平台按前缀识别错误 |
| R12a 可重跑 | `IF OBJECT_ID IS NULL → 空壳` + `ALTER` | 缺了重复部署报 2714 |
| R12b 禁 DROP+CREATE | 0 处 `IF OBJECT_ID IS NOT NULL … DROP PROCEDURE` | 丢权限与依赖，`stored-procedure-rules.md` §6 禁止 |
| R13a 温度哨兵 | 读 `temperature` 必须有 `T > -900` / `temperature <> -999` | `-999` = 无读数，进图会把 y 轴拉穿 |
| R13b 湿度哨兵 | 读 `humidity` 时**单独**要有 `Hu > -900` | 温度有过滤**不算**，见过「湿度 -999%」 |

### 明文形态专用

| 规则 | 判据 | 为什么 |
|---|---|---|
| R2 前缀 | 拼装串以 `option = {` 开头 | 平台 `eval` 整段代码；纯 JSON 会被当块语句 |
| R3 后缀 | 拼装串以 `};` 结尾 | 缺分号 eval 报错 |
| R4 裸键 | `N'...'` 里 0 处 `"标识符":` | 属性名不带双引号，加了退化成纯 JSON |
| R6 禁 graphic 百分比 | 0 处 `graphic` + `'100%'` | v4 不支持 graphic 百分比尺寸 |
| R7 禁函数 | 0 处 `function` / `=>` | option 会被当配置传，函数体过不了序列化 |
| R11 序列自洽 | `yAxisIndex` < `yAxis` 条数；`xAxisIndex` < `xAxis` 条数 | 越界 ⇒ `coordinateSystem` 未定义 |

### 装载形态专用

| 规则 | 判据 |
|---|---|
| P1 返回列 | 有 `SELECT @js AS value` |
| P2 解码器 | `var B=19968` 恰好 1 处，步长 14，`Math.floor` 拆包 |
| P3 无 atob | 全文 0 处 `atob` |
| P4 字面量 | 装载块每个字符在 U+4E00–U+8DFF，且不含 `'` `\` `"` 与换行 |
| P5 收尾 | 返回表达式以 `})();` 结尾 |
| P6 首段 | `DECLARE @b64` 第一段是 `CAST(N'…' AS NVARCHAR(MAX))` |
| P7 取数地址 | 按文件头底本判；地址表与判据见 [workflow_pack.md](./workflow_pack.md) §5 |
| P8 对拍 | 有压缩前底本时，解码结果与底本骨架逐字相同 |

P7 由文件头 `底本：基板正式库` / `底本：总装正式库` 决定判哪边；没有这行只列地址、不判环境。
P8 需 `verify_pack.py` 附第二个参数（同环境、装载前的过程正文）。

> ⚠️ **R7 的例外：合并组件的客户端切换。** option 里拼 `id` / `onclick` / 辅助函数时，
> 明文形态静态检查会报 R7 FAIL，属预期（见 `workflow_layout.md` §6.2）。
> 其余规则照常判；必须先在单图位真机验证切换，再上大屏。
> 装载形态整体就是 IIFE，R7 直接跳过。

> R13 拆两条的由来：同表同哨兵、两个指标必须**成对**写。`T > -900` 存在时旧规则会整条判 PASS，
> 湿度那支漏掉照样上线 ⇒ 现在按指标分别判。区间过滤与精确剔除两种写法都认。
>
> R13a/R13b **只对读温湿度列的过程**生效 —— 脚本按过程里有没有 `temperature` / `humidity` 自动启停。
> 别的看板不读这两列，不会因此判 FAIL；也别把这两条当通用规则，套到所有过程上。

---

## 第 3 关 · 编译

- 测试库有 `execute`：用 `<mcp>-execute` 执行整份脚本，看返回码。
- 无 `execute` 或正式库：只出脚本，由用户在本机 / SSMS 执行并回传返回码。
- 编译过 ≠ 跑通：Msg 174 / 2705 / 264 是编译期错；静默空白与断串要到第 4 关才暴露。

---

## 第 4 关 · 实跑取串

`<mcp>-query` 只放 `SELECT` / `WITH`，**不能 `EXEC`**，也开不了 `QUOTED_IDENTIFIER`。
取串用测试库的 `<mcp>-execute`，或由用户执行取串脚本；带 `@UserParameter` 报参数错误时走后者。

明文形态：`INSERT #OPTBUF EXEC` + base64 分块（`workflow_layout.md` §8.1），
或只读通道下 `sqlcmd` 分块，`extract_option.py` 拼回。

装载形态：过程自带 `@Chunked`，传 1 直接出 `M|序号|` 块：

```sql
EXEC dbo.WebAPI_<名称> @UserParameter = N'{...}', @Chunked = 1;
```

输出落 `<任务目录>/_tmp/raw_out.txt`，再：

```bash
py scripts/extract_option.py raw_out.txt option_real.txt
```

判别：明文 `option = {` 开头、`};` 结尾；装载 `(function` 开头、`})();` 结尾。长度 < 200 一律判失败。

---

## 第 5 关 · JS 语法

```bash
node scripts/js_syntax_check.js option_real.txt [--out option_eval.json]
```

脚本按形态自动选法：
- 明文：`new Function(src + ';return option;')` —— 等同平台 `eval`。
- 装载：`eval(src)` 直接取 IIFE 返回值 —— 解码器跑通即证明装载可解。

共用判据：结果是 object；有 `series` 或 `graphic.elements`；
需要直角坐标系的类型必须有 `grid` + `xAxis` + `yAxis`（pie / funnel / gauge 不要求）。
`--out` 把 eval 结果写成纯 JSON，供第 6 关渲染。

---

## 第 6 关 · 浏览器渲染

```bash
py scripts/gen_render_page.py option_eval.json <任务目录>/_tmp/check.html
chrome --headless=new --disable-gpu --window-size=1500,1150 \
       --virtual-time-budget=5000 --screenshot=<绝对路径>.png file:///<绝对路径>/check.html
```

- 页面自带：顶部状态栏（✅/❌ + 原因）、尺寸与键数统计、返回原文、报错堆栈。
- ECharts 用**本地 v4.9.0**，不要用 CDN（平台是 v4，v6 能过不代表 v4 能过）。
- 判据：`document.querySelectorAll('canvas').length >= 1` 且 console 0 错误。
- **没权限取串时**：把串直接贴进 `assets/verify.html`（双击即开、自带 4.9.0），
  两种形态都认，效果与这条等价。原型阶段（写 SQL 之前）也用这个页面。

---

## ⚠️ 致命坑：`media` 挂在平铺 option 上 ⇒ v4 整块不渲染

ECharts 的 media 查询只认 **`{baseOption: {...}, media: [...]}`** 顶层结构。
写成 `{title: ..., series: ..., media: [{query, option}]}` 时：

- **一张 canvas 都不建**
- **不抛异常、控制台干净**
- 平台 `RETURN 0`、状态正常
- 图位一片空白

修法两个：① 删掉 media（图位尺寸固定时首选）；② 改成 `{baseOption: {...}, media: [...]}`。
判据：`document.querySelectorAll('canvas').length === 0` 就是命中这个坑。

其余实测坑见 [SKILL.md](./SKILL.md) 第七节，不在本文件重复。
