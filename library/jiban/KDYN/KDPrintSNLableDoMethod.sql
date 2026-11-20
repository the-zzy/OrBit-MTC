/*

EXEC dbo.KDPrintSNLableDoMethod
    @I_Sender = N'' , -- nvarchar(200)
    @I_ReturnMessage = N'' , -- nvarchar(max)
    @I_ExceptionFieldName = N'' , -- nvarchar(100)
    @I_LanguageId = '' , -- char(1)
    @I_PlugInCommand = '' , -- varchar(5)
    @I_OrBitUserId = '' , -- char(12)
    @I_OrBitUserName = N'' , -- nvarchar(100)
    @I_ResourceId = '' , -- char(12)
    @I_ResourceName = N'' , -- nvarchar(100)
    @I_PKid = 'KDPI000064EM' , -- char(12)
    @I_ParentPKId = 'KDOI000004RY' , -- char(12)
    @I_Parameter = N'' -- nvarchar(100)

declare @I_ReturnMessage nvcarchar(max) = ''
EXEC dbo.KDPrintSNLableDoMethod
    @I_Sender = N'PrintBoxSNLable' , -- nvarchar(200)
    @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
    @I_ExceptionFieldName = N'' , -- nvarchar(100)
    @I_LanguageId = '' , -- char(1)
    @I_PlugInCommand = '' , -- varchar(5)
    @I_OrBitUserId = '' , -- char(12)
    @I_OrBitUserName = N'' , -- nvarchar(100)
    @I_ResourceId = '' , -- char(12)
    @I_ResourceName = N'' , -- nvarchar(100)
    @I_PKid = '' , -- char(12)
    @I_ParentPKId = 'KDBI0002IQVZ' , -- char(12)
    @I_Parameter = N'', -- nvarchar(100)
	@NewStartBoxSN VARCHAR(50) = 'K3XHZZ2230000111#105694',
	@NewEndBoxSN VARCHAR(50) = 'K3XHZZ2230000111#105694'


declare @I_ReturnMessage nvcarchar(max) = ''
EXEC dbo.KDPrintSNLableDoMethod
    @I_Sender = N'PrintPalletSNLable' , -- nvarchar(200)
    @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
    @I_ExceptionFieldName = N'' , -- nvarchar(100)
    @I_LanguageId = '' , -- char(1)
    @I_PlugInCommand = '' , -- varchar(5)
    @I_OrBitUserId = '' , -- char(12)
    @I_OrBitUserName = N'' , -- nvarchar(100)
    @I_ResourceId = '' , -- char(12)
    @I_ResourceName = N'' , -- nvarchar(100)
    @I_PKid = '' , -- char(12)
    @I_ParentPKId = 'KDBI0002IQVZ' , -- char(12)
    @I_Parameter = N'', -- nvarchar(100)
	@NewStartPalletSN VARCHAR(50) = 'CZBZZ2130002148#10005',
	@NewEndPalletSN VARCHAR(50) = 'CZBZZ2130002148#10005'

*/

