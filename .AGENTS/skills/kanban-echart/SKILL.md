---
name: kanban-echart
description: >-
  OrBit 看板 ECharts 全流程：图位反查 → 数据口径 → 明文/14bit 装载 → WebAPI_ 过程 → 六关验收 → 受控部署。
  用于做看板、改看板、图表取数。含版式细则、压缩装载、常见坑与本地脚本。
version: "4.0.1"
agent_created: true
source: custom
---

# ECharts 看板（自用版）

> **触发关键词**：`看板`、`ECharts`、`echart看板`（含错拼 `echat`）。命中即进入本技能。

**对象**：`dbo.KanBanITEM_Echart` 图位。数据源 = 图位绑定的存储过程，返回一列 `value`；
内容是 `option = {...};`（明文）或自解码 IIFE（14bit 装载），由平台 `eval`。

**规则真源**：环境、库、MCP 工具 ⇒ 技能 `mes-db`；过程规范 ⇒ `.AGENTS/rules/stored-procedure-rules.md`；
输出目录 ⇒ `.AGENTS/rules/output-path-convention.md`。本技能不抄第二份。

**唯一完整实例**：TH 温湿度 3D 看板（`WebAPI_THKanban*`）。配色、字号、尺寸、锚点、8 值解包
都是那个看板的值；新看板照规则做，数值重新定，⛔ 不照抄。

| 子文件 | 内容 |
|---|---|
| [workflow_build.md](./workflow_build.md) | 第 1~6 步：需求 → 图位反查 → 口径 → 形态 → 过程骨架 |
| [workflow_layout.md](./workflow_layout.md) | 版式与 option 细则：画布 / graphic / 配色 / series / 合并 / 平面图 / 本地验证 |
| [workflow_accept.md](./workflow_accept.md) | 验收与上线核对：六关 + 库内漂移比对 |
| [workflow_pack.md](./workflow_pack.md) | 14bit 装载：底本 / 写法 / 回填 / 对拍 |
| `scripts/` | 7 个检查与生成脚本，见第 6 节 |
| `assets/verify.html` | 离线验证页：粘 option 直接出图，两种形态都认，自带 ECharts 4.9.0 |

**适用**：折线 / 柱状 / 饼 / 排行 / 预警列表 / 概览卡 / 平面图 / 等轴测 / 多区块合并大屏，
以及需要压缩装载的大图。不限于温湿度看板。

---

## 〇、环境与边界

- 环境、库、MCP 与工具名 ⇒ 技能 `mes-db`。查表用 `<mcp>-query`，看过程用 `<mcp>-procedure`，执行过程用 `<mcp>-execute`。
- 过程部署只出 SQL 交人工；`execute` 只用于测试库的只读取串与验证，正式库不执行写。
- `execute` 带 `@UserParameter` 报参数错误时，属 MCP 传参缺陷，改用一次性直连脚本，不反复试。
- 跨实例取数地址只在 [workflow_pack.md](./workflow_pack.md) §5 写一份，本文件不复述。

---

## 一、平台机制（动手前认这七条）

| 机制 | 后果 |
|---|---|
| 数据源 = 图位「编辑数据源」里配的存储过程；返回**一列 `value`** | 过程结尾只能 `SELECT <串> AS value` |
| `EchartScript` 里 `componentData[].style.dataSource.apiName` = 过程名 | **一组件一过程**；改过程名必须同步改图位，否则断链 |
| 整屏 JSON 存在一行 `EchartScript` 里，图位尺寸也写在里面 | 尺寸由图位定；过程按像素绝对坐标排版 |
| 平台对 `value` 整段 `eval` | 明文形态**不能带函数**；装载形态本身就是 IIFE，属例外 |
| 平台 ECharts 是 **v4.9.0** | v5 语法不可用；graphic 百分比尺寸、group 居中语义都不成立 |
| 图位配置宽高 ≠ 平台实际渲染尺寸 | 实例：配置 `320×159`、平台按 `512×254`（≈1.6×）出图 ⇒ 两档都要渲染验证；比例按图位实测，别当常数 |
| 平台疑似缓存图位取到的 option | 过程部署后图位不刷新 ⇒ 重新保存 / 刷新图位才重新调 WebAPI |

