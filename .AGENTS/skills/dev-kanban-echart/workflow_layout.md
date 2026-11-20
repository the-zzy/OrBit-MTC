---
description: 看板 ECharts option 实现细则：画布坐标、graphic 写法、配色字号、内置 series、列表、合并画布、平面图、本地验证与取串
alwaysApply: false
---

# 看板 option 实现细则

> 前置：主入口 [SKILL.md](./SKILL.md)、需求与过程骨架 [workflow_build.md](./workflow_build.md)。
> 目标平台 **ECharts v4.9.0**；option 以字符串存库、平台 `eval` ⇒ **不能带函数**。
> 本文件所有写法都在线上跑过；没跑过的写法先本地验证（第 8.2 节）再上库。
> 本节讲**明文形态**。装载形态的骨架写法在 [workflow_pack.md](./workflow_pack.md)，版式规则通用。

---

## 1. 画布与坐标系

- 图位尺寸决定画布：`graphic` 只有绝对坐标，**没有百分比**。过程里把 `@W / @H` 写成常量，注释标「图位必须 W×H」。
- 所有元素**直挂 `graphic.elements` 顶层**，不用 `group` 包装 —— v4 里 `group` 的 `left:"center"` / `top:"middle"`
  按包围盒对齐，语义随版本漂移，实测整图偏移。
- 先排几何、后填数据：坐标全部用常量表达式（`@OFFX + i * @STEP`）算好，再代入取值列。
- z 序：背景 `z:-20 ~ -15`，前景（标题 / 竖条 / 徽章）`z:5 / 6`，避免被 series 盖住。
- 静态面板 `animation:false`，免得出图瞬间闪。

---

## 2. graphic 写法（v4 硬约束）

| 元素 | 写法 | 坑 |
|---|---|---|
| 文字 | `{type:"text", style:{x,y,text,fill,font,textAlign,textVerticalAlign}}` | **坐标在 `style.x/style.y`**；元素级 `x/y` 是 v5 语义，v4 下只出矩形、文字全丢 |
| 矩形 | `{type:"rect", shape:{x,y,width,height,r}, style:{fill,stroke,lineWidth}}` | 圆角用 `shape.r` |
| 多边形 | `{type:"polygon", shape:{points:[[x,y],...]}, style:{...}}` | 斜切光效会露折线，横向渐变代替 |
| 渐变 | `{type:"linear", x:0,y:0,x2:1,y2:0, colorStops:[{offset:0,color:"#..."},...]}` | ⛔ `echarts.graphic.LinearGradient` 存 JSON 时被丢；必须对象字面量 |
| 分隔线 | `{type:"grid", show:true, backgroundColor:"rgba(...)", height:1}` 或 1px `rect` | `title.width:"100%"` 只包住文字，铺不满 |

- **宽 2000 的 rect 上做横向渐变 ⇒ 可见区只用到最左 ~18%**：色标压在 `offset 0~0.22`，否则整条退化成纯色。
- 文本没有 `rich`（graphic 不吃）：同一行多段不同颜色的文字，用**多个 text 元素各自右对齐**，
  每段锚在自己的右边界，不要「估宽 + 偏移」—— 17px 粗体 `13.8℃` 估 52px、实际 63px，差 20%，必撞。
- 空态文案手工居中：v4 的 `textAlign` 相对 `style.x`，不给宽就不会自动居中 ⇒ `x = (@W - 15 * 字数) / 2`。
- 标题带（自绘 5 层）：底色横向渐变 → 左端柔光 → 顶边 1px 高光 → 底边亮线 → 亮线下 8px 投影；
  前景 = 左侧 4px 竖条（`shadowBlur:10`）+ 标题 + 右侧计数。

---

## 3. 配色与字号（实例值：TH 温湿度看板）

> 下表是 TH 温湿度看板跑通的配色与字号，**不是默认规范**。新看板按自己的场景定色，
> 但「同类信息同色、正常/预警/严重三档分明、字号阶梯不超 7 级」这三条照守。

| 用途 | 值 |
|---|---|
| 画布底 | `rgba(12,25,46,0.94)`；边框 `rgba(74,144,226,0.35)` |
| 主文字 | `#e8f1fb`；次文字 `#9fb0c8`；弱文字 `#5f7c9c` |
| 正常 / 预警 / 严重 | `#4ade80` / `#fbbf24` / `#f87171` |
| 徽章底 | 同色 18% 透明（`rgba(34,197,94,0.18)` 等） |
| 趋势双线 | 温度 `#2fd8e8`、湿度 `#a78bfa` |
| 分隔线 | `rgba(255,255,255,0.05)`（列表末行不画） |

