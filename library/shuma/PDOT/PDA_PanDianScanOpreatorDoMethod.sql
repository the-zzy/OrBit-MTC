CREATE PROCEDURE dbo.PDA_PanDianScanOpreatorDoMethod   ---设备盘点操作,PanDianOpretor事务对象使用 
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKid CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(50) = '' ,
--StocktakeDescription,PDOperator,stocktakeid,AssetLotSn
    @StocktakeDescription VARCHAR(50) = '' ,
    @PDOperator VARCHAR(20) = '' ,
    @Stocktakeid VARCHAR(12) = '' ,
    @AssetLotsn VARCHAR(30) = '' ,
    @ZoneCode VARCHAR(20) = '' ,
    @NotActiver BIT = 0 ,
    @UnUsedNum VARCHAR(30) = '' ,
    @Pdtype NVARCHAR(2) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    DECLARE @Personinfoid VARCHAR(12)= '';
    DECLARE @personname NVARCHAR(30)= '';
    DECLARE @locationDescription NVARCHAR(50)= '';
    DECLARE @locationid VARCHAR(12)= '';
    DECLARE @checkername NVARCHAR(50)= '';
    DECLARE @description NVARCHAR(50)= '';
    DECLARE @lotstocktakeid VARCHAR(12)= '';
    DECLARE @StocktakeItemLotid VARCHAR(12)= '';
    DECLARE @StocktakeItemId VARCHAR(12)= '';
    DECLARE @factoryname VARCHAR(100)= '';
    DECLARE @zoneNAME NVARCHAR(100)= '';
    DECLARE @factoryid VARCHAR(12)= '';
    DECLARE @Roomer NVARCHAR(30)= '';

    SET NOCOUNT ON;
    SET @AssetLotsn = UPPER(@AssetLotsn);
	
    IF @I_Sender = 'PandianOperatorShow'
    BEGIN
        SET @Personinfoid = '';
        SELECT  @Personinfoid = PersonInfoId, @personname = PersonName
        FROM    dbo.PersonInfo
        WHERE   PersonNumber = @PDOperator AND IsActivity = 1;
        IF ISNULL(@Personinfoid, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 请输入有效的在职人员!';
            SET @I_ExceptionFieldName = 'PDOperator';
            RETURN -1;
        END;

        SELECT  @personname AS OperatorName; 
        SET @I_ReturnMessage = 'ServerMessage: 请选择盘点计划!';
        SET @I_ExceptionFieldName = 'StocktakeDescription';
        RETURN 0;
    END;

    IF @I_Sender = 'ZoneCodeShow'
    BEGIN
        SET @locationDescription = '';
        SET @locationid = '';

        SELECT  @locationDescription = LocationDescription, @locationid = LocationId
        FROM    dbo.Location
        WHERE   LocationName = @ZoneCode;

        IF ISNULL(@locationid, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:位置没有定义，请先定义';
            SET @I_ExceptionFieldName = 'StocktakeDescription';
            RETURN 0;
        END;
	   
        SELECT  @locationDescription AS Location, @locationid AS locationid;
        SET @I_ReturnMessage = 'ServerMessage: 请选择盘点计划!';
        SET @I_ExceptionFieldName = 'AssetLotsn';
        RETURN 0;
    END;

    IF @I_Sender = 'leaveUnused'
    BEGIN
		
        IF ISNULL(@UnUsedNum, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:请先盘点后再点击闲置！';
            RETURN -1;
        END;

        SELECT  @factoryname = b.FactoryName, @factoryid = a.Factoryid
        FROM    dbo.Stocktake a
        INNER JOIN dbo.Factory b ON b.FactoryId = a.Factoryid
        WHERE   a.StocktakeId = @Stocktakeid;

        UPDATE  dbo.AssetDetail
        SET     NotActiver = 1
        WHERE   AssetNum = @UnUsedNum AND Company = @factoryname;

        UPDATE  b
        SET     NotActiver = 1
        FROM    dbo.Stocktake a
        INNER JOIN dbo.StocktakeCheckList b ON b.StocktakeId = a.StocktakeId
        WHERE   b.AssetNum = @UnUsedNum AND b.Company = @factoryname;
		
        SELECT  '' AS UnUsedNum;
        SET @I_ExceptionFieldName = 'AssetLotsn';
        SET @I_ReturnMessage = 'ServerMessage:资产编号[' + @UnUsedNum + ']已闲置';
        RETURN 0;
    END;
	
    IF ISNULL(@Stocktakeid, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择盘点计划!';
        SET @I_ExceptionFieldName = 'StocktakeDescription';
        RETURN -1;
    END; 

    IF ISNULL(@Pdtype, '') NOT IN ( '自盘', '复盘' )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择盘点类型！';
        RETURN -1;
    END;

    SELECT  @factoryname = b.FactoryName, @factoryid = a.Factoryid
    FROM    dbo.Stocktake a
    INNER JOIN dbo.Factory b ON b.FactoryId = a.Factoryid
    WHERE   a.StocktakeId = @Stocktakeid;

	---解析盘点计划，读出计划单号
   
    IF ISNULL(@AssetLotsn, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage: 请扫描有效的设备条码!';
        SET @I_ExceptionFieldName = 'AssetLotsn';
        RETURN -1;
    END;

    IF NOT EXISTS ( SELECT TOP 1
                            1
                    FROM    dbo.StocktakeCheckList
                    WHERE   StocktakeId = @Stocktakeid AND Company = @factoryname )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:未导入盘点明细表!' + @factoryname;
        SET @I_ExceptionFieldName = 'StocktakeDescription';
        RETURN -1;
    END;

    IF EXISTS ( SELECT  1
                FROM    dbo.AssetDetail
                WHERE   EquipmentNumber = @AssetLotsn )
    BEGIN
        SELECT  @AssetLotsn = AssetNum
        FROM    dbo.AssetDetail
        WHERE   EquipmentNumber = @AssetLotsn;
    END;


IF NOT EXISTS ( SELECT  1
                    FROM    dbo.StocktakeCheckList
                    WHERE   StocktakeId = @Stocktakeid AND AssetNum = @AssetLotsn AND IsCancel = 0 )
    BEGIN

	   DECLARE @PKID CHAR(12);
	   EXEC dbo.SysGetObjectPKId @ObjectId = '',      -- char(12)
	                             @ObjectName = N'StocktakeCheckList',   -- nvarchar(100)
	                             @PKID = @PKID OUTPUT -- char(12)

		EXEC dbo.SendMsgToOADoMethod @I_ReturnMessage = @I_ReturnMessage OUTPUT, -- nvarchar(max)
		                             @TriggerProcedure = N'',                    -- nvarchar(50)
		                             @SendMsg = N'数码盘点执行中PDA_PanDianScanOpreatorDoMethod',                             -- nvarchar(max)
		                             @UserName = N'2061399'                             -- nvarchar(max)
		
	    -------新增盘点项
		INSERT INTO dbo.StocktakeCheckList
		(
		    StocktakeCheckListId,   StocktakeId,  AssetDetailid,  Company, TypeName,
		    AssetNum,  EquipmentNumber, Descriptionx, ExtDescription,  UOM,
		    QTY,  CostCenter, IsSoftAsset, Roomer, ZoneCode,
		    NotActiver,  FirstCheckQTY, FirstCheckOperator, FirstCheckDate, ReCheckQTY,
		    ReCheckOperator,  ReCheckDate, Remark, IsCancel,  CreateUserId,  CreateDate
		)
		SELECT 
		   @PKID,        -- StocktakeCheckListId - char(12)
		    @Stocktakeid,        -- StocktakeId - char(12)
		    AssetDetailId,        -- AssetDetailid - char(12)
		    @factoryname,        -- Company - varchar(10)
		    N'',       -- TypeName - nvarchar(20)
		    @AssetLotsn,       -- AssetNum - nvarchar(50)
		    N'',       -- EquipmentNumber - nvarchar(50)
		    a.Descriptionx,       -- Descriptionx - nvarchar(100)
		    a.ExtDescription,       -- ExtDescription - nvarchar(100)
		    a.UOM,       -- UOM - nvarchar(10)
		    a.QTY,         -- QTY - int
		    a.CostCenter,       -- CostCenter - nvarchar(10)
		    a.IsSoftAsset,       -- IsSoftAsset - nvarchar(30)
		    a.Roomer,       -- Roomer - nvarchar(30)
		    a.ZoneCode,       -- ZoneCode - nvarchar(20)
		    a.NotActiver,      -- NotActiver - bit
		    0,         -- FirstCheckQTY - int
		    '',        -- FirstCheckOperator - varchar(30)
		    GETDATE(), -- FirstCheckDate - datetime
		    0,         -- ReCheckQTY - int
		    '',        -- ReCheckOperator - varchar(30)
		    GETDATE(), -- ReCheckDate - datetime
		    N'新增配置项',       -- Remark - nvarchar(200)
		    0,      -- IsCancel - bit
		    '',        -- CreateUserId - char(12)
		    GETDATE()  -- CreateDate - datetime
		FROM dbo.AssetDetail a WHERE AssetNum = @AssetLotsn    


    END;



    IF NOT EXISTS ( SELECT TOP 1
                            1
                    FROM    AssetDetail
                    WHERE   AssetNum = @AssetLotsn AND Activer = 1 AND Company = @factoryname )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage: 找不到该资产编号，请检查!' + @AssetLotsn;
        SET @I_ExceptionFieldName = 'AssetLotsn';
        RETURN -1;
    END;

    IF NOT EXISTS ( SELECT  1
                    FROM    dbo.StocktakeCheckList
                    WHERE   StocktakeId = @Stocktakeid AND AssetNum = @AssetLotsn AND IsCancel = 0 )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:设备编号[' + @AssetLotsn + ']不在本次盘点计划中！';
        SET @I_ExceptionFieldName = 'AssetLotsn';
        RETURN -1;
    END;

    IF NOT EXISTS ( SELECT  1
                    FROM    dbo.Location
                    WHERE   LocationName = @ZoneCode )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:区域码[' + @ZoneCode + ']在系统中不存在！';
        SET @I_ExceptionFieldName = 'AssetLotsn';
        RETURN -1;
    END;

    SELECT  @checkername = c.PersonName, @description = a.Descriptionx, @lotstocktakeid = a.StockTakeId,
            @Roomer = a.Roomer
    FROM    AssetDetail a
    LEFT JOIN dbo.PersonInfo c ON c.PersonNumber = a.Operator
    WHERE   a.AssetNum = @AssetLotsn AND a.Company = @factoryname;

    IF ISNULL(@Pdtype, '') = '自盘'
    BEGIN
        IF EXISTS ( SELECT  1
                    FROM    dbo.StocktakeCheckList
                    WHERE   StocktakeId = @Stocktakeid AND AssetNum = @AssetLotsn AND FirstCheckQTY = 1 )
        BEGIN
			
            SELECT  @ZoneCode = ZoneCode, @PDOperator = FirstCheckOperator
            FROM    dbo.StocktakeCheckList
            WHERE   StocktakeId = @Stocktakeid AND AssetNum = @AssetLotsn;

			SELECT  @locationDescription = LocationDescription, @locationid = LocationId
			FROM    dbo.Location
			WHERE   LocationName = @ZoneCode;

            SELECT  @AssetLotsn AS UnUsedNum;
            SET @I_ReturnMessage = 'ServerMessage:设备编号[' + @AssetLotsn + ']已自盘过，人员[' + @PDOperator + ']地点[' + @locationDescription + ']，请勿重复盘点！';
            SET @I_ExceptionFieldName = 'AssetLotsn';
            RETURN -1;
        END;
    END;
    ELSE
    BEGIN
        IF EXISTS ( SELECT  1
                    FROM    dbo.StocktakeCheckList
                    WHERE   StocktakeId = @Stocktakeid AND AssetNum = @AssetLotsn AND ReCheckQTY = 1 )
        BEGIN
			
            SELECT  @ZoneCode = ZoneCode, @PDOperator = ReCheckOperator
            FROM    dbo.StocktakeCheckList
            WHERE   StocktakeId = @Stocktakeid AND AssetNum = @AssetLotsn;

			SELECT  @locationDescription = LocationDescription, @locationid = LocationId
			FROM    dbo.Location
			WHERE   LocationName = @ZoneCode;

            SET @I_ReturnMessage = 'ServerMessage:设备编号[' + @AssetLotsn + ']已复盘过，人员[' + @PDOperator + ']地点[' + @locationDescription + ']，请勿重复盘点！';
            SET @I_ExceptionFieldName = 'AssetLotsn';
            RETURN -1;
        END;
    END;



    UPDATE  dbo.StocktakeCheckList
    SET     FirstCheckQTY = IIF(@Pdtype = '自盘', 1, FirstCheckQTY),
            FirstCheckOperator = IIF(@Pdtype = '自盘', @PDOperator, FirstCheckOperator),
            FirstCheckDate = IIF(@Pdtype = '自盘', GETDATE(), FirstCheckDate),
            ReCheckQTY = IIF(@Pdtype = '复盘', 1, ReCheckQTY),
            ReCheckOperator = IIF(@Pdtype = '复盘', @PDOperator, ReCheckOperator),
            ReCheckDate = IIF(@Pdtype = '复盘', GETDATE(), ReCheckDate), ZoneCode = RTRIM(LTRIM(UPPER(@ZoneCode)))
    WHERE   StocktakeId = @Stocktakeid AND AssetNum = @AssetLotsn;

    UPDATE  AssetDetail
    SET     Operator = @PDOperator, StockTakeId = @Stocktakeid, NotActiver = 0, stockCheckDate = GETDATE(),
            ZoneCode = RTRIM(LTRIM(UPPER(@ZoneCode)))
    WHERE   AssetNum = @AssetLotsn AND Company = @factoryname;

    --IF EXISTS ( SELECT  1
    --            FROM    dbo.UnUsedAssetNum
    --            WHERE   AssetNum = @AssetLotsn )
    --    SET @I_ReturnMessage = 'ServerMessage:请确认是否闲置资产!';
    --ELSE
    --    SET @I_ReturnMessage = 'ServerMessage:该资产编号[' + RTRIM(@AssetLotsn) + '/' + RTRIM(@description) + ' ]盘点完成!,请扫下一个';

    SET @I_ExceptionFieldName = 'AssetLotsn';
    SELECT  @description AS Description, '' AS assetlotsn, @Roomer AS Roomer, @AssetLotsn AS UnUsedNum;  ---清空前台界面
    RETURN 0; 

END;







