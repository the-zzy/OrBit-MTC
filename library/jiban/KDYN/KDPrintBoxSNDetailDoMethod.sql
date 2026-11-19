
-- =============================================
-- Author:		<OrBit benson>
-- Create Date: <2016.07.18>
-- Description:	散件打印外箱箱号
-- =============================================
CREATE PROCEDURE [dbo].[KDPrintBoxSNDetailDoMethod]
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
    @I_Parameter NVARCHAR(100) = '' ,		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @StartBoxSN NVARCHAR(50) = '' ,
    @EndBoxSN NVARCHAR(50) = '' ,
    @IsInvertedOrderPrint CHAR(1) = '1'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
    DECLARE @return_value INT;
    SET @return_value = -1;

	/*------检查元对象方法用户授权
	exec @return_value=[dbo].[MetadataPermissionCheckDoMethod]
		@I_ReturnMessage=@I_ReturnMessage output,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_Sender=@I_Sender

	if @return_value=-1
	begin
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end*/

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @i INT;
    DECLARE @KDOrderInfoId CHAR(12);
    DECLARE @OrderName NVARCHAR(500);
    DECLARE @KDBoxInfoId CHAR(12);
    DECLARE @BoxLevel NVARCHAR(50);
    DECLARE @BoxType NVARCHAR(50);
    DECLARE @Client NVARCHAR(50);
    DECLARE @Model NVARCHAR(50);
    DECLARE @OrderQty INT;
    DECLARE @Brand NVARCHAR(50);
    DECLARE @BoxSN NVARCHAR(50);
    DECLARE @BoxNumber NVARCHAR(50);
    DECLARE @A4KDBoxInfoId CHAR(12);
    DECLARE @A2KDBoxInfoId CHAR(12);
    DECLARE @PartNO NVARCHAR(50);
    DECLARE @VGCode NVARCHAR(50);
    DECLARE @Description NVARCHAR(500);
    DECLARE @EnglishDesc NVARCHAR(500);
    DECLARE @QTY NVARCHAR(50);
    DECLARE @TotalNet NVARCHAR(50);
    DECLARE @Gross NVARCHAR(50);
    DECLARE @L NVARCHAR(50);
    DECLARE @W NVARCHAR(50);
    DECLARE @H NVARCHAR(50);
    DECLARE @StartKDBoxInfoId CHAR(12);
    DECLARE @EndKDBoxInfoId CHAR(12);
    DECLARE @ProductionDate NVARCHAR(20);
    DECLARE @Country NVARCHAR(50);
    DECLARE @PanelPO NVARCHAR(50);
    DECLARE @SKDPO NVARCHAR(50);
    DECLARE @CustomerPO NVARCHAR(50);
    DECLARE @SupplierCode NVARCHAR(100)= '';
    DECLARE @ProjectNo NVARCHAR(100)= '';
    DECLARE @PoNo NVARCHAR(50)= '';
    DECLARE @LotNo NVARCHAR(50)= '';
    DECLARE @MadeCountry NVARCHAR(50)= '';
    DECLARE @RollingPlan NVARCHAR(100)= '';
    DECLARE @ModuleName NVARCHAR(50)= '';
    DECLARE @FieldsA NVARCHAR(500)= '';			  --附件字段A
    DECLARE @FieldsB NVARCHAR(500)= '';			  --附件字段B
    DECLARE @SingleWeight NVARCHAR(50)= '';          --单机重量

    SET @sql = '';
    SET @i = 0;
    SET @KDBoxInfoId = '';
    SET @BoxLevel = '';
    SET @BoxType = '';
    SET @KDOrderInfoId = '';
    SET @OrderName = '';
    SET @Client = '';
    SET @Model = '';
    SET @OrderQty = 0;
    SET @Brand = '';
    SET @BoxSN = '';
    SET @BoxNumber = '';
    SET @A4KDBoxInfoId = '';
    SET @A2KDBoxInfoId = '';
    SET @PartNO = '';
    SET @VGCode = '';
    SET @StartKDBoxInfoId = '';
    SET @EndKDBoxInfoId = '';
    SET @ProductionDate = CONVERT(VARCHAR, GETDATE(), 23);
    SET @Brand = '';
    SET @Country = '';
    SET @PanelPO = '';
    SET @SKDPO = '';
    SET @CustomerPO = '';

	--记录当前PKID
    DECLARE @BoxTemp TABLE
        (
          KDBoxInfoId CHAR(12) ,
          BoxLevel VARCHAR(20) ,
          BoxType VARCHAR(20) ,
          PCount INT
        );

    DECLARE @PrintData TABLE
        (
          BoxSN NVARCHAR(50) ,         --箱号
          BoxNumber NVARCHAR(50) ,     --箱编号
          VGCode NVARCHAR(50) ,        --客户编号
          ModuleName NVARCHAR(50) ,	--组件号
          PartNO NVARCHAR(50) ,        --物料品号
          Description NVARCHAR(500) ,  --物料描述
          EnglishDesc NVARCHAR(500) ,  --英文描述
          FieldsA NVARCHAR(500) ,		--附件字段A
          FieldsB NVARCHAR(500) ,		--附件字段B
          SingleWeight FLOAT ,			 --单机重量
          QTY FLOAT ,                  --数量
          TotalNet FLOAT ,             --净重
          Gross FLOAT ,            --毛重
          L FLOAT ,                    --长
          W FLOAT ,                    --宽
          H FLOAT                     --高
	    );

    IF ISNULL(@I_ParentPKId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择有效行项!';
        RETURN -1;
    END;

    IF ISNULL(@StartBoxSN, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入起始箱号!';
        RETURN -1;
    END;

    IF ISNULL(@EndBoxSN, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入截止箱号!';
        RETURN -1;
    END;

	--获取外箱信息
    SELECT TOP 1
            @KDBoxInfoId = KDBoxInfoId, @KDOrderInfoId = KDOrderInfoId, @BoxType = BoxType, @BoxLevel = BoxLevel
    FROM    KDBoxInfo
    WHERE   KDBoxInfoId = @I_ParentPKId;

	--获取订单信息
    SELECT  @OrderName = STUFF((
                                 SELECT DISTINCT
                                        '; ' + MO.SOName
                                 FROM   KDMO
                                 INNER JOIN MO ON KDMO.MOId = MO.MOId
                                 WHERE  KDMO.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
                               FOR
                                 XML PATH('')
                               ), 1, 2, ''), @Client = ISNULL(CustomerName, ''),
            @Description = ISNULL(OrderDescription, ''), @OrderQty = ISNULL(OrderQty, 0),
            @Model = ISNULL(CustomerModel, ''), @Brand = ISNULL(Brand, ''), @Country = ISNULL(Country, ''),
            @PanelPO = ISNULL(Panel, ''), @SKDPO = ISNULL(SKD, ''), @SupplierCode = ISNULL(SupplierCode, ''),
            @ProjectNo = ISNULL(ProjectNo, ''), @PoNo = ISNULL(PONO, ''), @LotNo = ISNULL(LotNo, ''),
            @MadeCountry = ISNULL(MadeCountry, ''), @RollingPlan = ISNULL(RollingPlan, ''),
            @ProductionDate = CONVERT(VARCHAR, OrderDate, 23)
    FROM    KDOrderInfo
    WHERE   KDOrderInfoId = @KDOrderInfoId;

    IF NOT EXISTS ( SELECT  1
                    FROM    KDBoxInfo
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @StartBoxSN AND IsCancel = 0 )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:起始箱 [' + @StartBoxSN + '] 无效，请检查!';
        RETURN -1;
    END;

    IF NOT EXISTS ( SELECT  1
                    FROM    KDBoxInfo
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @EndBoxSN AND IsCancel = 0 )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:截止箱 [' + @EndBoxSN + '] 无效，请检查!';
        RETURN -1;
    END;

	--外箱层级是否一致
    IF (
         SELECT BoxLevel
         FROM   KDBoxInfo
         WHERE  KDOrderInfoId = @KDOrderInfoId AND BoxSN IN ( @StartBoxSN ) AND IsCancel = 0
       ) != (
              SELECT    BoxLevel
              FROM      KDBoxInfo
              WHERE     KDOrderInfoId = @KDOrderInfoId AND BoxSN IN ( @EndBoxSN ) AND IsCancel = 0
            )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:不允许同时打印非同一层级的外箱标签，打印失败!';
        RETURN -1;
    END;

	--外箱类别是否一致
    IF (
         SELECT BoxType
         FROM   KDBoxInfo
         WHERE  KDOrderInfoId = @KDOrderInfoId AND BoxSN IN ( @StartBoxSN ) AND IsCancel = 0
       ) != (
              SELECT    BoxType
              FROM      KDBoxInfo
              WHERE     KDOrderInfoId = @KDOrderInfoId AND BoxSN IN ( @EndBoxSN ) AND IsCancel = 0
            )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:不允许同时打印非同一类别的外箱标签，打印失败!';
        RETURN -1;
    END;

    SELECT  @StartKDBoxInfoId = KDBoxInfoId
    FROM    KDBoxInfo
    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @StartBoxSN AND IsCancel = 0;
    SELECT  @EndKDBoxInfoId = KDBoxInfoId
    FROM    KDBoxInfo
    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @EndBoxSN AND IsCancel = 0;

    IF ISNULL(@StartKDBoxInfoId, '') > ISNULL(@EndKDBoxInfoId, '')
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:起始箱 [' + @StartBoxSN + '] 不允许大于截止箱 [' + @EndBoxSN + ']，请检查!';
        RETURN -1;
    END;

	--把信息写入表变量
    INSERT  INTO @BoxTemp ( KDBoxInfoId, BoxLevel, BoxType, PCount )
            SELECT  a.KDBoxInfoId, a.BoxLevel, a.BoxType, COUNT(b.ProductId) AS PCount
            FROM    dbo.KDBoxInfo a
            LEFT JOIN dbo.KDBoxItem b ON b.KDBoxInfoId = a.KDBoxInfoId AND b.IsCancel = 0
            WHERE   a.KDOrderInfoId = @KDOrderInfoId AND a.KDBoxInfoId >= @StartKDBoxInfoId AND a.KDBoxInfoId <= @EndKDBoxInfoId AND a.BoxLevel = @BoxLevel AND a.BoxType = @BoxType AND a.IsCancel = 0
            GROUP BY a.KDBoxInfoId, a.BoxLevel, a.BoxType
            ORDER BY a.KDBoxInfoId;

    IF NOT EXISTS ( SELECT  1
                    FROM    @BoxTemp )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:获取到的外箱数为零，打印失败!';
        RETURN -1;
    END; 

	--外箱层级是否一致
    IF (
         SELECT COUNT(DISTINCT BoxLevel)
         FROM   @BoxTemp
       ) > 1
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:不允许同时打印非同一层级的外箱标签，打印失败!';
        RETURN -1;
    END;

	--外箱类别是否一致
    IF (
         SELECT COUNT(DISTINCT BoxType)
         FROM   @BoxTemp
       ) > 1
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:不允许同时打印非同一类别的外箱标签，打印失败!';
        RETURN -1;
    END;

	--外箱物料种数是否一致
    IF (
         SELECT COUNT(DISTINCT PCount)
         FROM   @BoxTemp
       ) > 1
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:外箱中，存在装载的物料种数不一致的情况，打印失败!';
        RETURN -1;
    END;

	--更新打印次数
    UPDATE  KDBoxInfo
    SET     IsPrint = 1, PrintCount = PrintCount + 1
    WHERE   KDBoxInfoId IN ( SELECT KDBoxInfoId
                             FROM   @BoxTemp );

	--遍历所有箱号
    DECLARE cursor1 CURSOR
    FOR
    SELECT DISTINCT
            KDBoxInfoId
    FROM    @BoxTemp;
    OPEN cursor1;
    FETCH NEXT FROM cursor1 
	INTO @KDBoxInfoId;
    WHILE @@fetch_status = 0
    BEGIN	
        SET @BoxType = '';
        SET @BoxLevel = '';
        SET @BoxSN = '';
        SET @BoxLevel = '';

        SELECT  @BoxType = BoxType, @BoxLevel = BoxLevel, @BoxSN = BoxSN, @BoxNumber = BoxNumber
        FROM    KDBoxInfo
        WHERE   KDBoxInfoId = @KDBoxInfoId;

        INSERT  INTO @PrintData ( BoxSN, BoxNumber, VGCode, ModuleName, PartNO, Description, EnglishDesc, FieldsA,
                                  FieldsB, SingleWeight, QTY, TotalNet, Gross, L, W, H )
                SELECT  ISNULL(a.BoxSN, '') AS BoxSN, ISNULL(a.BoxNumber, '') AS BoxNumber,
                        ISNULL(c.CustomerNumber, '') AS VGCode, ISNULL(b.ModuleName, '') AS ModuleName,
                        ISNULL([dbo].[RemoveZero](ProductRoot.ProductName), '') AS PartNO,
                        ISNULL(Product.ProductDescription, '') AS Description,
                        ISNULL(Product.EngDesc, '') AS EnglishDesc, ISNULL(c.FieldsA, '') AS FieldsA,
                        ISNULL(c.FieldsB, '') AS FieldsB,
                        CONVERT(FLOAT, c.SingleWeight) AS SingleWeight,
                        CONVERT(FLOAT, b.RealQty) AS QTY, CONVERT(FLOAT, a.NetWeight) AS TotalNet,
                        CONVERT(FLOAT, a.GrossWeight) AS Gross, CONVERT(FLOAT, a.BoxLength) AS L,
                        CONVERT(FLOAT, a.BoxWidth) AS W, CONVERT(FLOAT, a.BoxHeight) AS H
                FROM    dbo.KDBoxInfo a
                INNER JOIN dbo.KDBoxItem b ON b.KDBoxInfoId = a.KDBoxInfoId AND b.IsCancel = 0
                INNER JOIN dbo.KDOrderItem c ON c.ProductId = b.ProductId AND c.KDOrderInfoId = @KDOrderInfoId --and b.ModuleName=c.ModuleName
                INNER JOIN Product ON Product.ProductId = c.ProductId
                INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
                WHERE   a.KDBoxInfoId = @KDBoxInfoId AND a.KDBoxInfoId >= @StartKDBoxInfoId AND a.KDBoxInfoId <= @EndKDBoxInfoId AND a.IsCancel = 0
                ORDER BY a.BoxSN;

        FETCH NEXT FROM cursor1 
		INTO @KDBoxInfoId;
    END; 
    CLOSE cursor1;
    DEALLOCATE cursor1; 

    IF NOT EXISTS ( SELECT  1
                    FROM    @PrintData )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:没有任何数据可打印，请检查!';
        RETURN -1;
    END;
	
    SELECT  @Client AS Customer, SUBSTRING(@OrderName, 3, 10) AS OrderNumber, @Model AS Model, @OrderQty AS OrderQty,
            @OrderName AS OrderName, @Brand AS Brand, @ProductionDate AS Date1, @Country AS Country, @CustomerPO BoxSN,
            BoxNumber AS CartonNo, VGCode, PartNO, Description, EnglishDesc AS Descriptionx, QTY, TotalNet AS UnitNet,
            Gross, L, W, H
    FROM    @PrintData;

    SET @I_ReturnMessage = 'ServerMessage:箱号打印成功!';
    RETURN 0;

	

    IF ISNULL(@BoxType, '') = 'A'
        SET @CustomerPO = @PanelPO;
    ELSE
        SET @CustomerPO = @SKDPO;

	--如果为 MRZ 报表，则执行此打印
	/*if SUBSTRING(@BoxLabelName,CHARINDEX('.',@BoxLabelName)+1,LEN(@BoxLabelName))='mrz'
	begin
		--打印数据
		select @Client as Client,Substring(@OrderName,3,10) as OrderNumber,@Model as Model,@OrderQty as OrderQty,
			@Brand as Brand,@ProductionDate as ProductionDate,@Country as Country,@CustomerPO
			BoxSN,BoxNumber,VGCode,PartNO,Description,EnglishDesc,QTY,TotalNet,Gross,L,W,H 
		from @PrintData

		set @I_ReturnMessage='ServerMessage:箱号打印成功!'
		return 0
	end*/

    IF @IsInvertedOrderPrint = '0'
    BEGIN
        DECLARE cursor1 CURSOR
        FOR
        SELECT DISTINCT
                BoxNumber, BoxSN
        FROM    @PrintData
        ORDER BY BoxSN;
    END;
    ELSE
    BEGIN
        DECLARE cursor1 CURSOR
        FOR
        SELECT DISTINCT
                BoxNumber, BoxSN
        FROM    @PrintData
        ORDER BY BoxSN DESC;
    END;

	--游标写入数据
    OPEN cursor1;
    FETCH NEXT FROM cursor1 
	INTO @BoxNumber, @BoxSN;
    WHILE @@FETCH_STATUS = 0
    BEGIN		
        SET @i = 0;
	
        IF ISNULL(@sql, '') <> ''
            SET @sql = @sql + ' UNION ALL ';

        SET @sql = @sql + ' SELECT ';
        SET @sql = @sql + '''' + CAST(SUBSTRING(@OrderName, 3, LEN(@OrderName)) AS VARCHAR) + ''' AS OrderNumber,';
        SET @sql = @sql + '''' + CAST(@Client AS VARCHAR) + ''' AS Client,';
        SET @sql = @sql + '''' + CAST(@Description AS NVARCHAR(500)) + ''' AS Description,';
        SET @sql = @sql + '''' + CAST(@Model AS VARCHAR) + ''' AS Model,';
        SET @sql = @sql + '''' + CAST(@OrderQty AS VARCHAR) + ''' AS OrderQty,';
        SET @sql = @sql + '''' + CAST(@Brand AS VARCHAR) + ''' AS Brand,';
        SET @sql = @sql + '''' + CAST(@ProductionDate AS VARCHAR) + ''' AS ProductionDate,';
        SET @sql = @sql + '''' + CAST(@Country AS VARCHAR) + ''' AS Country,';
        SET @sql = @sql + '''' + CAST(@CustomerPO AS VARCHAR) + ''' AS CustomerPO,';
        SET @sql = @sql + '''' + CAST(@BoxNumber AS VARCHAR) + ''' AS BoxNumber,';
        SET @sql = @sql + '''' + CAST(@BoxSN AS VARCHAR) + ''' AS BoxSN,';
        SET @sql = @sql + '''' + CAST(@SupplierCode AS NVARCHAR(100)) + ''' AS SupplierCode,';
        SET @sql = @sql + '''' + CAST(@ProjectNo AS NVARCHAR(100)) + ''' AS ProjectNo,';
        SET @sql = @sql + '''' + CAST(@PoNo AS NVARCHAR(50)) + ''' AS PoNo,';
        SET @sql = @sql + '''' + CAST(@LotNo AS NVARCHAR(50)) + ''' AS LotNo,';
        SET @sql = @sql + '''' + CAST(@MadeCountry AS NVARCHAR(50)) + ''' AS MadeCountry,';
        SET @sql = @sql + '''' + CAST(@RollingPlan AS NVARCHAR(100)) + ''' AS RollingPlan,';

        DECLARE cursor2 CURSOR
        FOR
        SELECT  VGCode, ModuleName, PartNO, EnglishDesc, FieldsA, FieldsB, SingleWeight, QTY, TotalNet, Gross, L, W, H
        FROM    @PrintData
        WHERE   BoxNumber = @BoxNumber
        ORDER BY BoxSN;
        OPEN cursor2;
        FETCH NEXT FROM cursor2 
		INTO @VGCode, @ModuleName, @PartNO, @EnglishDesc, @FieldsA, @FieldsB, @SingleWeight, @QTY, @TotalNet, @Gross, @L,
            @W, @H;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF CHARINDEX('''', @EnglishDesc, 1) > 0
            BEGIN
                SET @EnglishDesc = REPLACE(@EnglishDesc, '''', '''''');
            END;
            IF CHARINDEX('''', @FieldsA, 1) > 0
            BEGIN
                SET @FieldsA = REPLACE(@FieldsA, '''', '''''');
            END;
            IF CHARINDEX('''', @FieldsB, 1) > 0
            BEGIN
                SET @FieldsB = REPLACE(@FieldsB, '''', '''''');
            END;
            SET @i = @i + 1;		
            IF @i > 1
                SET @sql = @sql + ',';

            SET @sql = @sql + '''' + CAST(@VGCode AS NVARCHAR(50)) + ''' AS VGCode' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@ModuleName AS NVARCHAR(50)) + ''' AS ModuleName' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@PartNO AS NVARCHAR(50)) + ''' AS PartNO' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@EnglishDesc AS NVARCHAR(500)) + ''' AS EnglishDesc' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@FieldsA AS NVARCHAR(500)) + ''' AS FieldsA' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@FieldsB AS NVARCHAR(500)) + ''' AS FieldsB' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@SingleWeight AS VARCHAR) + ''' AS SingleWeight' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@QTY AS VARCHAR) + ''' AS QTY' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@TotalNet AS VARCHAR) + ''' AS TotalNet' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@Gross AS VARCHAR) + ''' AS Gross' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@L AS VARCHAR) + ''' AS L' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@W AS VARCHAR) + ''' AS W' + CAST(@i AS VARCHAR) + ',';
            SET @sql = @sql + '''' + CAST(@H AS VARCHAR) + ''' AS H' + CAST(@i AS VARCHAR);

            FETCH NEXT FROM cursor2 
			INTO @VGCode, @ModuleName, @PartNO, @EnglishDesc, @FieldsA, @FieldsB, @SingleWeight, @QTY, @TotalNet, @Gross,
                @L, @W, @H;
        END;
        CLOSE cursor2;
        DEALLOCATE cursor2;

        FETCH NEXT FROM cursor1 
		INTO @BoxNumber, @BoxSN;
    END;
    CLOSE cursor1;
    DEALLOCATE cursor1; 

    EXEC (@sql);
    SET @I_ReturnMessage = 'ServerMessage:箱号打印成功!从' + @StartBoxSN + '到' + @EndBoxSN;
    RETURN 0;
END;
 










