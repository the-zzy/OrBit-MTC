/**
 * MRT JSON 校验工具
 * 验证生成的 .mrt 文件结构完整性
 *
 * Usage: node validate_mrt.js <mrt文件路径>
 */

const fs = require("fs");
const path = require("path");

function validate(mrtPath) {
  const errors = [];
  const warnings = [];

  // 收集组件类型
  let componentTypes = [];

  // 1. 文件存在且可解析
  if (!fs.existsSync(mrtPath)) {
    return { valid: false, errors: [`文件不存在: ${mrtPath}`], warnings: [] };
  }

  let json;
  try {
    const content = fs.readFileSync(mrtPath, "utf8").trimStart();
    if (content.startsWith("<?xml") || content.startsWith("<StiSerializer")) {
      return {
        valid: true,
        errors: [],
        warnings: [
          "检测到 Stimulsoft XML 模板（现网电脑打印）。JSON 校验已跳过；请用设计器打开或对齐 CHEQ 结构自检。",
        ],
      };
    }
    json = JSON.parse(content);
  } catch (e) {
    return { valid: false, errors: [`JSON 解析失败: ${e.message}`], warnings: [] };
  }

  // 2. 检查 Report 结构
  if (json.ReportVersion === undefined && json.ReportName === undefined) {
    errors.push("缺少 MRT 核心字段 (ReportVersion / ReportName)");
  }
  if (json.ReportVersion && json.ReportVersion !== "2023.1.2") {
    errors.push(`ReportVersion 必须是 2023.1.2，当前是 ${json.ReportVersion}。更高版本设计器打不开`);
  }

  const checkFonts = (node) => {
    if (!node || typeof node !== "object") return;
    if (typeof node.Font === "string") {
      const size = node.Font.split(";")[1];
      if (size === "") {
        errors.push(`字体缺少字号，设计器打不开: ${node.Name || ""} Font=${node.Font}`);
      }
    }
    Object.values(node).forEach(checkFonts);
  };
  checkFonts(json);

  // 3. 检查 Dictionary
  if (!json.Dictionary) {
    warnings.push("缺少 Dictionary 节点，MRT 可能无法加载数据");
  } else {
    const ds = json.Dictionary.DataSources;
    if (!ds || Object.keys(ds).length === 0) {
      warnings.push("Dictionary 中未定义数据源 (DataSources)");
    }
  }

  // 4. 检查 Pages
  if (!json.Pages) {
    errors.push("缺少 Pages 节点");
  } else {
    const page = json.Pages["0"];
    if (!page) {
      errors.push("Pages 中没有页面 (Pages['0'])");
    } else {
      if (!page.PageWidth || !page.PageHeight) {
        warnings.push("页面缺少尺寸 (PageWidth / PageHeight)");
      }

      const comps = page.Components;
      if (!comps || Object.keys(comps).length === 0) {
        errors.push("页面中没有组件 (Components)");
      } else {
        // 检查组件类型
        const types = new Set();
        Object.values(comps).forEach(c => {
          types.add(c.Ident);
          if (c.Components) {
            Object.values(c.Components).forEach(sc => types.add(sc.Ident));
          }
        });
        componentTypes = Array.from(types);
        if (types.has("StiTable")) {
          const tableComps = Object.values(comps).filter(c => c.Ident === "StiTable");
          tableComps.forEach((tc, i) => {
            if (!tc.DataSourceName) {
              warnings.push(`StiTable #${i} 缺少 DataSourceName`);
            }
          });
        }
        if (types.has("StiChart")) {
          const chartComps = [];
          Object.values(comps).forEach(c => {
            if (c.Ident === "StiChart") chartComps.push(c);
            if (c.Components) {
              Object.values(c.Components).forEach(sc => {
                if (sc.Ident === "StiChart") chartComps.push(sc);
              });
            }
          });
          chartComps.forEach((cc, i) => {
            if (!cc.Series || Object.keys(cc.Series).length === 0) {
              warnings.push(`StiChart #${i} 缺少数据系列 (Series)`);
            }
          });
        }
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
    summary: {
      hasDictionary: !!json.Dictionary,
      dataSourceCount: json.Dictionary?.DataSources ? Object.keys(json.Dictionary.DataSources).length : 0,
      pageCount: json.Pages ? Object.keys(json.Pages).length : 0,
      componentCount: json.Pages?.["0"]?.Components ? Object.keys(json.Pages["0"].Components).length : 0,
      componentTypes: componentTypes
    }
  };
}

function main() {
  const mrtFile = process.argv[2];
  if (!mrtFile) {
    console.error("Usage: node validate_mrt.js <mrt文件路径>");
    process.exit(1);
  }

  const result = validate(path.resolve(mrtFile));
  console.log(JSON.stringify(result, null, 2));

  if (!result.valid) {
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { validate };
