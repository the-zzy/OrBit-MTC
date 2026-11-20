const fs = require("fs");
const path = require("path");

function buildSamplePayload(reportJson) {
  const columns = reportJson.Dictionary?.DataSources?.["0"]?.Columns || {};
  const row = {};

  Object.values(columns).forEach((column) => {
    row[column.Name] = column.Name;
  });

  return { root: [row] };
}

function buildHtml(mrtJsonText, samplePayload, nodeModulesPath) {
  const nmPath = nodeModulesPath || '../node_modules/';
  const safeMrt = mrtJsonText.replace(/<\/script/gi, "<\\/script");
  const safePayload = JSON.stringify(samplePayload, null, 2).replace(/<\/script/gi, "<\\/script");

  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Embedded MRT Preview</title>
  <link rel="stylesheet" href="${nmPath}stimulsoft-reports-js/Css/stimulsoft.viewer.office2013.whiteblue.css">
  <style>
    body { margin: 0; font-family: "Segoe UI", "Microsoft YaHei", sans-serif; background: #eef3f7; color: #1f2933; }
    .shell { display: grid; grid-template-columns: 360px 1fr; gap: 16px; min-height: 100vh; padding: 16px; }
    .panel { background: rgba(255,255,255,0.92); border: 1px solid rgba(31,41,51,0.12); border-radius: 18px; box-shadow: 0 16px 40px rgba(31,41,51,0.1); }
    .sidebar { padding: 18px; display: flex; flex-direction: column; gap: 14px; }
    h1 { margin: 0; font-size: 24px; }
    p { margin: 0; color: #5c6b77; font-size: 14px; line-height: 1.6; }
    textarea { width: 100%; min-height: 420px; resize: vertical; border: 1px solid rgba(31,41,51,0.12); border-radius: 14px; padding: 14px; font: 13px/1.5 Consolas, monospace; background: #fbfcfd; }
    .toolbar { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
    button { appearance: none; border: 0; border-radius: 12px; padding: 12px; font-size: 14px; font-weight: 700; cursor: pointer; }
    .primary { background: #0f766e; color: #fff; }
    .accent { background: #c2410c; color: #fff; }
    .status { min-height: 40px; padding: 10px 12px; border-radius: 12px; background: rgba(15,118,110,0.08); color: #115e59; font-size: 13px; }
    .status.error { background: rgba(194,65,12,0.1); color: #9a3412; }
    .viewer-wrap { padding: 8px; }
    #viewerContent { min-height: calc(100vh - 32px); border-radius: 14px; overflow: hidden; background: #fff; }
    #viewerContent > div { min-height: calc(100vh - 48px); }
    @media (max-width: 1100px) { .shell { grid-template-columns: 1fr; } #viewerContent { min-height: 70vh; } }
  </style>
</head>
<body>
  <div class="shell">
    <section class="panel sidebar">
      <div>
        <h1>Embedded Preview</h1>
        <p>这个页面已内嵌 MRT 模板内容，不依赖读取本地 .mrt 文件。修改 root 数据后可以直接预览和打印。</p>
      </div>
      <div class="toolbar">
        <button id="previewBtn" class="primary" type="button">预览</button>
        <button id="printBtn" class="accent" type="button">打印</button>
      </div>
      <textarea id="jsonInput" spellcheck="false"></textarea>
      <div id="status" class="status">已加载 embedded 模板与 root 示例数据。</div>
    </section>
    <section class="panel viewer-wrap">
      <div id="viewerContent"></div>
    </section>
  </div>

  <script src="${nmPath}stimulsoft-reports-js/Scripts/stimulsoft.reports.js"></script>
  <script src="${nmPath}stimulsoft-reports-js/Scripts/stimulsoft.viewer.js"></script>
  <script id="templateJson" type="application/json">${safeMrt}</script>
  <script>
    const initialPayload = ${safePayload};
    const jsonInput = document.getElementById("jsonInput");
    const statusNode = document.getElementById("status");
    jsonInput.value = JSON.stringify(initialPayload, null, 2);

    const options = new Stimulsoft.Viewer.StiViewerOptions();
    options.appearance.scrollbarsMode = false;
    options.appearance.zoom = 100;
    options.toolbar.showSendEmailButton = false;
    options.toolbar.showOpenButton = false;
    options.toolbar.showAboutButton = false;
    options.toolbar.viewMode = Stimulsoft.Viewer.StiWebViewMode.SinglePage;
    options.toolbar.zoom = 100;

    const viewer = new Stimulsoft.Viewer.StiViewer(options, "StiViewer", false);
    viewer.renderHtml("viewerContent");

    function setStatus(message, isError) {
      statusNode.textContent = message;
      statusNode.className = isError ? "status error" : "status";
    }

    async function buildReport() {
      const payload = JSON.parse(jsonInput.value);
      if (!payload || !Array.isArray(payload.root) || payload.root.length === 0) {
        throw new Error("JSON 需要是 { root: [ {...} ] } 结构，且 root 至少有一条记录。");
      }

      const report = new Stimulsoft.Report.StiReport();
      report.load(document.getElementById("templateJson").textContent);

      const dataSet = new Stimulsoft.System.Data.DataSet("LabelData");
      dataSet.readJson(payload);
      report.regData("LabelData", "LabelData", dataSet);
      report.dictionary.synchronize();

      await new Promise((resolve) => report.renderAsync(resolve));
      return report;
    }

    async function previewReport() {
      try {
        setStatus("正在渲染预览，请稍候...", false);
        const report = await buildReport();
        viewer.report = report;
        setStatus("预览已更新。", false);
      } catch (error) {
        console.error(error);
        setStatus("预览失败: " + error.message, true);
      }
    }

    async function printReport() {
      try {
        setStatus("正在准备打印...", false);
        const report = await buildReport();
        viewer.report = report;
        report.print();
        setStatus("已触发打印。", false);
      } catch (error) {
        console.error(error);
        setStatus("打印失败: " + error.message, true);
      }
    }

    document.getElementById("previewBtn").addEventListener("click", previewReport);
    document.getElementById("printBtn").addEventListener("click", printReport);
    previewReport();
  </script>
</body>
</html>`;
}

function main() {
  const mrtFile = process.argv[2]
    ? path.resolve(process.argv[2])
    : path.resolve(process.cwd(), "label-template.mrt");
  const htmlFile = process.argv[3]
    ? path.resolve(process.argv[3])
    : mrtFile.replace(/\.mrt$/i, "_embedded_preview.html");

  const previewPath = exportEmbeddedPreview(mrtFile, htmlFile);
  console.log(previewPath);
}

function toPosixRelative(fromDir, targetDir) {
  let rel = path.relative(fromDir, targetDir).replace(/\\/g, "/");
  if (!rel.endsWith("/")) rel += "/";
  return rel;
}

function resolveNodeModulesPath(htmlFilePath) {
  const htmlDir = path.dirname(path.resolve(htmlFilePath));
  const skillModules = path.resolve(__dirname, "..", "node_modules");
  if (fs.existsSync(skillModules)) return toPosixRelative(htmlDir, skillModules);

  let dir = htmlDir;
  while (dir) {
    const candidate = path.join(dir, "node_modules");
    if (fs.existsSync(candidate)) return toPosixRelative(htmlDir, candidate);
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return "../node_modules/";
}

function exportEmbeddedPreview(mrtFile, htmlFile, samplePayload, mrtJsonText) {
  const effectiveMrtText = mrtJsonText || fs.readFileSync(mrtFile, "utf8");
  const effectivePayload =
    samplePayload || buildSamplePayload(JSON.parse(effectiveMrtText));
  const nmPath = resolveNodeModulesPath(htmlFile);
  const html = buildHtml(effectiveMrtText, effectivePayload, nmPath);
  fs.writeFileSync(htmlFile, html, "utf8");
  return htmlFile;
}

if (require.main === module) {
  main();
}

module.exports = {
  buildSamplePayload,
  exportEmbeddedPreview
};