- 字体统一 `Microsoft YaHei`；字号阶梯：标题 20 / 小标题 17 / 数值 17 粗 / 正文 14 / 次要 13 / 辅助 11 / 徽章 9。
- 图标用文字代替（`font:"bold 9px Microsoft YaHei"` + `textAlign:"center"`），或纯几何（温度计 = 圆角矩形 + 圆）。

---

## 4. 内置 series（能用内置就别自绘）

```js
// 折线 + 隐轴 + 只留首尾标签
xAxis: {type:"category", data:[...], axisLabel:{interval:999, showMinLabel:true, showMaxLabel:true}},
yAxis: [{show:false, splitNumber:4}, {show:false}],
series: [
  {name:"温度(℃)", type:"line", yAxisIndex:0, smooth:true, symbol:"none", data:[...]},
  {name:"湿度(%)", type:"line", yAxisIndex:1, smooth:true, symbol:"none", data:[...]}
],
legend: {left:14, bottom:6, icon:"rect", itemWidth:16, itemHeight:2},
grid: {left:34, right:34, top:44, bottom:28}
```

- ⚠️ **首尾标签被裁**：`boundaryGap:false` 时标签居中于端点，`grid.left/right ≥ 半标签宽`
  （`00:00` ≈ 32px ⇒ 留 16 以上；实测定 34）。`containLabel:true` 解决不了，语义相反。
- 断点用 `null` 字面量，不填 0（`smooth:true` 遇 `null` 自动断开，这是期望行为）。
- `AVG` 分桶后遇全 `NULL` 仍是 `NULL` ⇒ 拼串 `ISNULL(..., 'null')`，否则拼出空字符串 ⇒ JS 语法错。
- 饼 / 漏斗 / 仪表盘 / 环形不要求 `grid / xAxis / yAxis`；折线 / 柱状 / 混合才要求。
- `series` 的 `yAxisIndex` / `xAxisIndex` 必须小于对应轴条数，越界报 `coordinateSystem` 未定义。
- 小尺寸防挤**不要用 `media`**：平铺 option 上挂 `media` ⇒ v4 整块不渲染（判据与修法见主 SKILL.md 坑速查 #1）。
  直接按目标尺寸把字号 / `grid` / 图例位置写死。

---

## 5. 列表（预警清单 / 排行）

平台串不能带 `custom series`（要函数）⇒ 列表用**逐元素 graphic**：

- 每行 = 背景（可选）+ 若干 `text` + 分隔线 `rect`；行高按条数均分、设上限（实测 66），条数变化不折行、也不把两行撑满屏。
- 列位全部**右对齐锚点**：`timeX = W-16`（时间）、`valX = timeX-58`（指标 + 值）、`nameMaxW = W - 36 - 152`（名称，超出截断）。
  右侧三列都靠 `right` 定位，画布换宽度自动跟走。
- 圆点用**三个同心圆**（外光环 16% 透明 + 实心 + 发光），不用 `shadow` —— v4 里 shadow 会把圆撑偏约 7px。
- 顶部对齐，不做整组垂直居中（2 条数据会孤零零挂在半空）。
- 空态：居中一行「暂无预警」。

---

## 6. 合并画布

### 6.1 服务端合并（一个过程、一个画布、多个区块）

- 触发：一个图位要同时看到「房间平面图 + 趋势 + 卡片」时，**不拆成三个图位**，合成一个 option。
- 做法：画布加高（实测 `400×920`），按 `y` 分段：每段一个标题带 + 一块内容；段间留 8~12px。
- 尺寸写死：`SET @W = 400; SET @H = 920;`（参数里收 `W/H` 但强制覆盖），几何按这个画布排。
- 合并后就是普通 `WebAPI_*`，六关照旧；图位尺寸必须与新画布一致。
- 代价对比：拆分 = 图位缓存 / 绑定 / 六关各做一遍；合并 = 过程变大、改一处要重跑全图。

### 6.2 客户端合并（多个已有图位并成一块大屏）

实测于 2026-10-21（5 图位、1880×900、DPR1、无头 Chrome）。

