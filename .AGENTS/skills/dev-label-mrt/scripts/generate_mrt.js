const fs = require("fs");
const path = require("path");
const { createRequire } = require("module");

// ---------- Stimulsoft 加载 ----------
function loadStimulsoft() {
  const candidates = [path.join(process.cwd(), "package.json"), __filename];
  for (const base of candidates) {
    try {
      const req = createRequire(base);
      return req("stimulsoft-reports-js");
    } catch (_) {}
  }
  throw new Error(
    "Cannot resolve 'stimulsoft-reports-js'. Install it with: npm install stimulsoft-reports-js"
  );
}

let Stimulsoft;
function getStimulsoft() {
  if (!Stimulsoft) Stimulsoft = loadStimulsoft();
  return Stimulsoft;
}

// ---------- 组件辅助函数 ----------
function addText(page, opts) {
  const Sti = getStimulsoft();
  const text = new Sti.Report.Components.StiText();
  text.name = opts.name;
  text.left = opts.left;
  text.top = opts.top;
  text.width = opts.width;
  text.height = opts.height;
  text.text = opts.text;
  if (opts.horAlignment) text.horAlignment = opts.horAlignment;
  if (opts.vertAlignment) text.vertAlignment = opts.vertAlignment;
  if (opts.font) text.font = opts.font;
  if (opts.type) text.type = opts.type;
  page.components.add(text);
  return text;
}

function addBarcode(page, opts) {
  const Sti = getStimulsoft();
  const barcode = new Sti.Report.BarCodes.StiBarCode();
  barcode.name = opts.name;
  barcode.left = opts.left;
  barcode.top = opts.top;
  barcode.width = opts.width;
  barcode.height = opts.height;
  barcode.barCodeType =
    opts.barCodeType || new Sti.Report.BarCodes.StiEAN128aBarCodeType();
  barcode.code = opts.code;
  if (typeof opts.showLabelText === "boolean") barcode.showLabelText = opts.showLabelText;
  if (opts.font) barcode.font = opts.font;
  page.components.add(barcode);
  return barcode;
}

function addImage(page, opts) {
  const Sti = getStimulsoft();
  const image = new Sti.Report.Components.StiImage();
  image.name = opts.name;
  image.left = opts.left;
  image.top = opts.top;
  image.width = opts.width;
  image.height = opts.height;
  image.imageURL = opts.imageURL;
  page.components.add(image);
  return image;
}

// ---------- 数据源辅助 ----------
function createRootDictionary(config = {}) {
  const defaults = {
    LogoUrl: "", CompanyName: "Hytera",
    CompanySubName: "Communications Corporation Limited",
    CompanyAddress: "Hytera Tower, Hi-Tech Industrial Park North, Shenzhen, China",
    BoxNo: "P0BES0227", Model: "SM09D1", Quantity: "10 PCS",
    InvoiceNo: "", OrderNo: "", Destination: "Hong Kong",
    WorkOrderNo: "MO: HW-20250218034323", CustomerPoNo: "30030000000037",
    ItemTitle: "BATCH NO. / INNER BOX NO."
  };
  for (let i = 1; i <= 10; i++) defaults[`ItemCode${i}`] = `ITEM${String(i).padStart(3, "0")}`;
  return { ...defaults, ...(config.rootSample || {}) };
}

