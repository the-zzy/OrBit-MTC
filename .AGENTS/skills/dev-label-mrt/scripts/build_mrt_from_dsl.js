/**
 * MRT DSL Builder
 * 将声明式 DSL 转换为 Stimulsoft Reports.JS 兼容的 .mrt JSON。
 * 支持 document（文档模板）和 report（报表模板）两种类型。
 * 不依赖 stimulsoft-reports-js 包。
 */
const fs = require("fs");
const path = require("path");

// ==================== 工具函数 ====================

function guid() {
  return "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx".replace(/x/g, () =>
    Math.floor(Math.random() * 16).toString(16)
  );
}

// ==================== MRT JSON 生成 ====================

function buildReportJson(reportName, pages, dictionary) {
  return {
    ReportVersion: "2023.1.2",
    ReportGuid: guid(),
    ReportName: reportName,
    ReportAlias: reportName,
    ReportUnit: "Centimeters",
    EngineVersion: "EngineV2",
    CalculationMode: "Interpretation",
    Dictionary: dictionary || {},
    Pages: { "0": pages }
  };
}

function buildPage(config) {
  return {
    Ident: "StiPage", Name: "Page1", Guid: guid(),
    Interaction: { Ident: "StiInteraction" },
    Border: ";;2;;;;;solid:Black", Brush: "solid:",
    Components: {},
    PageWidth: config.width || 21,
    PageHeight: config.height || 29.7,
    Orientation: config.orientation === "landscape" ? "Landscape" : "Portrait",
    Watermark: { TextBrush: "solid:50,0,0,0" },
    Margins: config.margins
      ? { Left: config.margins[0] || 0.5, Right: config.margins[1] || 0.5, Top: config.margins[2] || 0.5, Bottom: config.margins[3] || 0.5 }
      : { Left: 0.5, Right: 0.5, Top: 0.5, Bottom: 0.5 }
  };
}

function buildDictionary(dataSources, dbName, nameInSourceOverrides) {
  const db = dbName || "LabelData";
  const dbs = { "0": { Ident: "StiJsonDatabase", Name: db, Alias: db, PathData: `resource://${db}` } };
  const dsList = {};
  let dsIdx = 0;

  Object.entries(dataSources || {}).forEach(([name, columns]) => {
    const ns = (nameInSourceOverrides && nameInSourceOverrides[name]) || `${db}.${name}`;
    dsList[String(dsIdx++)] = {
      Ident: "StiDataTableSource", Name: name, Alias: name,
      Columns: Object.fromEntries((columns || []).map((col, ci) => [
        String(ci), { Name: col, NameInSource: col, Alias: col, Type: "System.String" }
      ])),
      NameInSource: ns
    };
  });

  return { Resources: {}, DataSources: dsList, Databases: dbs };
}

// ==================== 文档模板构建 ====================

