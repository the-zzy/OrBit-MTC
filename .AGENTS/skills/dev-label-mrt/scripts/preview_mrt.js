const fs = require("fs");
const path = require("path");
const { createRequire } = require("module");

function loadStimulsoft() {
  const candidates = [
    path.join(process.cwd(), "package.json"),
    __filename
  ];

  for (const base of candidates) {
    try {
      const req = createRequire(base);
      return req("stimulsoft-reports-js");
    } catch (error) {
      // Try the next resolution base.
    }
  }

  throw new Error(
    "Cannot resolve 'stimulsoft-reports-js'. Install it in the current workspace with: npm install stimulsoft-reports-js"
  );
}

const Stimulsoft = loadStimulsoft();

function renderReport(report) {
  return new Promise((resolve) => {
    report.renderAsync(() => resolve());
  });
}

function memoryStreamToBuffer(stream) {
  if (typeof stream.toArray === "function") {
    return Buffer.from(stream.toArray());
  }

  if (typeof stream.toByteArray === "function") {
    return Buffer.from(stream.toByteArray());
  }

  throw new Error("Unsupported MemoryStream API");
}

function registerSampleData(report, mrtFile) {
  const json = JSON.parse(fs.readFileSync(mrtFile, "utf8"));
  const columns = json.Dictionary?.DataSources?.["0"]?.Columns || {};
  const row = {};
  Object.values(columns).forEach((column) => {
    row[column.Name] = column.Name;
  });
  const dataSet = new Stimulsoft.System.Data.DataSet("LabelData");
  dataSet.readJson({ root: [row] });
  report.regData("LabelData", "LabelData", dataSet);
  if (report.dictionary && typeof report.dictionary.synchronize === "function") {
    report.dictionary.synchronize();
  }
}

async function exportHtmlPreview(mrtFile, htmlFile) {
  const report = new Stimulsoft.Report.StiReport();
  report.loadFile(mrtFile);
  registerSampleData(report, mrtFile);
  await renderReport(report);

  const settings = new Stimulsoft.Report.Export.StiHtmlExportSettings();
  settings.useEmbeddedImages = true;
  settings.addPageBreaks = false;
  settings.continuousPages = true;
  settings.zoom = 1;

  const service = new Stimulsoft.Report.Export.StiHtmlExportService();
  const stream = new Stimulsoft.System.IO.MemoryStream();
  service.exportTo(report, stream, settings);

  fs.writeFileSync(htmlFile, memoryStreamToBuffer(stream));
  return htmlFile;
}

async function main() {
  const mrtFile = process.argv[2]
    ? path.resolve(process.argv[2])
    : path.resolve(process.cwd(), "label-template.mrt");
  const htmlFile = process.argv[3]
    ? path.resolve(process.argv[3])
    : mrtFile.replace(/\.mrt$/i, "_preview.html");

  const previewPath = await exportHtmlPreview(mrtFile, htmlFile);
  console.log(previewPath);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = {
  exportHtmlPreview
};
