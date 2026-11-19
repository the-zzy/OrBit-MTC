# 看板子工作流 · 第 1~6 步

> 主入口与红线 ⇒ [SKILL.md](./SKILL.md)。
> 版式与 option 细则 ⇒ [workflow_layout.md](./workflow_layout.md)；
> 验收 ⇒ [workflow_accept.md](./workflow_accept.md)；装载 ⇒ [workflow_pack.md](./workflow_pack.md)。
> **看板用存储过程，前缀必须是 `WebAPI_`；这不是对外 API** —— 对外 API（设备 / 其他系统）走 `api-interface`。
> 过程规范按 `.agents/rules/stored-procedure-rules.md` 执行，本文件只写看板增量。

---

## 1. 需求确认

| 必答项 | 说明 |
|---|---|
| 版式 | 要参考图；只说「做个图」就停下来问 |
| 画布尺寸 | 像素宽高（graphic 绝对坐标，尺寸错整图错位） |
| 数据口径 | 统计面、时间窗、分档阈值、来源表 |
| 交互 | 平台 option 不能带函数 ⇒ 交互只能是**外部传参重调** |
| 刷新 | 由平台调度决定，过程内不写定时 |

- 需求属于哪个看板、哪个图位，先问屏幕位置；「左边这三个」这类指代必须按位置反查（见第 2 步）。
- ⛔ 口径没定就写过程 = 返工。口径有歧义时先出「数字表」给 master 认，再动 SQL。

---

## 2. 反查图位（动手前必做）

配置表 `dbo.KanBanITEM_Echart`：一屏 JSON 存在一行 `EchartScript` 里，**一行可能挂多个组件**。
用目标环境的 `<mcp>-query` 工具执行（环境与 MCP 见技能 `mes-db`）。

```sql
-- 2.1 哪些行含目标过程
SELECT EchartDIVName, DIVX, DIVY, IsActive, LEN(EchartScript) AS L,
       CHARINDEX('<过程名>', EchartScript) AS pos
FROM dbo.KanBanITEM_Echart WITH(NOLOCK)
WHERE EchartScript LIKE '%<过程名>%'
ORDER BY L DESC;

-- 2.2 按 150 字符切片取回，绕开单列截断
WITH S AS (
    SELECT EchartScript AS js FROM dbo.KanBanITEM_Echart WITH(NOLOCK)
    WHERE EchartScript LIKE '%<过程名>%'
)
SELECT v.n, '[' + SUBSTRING(S.js, (v.n - 1) * 150 + 1, 150) + ']' AS chunk
FROM S CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),
                          (11),(12),(13),(14),(15),(16),(17),(18),(19),(20)) AS v(n)
WHERE (v.n - 1) * 150 < LEN(S.js)
ORDER BY v.n;
```

- 取回后正则提 `apiName` 与 `width` / `height`；`canvasStyleData` 里另有整屏基准（实例 `1920×1080`、`preWidth 1200`）。
- **配置宽高 ≠ 实际渲染尺寸**：实例图位 `320×159`、平台按 `512×254`（≈1.6×）出图。
  ⇒ 渲染验证两档都跑：配置尺寸 + 平台实际比例尺寸，再拿平台截图对；比例按图位实测，别当常数。
- 超长 JSON 用 hex / base64 分块取回，避免中文被 `varchar` 截断。
- ⛔ **master 指图时按屏幕位置反查 `apiName`，不许按交付件目录里的文件名猜。**
  曾把「左边这三个图」误解成目录里未修的五个过程，误改五个无关图位并推到正式库，全部回撤。
- ⛔ 一个过程名只绑一个组件；改名 = 断链，图位必须同步改。

---

## 3. 数据口径与表结构

### 3.1 查表结构

用目标环境的 `<mcp>-query` 工具（只读）：

```sql
SELECT c.name AS 列名, ty.name AS 类型, c.max_length AS 长度,
       c.is_nullable AS 可空, c.column_id AS 序号, ep.value AS 字段说明
FROM sys.columns c
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
WHERE c.object_id = OBJECT_ID('<表名>')
ORDER BY c.column_id;
```

### 3.2 口径确认清单（逐条写进过程头注释）

下面每条的**判据**通用，括号里是 TH 温湿度看板的实例值。换看板照判据问，答案重新取。

1. **统计面**：分母是什么、从哪张表数，台账数 ≠ 实际有数据的主体数。
   （实例：现场 8 层 37 间 vs 库内 3 层 15 间有采集点，是两个统计面。）
2. **无效值 / 哨兵**：哪几个值是「无读数」而不是真实数字？**同表的每个指标都要单独排除**。
   （实例：`temperature` / `humidity` = `-999`，两列各自要 `> -900`。）
3. **超时判定**：多久没数据算失效？`NULL` 必须先单独判，不能落进正常档。
   （实例：`RecordDate` 超 180 分钟判停报。）