-- =============================================
-- Author:		<Wang RT>
-- Create date: <2020.7.23>
-- Description:	巴西散料栈板箱号打印
-- =============================================
CREATE PROCEDURE  [dbo].[KDPrintSNLableDoMethod]
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
@I_Parameter nvarchar(100)='',		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
@NewStartBoxSN VARCHAR(50) = '',
@NewEndBoxSN VARCHAR(50) = '',
@NewStartPalletSN VARCHAR(50) = '',
@NewEndPalletSN VARCHAR(50) = '',
@BoxLabelName NVARCHAR(100) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @return_value int

	--检查元对象方法用户授权
	exec @return_value=[dbo].[MetadataPermissionCheckDoMethod]
		@I_ReturnMessage=@I_ReturnMessage output,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_Sender=@I_Sender

	if @return_value=-1
	begin
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end

	DECLARE @KDOrderInfoId CHAR(12) = '';
	DECLARE @KDPalletInfoId CHAR(12) = '';
	DECLARE @BoxType VARCHAR(10) = '';
	DECLARE @Times INT = 1;
	DECLARE @Count INT = 0;
	DECLARE @PalletSN NVARCHAR(50) = '';
		
	DECLARE @TempPalletSN TABLE
	(
		ID INT IDENTITY(1,1),
		KDPalletInfoId CHAR(12),
		PalletSN VARCHAR(50)
	)

	DECLARE @TempPalletTable TABLE
	(
		PalletSN VARCHAR(50),SN1 VARCHAR(50),SN2 VARCHAR(50),SN3 VARCHAR(50),SN4 VARCHAR(50),SN5 VARCHAR(50),
		SN6 VARCHAR(50),SN7 VARCHAR(50),SN8 VARCHAR(50),SN9 VARCHAR(50),SN10 VARCHAR(50),
		SN11 VARCHAR(50),SN12 VARCHAR(50),SN13 VARCHAR(50),SN14 VARCHAR(50),SN15 VARCHAR(50),
		SN16 VARCHAR(50),SN17 VARCHAR(50),SN18 VARCHAR(50),SN19 VARCHAR(50),SN20 VARCHAR(50),
		SN21 VARCHAR(50),SN22 VARCHAR(50),SN23 VARCHAR(50),SN24 VARCHAR(50),SN25 VARCHAR(50),
		SN26 VARCHAR(50),SN27 VARCHAR(50),SN28 VARCHAR(50),SN29 VARCHAR(50),SN30 VARCHAR(50),
		SN31 VARCHAR(50),SN32 VARCHAR(50),SN33 VARCHAR(50),SN34 VARCHAR(50),SN35 VARCHAR(50),
		SN36 VARCHAR(50),SN37 VARCHAR(50),SN38 VARCHAR(50),SN39 VARCHAR(50),SN40 VARCHAR(50),
		SN41 VARCHAR(50),SN42 VARCHAR(50),SN43 VARCHAR(50),SN44 VARCHAR(50),SN45 VARCHAR(50),
		SN46 VARCHAR(50),SN47 VARCHAR(50),SN48 VARCHAR(50),SN49 VARCHAR(50),SN50 VARCHAR(50),
		SN51 VARCHAR(50),SN52 VARCHAR(50),SN53 VARCHAR(50),SN54 VARCHAR(50),SN55 VARCHAR(50),
		SN56 VARCHAR(50),SN57 VARCHAR(50),SN58 VARCHAR(50),SN59 VARCHAR(50),SN60 VARCHAR(50)
	)

	DECLARE @TempPalletItem TABLE
	(
		ZBH VARCHAR(50),KHJX VARCHAR(50),DDH VARCHAR(50),PCH VARCHAR(50),
		ZZXS VARCHAR(50),CD VARCHAR(50),WWPH VARCHAR(50),ZXSL VARCHAR(50),
		DXCKG VARCHAR(50),JZ VARCHAR(50),MZ VARCHAR(50),YWMS VARCHAR(500),
		ZZWLZMZ VARCHAR(50),ZZWLZTJ VARCHAR(50)
	)

	DECLARE @TempFinallyTable TABLE
	(
		Seq INT IDENTITY(1,1),
		ZBH VARCHAR(50),KHJX VARCHAR(50),DDH VARCHAR(50),PCH VARCHAR(50),
		ZZXS VARCHAR(50),CD VARCHAR(50),WWPH VARCHAR(50),ZXSL VARCHAR(50),
		DXCKG VARCHAR(50),JZ VARCHAR(50),MZ VARCHAR(50),YWMS VARCHAR(500),
		ZZWLZMZ VARCHAR(50),ZZWLZTJ VARCHAR(50),
		PalletSN VARCHAR(50),SN1 VARCHAR(50),SN2 VARCHAR(50),SN3 VARCHAR(50),SN4 VARCHAR(50),SN5 VARCHAR(50),
		SN6 VARCHAR(50),SN7 VARCHAR(50),SN8 VARCHAR(50),SN9 VARCHAR(50),SN10 VARCHAR(50),
		SN11 VARCHAR(50),SN12 VARCHAR(50),SN13 VARCHAR(50),SN14 VARCHAR(50),SN15 VARCHAR(50),
		SN16 VARCHAR(50),SN17 VARCHAR(50),SN18 VARCHAR(50),SN19 VARCHAR(50),SN20 VARCHAR(50),
		SN21 VARCHAR(50),SN22 VARCHAR(50),SN23 VARCHAR(50),SN24 VARCHAR(50),SN25 VARCHAR(50),
		SN26 VARCHAR(50),SN27 VARCHAR(50),SN28 VARCHAR(50),SN29 VARCHAR(50),SN30 VARCHAR(50),
		SN31 VARCHAR(50),SN32 VARCHAR(50),SN33 VARCHAR(50),SN34 VARCHAR(50),SN35 VARCHAR(50),
		SN36 VARCHAR(50),SN37 VARCHAR(50),SN38 VARCHAR(50),SN39 VARCHAR(50),SN40 VARCHAR(50),
		SN41 VARCHAR(50),SN42 VARCHAR(50),SN43 VARCHAR(50),SN44 VARCHAR(50),SN45 VARCHAR(50),
		SN46 VARCHAR(50),SN47 VARCHAR(50),SN48 VARCHAR(50),SN49 VARCHAR(50),SN50 VARCHAR(50),
		SN51 VARCHAR(50),SN52 VARCHAR(50),SN53 VARCHAR(50),SN54 VARCHAR(50),SN55 VARCHAR(50),
		SN56 VARCHAR(50),SN57 VARCHAR(50),SN58 VARCHAR(50),SN59 VARCHAR(50),SN60 VARCHAR(50)
	)

	IF @I_Sender = 'PrintPalletSNLable'
	BEGIN

		IF ISNULL(@NewStartPalletSN,LEN(@NewStartPalletSN)-4) <> ISNULL(@NewEndPalletSN,LEN(@NewEndPalletSN)-4)
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage:栈板号类别不一致！'
			RETURN -1;
		END 
		
		IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.KDPalletInfo WHERE KDOrderInfoId = @I_ParentPKId AND PalletSN = @NewStartPalletSN AND IsCancel = 0 )
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage:栈板号不存在！ [' + @NewStartPalletSN + ']'
			RETURN -1;
		END

		IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.KDPalletInfo WHERE KDOrderInfoId = @I_ParentPKId AND PalletSN = @NewEndPalletSN AND IsCancel = 0 )
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage:栈板号不存在！ [' + @NewEndPalletSN + ']'
			RETURN -1;
		END

		INSERT INTO @TempPalletSN ( KDPalletInfoId, PalletSN )
		SELECT DISTINCT 
		KDPalletInfoId,a.PalletSN
		FROM dbo.KDPalletInfo a
		LEFT JOIN dbo.ShipPallet b ON b.PalletSN = a.PalletSN
		WHERE KDOrderInfoId = @I_ParentPKId
		AND b.ShipPalletId IS NOT NULL
		AND a.PalletSN >= @NewStartPalletSN AND a.PalletSN <= @NewEndPalletSN
		AND a.IsCancel = 0
		ORDER BY PalletSN

		SELECT @Count = COUNT(1) FROM @TempPalletSN
		
		WHILE @Times <= @Count
		BEGIN
			CREATE TABLE #TempBoxSN
			(
				SN INT  IDENTITY(1,1),
				BoxSN VARCHAR(50)
			)
			
			SELECT @PalletSN = PalletSN, @KDPalletInfoId = KDPalletInfoId FROM @TempPalletSN WHERE ID = @Times
			INSERT INTO @TempPalletItem ( ZBH, KHJX, DDH, PCH, ZZXS, CD, WWPH, ZXSL, DXCKG, JZ, MZ, YWMS, ZZWLZMZ, ZZWLZTJ )
			SELECT ISNULL(a.PalletSN,'') AS ZBH,ISNULL(b.CustomerModel,'') AS KHJX, ISNULL(b.OrderName,'') AS DDH, 
			ISNULL(b.LotNo,'') AS PCH,COUNT(DISTINCT c.BoxSN) AS ZZXS,'CHINA' AS CD,
			ISNULL(h.prdname,'') AS WWPH, ISNULL(CAST(MAX(f.RealQty) AS INT),0) AS ZXSL, 
			LTRIM(RTRIM(CAST(CAST(MAX(e.BoxLength) AS INT) AS VARCHAR(10)) + 'X' + 
			CAST(CAST(MAX(e.BoxWidth) AS INT) AS VARCHAR(10)) + 'X' + 
			CAST(CAST(MAX(e.BoxHeight) AS INT) AS VARCHAR(10)))) AS DXCKG,
			CAST(MAX(e.NetWeight) AS INT) AS JZ,CAST(MAX(e.GrossWeight) AS INT) AS MZ, 
			ISNULL(h.EngDesc,'') AS YWMS, 
			MAX(e.GrossWeight) * COUNT(DISTINCT c.BoxSN) + CAST(MAX(a.PGROSSWEIGHT) AS INT) AS ZZWLZMZ,
			MAX(a.Volume) AS ZZWLZTJ
			FROM dbo.KDPalletInfo a
			LEFT JOIN dbo.KDOrderInfo b ON b.KDOrderInfoId = a.KDOrderInfoId
			LEFT JOIN dbo.ShipPallet c ON c.PalletSN = a.PalletSN
			LEFT JOIN dbo.KDBoxInfo e ON c.BoxSN = e.BoxSN
			LEFT JOIN dbo.KDBoxItem f ON e.KDBoxInfoId = f.KDBoxInfoId
			LEFT JOIN dbo.KDOrderItem g ON b.KDOrderInfoId = g.KDOrderInfoId AND f.ProductId = g.ProductId
			LEFT JOIN dbo.Product h ON f.ProductId = h.ProductId
			WHERE KDPalletInfoId = @KDPalletInfoId
			GROUP BY a.PalletSN,b.CustomerModel,b.OrderName,b.LotNo,h.prdname,h.EngDesc

			INSERT #TempBoxSN ( BoxSN )
			SELECT TOP 60 b.BoxSN
			FROM dbo.KDPalletInfo a
			LEFT JOIN dbo.ShipPallet b ON b.PalletSN = a.PalletSN AND b.IsCancel = 0
			WHERE a.KDPalletInfoId = @KDPalletInfoId
			ORDER BY b.BoxSN


			INSERT INTO @TempPalletTable ( PalletSN, SN1, SN2, SN3, SN4, SN5, SN6, SN7, SN8, SN9, SN10, SN11, SN12, SN13, SN14,
											SN15, SN16, SN17, SN18, SN19, SN20, SN21, SN22, SN23, SN24, SN25, SN26, SN27, SN28, SN29,
											SN30, SN31, SN32, SN33, SN34, SN35, SN36, SN37, SN38, SN39, SN40, SN41, SN42, SN43, SN44,
											SN45, SN46, SN47, SN48, SN49, SN50, SN51, SN52, SN53, SN54, SN55, SN56, SN57, SN58, SN59, SN60 )
			SELECT DISTINCT
			@PalletSN AS PalletSN,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 1) AS SN1,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 2) AS SN2,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 3) AS SN3,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 4) AS SN4,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 5) AS SN5,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 6) AS SN6,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 7) AS SN7,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 8) AS SN8,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 9) AS SN9,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 10) AS SN10, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 11) AS SN11,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 12) AS SN12,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 13) AS SN13, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 14) AS SN14,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 15) AS SN15,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 16) AS SN16, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 17) AS SN17,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 18) AS SN18,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 19) AS SN19, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 20) AS SN20,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 21) AS SN21,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 22) AS SN22, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 23) AS SN23,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 24) AS SN24,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 25) AS SN25, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 26) AS SN26,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 27) AS SN27,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 28) AS SN28, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 29) AS SN29,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 30) AS SN30,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 31) AS SN31, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 32) AS SN32,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 33) AS SN33,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 34) AS SN34, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 35) AS SN35,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 36) AS SN36,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 37) AS SN37, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 38) AS SN38,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 39) AS SN39,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 40) AS SN40, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 41) AS SN41,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 42) AS SN42,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 43) AS SN43, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 44) AS SN44,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 45) AS SN45,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 46) AS SN46, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 47) AS SN47,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 48) AS SN48,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 49) AS SN49, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 50) AS SN50,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 51) AS SN51,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 52) AS SN52, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 53) AS SN53,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 54) AS SN54,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 55) AS SN55, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 56) AS SN56,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 57) AS SN57,
			(SELECT BoxSN FROM #TempBoxSN WHERE SN = 58) AS SN58, (SELECT BoxSN FROM #TempBoxSN WHERE SN = 59) AS SN59,	(SELECT BoxSN FROM #TempBoxSN WHERE SN = 60) AS SN60
			FROM #TempBoxSN

			--插入最终表
			INSERT INTO @TempFinallyTable ( ZBH, KHJX, DDH, PCH, ZZXS, CD, WWPH, ZXSL, DXCKG, JZ, MZ, YWMS, ZZWLZMZ, ZZWLZTJ,
											 PalletSN, SN1, SN2, SN3, SN4, SN5, SN6, SN7, SN8, SN9, SN10, SN11, SN12, SN13, SN14,
											 SN15, SN16, SN17, SN18, SN19, SN20, SN21, SN22, SN23, SN24, SN25, SN26, SN27, SN28,
											 SN29, SN30, SN31, SN32, SN33, SN34, SN35, SN36, SN37, SN38, SN39, SN40, SN41, SN42,
											 SN43, SN44, SN45, SN46, SN47, SN48, SN49, SN50, SN51, SN52, SN53, SN54, SN55, SN56,
											 SN57, SN58, SN59, SN60 )
			SELECT ZBH, KHJX, DDH, PCH, ZZXS, CD, WWPH, ZXSL, DXCKG, JZ, MZ, YWMS, ZZWLZMZ, CAST(ZZWLZTJ AS DECIMAL(18,2)), PalletSN, 
			MAX(SN1), MAX(SN2), MAX(SN3), MAX(SN4), MAX(SN5), MAX(SN6), MAX(SN7), MAX(SN8), MAX(SN9), MAX(SN10), 
			MAX(SN11), MAX(SN12), MAX(SN13), MAX(SN14), MAX(SN15), MAX(SN16), MAX(SN17), MAX(SN18), MAX(SN19), MAX(SN20), 
			MAX(SN21), MAX(SN22), MAX(SN23), MAX(SN24), MAX(SN25), MAX(SN26), MAX(SN27), MAX(SN28), MAX(SN29), MAX(SN30), 
			MAX(SN31), MAX(SN32), MAX(SN33), MAX(SN34), MAX(SN35), MAX(SN36), MAX(SN37), MAX(SN38), MAX(SN39), MAX(SN40), 
			MAX(SN41), MAX(SN42), MAX(SN43), MAX(SN44), MAX(SN45), MAX(SN46), MAX(SN47), MAX(SN48), MAX(SN49), MAX(SN50), 
			MAX(SN51), MAX(SN52), MAX(SN53), MAX(SN54), MAX(SN55), MAX(SN56), MAX(SN57), MAX(SN58), MAX(SN59), MAX(SN60)
			FROM @TempPalletItem a
			LEFT JOIN @TempPalletTable b ON a.ZBH = b.PalletSN
			GROUP BY ZBH, KHJX, DDH, PCH, ZZXS, CD, WWPH, ZXSL, DXCKG, JZ, MZ, YWMS, ZZWLZMZ, ZZWLZTJ, PalletSN
			
			--清空表
			DELETE FROM @TempPalletItem
			DELETE FROM @TempPalletTable
			DROP TABLE #TempBoxSN

			SET @Times = @Times + 1
		END

		UPDATE dbo.KDPalletInfo
		SET PrintCount = PrintCount + 1
		WHERE KDPalletInfoId IN 
		( SELECT KDPalletInfoId FROM @TempPalletSN )

		SELECT * FROM @TempFinallyTable ORDER BY Seq DESC

		SET @I_ReturnMessage = 'ServerMessage:打印成功！'
		RETURN 0;
	END

	IF @I_Sender IN ('PrintBoxSNLable2','PrintBoxSNLable')
    BEGIN

		IF ISNULL(@NewStartBoxSN,'') = '' OR ISNULL(@NewEndBoxSN,'') = ''
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage:起始箱号和截止箱号不能为空，请检查！'
			RETURN -1				
		END 
		
		SELECT @KDOrderInfoId = KDOrderInfoId, @BoxType = BoxType FROM dbo.KDBoxInfo WHERE KDBoxInfoId = @I_ParentPKId

		IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.KDBoxInfo WHERE KDOrderInfoId = @KDOrderInfoId AND BoxType = @BoxType AND BoxSN = @NewStartBoxSN )
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage:起始箱号不存在！'
			RETURN -1;
		END

		IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.KDBoxInfo WHERE KDOrderInfoId = @KDOrderInfoId AND BoxType = @BoxType AND BoxSN = @NewEndBoxSN )
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage:截止箱号不存在！'
			RETURN -1;
		END

		IF @NewStartBoxSN > @NewEndBoxSN
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage:起始箱号不能大于截止箱号！'
			RETURN -1;
		END

		SELECT ISNULL(d.CustomerModel,'') AS MODEL,ISNULL(c.EngVendorname,'') AS GYS,c.prdname AS WLPH,ISNULL(c.EngDesc,'') AS YWMS,
		ISNULL(d.OrderName,'') AS DDH,ISNULL(CAST(b.RealQty AS INT),0) AS QTY,ISNULL(CAST(a.NetWeight AS INT),0) AS JZ,ISNULL(CAST(a.GrossWeight AS INT),0) AS MZ,
		ISNULL(CAST(a.BoxLength AS INT),0) AS L,ISNULL(CAST(a.BoxWidth AS INT),0) AS W,ISNULL(CAST(a.BoxHeight AS INT),0) AS H,ISNULL(d.LotNo,'') AS PCH,
		d.PONO AS PO,CONVERT(VARCHAR(10),d.CreateDate,120) AS RQ,
		a.BoxSN AS XH
		FROM dbo.KDBoxInfo a
		LEFT JOIN dbo.KDBoxItem b ON b.KDBoxInfoId = a.KDBoxInfoId
		LEFT JOIN dbo.Product c ON c.ProductId = b.ProductId
		LEFT JOIN dbo.KDOrderInfo d ON a.KDOrderInfoId = d.KDOrderInfoId
		LEFT JOIN dbo.KDOrderItem e ON d.KDOrderInfoId = e.KDOrderInfoId AND e.ProductId = b.ProductId
		WHERE a.KDOrderInfoId = @KDOrderInfoId AND a.BoxType = @BoxType
		AND a.BoxSN >=@NewStartBoxSN AND a.BoxSN <=@NewEndBoxSN AND a.IsCancel = 0
		ORDER BY a.BoxSN

		UPDATE dbo.KDBoxInfo
		SET PrintCount = PrintCount + 1
		WHERE KDOrderInfoId = @KDOrderInfoId AND BoxType = @BoxType
		AND BoxSN >=@NewStartBoxSN AND BoxSN <=@NewEndBoxSN AND IsCancel = 0

		SET @I_ReturnMessage = 'ServerMessage:打印成功！'

		RETURN 0
	END
	RETURN 0

END






