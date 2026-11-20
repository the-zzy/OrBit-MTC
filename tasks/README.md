# 任务交付物

按需求收集交付文件，和功能库分开。

## 结构

```text
tasks/{MCP名}/{类别}/{功能英文名}/
```

- `{MCP名}`：`jiban-mes-prod`、`jiban-mes-test`、`zongzhuang-mes-prod`、`zongzhuang-mes-test`、`tongxin-mes-prod`、`guangyuan-mes-prod`、`guangyuan-wms-prod`、`shuma-mes-prod`
- `{类别}`：`dev`、`flow`、`plugin`、`ops`
- `{功能英文名}`：英文，建表时没有另给名字就用表名

## 和 library 的分工

- `tasks/`：任务交付物。部署脚本、回滚脚本、测试数据、BP/WG、接口文档、变更说明都放这里。
- `library/{plant}/{command}/`：工作台的功能元数据缓存。`object.json` 由工作台拉取维护，SQL 只放被 `object.json` 引用的过程。

## 当前任务

| 任务 | 目录 |
|---|---|
| PDOT 移动盘点 PDA 网关 | `tasks/shuma-mes-prod/dev/pdot-pda-api/` |
| CKD 装箱（越南）合盘校验 | `tasks/jiban-mes-prod/dev/pda-ckd-packing-yn/` |
| PDA_BindBarCodeDoMethod 一对多绑定修复 | `tasks/jiban-mes-prod/dev/pda-bind-barcode-domethod/` |