---

## 二、两种返回形态（选错则后面全错）

平台只看 `value` 能不能 `eval` 出 option。两种形态都合法，**验收判据完全不同**。

| | **A 明文** | **B 14bit 装载** |
|---|---|---|
| 首 | `option = {` | `(function(){ ... })();` |
| 尾 | `};` | `})();` |
| 属性名 | 裸键（不带双引号） | 无（骨架内部自有写法） |
| 函数 | 禁，唯一例外是合并组件的客户端切换 | 本来就有：`var B=19968` 拆包 + LZ 解码 + `eval` |
| 取串 | 分块 base64 拼回 | 过程自带 `@Chunked=1` 出 `M\|序号\|` 块 |
| 适用 | 绝大多数图位 | option 超 2 万字符、平台取串超时 / 截断，或图位本就是 TH 3D 原生骨架 |

**选 B 的硬前提**：必须拿到**该环境自己的**前端骨架正文当底本，只把数据段挖成占位由 SQL 回填。
没有底本就不许走 B。⛔ 另一环境的过程不能拿来顶替（见 [workflow_pack.md](./workflow_pack.md)）。

⛔ 不要另造「短键名 + 映射表」的压缩串 —— 需前端解码，前端不改就崩。
压缩收益只能来自**删静态几何与去重复结构**，不是删空格。

---

## 三、全流程（十一步，顺序不能省）

| # | 步骤 | 产物 | 通过判据 |
|---|---|---|---|
| 1 | 需求与选型 | 一句话版式 + 画布尺寸 + 交互口径 | 形态或尺寸说不清时，先出原型再定 |
| 2 | 反查图位 | `apiName`、真实宽高、同屏组件清单 | 图位配置表查得到且已绑定 |
| 3 | 口径与数据 | 统计面、哨兵、停报、台账缺口 | 每个数字都能回库复算 |
| 4 | 定返回形态 | A 明文或 B 装载，写进过程头注释 | 选 B 必须已持有该环境骨架底本 |
| 5 | **option 原型 + HTML 验证** | 手写 option + `assets/verify.html` 截图 | **页面出图、无报错**（硬门） |
| 6 | 写过程（明文） | `tasks/<MCP名>/dev/<功能英文名>/WebAPI_<名称>.sql` | 静态规则（第 2 关）全 PASS |
| 7 | **压缩装载**（B 形态必做） | `scripts/pack_option.py --sql` 出的装载块 | 脚本自检：拆包 + LZ 解码逐字节一致 |
| 8 | 验收 | 取串 / JS / 渲染证据 / 装载对拍 | 见 [workflow_accept.md](./workflow_accept.md) |
| 9 | 测试库真编译 | 测试库 `execute` 返回码 0，或人工执行回传 | 编译过 ≠ 跑通，仍要实跑取串 |
| 10 | 正式部署 | 执行前快照 + 部署 + 回查 | `modify_date` 变 + `ANSI/QI=1/1` + 特征词命中 |
| 11 | 平台核对与留痕 | 截图 / 结论 + 任务目录留痕 | 图位重新调取后与本地渲染一致 |

> ⛔ **第 5 步是硬门**：HTML 里渲染不出来，就不许写存储过程。
> option 在 `assets/verify.html` 里调通（两种形态都认），再决定要不要压、怎么压。
> 没有取串权限时这条路照样走得通 —— 手工粘 option 即可，不需要连库。
>
> **第 6 → 7 是最容易漏的一环**：先把明文写对、渲染通过，再压成装载块。
> 反过来先压再调，等于每改一次都要重压，且压缩串肉眼无法定位版式错。
>
> 第 8 步与第 9 步不可互换。**真编译**拦编译期错（Msg 174 / 2705 / 264）；
> **实跑取串**拦静默空白与断串。两者都过才算数。
> 交付前必须**实际取真实输出**：dump 到的定义一致，不代表运行结果正确。

---

## 四、红线

### 4.1 通用规则（不在此展开）

| 内容 | 真源 |
|---|---|
| 事务、`TRY/CATCH`、`RETURN 0/-1`、`ServerMessage:`、可重跑守卫、`SqlProcedureIssueLog` | `.agents/rules/stored-procedure-rules.md` |
| 环境、库、MCP、工具、可执行动作 | 技能 `mes-db` |
| 输出目录 | `.AGENTS/rules/output-path-convention.md`：`tasks/<MCP名>/<类别>/<功能英文名>/` |