function applyRootDataSource(reportJson, sampleRow) {
  const fieldNames = Object.keys(sampleRow);
  const page = reportJson.Pages?.["0"];
  const originalComponents = page?.Components || {};

  reportJson.Dictionary = reportJson.Dictionary || {};
  delete reportJson.Dictionary.Variables;
  delete reportJson.Dictionary.Resources;

  reportJson.Dictionary.DataSources = {
    "0": {
      Ident: "StiDataTableSource", Name: "root", Alias: "root",
      Columns: Object.fromEntries(fieldNames.map((name, i) => [
        String(i), { Name: name, NameInSource: name, Alias: name, Type: "System.String" }
      ])),
      NameInSource: "LabelData.root"
    }
  };
  reportJson.Dictionary.Databases = {
    "0": { Ident: "StiJsonDatabase", Name: "LabelData", Alias: "LabelData" }
  };

  const rewrite = (v) => {
    let r = v;
    fieldNames.forEach(n => { r = r.replaceAll(`{${n}}`, `{root.${n}}`); });
    return r;
  };

  Object.values(originalComponents).forEach(c => {
    if (c.Ident === "StiText" && c.Text?.Value) {
      c.Text.Value = rewrite(c.Text.Value);
      if (c.Text.Value.includes("{root.")) c.Type = "Expression";
    }
    if (c.Ident === "StiBarCode" && c.Code?.Value) {
      c.Code.Value = rewrite(c.Code.Value);
      c.BackColor = "Transparent";
      c.BarCodeType = { Ident: "StiEAN128aBarCodeType" };
    }
    if (c.Ident === "StiImage" && c.ImageURL?.Value) {
      c.ImageURL.Value = rewrite(c.ImageURL.Value);
    }
  });

  page.Components = {
    "0": {
      Ident: "StiDataBand", Name: "DataBand1",
      ClientRectangle: `0,0,${page.PageWidth || page.Width || 10.5},${page.PageHeight || page.Height || 7.5}`,
      Interaction: { Ident: "StiBandInteraction" },
      Border: ";;;;;;;solid:Black", Brush: "solid:",
      Components: originalComponents, DataSourceName: "root"
    }
  };
}

// ==================== 标签模板（Carton Label） ====================
function buildCartonLabel(config = {}) {
  const Sti = getStimulsoft();
  const report = Sti.Report.StiReport.createNewReport();
  report.reportName = config.reportName || "Carton Box Label";
  report.reportAlias = config.reportAlias || report.reportName;
  report.reportUnit = Sti.Report.StiReportUnitType.Centimeters;

  const page = report.pages.getByIndex(0);
  page.name = config.pageName || "LabelPage";
  page.pageWidth = config.pageWidth || 10.5;
  page.pageHeight = config.pageHeight || 7.5;
  page.margins = new Sti.Report.Components.StiMargins(0, 0, 0, 0);

  const fontFamily = config.fontFamily || "Microsoft YaHei";
  const font = (size, style = Sti.System.Drawing.FontStyle.Regular) =>
    new Sti.System.Drawing.Font(fontFamily, size, style);

  addImage(page, { name: "LogoImage", left: 0.35, top: 0.3, width: 3.0, height: 1.0, imageURL: "{LogoUrl}" });
  addText(page, { name: "CompanyNameText", left: 0.35, top: 0.28, width: 3.2, height: 0.95, text: "{CompanyName}", font: font(20, Sti.System.Drawing.FontStyle.Bold) });

  const leftRows = [
    ["MODEL:", "{Model}"], ["QUANTITY:", "{Quantity}"], ["INVOICE NO.:", "{InvoiceNo}"],
    ["ORDER NO.:", "{OrderNo}"], ["DESTINATION:", "{Destination}"],
    ["WORK ORDER:", "{WorkOrderNo}"], ["BOX / REF NO.:", "{CustomerPoNo}"]
  ];
  leftRows.forEach(([label, value], i) => {
    const top = 1.6 + i * 0.52;
    addText(page, { name: `Label${i + 1}`, left: 0.35, top, width: 1.55, height: 0.34, text: label, font: font(8, Sti.System.Drawing.FontStyle.Bold) });
    addText(page, { name: `Value${i + 1}`, left: 1.95, top: top - 0.02, width: 1.55, height: 0.38, text: value, font: font(i < 2 ? 10 : 8) });
  });

  addBarcode(page, { name: "BoxNoBarcode", left: 4.15, top: 0.35, width: 5.3, height: 0.82, code: "{BoxNo}", showLabelText: true, font: font(8) });
  addText(page, { name: "BoxNoText", left: 4.15, top: 1.18, width: 5.3, height: 0.34, text: "{BoxNo}", horAlignment: Sti.Base.Drawing.StiTextHorAlignment.Center, font: font(9) });
  addText(page, { name: "ItemTitleText", left: 4.15, top: 1.55, width: 5.3, height: 0.28, text: "{ItemTitle}", horAlignment: Sti.Base.Drawing.StiTextHorAlignment.Center, font: font(6, Sti.System.Drawing.FontStyle.Bold) });

  const colXs = [4.25, 7.0];
  for (let i = 1; i <= 10; i++) {
    const row = Math.floor((i - 1) / 2);
    const col = (i - 1) % 2;
    const x = colXs[col];
    const y = 1.95 + row * 0.85;
    const field = `{ItemCode${i}}`;
    addBarcode(page, { name: `ItemBarcode${i}`, left: x, top: y, width: 2.45, height: 0.52, code: field, showLabelText: false, font: font(6) });
    addText(page, { name: `ItemText${i}`, left: x, top: y + 0.54, width: 2.45, height: 0.22, text: field, horAlignment: Sti.Base.Drawing.StiTextHorAlignment.Center, font: font(7) });
  }

  addText(page, { name: "FooterCompany", left: 0.45, top: 6.25, width: 9.3, height: 0.45, text: "{CompanySubName}", horAlignment: Sti.Base.Drawing.StiTextHorAlignment.Center, font: font(9, Sti.System.Drawing.FontStyle.Bold) });
  addText(page, { name: "FooterAddress", left: 0.45, top: 6.72, width: 9.3, height: 0.34, text: "{CompanyAddress}", horAlignment: Sti.Base.Drawing.StiTextHorAlignment.Center, font: font(6) });

  return report;
}