4. **脏行**：台账里有不属于业务主体的行。
   （实例：`deviceName = sn` 的接入残留行，凭空多出 4 间。）
5. **类型与采样**：指标列是否 `varchar`、采样是否等间隔。前者一律 `TRY_CONVERT`，后者分桶 `AVG`。
6. **阈值 / 标准值**：区间怎么写、无管控怎么表示、要不要套时间窗。
   （实例：`18-28℃` / `2-10℃` / `/` 不管控；标准值不套时间窗，否则停采 30 天色带整条消失。）
   ⚠️ 分隔符要按**库里实际值**定，别按文案猜（实例：标准值分隔符全库是 `-`，文案写的是 `~`）。
7. **数据滞后**：最新数据可能落后数小时。要「最近 N 小时」时以 `@LastDate` 回推，⛔ 不用 `GETDATE()` 硬减。
8. **业务例外**：哪些「看起来异常」其实是正常的。
   （实例：冰箱腔体湿度 72~98% 是真实值，不做异常处理。）
9. **空值语义**：`NULL` 与 `0` 在业务上分别代表什么，图里怎么显示（断点 / 0 / 不画）。
10. **跨天与时区**：日报切点、库时区与看板时区是否一致。

> 每个数字都能回库复算：`SUM()` 遇 NULL 整组为 NULL，`COUNT(*)` 与 `COUNT(列)` 并查。

---

## 4. 定返回形态

写完口径先定形态，别写一半再改。

| 判据 | 选 A 明文 | 选 B 14bit 装载 |
|---|---|---|
| 估算 option 字符数 | < 2 万 | ≥ 2 万，或平台取串已出现超时 / 截断 |
| 前端骨架 | 不需要 | **必须持有该环境自己的骨架正文** |
| 后续维护 | 直接改拼串 | 改数据段占位，骨架逐字节不动 |

- 选 B 的流程、装载写法、对拍判据全部在 [workflow_pack.md](./workflow_pack.md)。
- ⛔ 没有底本不许走 B。底本只能来自同环境，另一环境的过程不能顶替。
- 形态写进过程头注释（`-- 返回形态: A 明文` / `-- 返回形态: B 14bit 装载`），验收脚本据此选规则表。

---

## 4.5 原型与 HTML 验证（硬门，不过不写 SQL）

**顺序要求：先出 option 原型并在 HTML 里渲染通过，再动存储过程。**
没有取串权限不影响这一步 —— 手工粘 option 即可，不需要连库。

打开 `assets/verify.html`（双击即开，自带 ECharts 4.9.0）：

1. 把 option 粘进左侧文本框，点「验证」。
2. 尺寸栏填图位真实宽高，多个用逗号分隔（默认 `320x159,512x254,420x430`）。
3. 状态栏绿色且每个尺寸都出图，才算过。

页面能认两种内容，按内容自动判：

| 贴进去的 | 判定 | 走法 |
|---|---|---|
| `option = { … };` | A 明文 | `new Function(src + ';return option;')` |
| `(function(){ … })();` | B 装载 | `eval(src)`，解码器自验 |

通过判据（缺一不算）：

- 状态栏 `✅`，无 `Invalid or unexpected token` / `Cannot read` 之类报错
- 每个尺寸都生成了 canvas（`canvas 数 = 尺寸数`）
- 顶层键与设计一致：折线 / 柱状 / 混合要有 `grid` + `xAxis` + `yAxis`；饼 / 漏斗 / 仪表盘不要求
- 首尾标签不被裁、文字不重叠、图元不出画布

⛔ 常见失败原因看 `workflow_layout.md` §2 / §4：`media` 挂平铺 option、graphic 文字坐标写在元素级、
首尾标签被 grid 裁掉。改完再验，别带着已知问题进 SQL。

原型定稿后另存一份到 `<任务目录>/_tmp/`；后续写过程就是把这版 option 拆成拼串语句。

---

## 5. 过程骨架

### 5.1 命名与登记

- 过程名 `WebAPI_<功能描述>`（帕斯卡命名法），**前缀** `WebAPI_`，不是 `_WEBAPI` 后缀。
- 命名先查技能库，再查库内统计 —— 库内是现状不是规范。
- `WebAPI_*` 看板过程**不登记 `SysPlugIn`、不挂 `SysMenu`**。
- 交付文件名用 `WebAPI_<功能描述>.sql`，放任务目录；目录见第 6 节。

### 5.2 固定参数（四个，一个不能少）

```sql
@OrBitUserName NVARCHAR(100) = '',   -- 平台注入：用户名
@ResourceName  NVARCHAR(100) = '',   -- 平台注入：电脑名
@UserParameter NVARCHAR(MAX) = '',   -- 业务参数 JSON 串
@UserData      NVARCHAR(MAX) = ''    -- JSON / XML 数据
```