function buildDocument(config) {
  const dsl = config.dsl || {};
  const page = buildPage(dsl.page || { width: 21, height: 14.8, orientation: "landscape" });
  const pageW = page.PageWidth;
  page.Margins = { Left: 0.5, Right: 0.5, Top: 0.5, Bottom: 0.5 };

  const hdrFields = dsl.header?.fields || [];
  const tblCols = dsl.table?.columns || [];
  const allFields = [
    ...hdrFields.map(f => f.field || f.name),
    ...tblCols.map(c => c.field)
  ];
  if (dsl.header?.barcode && !allFields.includes(dsl.header.barcode.field)) {
    allFields.push(dsl.header.barcode.field);
  }
  const dataSources = { root: allFields };
  const dictionary = config.dictionary || buildDictionary(dataSources);

  const components = {};
  let idx = 0;

  // --- 表头分组 ---
  const hdrComps = {};
  let hdrCIdx = 0;
  let curTop = 0.4;

  if (dsl.header?.title) {
    hdrComps[String(hdrCIdx++)] = {
      Ident: "StiText", Name: "TitleText", Guid: guid(),
      ClientRectangle: `${pageW / 2 - 3},${curTop},6,0.9`,
      Interaction: { Ident: "StiInteraction" },
      Text: { Value: dsl.header.title.text || "单据" },
      HorAlignment: "Center", VertAlignment: "Center",
      Font: `微软雅黑;${dsl.header.title.fontSize || 16};${dsl.header.title.bold ? "Bold;" : ";"}`,
      Border: ";;;;;;;solid:Black", Brush: "solid:", TextBrush: "solid:Black",
      Type: "Expression"
    };
    curTop += 1.0;
  }

  if (dsl.header?.barcode) {
    hdrComps[String(hdrCIdx++)] = {
      Ident: "StiBarCode", Name: "BarCode1", Guid: guid(),
      ClientRectangle: `${pageW - 5},${curTop - 0.6},4.5,1.2`,
      Interaction: { Ident: "StiInteraction" },
      Border: ";;;;;;;solid:Black", BackColor: "Transparent", AutoScale: true,
      BarCodeType: { Ident: "StiCode128AutoBarCodeType" },
      Code: { Value: `{root.${dsl.header.barcode.field}}` }
    };
  }

  let fieldRow = 0;
  const fieldStartY = curTop + 0.2;
  hdrFields.forEach((f, i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    const fx = col === 0 ? 0.5 : pageW / 2;
    const fy = fieldStartY + row * 0.65;
    const labelW = 1.8;
    const valW = pageW / 2 - labelW - 0.5;

    hdrComps[String(hdrCIdx++)] = {
      Ident: "StiText", Name: `HL_${f.name}`, Guid: guid(),
      ClientRectangle: `${fx},${fy},${labelW},0.5`,
      Interaction: { Ident: "StiInteraction" },
      Text: { Value: f.label || f.name },
      Font: "微软雅黑;9;;", Border: ";;;;;;;solid:Black",
      Brush: "solid:", TextBrush: "solid:Black",
      HorAlignment: "Right", VertAlignment: "Center",
      Type: "Expression"
    };
    hdrComps[String(hdrCIdx++)] = {
      Ident: "StiText", Name: `HV_${f.name}`, Guid: guid(),
      ClientRectangle: `${fx + labelW},${fy},${valW},0.5`,
      Interaction: { Ident: "StiInteraction" },
      Text: { Value: `{root.${f.field || f.name}}` },
      Font: "微软雅黑;9;;", Border: ";;;;;;;solid:Black",
      Brush: "solid:", TextBrush: "solid:Black",
      VertAlignment: "Center",
      Type: "DataColumn"
    };
    fieldRow = row;
  });

  const groupField = hdrFields.length > 0 ? (hdrFields[0].field || hdrFields[0].name) : "";

  components[idx++] = {
    Ident: "StiGroupHeaderBand", Name: "GroupHeaderBand1", Guid: guid(),
    CanGrow: true,
    ClientRectangle: `0,${0.2},${pageW},${fieldStartY + (fieldRow + 1) * 0.65 + 0.3}`,
    Interaction: { Ident: "StiBandInteraction" },
    Border: ";;;;;;;solid:Black", Brush: "solid:",
    Condition: { Value: `{root.${groupField}}` },
    Components: hdrComps
  };

  // --- 明细表格 ---
  const tblStartY = fieldStartY + (fieldRow + 1) * 0.65 + 0.6;
  const tabletComps = {};
  let tabletIdx = 0;

  let colX = 0;
  const colWidths = tblCols.map(c => c.width || 2);
  colWidths.forEach((cw, ci) => {
    tabletComps[String(tabletIdx++)] = {
      Ident: "StiTableCell", Name: `TH_${ci}`, Guid: guid(),
      ClientRectangle: `${colX},0,${cw},0.65`,
      Restrictions: "AllowMove, AllowSelect, AllowChange",
      Interaction: { Ident: "StiInteraction" },
      Text: { Value: tblCols[ci].header || tblCols[ci].field },
      HorAlignment: "Center", VertAlignment: "Center",
      Font: "微软雅黑;9;Bold;",
      Border: "All;;;;;;;solid:0,0,0",
      Brush: "solid:91,155,213", TextBrush: "solid:255,255,255",
      Type: "Expression", ID: ci
    };
    colX += cw;
  });

  colX = 0;
  colWidths.forEach((cw, ci) => {
    tabletComps[String(tabletIdx++)] = {
      Ident: "StiTableCell", Name: `TD_${ci}`, Guid: guid(),
      ClientRectangle: `${colX},0.65,${cw},0.55`,
      Restrictions: "AllowMove, AllowSelect, AllowChange",
      Interaction: { Ident: "StiInteraction" },
      Text: { Value: `{root.${tblCols[ci].field}}` },
      HorAlignment: tblCols[ci].align === "right" ? "Right" : tblCols[ci].align === "center" ? "Center" : "Left",
      VertAlignment: "Center",
      Font: "微软雅黑;9;;",
      Border: "All;;;;;;;solid:105,105,105",
      Brush: "solid:", TextBrush: "solid:Black",
      Type: "DataColumn", ID: ci + tblCols.length
    };
    colX += cw;
  });

  components[idx++] = {
    Ident: "StiTable", Name: "ItemsTable", Guid: guid(),
    CanGrow: true,
    ClientRectangle: `0,${tblStartY},${pageW},1.2`,
    Expressions: { "0": { Name: "CountData" } },
    Interaction: { Ident: "StiBandInteraction" },
    Border: "All;;;;;;;solid:Black", Brush: "solid:",
    Components: tabletComps,
    MinHeight: 0.2, DataSourceName: "root",
    RowCount: 2, ColumnCount: tblCols.length,
    HeaderRowsCount: 1, NumberID: tblCols.length + 1
  };

  if (dsl.footer?.fields) {
    const ftrY = tblStartY + 1.5;
    const ftrFields = dsl.footer.fields;
    const gap = pageW / (ftrFields.length + 1);
    const ftrComps = {};
    let ftrIdx = 0;
    ftrFields.forEach((f, fi) => {
      const fx = gap * fi + 0.5;
      ftrComps[String(ftrIdx++)] = {
        Ident: "StiText", Name: `FL_${fi}`, Guid: guid(),
        ClientRectangle: `${fx},${ftrY},${gap - 0.5},0.5`,
        Interaction: { Ident: "StiInteraction" },
        Text: { Value: f.label },
        Font: "微软雅黑;9;;",
        Border: ";;;;;;;solid:Black", Brush: "solid:", TextBrush: "solid:Black",
        Type: "Expression"
      };
      ftrComps[String(ftrIdx++)] = {
        Ident: "StiHorizontalLinePrimitive", Name: `FLine_${fi}`, Guid: guid(),
        ClientRectangle: `${fx},${ftrY + 0.55},${gap * 0.6},0.0254`,
        Interaction: { Ident: "StiInteraction" },
        StartCap: ";;;", EndCap: ";;;"
      };
    });

    components[idx++] = {
      Ident: "StiGroupFooterBand", Name: "GroupFooterBand1", Guid: guid(),
      ClientRectangle: `0,${ftrY - 0.1},${pageW},1.2`,
      Interaction: { Ident: "StiBandInteraction" },
      Border: ";;;;;;;solid:Black", Brush: "solid:",
      Components: ftrComps,
      PrintAtBottom: true, NewPageAfter: false
    };
  }

  page.Components = components;
  return buildReportJson(dsl.reportName || "Document", page, dictionary);
}