// ==================== 输出与导出 ====================
function fixFontString(font) {
  const parts = String(font).split(";");
  if (parts.length >= 2 && parts[1] === "") parts[1] = "8";
  return parts.join(";");
}

function normalizeReportJson(reportJson, config = {}) {
  reportJson.ReportVersion = "2023.1.2";
  delete reportJson.ScriptLanguage;
  delete reportJson.UsePlatformDependentScript;

  const page = reportJson.Pages && reportJson.Pages["0"];
  if (page) {
    const width = config.pageWidth || 10.5;
    const height = config.pageHeight || 7.5;
    page.PageWidth = width;
    page.PageHeight = height;
    const band = page.Components && page.Components["0"];
    if (band && band.Ident === "StiDataBand") {
      band.ClientRectangle = `0,0,${width},${height}`;
    }
  }

  const walk = (node) => {
    if (!node || typeof node !== "object") return;
    if (typeof node.Font === "string") node.Font = fixFontString(node.Font);
    Object.values(node).forEach(walk);
  };
  walk(reportJson);
}

function writeReport(report, outputFile, config = {}) {
  const reportJson = JSON.parse(report.saveToJsonString());
  const sampleRow = createRootDictionary(config);
  applyRootDataSource(reportJson, sampleRow);
  normalizeReportJson(reportJson, config);
  fs.writeFileSync(outputFile, JSON.stringify(reportJson, null, 2), "utf8");
}

async function generateLabelArtifacts(outputFile, config = {}) {
  const resolved = path.resolve(outputFile);
  const previewFile = resolved.replace(/\.mrt$/i, "_preview.html");
  const embeddedFile = resolved.replace(/\.mrt$/i, "_embedded_preview.html");
  writeReport(buildCartonLabel(config), resolved, config);

  const { exportHtmlPreview } = require("./preview_mrt");
  const { exportEmbeddedPreview } = require("./preview_mrt_embedded");
  await exportHtmlPreview(resolved, previewFile);
  exportEmbeddedPreview(resolved, embeddedFile);

  return { mrt: resolved, preview: previewFile, embeddedPreview: embeddedFile };
}

if (require.main === module) {
  const output = process.argv[2]
    ? path.resolve(process.argv[2])
    : path.resolve(process.cwd(), "label-template.mrt");
  generateLabelArtifacts(output)
    .then(a => { console.log(JSON.stringify(a, null, 2)); })
    .catch(e => { console.error(e); process.exit(1); });
}

module.exports = {
  buildCartonLabel, createRootDictionary, writeReport, generateLabelArtifacts
};