### 4.2 看板专属红线

1. 明文返回格式定死：**裸键名**（属性名不带双引号）、`option = ` 前缀、`};` 结尾、**无 `media`**。
   函数默认禁；例外 = 合并组件的客户端切换（[workflow_layout.md](./workflow_layout.md) §6.2），
   上平台前必须单图位真机验证。
2. 装载形态不豁免通用过程规则：解码器、拼串与取数整体包进 `TRY/CATCH`，空数据回 `ServerMessage:`。
3. 同一张表的**每个指标都要各自**排除无效值；一个指标过滤了不代表另一个也过滤了。
   实例：温湿度表 `-999` 哨兵要成对写，只过滤温度照样上线，见过「湿度 -999%」。
4. `RADIANS()` 本库对整数参数返回 FLOOR（`RADIANS(225)` = 3）⇒ 只许传浮点，或统一用 `x * PI()/180`。
5. 改图位所指过程名 = 必须同步改 `EchartScript`；只改库不改图位，线上仍跑旧过程。
6. **签名例外**：看板过程固定四参数（`@OrBitUserName` / `@ResourceName` / `@UserParameter` / `@UserData`），
   没有 `@I_OrBitUserId`，无法写 `dbo.SqlProcedureIssueLog`。异常只回 `ServerMessage:` 结果集；
   这是对 `stored-procedure-rules.md` §2 的已知签名例外。

---

## 五、交付与留痕

- 目录 ⇒ `.AGENTS/rules/output-path-convention.md`：`tasks/<MCP名>/<类别>/<功能英文名>/`；看板用 `dev` 类别。
- 交付件与测试案例放任务目录；原型 / 截图 / 临时脚本放任务目录 `_tmp/`。
- 出件不算答复：关键 SQL 原文贴进对话，路径给纯文本，不开预览面板。
- 看板部署完成判据：`modify_date` 变 + `ANSI_NULLS/QUOTED_IDENTIFIER` 均为 1 + 特征词 0→非 0。

---

## 六、脚本与页面

全部在技能内 `scripts/` 与 `assets/`，脚本相对调用（`py scripts/xxx.py`），不依赖执行位置。

| 脚本 | 用途 | 调用 |
|---|---|---|
| `assets/verify.html` | **离线验证页**（第 5 步主用）：粘贴 option → 多尺寸出图 + 报错 | 双击 `assets/verify.html` |
| `pack_option.py` | **明文 option → 14bit 装载块**（自检逐字节一致） | `py scripts/pack_option.py <option.txt> --sql <out.sql>` |
| `check_proc.py` | 静态规则（按形态自动选表）/ 运行时规则 | `py scripts/check_proc.py static <proc.sql> [more.sql]`<br>`py scripts/check_proc.py runtime <option.txt>` |
| `extract_option.py` | 分块返回拼回成完整串（自动 base64 解码） | `py scripts/extract_option.py <raw_out.txt> <option_out.txt>` |
| `js_syntax_check.js` | JS 语法 + eval 出对象 + 顶层键齐备 | `node scripts/js_syntax_check.js <option.txt> [--out option_eval.json]` |
| `gen_render_page.py` | 生成 ECharts v4.9.0 渲染验证页 | `py scripts/gen_render_page.py <option.txt> <out.html>` |
| `fix_format.py` | 一键去属性名双引号、删平铺 `media` | `py scripts/fix_format.py <proc.sql> [--dry-run]` |
| `verify_pack.py` | 14bit 装载核对 + 与底本逐字对拍 | `py scripts/verify_pack.py <候选.sql> [底本.sql]` |
| — | 无头截图 | `chrome --headless=new --disable-gpu --window-size=1500,1150 --virtual-time-budget=5000 --screenshot=<绝对路径>.png file:///<绝对路径>.html` |

`check_proc.py` 按过程里有没有 `var B=19968` 自动判形态：