- **纯 graphic 的图位**：整块塞进一个 `graphic` group —— `{type:"group", left, top, children:[...]}`，
  **元素内部坐标一个不改**。图位里「`id` + `onclick` → `__zr` → `attr()` 改元素」的切换逻辑原样可用；
  逐个平移元素坐标会让回调里的预生成坐标对不上，点一下就跳位。
- **带 `title` / `grid` / `xAxis` / `series` 的图位不能分组** ⇒ 只能逐个平移元素，
  并重新编号 `gridIndex` / `xAxisIndex` / `yAxisIndex`。
- 散点热区随 `grid` 平移时，坐标轴 `min` / `max` 不要动 ⇒ 热区与图形继续重合。
- `tooltip` 全局只有一个：优先留 `trigger:"item"` 那份；被丢掉的轴 tooltip 不再画 axisPointer 竖线。
- 性能实测：710 个显示节点 / 1 块 canvas；首次 `setOption` 75~84 ms，连续 5 次「清空 + 重画」中位 **13.6 ms**
  ⇒ 单画布刷新足以支撑 30s 级刷新周期。
- 验证：`dispatchAction({type:"showTip", seriesIndex, dataIndex})` 查热区对位；
  直接调 option 里元素的 `onclick({target: zrEl})` 查切换。
- ⚠️ 这条路径**违反「option 不带函数」的默认红线**，属实测例外：只用于合并组件的客户端切换，
  函数必须由存储过程字符串拼出、不用 v5 语法，且先在小画布单图位验证再放大屏。

---

## 7. 平面图 / 等轴测

> 以下全部由 TH 楼宇剖面（3D 看板）实测得出，是**一个完整实例**；
> 画别的平面图时照投影与可见性判据，坐标与厚度按图重算。

- 等轴测投影：`sx = (x - y) * cos30`、`sy = (x + y) * 0.5`；臂尖、楼板、电梯柱全部先算世界坐标，再投影。
- ⛔ **`RADIANS(整数)` 在本库返回 FLOOR**（`RADIANS(225)` = 3）⇒ 写 `225 * PI() / 180` 或 `RADIANS(225.0)`。
- **V 型图的左右会反过来**：等轴测下两臂向前张开，右臂尖是全图最左点、左臂尖是最右点。
  楼层名锚点要取对侧臂尖，偏移 `∓14` + `textAlign:"right" / "left"`。
- **侧壁可见性用屏幕空间判据**：投影后取右手法线 `ny = -ex / len`，`ny > 0`（朝下、朝观察者）才拉侧壁。
  用世界坐标法线判 ⇒ V 型正面 6 条长边全被跳过，画出来只有 3 条边有厚度。
- 楼板厚度（`@WALLH`）与房间盒高（`@BOXH`）分开：共用会把房间壁拉成一块立牌盖住楼板面。
- 电梯柱：柱心必须在 `(0,0)`，且**最后画**（放前面会被逐层楼板轮廓切成碎片）；柱底抬到负二层楼板顶面之上。
- 楼宇名标签最后画，加 `stroke:"#04101e", lineWidth:3`，否则落在楼板上看不清。
- 房间下钻：`@UserParameter {"DeviceName":"SMT-2"}` 换房间重调；点图切换做不到（不能带函数）。

---

## 8. 取串与本地验证

### 8.1 取回长 option 串（sqlcmd 单列 256 截断）

**只有一个分块协议**：`M|6 位序号|<200 字符 base64 块>#`。过程里加 `@Chunked BIT = 0` 参数，
传 1 时走分块返回；手写取串脚本也按同一形态输出。

```sql
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
CREATE TABLE #OPTBUF (v nvarchar(max));
GO
DELETE FROM #OPTBUF;
INSERT INTO #OPTBUF (v) EXEC dbo.<过程名> @UserParameter = N'{...}';
WITH X AS (
    SELECT CAST(N'' AS XML).value('xs:base64Binary(sql:column("t.b"))', 'VARCHAR(MAX)') AS s
    FROM (SELECT CAST(v AS VARBINARY(MAX)) AS b FROM #OPTBUF) t
),
N AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 200 FROM N WHERE n + 200 <= (SELECT LEN(s) FROM X)
)
SELECT 'M|' + RIGHT('000000' + CONVERT(VARCHAR(8), n), 6) + '|' + SUBSTRING((SELECT s FROM X), n, 200) + '#' AS s
FROM N ORDER BY n OPTION (MAXRECURSION 0);
DELETE FROM #OPTBUF;
DROP TABLE #OPTBUF;
GO
SELECT 'CAPDONE' AS s;
GO
```

