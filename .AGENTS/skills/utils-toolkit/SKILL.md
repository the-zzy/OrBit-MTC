---
name: utils-toolkit
description: >-
  通用工具函数技能索引，提供主键生成、消息推送、邮件发送等常用功能。
  供其他技能按需调用独立函数，节省token。
alwaysApply: false
agent_created: true
---

# Utils Toolkit - 通用工具函数索引

> **职责**：提供常用工具函数的索引和快速查找
> **调用方式**：由其他技能按需读取独立函数文件
> **版本**：v2.1
> **更新日期**：2026-09-14

---

## 工具函数清单

| 函数 | 功能 | 文件路径 | 调用场景 |
|------|------|----------|----------|
| `GeneratePK` | 生成主键 | [functions/generate-pk.md](functions/generate-pk.md) | 建表、存储过程 |
| `GeneratePKHeader` | 生成唯一 ObjectPKHeader | [functions/generate-pkheader.md](functions/generate-pkheader.md) | 元对象创建、SysObject 插入 |
| `SendWXMessage` | 企业微信推送（含3种方式） | [functions/send-wx-message.md](functions/send-wx-message.md) | 通知、报警、表格推送 |
| `SendEmail` | 发送邮件 | [functions/send-email.md](functions/send-email.md) | 报告、提醒 |
| `CallAPI` | 调用外部API | [functions/call-api.md](functions/call-api.md) | 数据同步 |
| `CheckSpecification` | 校验批号当前工作流节点 | [functions/check-specification.md](functions/check-specification.md) | 设备口 GET/SUBMIT、Orbit 事务扫码 |

---

## 使用方式

其他技能需要使用某个函数时，只读取对应的独立函数文件：

### 示例1：需要生成主键
```
读取文件：.AGENTS/skills/utils-toolkit/functions/generate-pk.md
获取主键生成的SQL代码
```

### 示例2：需要推送企业微信消息
```
读取文件：.AGENTS/skills/utils-toolkit/functions/send-wx-message.md
获取企业微信推送的SQL代码（包含3种推送方式）
- 函数1：API_SendWXGroupImage - 简单表格推送
- 函数2：API_SendWXGroupMsg - 文本消息+@用户
- 函数3：API_SendWXGroupImageWithMerge - 支持合并单元格的表格推送
```

### 示例3：需要发送邮件
```
读取文件：.AGENTS/skills/utils-toolkit/functions/send-email.md
获取邮件发送的SQL代码
```

### 示例4：需要调用外部API
```
读取文件：.AGENTS/skills/utils-toolkit/functions/call-api.md
获取API调用的SQL代码
```

### 示例5：需要校验批号当前节点
```
读取文件：.AGENTS/skills/utils-toolkit/functions/check-specification.md
调用 SysCheckSpecification；设备口消息前缀 MES:
```

---

## 优势

✅ **节省Token**：只读取需要的函数，不加载全部内容  
✅ **独立维护**：每个函数独立文件，便于更新和维护  
✅ **快速查找**：通过索引快速定位所需函数  
✅ **灵活组合**：可以同时读取多个函数文件

---

## 更新记录

| 版本 | 日期 | 内容 |
|------|------|------|
| v1.0 | 2026-05-20 | 初始版本，提供主键生成和消息推送 |
| v2.0 | 2026-06-05 | 重构为索引模式，拆分为独立函数文件 |
| v2.1 | 2026-09-14 | 增加 CheckSpecification 规程节点校验 |