- **明文**：R2 前缀 / R3 结尾 / R4 裸键 / R6 无百分比 / R7 禁函数。
- **装载**：改判 `SELECT @js AS value`、解码器唯一、字面量落在 U+4E00–U+8DFF、全文 0 处 `atob`；R7 跳过。
- **legacy**：只有 `atob`、没有 `B=19968`，判 FAIL 并提示重做为 14bit。
- 两形态共有：R1 列名、R5 无 `media`、R8 无显式事务、R9 TRY/CATCH+RETURN、R10 `ServerMessage:`、
  R12a 可重跑守卫、R12b 禁 `DROP + CREATE`。

> 库内标准版 `WebAPI_THKanbanFlash` 当前会在 R9 / R10 上 FAIL —— 缺 `TRY/CATCH` 与 `ServerMessage:`，
> 属已知待修缺陷，不是规则误判。新做必须补。

---

## 七、坑速查（按出现频率排序）

| # | 坑 | 判据 / 修法 |
|---|---|---|
| 1 | `media` 挂在平铺 option 上 | v4 **一张 canvas 都不建、不抛错、空白** ⇒ 删 `media` 或改 `{baseOption, media}` |
| 2 | 属性名带双引号 | 退化成纯 JSON，与 `option = ` 前缀冲突 ⇒ 语法错；`fix_format.py` 一键去引号 |
| 3 | `graphic` text 坐标写在元素级 `x/y` | v4 只认 `style.x / style.y`（元素级是 v5 语义）：矩形出、文字全丢 |
| 4 | `graphic` 用百分比尺寸 | v4 不支持 ⇒ 写死像素；`group` 的 `left:"center"` 语义随版本漂移 ⇒ 元素直挂 `graphic.elements` |
| 5 | `RADIANS(整数)` 截断 | 楼宇图 V 型歪 53° 的真因 ⇒ 改 `RADIANS(225.0)` 或 `225 * PI()/180` |
| 6 | 哨兵只过滤一个指标（实例：温湿度表只过滤温度） | 同表多指标要各自排除无效值；正式库首跑蹦「湿度 -999%」⇒ 湿度支单独 `Hu > -900`（R13b） |
| 7 | `CROSS APPLY` 取最新一条 | 台账无采集点时整间房消失（15 间只统计出 13 间）⇒ 改 `LEFT JOIN` 派生表 / `OUTER APPLY` |
| 8 | `NULL > @OfflineMin` | UNKNOWN 不命中 WHEN ⇒ 无采集跌到 `ELSE 'check'` 算正常 ⇒ 先判 `RecordDate IS NULL` |
| 9 | `sqlcmd` 单列截断 256 字符 | 长串必须分块取回；装载形态直接用过程自带 `@Chunked=1` |
| 10 | 图位不刷新 | 部署成功但线上仍是旧图 ⇒ 重新保存图位配置触发重调 |
| 11 | 命名先搜库内统计 | 库内是现状不是规范 ⇒ 先按技能定 `WebAPI_` 前缀（不是 `_WEBAPI` 后缀） |
| 12 | Linux / Git Bash 副作用 | heredoc 吞反斜杠（正则写 `[{]`）；`sqlcmd -i` 绝对路径「拒绝访问」⇒ `cd` 后传相对名；`LIKE` 含 `[` 假阴性 ⇒ 用 `CHARINDEX` |
| 13 | 合并多图位时逐个平移元素 | 纯 graphic 图位应整体塞进 `graphic` group（内部坐标不动），否则 `onclick` 回调里的预生成坐标对不上；带坐标轴的图位不能分组，只能逐个平移并重编 `gridIndex` / `xAxisIndex` / `yAxisIndex` |
| 14 | 装载形态漏掉 TRY/CATCH 与兜底 | 解码器 + 拼串整体包 `TRY/CATCH`，空数据给 `ServerMessage:` 串；缺了就是静默空白 |

---

## 八、维护

- 版式细节与实测数据 ⇒ [workflow_layout.md](./workflow_layout.md)；装载细节 ⇒ [workflow_pack.md](./workflow_pack.md)。
- 单次交付的过程全文 ⇒ `tasks/<MCP名>/dev/<功能英文名>/`；执行证据与临时件放同目录 `_tmp/`。
- ⛔ 不把过程正文、行数、`modify_date` 写进长期记忆（只留指针）。