// ==================== 报表模板构建 ====================

function buildReport(config) {
  const dsl = config.dsl || {};
  const page = buildPage(dsl.page || { width: 21, height: 29.7, orientation: "portrait" });
  const pageW = page.PageWidth;
  page.Margins = { Left: 0.5, Right: 0.5, Top: 0.5, Bottom: 0.5 };

  // 收集所有数据源字段
  const allDS = {};
  function addDS(name, fields) {
    if (!allDS[name]) allDS[name] = [];
    fields.forEach(f => { if (!allDS[name].includes(f)) allDS[name].push(f); });
  }
  (dsl.tables || []).forEach(t => addDS(t.dataSource, t.columns.map(c => c.field)));
  (dsl.charts || []).forEach(c => addDS(c.dataSource, [c.argumentField, ...c.series.map(s => s.field)]));
  if (dsl.detailTable) addDS(dsl.detailTable.dataSource, dsl.detailTable.columns.map(c => c.field));

  const dictionary = config.dictionary || buildDictionary(allDS, "LabelData");

  const components = {};
  let idx = 0;
  let curTop = 0.4;

  // --- 报表标题 ---
  if (dsl.title) {
    components[idx++] = {
      Ident: "StiReportTitleBand", Name: "ReportTitleBand1", Guid: guid(),
      CanGrow: true,
      ClientRectangle: `0,${curTop},${pageW},0.8`,
      Interaction: { Ident: "StiInteraction" },
      Border: ";;;;;;;solid:Black", Brush: "solid:",
      Components: {
        "0": {
          Ident: "StiText", Name: "ReportTitle", Guid: guid(),
          ClientRectangle: `0,0,${pageW},0.8`,
          Interaction: { Ident: "StiInteraction" },
          Text: { Value: dsl.title.text || "报表" },
          HorAlignment: "Center", VertAlignment: "Center",
          Font: `微软雅黑;${dsl.title.fontSize || 16};;`,
          Border: ";;;;;;;solid:Black", Brush: "solid:",
          TextBrush: "solid:Black", Type: "Expression"
        }
      }
    };
    curTop += 1.0;
  }

  // --- 汇总表 ---
  (dsl.tables || []).forEach((tableDef) => {
    const dsName = tableDef.dataSource;
    const cols = tableDef.columns || [];
    let colX = 0;
    const hdrComps = {};
    cols.forEach((col, ci) => {
      hdrComps[String(ci)] = {
        Ident: "StiText", Name: `Hdr_${ci}`, Guid: guid(),
        ClientRectangle: `${colX},0,${col.width || 2.5},0.65`,
        Interaction: { Ident: "StiInteraction" },
        Text: { Value: col.header || col.field },
        HorAlignment: "Center", VertAlignment: "Center",
        Font: "微软雅黑;10;Bold;",
        Border: "All;;;;;;;solid:0,0,0",
        Brush: "solid:91,155,213", TextBrush: "solid:255,255,255",
        Type: "Expression"
      };
      colX += col.width || 2.5;
    });
    components[idx++] = {
      Ident: "StiHeaderBand", Name: "SummaryHeader", Guid: guid(),
      CanGrow: true,
      ClientRectangle: `0,${curTop},${pageW},0.65`,
      Interaction: { Ident: "StiBandInteraction" },
      Border: ";;;;;;;solid:Black", Brush: "solid:",
      Components: hdrComps
    };
    curTop += 0.65;
    colX = 0;
    const dataComps = {};
    cols.forEach((col, ci) => {
      dataComps[String(ci)] = {
        Ident: "StiTableCell", Name: `Val_${ci}`, Guid: guid(),
        ClientRectangle: `${colX},0,${col.width || 2.5},0.55`,
        Restrictions: "AllowMove, AllowSelect, AllowChange",
        Interaction: { Ident: "StiInteraction" },
        Text: { Value: `{${dsName}.${col.field}}` },
        HorAlignment: "Center", VertAlignment: "Center",
        Font: "微软雅黑;10;;",
        Border: "All;;;;;;;solid:105,105,105",
        Brush: "solid:", TextBrush: "solid:Black",
        Type: "DataColumn", ID: ci
      };
      colX += col.width || 2.5;
    });
    components[idx++] = {
      Ident: "StiTable", Name: "SummaryTable", Guid: guid(),
      CanGrow: true,
      ClientRectangle: `0,${curTop},${pageW},0.55`,
      Expressions: { "0": { Name: "CountData" } },
      Interaction: { Ident: "StiBandInteraction" },
      Border: ";;;;;;;solid:Black", Brush: "solid:",
      Components: dataComps,
      MinHeight: 0.2, DataSourceName: dsName,
      RowCount: 1, NumberID: cols.length
    };
    curTop += 0.8;
  });

  // --- 图表 ---
  (dsl.charts || []).forEach((chartDef, ci) => {
    const ch = chartDef.height || 5;
    const cw = chartDef.width || pageW;
    const dsName = chartDef.dataSource;
    curTop += 0.3;

    const seriesIdent = chartDef.type === "Column" ? "StiClusteredColumnSeries"
      : chartDef.type === "StackedColumn" ? "StiStackedColumnSeries"
      : chartDef.type === "Line" ? "StiLineSeries"
      : chartDef.type === "Pie" ? "StiPieSeries"
      : chartDef.type === "Area" ? "StiAreaSeries"
      : "StiStackedColumnSeries";
    const areaIdent = chartDef.type === "Column" ? "StiClusteredColumnArea"
      : chartDef.type === "StackedColumn" ? "StiStackedColumnArea"
      : chartDef.type === "Line" ? "StiLineArea"
      : chartDef.type === "Area" ? "StiAreaArea"
      : "StiStackedColumnArea";

    const series = {};
    let si = 0;
    (chartDef.series || []).forEach(s => {
      series[String(si++)] = {
        Ident: seriesIdent, AllowApplyStyle: false,
        ShowSeriesLabels: "FromSeries", ShowShadow: false,
        SeriesLabels: { Ident: "StiLeftAxisLabels", MarkerSize: { Width: 8, Height: 6 }, ValueTypeSeparator: "-", LabelColor: "50,58,69", BorderColor: "Transparent", Brush: "solid:119,255,255,255", Font: ";10;;" },
        ValueDataColumn: `${dsName}.${s.field}`,
        ArgumentDataColumn: `${dsName}.${chartDef.argumentField}`,
        Value: { Value: `{${dsName}.${s.field}}` },
        Argument: { Value: `{${dsName}.${chartDef.argumentField}}` },
        Title: { Value: s.text },
        BorderColor: "Transparent",
        Brush: s.color ? `solid:${s.color.replace("#", "")}` : "solid:0,176,80",
        BrushNegative: "solid:Firebrick", CornerRadius: "0, 0, 0, 0"
      };
    });

    components[idx++] = {
      Ident: "StiDataBand", Name: `ChartBand_${ci}`, Guid: guid(),
      CanGrow: true,
      ClientRectangle: `0,${curTop},${pageW},${ch}`,
      DataSourceName: dsName,
      Expressions: { "0": { Name: "CountData" } },
      Interaction: { Ident: "StiBandInteraction" },
      Border: ";;;;;;;solid:Black", Brush: "solid:",
      Components: {
        "0": {
          Ident: "StiChart", Name: `Chart${ci}`, Guid: guid(),
          ClientRectangle: `0,0,${cw},${ch}`,
          Interaction: { Ident: "StiInteraction" },
          Border: ";;;;;;;solid:Black", Brush: "solid:255,255,255", EditorType: "Simple",
          Series: series,
          Area: { Ident: areaIdent, BorderColor: "Transparent", Brush: "solid:255,255,255",
            InterlacingHor: { InterlacedBrush: "solid:10,155,155,155", Area: true },
            InterlacingVert: { InterlacedBrush: "solid:10,155,155,155", Area: true },
            GridLinesHor: { Color: "100,105,105,105", Area: true },
            GridLinesVert: { Color: "100,105,105,105", Area: true },
            YAxis: { Ident: "StiYLeftAxis", Labels: { Color: "140,140,140" }, LineColor: "140,140,140", Title: { Color: "140,140,140" } },
            XAxis: { Ident: "StiXBottomAxis", Labels: { Color: "140,140,140" }, LineColor: "140,140,140", Title: { Color: "140,140,140" } }
          },
          Table: { GridLineColor: "Transparent", Header: { Brush: "solid:White" }, DataCells: { TextColor: "140,140,140" } },
          SeriesLabels: { Ident: "StiCenterAxisLabels", MarkerSize: { Width: 8, Height: 6 }, ValueTypeSeparator: "-", LabelColor: "50,58,69", BorderColor: "Transparent", Brush: "solid:119,255,255,255", Font: ";10;;" },
          Legend: { Ident: "StiLegend", ShowShadow: false, BorderColor: "Transparent", Brush: "solid:255,255,255", TitleColor: "105,105,105", LabelsColor: "140,140,140", Direction: "LeftToRight", HorAlignment: "Right", MarkerSize: { Width: 10, Height: 10 } },
          Title: { Text: chartDef.title || "图表", Brush: "solid:140,140,140", Visible: true }
        }
      }
    };
    curTop += ch + 0.3;
  });

  // --- 明细表 ---
  if (dsl.detailTable) {
    const dt = dsl.detailTable;
    const dsName = dt.dataSource;
    const cols = dt.columns || [];
    curTop += 0.3;
    const headerH = 0.7;
    const rowH = 0.55;
    let colX = 0;
    const hdrComps = {};
    cols.forEach((col, ci) => {
      const cw = col.width || 2;
      hdrComps[String(ci)] = {
        Ident: "StiText", Name: `DH_${ci}`, Guid: guid(),
        ClientRectangle: `${colX},0,${cw},${headerH}`,
        Interaction: { Ident: "StiInteraction" },
        Text: { Value: col.header || col.field },
        HorAlignment: "Center", VertAlignment: "Center",
        Font: "微软雅黑;9;Bold;",
        Border: "All;;;;;;;solid:0,0,0",
        Brush: "solid:91,155,213", TextBrush: "solid:255,255,255",
        Type: "Expression"
      };
      colX += cw;
    });
    components[idx++] = {
      Ident: "StiHeaderBand", Name: "DetailHeader", Guid: guid(),
      CanGrow: true,
      ClientRectangle: `0,${curTop},${pageW},${headerH}`,
      Interaction: { Ident: "StiBandInteraction" },
      Border: ";;;;;;;solid:Black", Brush: "solid:",
      Components: hdrComps
    };
    curTop += headerH;
    colX = 0;
    const dataComps = {};
    cols.forEach((col, ci) => {
      const cw = col.width || 2;
      dataComps[String(ci)] = {
        Ident: "StiTableCell", Name: `DC_${ci}`, Guid: guid(),
        ClientRectangle: `${colX},0,${cw},${rowH}`,
        Restrictions: "AllowMove, AllowSelect, AllowChange",
        Interaction: { Ident: "StiInteraction" },
        Text: { Value: `{${dsName}.${col.field}}` },
        HorAlignment: col.align === "right" ? "Right" : col.align === "center" ? "Center" : "Left",
        VertAlignment: "Center",
        Font: "微软雅黑;9;;",
        Border: "All;;;;;;;solid:105,105,105",
        Brush: "solid:", TextBrush: "solid:Black",
        Type: "DataColumn", ID: ci
      };
      colX += cw;
    });
    components[idx++] = {
      Ident: "StiTable", Name: "DetailTable", Guid: guid(),
      CanGrow: true,
      ClientRectangle: `0,${curTop},${pageW},${rowH}`,
      Expressions: { "0": { Name: "CountData" } },
      Interaction: { Ident: "StiBandInteraction" },
      Border: "All;;;;;;;solid:0,0,0", Brush: "solid:",
      Components: dataComps,
      MinHeight: 0.2, DataSourceName: dsName,
      RowCount: 1, NumberID: cols.length
    };
  }

  page.Components = components;

  return buildReportJson(dsl.reportName || "Report", page, dictionary);
}