业务参数一律走 `@UserParameter`：

```sql
DECLARE @Dev NVARCHAR(100) = N'SMT-3';
IF ISNULL(@UserParameter, '') <> ''
BEGIN
    BEGIN TRY
        SET @Dev = ISNULL(JSON_VALUE(@UserParameter, '$.DeviceName'), @Dev);
    END TRY
    BEGIN CATCH
        SET @Dev = N'SMT-3';
    END CATCH
END
```

- 标量用 `JSON_VALUE`；**数组用 `OPENJSON`**（`JSON_VALUE` 取不到数组）。
- 日期入参按 `yyyy-MM-dd` 字符串收，`TRY_CONVERT(DATE, ...)` 校验，非法回落默认。
- 筛选条件用 `(ISNULL(@P,'')='' OR col LIKE '%'+@P+'%')`，空值 = 不过滤。
- 鼠标事件接不上：切视角 / 切房间只能由外部改 `@UserParameter` 重调。

### 5.3 骨架（明文形态）

```sql
-- =============================================
-- 存储过程: WebAPI_<功能名称>
-- 环境: <深圳基板正式 / 深圳总装正式 / ...>
-- 功能: <一句话>
-- 数据源: dbo.<表>
-- 画布: 固定 <W>×<H>，graphic 绝对坐标
-- 返回形态: A 明文
-- =============================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'dbo.WebAPI_<功能名称>', N'P') IS NULL
    EXEC (N'CREATE PROCEDURE dbo.WebAPI_<功能名称> AS BEGIN SET NOCOUNT ON; SELECT N'''' AS value; END');
GO
ALTER PROCEDURE [dbo].[WebAPI_<功能名称>]
    @OrBitUserName NVARCHAR(100) = '',
    @ResourceName  NVARCHAR(100) = '',
    @UserParameter NVARCHAR(MAX) = '',
    @UserData      NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    BEGIN TRY
        /* 0. 参数与常量 */
        DECLARE @W INT = 400, @H INT = 920;
        /* 1. 取数：所有表 WITH(NOLOCK)，哨兵成对过滤 */
        /* 2. 拼串：数字先 CONVERT(VARCHAR(n), ...)，空值兜 'null' */
        DECLARE @Option NVARCHAR(MAX);
        /* 3. 输出：裸键、option = 前缀、}; 结尾、无 media、无函数 */
        SET @Option = N'option = {...};';

        IF ISNULL(@Option, N'') = N''
        BEGIN
            SELECT N'ServerMessage: 无数据' AS value;
            RETURN -1;
        END

        SELECT @Option AS value;
        RETURN 0;
    END TRY
    BEGIN CATCH
        SELECT N'ServerMessage: 生成失败 - ' + ERROR_MESSAGE() AS value;
        RETURN -1;
    END CATCH
END
GO
```

- 不写 `dbo.SqlProcedureIssueLog`：看板四参数签名没有 `@I_OrBitUserId`，见 [SKILL.md](./SKILL.md) 红线 8。
- 装载形态的骨架见 [workflow_pack.md](./workflow_pack.md) §3：`IF OBJECT_ID IS NULL → 空壳` + `ALTER`，
  解码器与拼串整体包 `TRY/CATCH`，末尾 `SELECT @js AS value`。

### 5.4 拼串规则（明文形态）

- 一行一列 `value`；**属性名裸键**（不加双引号），整段 `'option = {...};'`。
- 字符串值用双引号包（`text:"正常"`），中文直接写；值内双引号 / 反斜杠要转义。
- 数字先 `CONVERT(VARCHAR(n), ...)`；空值 `ISNULL(x, 'null')` —— 断点必须是 `null` 字面量，不能是空串。
- 少用中间对象：取数优先 CTE / `FOR XML PATH` 直接拼；`#temp` 与表变量用完即清。
- 空数据必须给兜底串（`ServerMessage:` 或空态 option），不许返回空串 / 断串。

---

## 6. 输出文件

- 目录 ⇒ `.AGENTS/rules/output-path-convention.md`：`tasks/<MCP名>/dev/<功能英文名>/`。
- 交付件与测试案例放任务目录；临时件放同目录 `_tmp/`。
- 看板文件名：`WebAPI_<看板名称>.sql`。

## 7. 出件前自检（第 5 步关门）

1. `py scripts/check_proc.py static <交付件>` 全 PASS。
2. 过程头注释写清：环境、数据源、画布尺寸、返回形态、统计面、分档阈值、返回值形态。
3. 交付件可重跑：`IF OBJECT_ID IS NULL → 空壳` + `ALTER PROCEDURE`。
4. SQL 文件 UTF-8 带 BOM + CRLF；文件名 ASCII，不带序号 / 版本号。
5. 下一步进验收，不许跳。
