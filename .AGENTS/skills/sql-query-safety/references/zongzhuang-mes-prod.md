# 总装 MES 正式：大表清单

- 用途：AI 查库前的自我检查清单，不改数据库权限，不对他人生效
- 库：`OrBitXIZC` @ `172.16.8.31`（MCP `zongzhuang-mes-prod`）
- 快照日期：2026-11-20
- 口径：`sys.partitions` 行数估算；体积只算聚集索引/堆，不含非聚集索引（实际更大）
- 全库业务表：2063 张；本表收录 ≥100 万行或 ≥1 GB 的 120 张

## 刷新方法

```sql
SELECT t.name AS tbl, r.row_est, s.total_mb
FROM sys.tables t
CROSS APPLY (
  SELECT SUM(rows) AS row_est FROM sys.partitions p
  WHERE p.object_id = t.object_id AND p.index_id IN (0,1)
) r
CROSS APPLY (
  SELECT SUM(a.total_pages)*8/1024 AS total_mb
  FROM sys.partitions p
  JOIN sys.allocation_units a
       ON (a.type IN (1,3) AND a.container_id = p.hobt_id)
       OR (a.type = 2 AND a.container_id = p.partition_id)
  WHERE p.object_id = t.object_id AND p.index_id IN (0,1)
) s
WHERE t.is_ms_shipped = 0
  AND (r.row_est >= 1000000 OR s.total_mb >= 1024)
ORDER BY r.row_est DESC;
```

## P0 禁止直接查（≥1 亿行 或 ≥20 GB）

AI 不得通过 MCP 直接 SELECT。遇到需求先停下，向用户说明是 P0 表，索取主键/唯一索引等值条件并取得逐条授权。

| 表 | 行数 | 体积 |
|---|---:|---:|
| DataChainAssembly | 575,300,925 | 43.6 GB |
| DataChain | 444,680,394 | 80.9 GB |
| DataChainMove | 232,964,551 | 64.0 GB |
| Lot | 198,949,286 | 10.7 GB |
| TestResultItem | 141,978,794 | 32.0 GB |
| WriteDataTest | 129,506,558 | 26.4 GB |
| TestResultSub | 127,164,851 | 16.3 GB |
| MOItemLot | 116,114,402 | 4.2 GB |
| material_poolHistory | 115,847,035 | 52.3 GB |
| LotFirstMove | 105,657,477 | 2.7 GB |
| Interface_CallAPIServiceLog | 625,425 | **154.6 GB**（LOB） |
| T_Download_Log | 1,356,291 | **86.9 GB**（LOB） |
| xml_Test | 100,513 | **28.7 GB**（XML） |

## P1 高危（≥1000 万行 或 ≥5 GB）

| 表 | 行数 | 体积 |
|---|---:|---:|
| OrderSetItem | 87,627,054 | 6.4 GB |
| ShipBox | 84,764,278 | 4.9 GB |
| Slideway | 75,814,175 | 4.9 GB |
| OrigShipPallet | 74,029,696 | 15.5 GB |
| PredictInStorageItemLot | 70,253,582 | 3.9 GB |
| WW_FGInventory | 67,811,714 | 3.7 GB |
| ShipPallet | 65,011,618 | 2.7 GB |
| TVAssembleOffline | 63,302,120 | 9.8 GB |
| VendorDeliveryItemLot | 59,082,971 | 4.0 GB |
| LotTrack | 56,980,945 | 14.4 GB |
| WW_RMInventory | 52,183,156 | 3.9 GB |
| DataChainStart | 49,298,805 | 11.0 GB |
| DeliveryOrderItemlot | 38,077,966 | 10.4 GB |
| PackingListItem | 35,120,392 | 11.0 GB |
| FGUnderBondInfo | 33,358,956 | 4.8 GB |
| MOItem | 32,362,352 | 8.1 GB |
| OrderSetItemPrint | 31,733,956 | 0.7 GB |
| DataChainTEST | 25,129,437 | 7.6 GB |
| PickingListItemLot | 24,006,451 | 6.0 GB |
| HrDeptFromHR | 22,222,304 | 5.0 GB |
| ElementOrderItem | 19,627,956 | 7.6 GB |
| BinKey | 19,289,882 | 18.7 GB |
| StocktakeBase | 18,672,617 | 5.4 GB |
| ADCTestCheck | 17,643,254 | 2.5 GB |
| PersonInfoFromHR | 17,055,940 | 4.1 GB |
| RunMonitor | 17,009,301 | 1.4 GB |
| KDBoxItem | 16,992,296 | 3.1 GB |
| KDBoxInfo | 13,508,408 | 6.6 GB |
| DataChainAssemblyItem | 13,243,767 | 2.1 GB |
| SNBinding | 12,213,852 | 1.5 GB |
| DataChainUserComment | 11,893,276 | 0.7 GB |
| IQCOrder | 11,596,280 | 3.4 GB |
| ClockRecord | 11,262,537 | 0.7 GB |
| SysEventLog | 11,069,781 | 2.9 GB |
| WW_RMInvenotry_log | 10,521,980 | 2.6 GB |
| OrderSetItem_History | 6,982,929 | 5.0 GB |
| xml_tmp | 327,312 | 5.0 GB |

## P2 注意（≥100 万行 或 ≥1 GB）

