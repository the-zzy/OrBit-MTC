---
name: mes-db
description: >-
  按工厂、MES 或 WMS、测试或正式选择数据库，并且只调用这一套库的工具。用户提到基板、总装、通信、光元、MES、WMS、测试、正式、查表或存储过程时使用。
---

# 数据库

跟用户说明用中文。真正执行的 MCP 名和工具名用英文，方便下命令。一个 MCP 只连一个库，不能在参数里换库。

没写系统时也是 MES。只有仓储写成 WMS。

| 环境 | 库 | 能做的事 |
|---|---|---|
| 基板 MES 测试 | `192.168.0.21` / `JIBAN` | 查表、看存储过程、执行存储过程 |
| 基板 MES 正式 | `172.16.9.111` / `OrBitXIZC` | 查表、看存储过程、执行存储过程 |
| 总装 MES 测试 | `172.16.9.112` / `TV` | 查表、看存储过程、执行存储过程 |
| 总装 MES 正式 | `172.16.8.31` / `OrBitXIZC` | 查表、看存储过程 |
| 通信 MES 正式 | `192.168.0.246` / `OrBitXICH` | 查表 |
| 光元 MES 正式 | `172.16.8.244` / `OrBitXIZC` | 查表 |
| 光元 WMS 正式 | `172.16.9.244` / `OrBitXIZC` | 查表、看存储过程、执行存储过程 |

## 执行名

查表是 `query`，看存储过程是 `procedure`，执行存储过程是 `execute`。工具全名是 MCP 名加这个动作。表里没有的事，就没有这个工具。

| 环境 | MCP | 工具 |
|---|---|---|
| 基板 MES 测试 | `jiban-mes-test` | `jiban-mes-test-query` `jiban-mes-test-procedure` `jiban-mes-test-execute` |
| 基板 MES 正式 | `jiban-mes-prod` | `jiban-mes-prod-query` `jiban-mes-prod-procedure` `jiban-mes-prod-execute` |
| 总装 MES 测试 | `zongzhuang-mes-test` | `zongzhuang-mes-test-query` `zongzhuang-mes-test-procedure` `zongzhuang-mes-test-execute` |
| 总装 MES 正式 | `zongzhuang-mes-prod` | `zongzhuang-mes-prod-query` `zongzhuang-mes-prod-procedure` |
| 通信 MES 正式 | `tongxin-mes-prod` | `tongxin-mes-prod-query` |
| 光元 MES 正式 | `guangyuan-mes-prod` | `guangyuan-mes-prod-query` |
| 光元 WMS 正式 | `guangyuan-wms-prod` | `guangyuan-wms-prod-query` `guangyuan-wms-prod-procedure` `guangyuan-wms-prod-execute` |

## 调用

1. 先确定工厂、系统、测试还是正式，只选上面的一套。
2. 只调用这一套的英文工具名。
3. 要查另一套库，换 MCP，不在参数里改地址或库名。
4. 别用其他对话里的库。这个对话查哪套，就只调哪套。
5. 账号是 `AIAssistant`。凭据在 `secrets/{MCP名}.env`，不读进对话。
