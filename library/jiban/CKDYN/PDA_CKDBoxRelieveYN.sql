-- =============================================
-- Author:		<LZH>
-- Create date: <2024.08.28>
-- Description:	CKD 箱号解绑(越南)
-- =============================================
CREATE PROCEDURE  [dbo].[PDA_CKDBoxRelieveYN]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKid char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='',      --插件参数

--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
@BoxSN nvarchar(50)='',
@ScanSN nvarchar(50) = ''
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	DECLARE @ScanQty DECIMAL(18, 4);
	DECLARE @KDBoxInfoId CHAR(12);
	DECLARE @ProductId CHAR(12);
	DECLARE @TotalNetWeight DECIMAL(18, 4);   --净重 KG
	DECLARE @LotSN VARCHAR(50);
	DECLARE @Qty DECIMAL(18, 4);
	DECLARE @KDMOItemId CHAR(12);
	
	DECLARE @LotSNList TABLE
    (
      Seq INT IDENTITY,
      LotSN VARCHAR(50),
      ProductId CHAR(12),
      LotQty DECIMAL(18, 4)
    );
   
    DECLARE @KDMOItemRelieveInfo TABLE 
    (
    	KDMOItemId CHAR(12),
    	LotQty DECIMAL(18, 4)
    )

	--扫描箱号
	IF EXISTS (
		SELECT 1 FROM ShipBox where BoxSN = @ScanSN AND IsCancel = 0
	)
	BEGIN
		IF EXISTS (
			SELECT 1 FROM ShipPallet WHERE BoxSN = @ScanSN AND IsCancel = 0
		)
		BEGIN
			SELECT '' AS ScanSN;
			SET @I_ExceptionFieldName = 'ScanSN';
			SET @I_ReturnMessage='ServerMessage: 扫描的箱号已经装栈，请先解绑栈板!' + @ScanSN;
			RETURN -1;
		END
		
		SELECT @ScanQty = SUM(b.LotQty)
		FROM dbo.ShipBox a
		INNER JOIN dbo.WW_RMInventory b ON a.LotSN = b.LotSN
		WHERE a.BoxSN = @ScanSN AND a.IsCancel = 0;
		
		--返回界面数据
		SELECT '' AS ScanSN, @ScanSN as BoxSN, @ScanQty AS ScanQty;
		SET @I_ExceptionFieldName = 'ScanSN';
		SET @I_ReturnMessage='ServerMessage:获取箱号成功,请扫描批号解绑!';
		RETURN 0;
	END	
	
	IF ISNULL(@BoxSN, '') = ''
	BEGIN
		SELECT '' AS ScanSN;
		SET @I_ExceptionFieldName = 'ScanSN';
		SET @I_ReturnMessage='ServerMessage:箱号无效，请先扫描有效的箱号!';
		RETURN -1;
	END 
	
	IF EXISTS (
		SELECT 1 FROM ShipPallet WHERE BoxSN = @BoxSN AND IsCancel = 0
	)
	BEGIN
		SELECT '' AS ScanSN;
		SET @I_ExceptionFieldName = 'ScanSN';
		SET @I_ReturnMessage='ServerMessage: 扫描的箱号已经装栈，请先解绑栈板!' + @ScanSN;
		RETURN -1;
	END
	
	--扫描数据
	IF LEFT(@ScanSN, 1) = 'R'
	BEGIN
		INSERT INTO @LotSNList(LotSN, ProductId, LotQty)
		SELECT LotSN, ProductId, LotQty FROM dbo.WW_RMInventory WHERE LotSN = @Scansn AND IsCancel = 0
	END
	
	IF LEFT(@ScanSN, 1) = 'B'
	BEGIN
		INSERT INTO @LotSNList(LotSN, ProductId, LotQty)
		SELECT LotSN, ProductId, LotQty FROM dbo.WW_RMInventory WHERE BoxSN = @Scansn AND IsCancel = 0
	END	

	IF NOT EXISTS (
		SELECT 1 FROM @LotSNList
	)
	BEGIN
		SELECT  '' AS ScanSN;		
        SET @I_ReturnMessage = 'ServerMessage: 扫描批号无效,请检查!' + @ScanSN;
        SET @I_ExceptionFieldName = 'ScanSN';
        RETURN -1;
	END
	
	SELECT @ProductId = ProductId FROM @LotSNList;
	SELECT @KDBoxInfoId = KDBoxInfoId FROM KDBoxInfo WHERE BoxSN = @BoxSN AND IsCancel = 0;
	
	IF EXISTS (
		SELECT 1
		FROM @LotSNList a
		LEFT JOIN ShipBox b WITH (NOLOCK) ON a.LotSN = b.LotSN AND b.IsCancel = 0
		WHERE b.LotSN IS NULL
	)
	BEGIN
		SELECT  '' AS ScanSN;		
        SET @I_ReturnMessage = 'ServerMessage: 扫描的批号没有装箱,请检查!' + @ScanSN;
        SET @I_ExceptionFieldName = 'ScanSN';
        RETURN -1;
	END
	
	IF EXISTS (
		SELECT 1
		FROM @LotSNList a
		LEFT JOIN ShipBox b WITH (NOLOCK) ON a.LotSN = b.LotSN AND b.IsCancel = 0
		WHERE ISNULL(b.BoxSN, '') <> @BoxSN
	)
	BEGIN
		SELECT  '' AS ScanSN;		
        SET @I_ReturnMessage = 'ServerMessage: 扫描的批号不属于该箱,请检查!' + @ScanSN;
   SET @I_ExceptionFieldName = 'ScanSN';
        RETURN -1;
	END
	
	IF EXISTS (
		SELECT 1
		FROM @LotSNList a
		LEFT JOIN KDMOItemLot b WITH (NOLOCK) ON a.LotSN = b.LotSN AND b.IsCancel = 0
		WHERE b.LotSN IS NULL 
	)
	BEGIN
		SELECT  '' AS ScanSN;		
        SET @I_ReturnMessage = 'ServerMessage: 扫描的批号装箱数据有误,请联系IT!' + @ScanSN;
        SET @I_ExceptionFieldName = 'ScanSN';
        RETURN -1;
	END
	
	--开始解绑
	UPDATE b
	SET b.LotSN = b.LotSN + '_BK', b.IsCancel = 1
	FROM @LotSNList a 
	INNER JOIN ShipBox b ON a.LotSN = b.LotSN
	WHERE b.BoxSN = @BoxSN 
	AND b.IsCancel = 0;

	--如果装箱明细中组件被全部解绑，则删除组件
	IF NOT EXISTS (
		SELECT 1 
		FROM ShipBox
		WHERE BoxSN = @BoxSN
		AND ProductId = @ProductId
		AND IsCancel = 0
	)
	BEGIN
		UPDATE KDBoxItem SET IsCancel = 1 WHERE KDBoxInfoId = @KDBoxInfoId AND ProductId = @ProductId; 
	END
	
	--剩余装箱数量
	SELECT @ScanQty = ISNULL(SUM(b.LotQty), 0)
	FROM ShipBox a WITH (NOLOCK)
	INNER JOIN WW_RMInventory b WITH (NOLOCK) ON a.LotSN = b.LotSN
	WHERE a.BoxSN = @BoxSN
	AND a.IsCancel = 0
	
	--净重计算
	SELECT @TotalNetWeight = SUM(b.LotQty * ISNULL(c.UnitNetWeight, 0)) / 1000.00
	FROM ShipBox a WITH (NOLOCK)
	INNER JOIN WW_RMInventory b WITH (NOLOCK) ON a.LotSN = b.LotSN
	LEFT JOIN Vendor_Product c WITH (NOLOCK) ON b.VendorId = c.VendorId AND b.ProductId = c.ProductId
	WHERE a.BoxSN = @BoxSN
	AND a.IsCancel = 0
	GROUP BY a.BoxSN;

	UPDATE KDBoxInfo SET NetWeight = CAST(@TotalNetWeight AS DECIMAL(18, 2)) WHERE KDBoxInfoId = @KDBoxInfoId;
 	UPDATE KDBoxItem SET RealQty = @ScanQty WHERE KDBoxInfoId = @KDBoxInfoId AND ProductId = @ProductId;
	

	--分配数据回滚 KDMOItemLot KDMOItem
	DECLARE LotCursor CURSOR FOR
	SELECT LotSN FROM @LotSNList
	OPEN LotCursor;	
	FETCH NEXT FROM LotCursor INTO @LotSN;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @KDMOItemId = '';
		SET @Qty = 0;
	
		DELETE @KDMOItemRelieveInfo;
		
		INSERT INTO @KDMOItemRelieveInfo(KDMOItemId, LotQty)
		SELECT KDMOItemId, LotQty 
		FROM KDMOItemLot 
		WHERE LotSN = @LotSN AND IsCancel = 0;
	
		UPDATE a
		SET a.IssuedQty = a.IssuedQty - b.LotQty
		FROM KDMOItem a
		INNER JOIN @KDMOItemRelieveInfo b ON a.KDMOItemId = b.KDMOItemId;
	
		UPDATE KDMOItemLot SET LotSN = LotSN + '_BK', IsCancel = 1 WHERE LotSN = @LotSN AND IsCancel = 0;

	    FETCH NEXT FROM LotCursor INTO @LotSN;
	END

	CLOSE LotCursor;
	DEALLOCATE LotCursor;


	SELECT '' as ScanSN, @ScanQty AS ScanQty;
	SET @I_ReturnMessage = 'ServerMessage: 解绑成功!';

	RETURN 0

END