| 表 | 行数 | 体积 |
|---|---:|---:|
| WW_RMCellUP | 9,848,276 | 0.6 GB |
| ELEMENTCustSN | 8,926,512 | 1.0 GB |
| HaierSNInfo | 8,839,674 | 3.2 GB |
| PickingListItem | 8,710,917 | 2.2 GB |
| PalletInfo | 7,393,203 | 1.1 GB |
| WorkflowDefectItem | 6,141,374 | 0.3 GB |
| VendorDeliveryItem | 6,019,395 | 2.8 GB |
| TVDeviceLot | 5,798,405 | 0.8 GB |
| WorkflowDefect | 5,628,023 | 1.4 GB |
| OQCOrderTVItem | 5,492,188 | 0.7 GB |
| VNContainerItem | 5,479,591 | 2.3 GB |
| SrmSyncPO | 5,437,842 | 0.2 GB |
| DCMoreBarcodeNGPCB | 5,399,494 | 0.6 GB |
| DCRepairRecord | 5,340,345 | 2.1 GB |
| POItem | 5,316,195 | 1.9 GB |
| DCDefectScan | 5,289,198 | 1.3 GB |
| TestResultMain | 5,186,468 | 0.5 GB |
| PredictInStorageItemPalletSN | 5,029,955 | 0.8 GB |
| TableModifyMonitor | 5,005,507 | 2.3 GB |
| CustomerInspectionItem | 4,760,396 | 0.7 GB |
| QCDefectLotItem | 4,448,425 | 0.5 GB |
| DOScanHistory | 4,359,602 | 0.9 GB |
| KDPalletInfo | 4,282,822 | 1.0 GB |
| VIZIOMACULPK | 3,819,264 | 0.7 GB |
| SysModifyHistory | 3,755,735 | 2.7 GB |
| XiaomiProductPlan | 3,629,767 | 1.4 GB |
| xmltest | 3,535,716 | 3.8 GB |
| EquipmentUpkeep | 3,265,797 | 0.5 GB |
| IQCCheckinLot | 3,164,594 | 1.5 GB |
| DCWeightCollect | 3,123,210 | 0.8 GB |
| MLotSplitRecord | 2,979,782 | 0.5 GB |
| VendorDelivery | 2,935,068 | 0.7 GB |
| CustomerSerialManageItem | 2,852,801 | 0.5 GB |
| InventoryCheckItem | 2,808,962 | 0.6 GB |
| StandardReworkRecord | 2,738,222 | 0.5 GB |
| BOMItem | 2,737,732 | 0.5 GB |
| PickingList | 2,662,642 | 0.6 GB |
| InterfaceProjectExeReocrd | 2,580,125 | 3.8 GB |
| DeliveryOrderItem | 2,525,487 | 0.5 GB |
| FoundryOnActivityResult | 2,443,135 | 0.5 GB |
| BoxInfo | 2,315,404 | 0.3 GB |
| Interface_MOInStorage | 2,159,459 | 1.0 GB |
| OverdueInspectionReportItemLot | 2,140,870 | 0.2 GB |
| LoadMaterialVerification | 2,135,921 | 0.3 GB |
| BarCodeConfigurationItem | 1,989,139 | 0.2 GB |
| amtc | 1,984,392 | 0.4 GB |
| MaterialHandoverRecord | 1,949,627 | 0.4 GB |
| OQCCheckItem | 1,945,966 | 0.3 GB |
| ElementDelLog | 1,777,172 | 0.3 GB |
| CommodityInspectionLog | 1,766,398 | 0.2 GB |
| TradeLog | 1,710,000 | 0.3 GB |
| MXGTVContainerItem | 1,575,244 | 0.7 GB |
| ESNTestResult | 1,499,363 | 2.5 GB |
| KDShipPallet | 1,498,965 | 0.4 GB |
| Vendordeliveryresitem | 1,437,010 | 0.4 GB |
| NoSrmpo | 1,432,269 | 0.2 GB |
| DeliveryOrder | 1,430,453 | 0.5 GB |
| PO | 1,425,588 | 0.3 GB |
| PretreatmentReworkItem | 1,367,166 | 0.5 GB |
| XMOEM_090 | 1,302,068 | 0.6 GB |
| KDOrderItem | 1,299,814 | 0.3 GB |
| CommodityInspectionTest | 1,262,219 | 0.3 GB |
| BrightLights | 1,240,826 | 0.1 GB |
| PredictInStorage | 1,180,809 | 0.3 GB |
| IQCCheckResult_QMS | 1,151,334 | 0.2 GB |
| SRMVendorDelivery | 1,096,001 | 0.1 GB |
| DataChainWIP | 1,063,079 | 0.1 GB |
| MTCWorkOrderOutputSN | 1,040,607 | 0.3 GB |
| BinKeyForGoogle | 324,083 | 2.6 GB |
| SQLGitVersion | 46,341 | 1.6 GB |

## 已知索引备忘

| 表 | 索引 | 说明 |
|---|---|---|
| Lot | `PK_Lot` 聚集（`LotId`）、`IX_Lot_LotSN` 唯一非聚集（`LotSN`）、`IX_Lot_CreateDate`、`IX_Lot_OrderName_LotId_LotSn`（含 `LotId`、`LotSN`） | `LotSN` 前缀可 seek，后导通配符不可 |
| MO | 约 86.6 万行 | `MOId` 关联成本低 |