// ==================== DSL 解析与生成 ====================

function buildFromDsl(dsl, config = {}) {
  if (!dsl || !dsl.type) {
    throw new Error("DSL must have a 'type' field: 'document', 'report', or 'label'");
  }
  if (dsl.type === "label") {
    throw new Error("For label templates, use scripts/generate_mrt.js directly");
  }
  if (dsl.type === "document") {
    return buildDocument({ dsl, ...config });
  }
  if (dsl.type === "report") {
    return buildReport({ dsl, ...config });
  }
  throw new Error(`Unknown DSL type: ${dsl.type}. Supported: document, report`);
}

// ==================== 文件输出 ====================

function writeMrt(outputFile, mrtJson) {
  fs.writeFileSync(outputFile, JSON.stringify(mrtJson, null, 2), "utf8");
  return path.resolve(outputFile);
}

function main() {
  const dslFile = process.argv[2];
  const outputFile = process.argv[3]
    ? path.resolve(process.argv[3])
    : path.resolve(process.cwd(), "output.mrt");
  if (!dslFile) {
    console.error("Usage: node build_mrt_from_dsl.js <dsl.json> [output.mrt]");
    process.exit(1);
  }
  const dsl = JSON.parse(fs.readFileSync(dslFile, "utf8"));
  const mrtJson = buildFromDsl(dsl);
  writeMrt(outputFile, mrtJson);
  console.log(JSON.stringify({ mrt: path.resolve(outputFile) }, null, 2));
}

if (require.main === module) {
  main();
}

module.exports = {
  buildFromDsl, buildDocument, buildReport, writeMrt
};