- base64 转成纯 ASCII，避开中文 / 双字节被截断；`extract_option.py` 认这个形态，自动解 base64。
- **base64 解码后正文可能以空格开头**（缩进）⇒ 解析时 `|` 后不许吞空格，否则拼回短几个字符（`total_len` 对不上就是它）。
- 用测试库的 `<mcp>-execute` 执行；没有 `execute`（含正式库）就把脚本交人工执行并回传输出。
  `<mcp>-query` 禁 `EXEC`，也开不了 `QUOTED_IDENTIFIER`（含 `FOR XML ... .value()` 的脚本会报 Msg 1934）。
- 旧法 `INSERT #tmp EXEC` + `SUBSTRING` 分块也能取，但中文列容易断字，优先 base64。

### 8.2 本地验证（原型阶段 → 取串之后）

**原型阶段（第 5 步，写 SQL 之前）**：手工把 option 粘进 `assets/verify.html`，双击即开、自带 ECharts 4.9.0。
状态栏绿 + 每个尺寸都出 canvas 才算过。这一步不需要连库、不需要任何权限。

**取串之后（第 8 步验收）**，按成本递增再跑四道：

1. **静态**：`py scripts/check_proc.py static <sql>`（第 2 关，六关之一）。
2. **JS 语法**：把取回的串写成 `option.txt`，`node scripts/js_syntax_check.js option.txt` 输出 `OK`。
3. **v4 渲染**：`gen_render_page.py option.txt <任务目录>/_tmp/check.html` 生成验证页，
   引用本地 4.9.0 后跑无头 Chrome 截图：

   ```bash
   chrome --headless=new --disable-gpu --window-size=1500,1150 \
          --virtual-time-budget=5000 --screenshot=<绝对路径>.png file:///<绝对路径>/check.html
   ```

   ⚠️ 页面必须引**本地** `echarts.min.js`（CDN 在无头环境超时）；**不要用 v6 验 v4**。
4. **SSR 数节点**：`echarts.init(null, null, {renderer:"svg", ssr:true, width, height})` → `renderToSVGString()`，
   正则数 `<text>`，机械确认哪些文字被渲染（比截图肉眼看可靠）。

- 多实例共用同一 option 时用 `echarts.util.clone()`：
  ⛔ `JSON.parse(JSON.stringify(option))` 会丢 `renderItem` 函数；直接共享对象会被 `setOption` 就地改写、互相污染。
- 截图诊断：`--dump-dom` 抓 textContent 会被转义，诊断字符串改成短拼接；像素采样先确认真实偏移。

### 8.3 平台核对

- 部署成功 ≠ 图位生效：平台疑似缓存图位取到的 option ⇒ 重新保存 / 刷新图位配置触发重调。
- 错位排查用**标定 option**（纯几何参照物）：本地 4.9 渲染与平台截图几何对齐 ⇒ 平台无缩放、无剪切，问题在旧版 option。
- 反推版本：从平台返回的串里算几何特征量（臂角 / 臂长 / 对称中心），整数弧度的近似值 = 手写参数或旧版残留的指纹。

---

## 9. 版式配方速查（TH 温湿度看板实测值）

> 尺寸与画布是那一版实测的，**换看板要重排**。表里的价值在「这类版式该怎么拆」，
> 不在具体数字 —— 照抄尺寸而不重跑六关，等于没验。

| 场景 | 做法 | 画布 |
|---|---|---|
| 温度湿度趋势 | 双 Y 轴折线 + 隐轴 + 只留首尾 x 标签 + 左下短横线图例 | 320×159 / 420×430 |
| 预警清单 | 逐元素 graphic：标题带 + 行（圆点 / 名称 / 指标 / 值 / 时间）+ 分隔线 | 368×507 |
| 整体概览卡 | 5 行徽章：`rect` 底 + 文字图标 + 名称 + 数值 + 占比 | 400×300 / 340×300 |
| 楼宇 V 型剖面 | 等轴测多边形 + 侧壁 + 楼板厚度 + 电梯柱 + 楼层标签 | 1200×800 |
| 房间平面图 | 单层等轴测 + 房间标签交错 + 温 / 湿双卡 | 340×300 |
| 合并房间分析 | 平面图 + 趋势 + 卡片三段纵向排列 | 400×920 |

> 尺寸是实测值，不是建议值：图位改尺寸，过程必须同步重排并重跑六关。
