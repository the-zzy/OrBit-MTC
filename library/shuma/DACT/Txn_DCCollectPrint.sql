-- =============================================
-- Author:		<OrBit benson>
-- Create date: <2016-05-03>
-- Description:	<采集打印扫描>
-- =============================================
CREATE PROCEDURE dbo.Txn_DCCollectPrint
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名	
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKId CHAR(12) = '' ,				--主键
    @I_SourcePKId CHAR(12) = '' ,			--执行拷贝时传入的源主键  
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' , 		--插件参数	
    @OrderName NVARCHAR(50) = '' ,         --订单号
    @Operator NVARCHAR(50) = '' ,          --操作员
    @LotSN NVARCHAR(500) = '' ,             --产品条码
    @ItemValue NVARCHAR(500) = '' ,         --采集项内容   
    @CollectStr NVARCHAR(MAX) = '' ,
    @NextItemName NVARCHAR(50) = '' ,
    @MOName NVARCHAR(50) = ''       ------工单号，李鲜    
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @return_value INT;
    DECLARE @TxnCode VARCHAR(10);
    DECLARE @Date DATETIME;
    DECLARE @DataChainId CHAR(12);
    DECLARE @LotId CHAR(12);
    DECLARE @LotStatus CHAR(1);
    DECLARE @LotQty FLOAT;
    DECLARE @LotProductId CHAR(12);
    DECLARE @LotMOId CHAR(12);
    DECLARE @WorkcenterId CHAR(12);
    DECLARE @LotWorkflowId CHAR(12);
    DECLARE @LotWorkflowStepId CHAR(12);
    DECLARE @LotSpecificationId CHAR(12);
    DECLARE @LotOrderName NVARCHAR(50);
    DECLARE @ItemName NVARCHAR(50);
    DECLARE @CollectSettingId CHAR(12);
    DECLARE @DataChainAssemblyId CHAR(12);
    DECLARE @CollectSN NVARCHAR(200);
    DECLARE @ScanTempCount INT;
    DECLARE @CollectCount INT;
    DECLARE @Sequence INT;                   --采集项的顺序
    DECLARE @AssemblyTime DATETIME;
	--declare @NextItemName nvarchar(50)
    DECLARE @CollectProductId CHAR(12);
    DECLARE @ScanQty INT;                   --资源扫描数
    DECLARE @IsAssemblyStep BIT;            --是否装配节点
    DECLARE @MESTxnObjectName NVARCHAR(50);  --事务名称
    DECLARE @CollectItemId CHAR(12);	
    DECLARE @FinishQty INT;
    DECLARE @TempStr NVARCHAR(200);
    DECLARE @TempItemName NVARCHAR(50);
    DECLARE @TempItemValue NVARCHAR(200);
    DECLARE @index INT;
    DECLARE @i INT;
    DECLARE @FieldSettingId CHAR(12);
    DECLARE @OrderFieldSettingId CHAR(12);
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @CheckCollectSN NVARCHAR(200);
    DECLARE @CheckCollectName NVARCHAR(50);


    SET @return_value = -1;
    SET @I_ExceptionFieldName = 'ItemValue';
    SET @TxnCode = 'DC';
    SET @Date = GETDATE(); 
    SET @MESTxnObjectName = 'DC CollectPrint'; --采集打印事务名称
    SET @LotId = '';
    SET @LotStatus = '';
    SET @LotQty = 0;
    SET @LotProductId = '';
    SET @LotWorkflowId = '';
    SET @LotWorkflowStepId = '';
    SET @LotSpecificationId = '';
    SET @LotOrderName = '';
    SET @LotMOId = '';
    SET @ScanTempCount = 0;
    SET @CollectCount = 0;
    SET @CollectSN = '';
    SET @DataChainAssemblyId = '';
    SET @CollectSettingId = '';
    SET @WorkcenterId = '';
    SET @ItemName = '';
	--set @NextItemName=''
    SET @CollectProductId = '';
    SET @ScanQty = 0;
    SET @IsAssemblyStep = 0;
    SET @CollectItemId = '';
    SET @FinishQty = 0;
    SET @TempStr = '';
    SET @index = 0;
    SET @TempItemName = '';
    SET @TempItemValue = '';
    SET @i = 0;
    SET @FieldSettingId = '';
    SET @OrderFieldSettingId = '';
    SET @sql = '';
    SET @CheckCollectName = '';
    SET @CheckCollectSN = '';

	--转换
    SET @LotSN = UPPER(LTRIM(RTRIM(@LotSN)));
    SET @ItemValue = UPPER(LTRIM(RTRIM(@ItemValue)));

    CREATE TABLE #CollectTemp
        (
          ID INT ,
          CollectName NVARCHAR(50) NULL ,
          CollectSN NVARCHAR(200) NULL
        );

	--如果参数不为空，则写入表变量
    IF ISNULL(@CollectStr, '') <> ''
    BEGIN
        SET @i = 0;
        DECLARE cursor1 CURSOR
        FOR
        SELECT  parameter_Value
        FROM    dbo.ConvertParameterToTable(@CollectStr, ';');
        OPEN cursor1;
        FETCH NEXT FROM cursor1 
		INTO @TempStr;
        WHILE @@fetch_status = 0
        BEGIN	
            SET @i = @i + 1;
            SET @index = 0;

            SET @TempItemName = '';
            SET @TempItemValue = '';

            SET @index = CHARINDEX(',', @TempStr);
            SET @TempItemName = SUBSTRING(@TempStr, 0, @index);
            SET @TempItemValue = SUBSTRING(@TempStr, @index + 1, LEN(@TempStr));
			
			--写入表变量数据
            INSERT  INTO #CollectTemp ( ID, CollectName, CollectSN )
            VALUES  ( @i, @TempItemName, @TempItemValue );
				
            FETCH NEXT FROM cursor1 
			INTO @TempStr;
        END; 
        CLOSE cursor1;
        DEALLOCATE cursor1; 
    END;

	--检查资源是否已维护
    IF ISNULL(@I_ResourceId, '') = ''
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:资源 [' + @I_ResourceName + '] 未在 MES 维护，请检查!';
        RETURN -1;
    END;

	---判断操作员是否为空
    IF ISNULL(@ItemValue, '') = ''
    BEGIN
        SELECT  Product_CollectSetting.Sequence, CollectItem.CollectItemName, #CollectTemp.CollectSN
        FROM    Product_CollectSetting
        INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
        LEFT JOIN #CollectTemp ON #CollectTemp.CollectName = CollectItem.CollectItemName
        WHERE   Product_CollectSetting.ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId
        ORDER BY Product_CollectSetting.Sequence;
        SELECT  '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;		
		
        SET @I_ReturnMessage = 'ServerMessage:请输入采集项!';
        RETURN -1;
    END;

	--检查工号是否存在
    IF NOT EXISTS ( SELECT  1
                    FROM    PersonInfo
                    WHERE   PersonNumber = @Operator AND IsActivity = 1 )
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS Operator, '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:作业员 [' + @Operator + '] 无效，请检查!';
        SET @I_ExceptionFieldName = 'Operator';
        RETURN -1;
    END;
	

	--------------- add  采集扫描 李鲜 2021.7.22 多码合一，分格符-------
	---------在OrderFieldSetting表中MOName只有null和10位       @MOId是根据值列表获取的，已经去除了前面的0   [dbo].[RemoveZero](MO.MOName) as MOName,

	-------------用订单号来获取，不用工单来，那样前面的的MOname就不需要添加
	
	-------------用订单号来获取，不用工单来，那样前面的的MOname就不需要添加

    DECLARE @IsCodeUnity NVARCHAR(12);  --是不是多码合一
	
    DECLARE @sqlset NVARCHAR(MAX);  
   
    SELECT  @IsCodeUnity = ISNULL(a.IsCodeUnity, '')
    FROM    OrderFieldSetting a
    WHERE   a.OrderName = @OrderName;

    IF @IsCodeUnity = 1
    BEGIN


        DECLARE @ModelSettingIdLIXIAN NVARCHAR(50);
        DECLARE @OrderFieldSettingIdlixian NVARCHAR(50); ----前面已声明
        SELECT  @ModelSettingIdLIXIAN = ModelSettingId, @OrderFieldSettingIdlixian = OrderFieldSettingId
        FROM    OrderFieldSetting a
        WHERE   a.OrderName = @OrderName;
	  
        DECLARE @FieldSettingIdlixian NVARCHAR(50);      
        SELECT  @FieldSettingIdlixian = FieldSettingId
        FROM    dbo.ModelFieldSetting a
        WHERE   a.ModelSettingId = @ModelSettingIdLIXIAN AND a.IsMainSN = '1';

        DECLARE @FieldNameLIXIAN NVARCHAR(50);   ----字段  主批号的字段
        SELECT  @FieldNameLIXIAN = FieldName
        FROM    FieldSetting
        WHERE   FieldSettingId = @FieldSettingIdlixian;


		----判断是不是通过截取来获取lotsn
        DECLARE @IsNumberIntercept NVARCHAR(12);  --是不是位置截取
        SELECT  @IsNumberIntercept = ISNULL(a.IsNumberIntercept, '')
        FROM    OrderFieldSetting a
        WHERE   a.OrderName = @OrderName;

        IF @IsNumberIntercept = 1
        BEGIN

            DECLARE @StartPosition NVARCHAR(12);  --获取开始截取的位置
            DECLARE @EndPosition NVARCHAR(12);  --获取截取的长度

            SELECT  @EndPosition = ISNULL(a.EndPosition, ''), @StartPosition = ISNULL(a.StartPosition, '')
            FROM    OrderFieldSetting a
            WHERE   a.OrderName = @OrderName;

           
            SET @sqlset = '  SELECT @LotSN=' + @FieldNameLIXIAN + ' FROM ordersetitem WHERE   OrderFieldSettingId=' + QUOTENAME(@OrderFieldSettingIdlixian,
                                                                                                        '''') + ' AND  ' + @FieldNameLIXIAN + '= SUBSTRING(' + QUOTENAME(@LotSN,
                                                                                                        '''') + ', ' + @StartPosition + ',' + @EndPosition + ')';
            EXEC sp_executesql
                @sqlset ,
                N'@LotSN nVARCHAR(50) out' ,
                @LotSN OUTPUT;
		
		
        END;
        ELSE
        BEGIN
                

	-------获取分隔符
            DECLARE @Separator NVARCHAR(20);   --分隔符
            SELECT  @Separator = ISNULL(a.Separator, '')
            FROM    OrderFieldSetting a
            WHERE   a.OrderName = @OrderName;


	     
            SET @sqlset = '  SELECT @LotSN=' + @FieldNameLIXIAN + ' FROM ordersetitem WHERE   OrderFieldSettingId=' + QUOTENAME(@OrderFieldSettingIdlixian,
                                                                                                        '''') + ' AND  ' + @FieldNameLIXIAN + ' IN ( SELECT parameter_Value FROM dbo.ConvertParameterToTable(' + QUOTENAME(@LotSN,
                                                                                                        '''') + ',' + QUOTENAME(@Separator,
                                                                                                        '''') + '))';
            EXEC sp_executesql
                @sqlset ,
                N'@LotSN nVARCHAR(50) out' ,
                @LotSN OUTPUT;



        END;

    END;



	--------------- end   李鲜 2021.7.21 多码合一，分格符-------



    IF NOT EXISTS ( SELECT  1
                    FROM    Lot
                    WHERE   LotSN = @LotSN )
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SET @I_ReturnMessage = 'ServerMessage:产品条码 [' + @LotSN + '] 不存在，请检查!';
        SET @I_ExceptionFieldName = 'LotSN';
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
        RETURN -1;
    END;

	--获取 Lot 信息
    SELECT  @LotId = LotId, @LotQty = Qty, @LotStatus = LotStatus, @LotProductId = ProductId, @LotMOId = MOId,
            @LotWorkflowId = WorkflowId, @LotWorkflowStepId = WorkflowStepId, @LotSpecificationId = SpecificationId,
            @LotOrderName = OrderName
    FROM    Lot
    WHERE   LotSN = @LotSN;

	--检查LotSN是否被锁定 1代表可用，0代表锁定
    IF ISNULL(@LotStatus, 1) <> '1'
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;		
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:产品条码 [ ' + @LotSN + ' ] 状态不可用，无法对其操作!';	
        RETURN -1;
    END;

    IF ISNULL(@OrderName, '') <> ISNULL(@LotOrderName, '')
    BEGIN
		--返回界面
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:产品批号 [' + @LotSN + '] 不属于此订单 [' + @OrderName + ']，应为订单 [' + @LotOrderName + ']，请检查!'+@ItemValue;
        RETURN -1;
    END;






    IF ISNULL(@WorkcenterId, '') = ''
    BEGIN

        SELECT  @WorkcenterId = WorkcenterId
        FROM    dbo.SysUser WITH ( NOLOCK )
        WHERE   UserId = @I_OrBitUserId;

    END;


--获取线体名
    DECLARE @WorkcenterName NVARCHAR(20);
    SELECT  @WorkcenterName = WorkcenterName
    FROM    Workcenter WITH ( NOLOCK )
    WHERE   WorkcenterId = @WorkcenterId;

    IF @WorkcenterName = '7B'
    BEGIN
		----------------add   2021.8.5 李鲜 采集项多码合一------------------

        DECLARE @AcquisitionStaPosition NVARCHAR(12);
        DECLARE @AcquisitionEndPosition NVARCHAR(12);


        SELECT  @AcquisitionStaPosition = ISNULL(a.AcquisitionStaPosition, ''),
                @AcquisitionEndPosition = ISNULL(a.AcquisitionEndPosition, '')
        FROM    OrderFieldSetting a
        WHERE   a.OrderName = @OrderName;

		   --SET @I_ReturnMessage = 'ServerMessage:原来的'+@ItemValue+ '采集项!'
		   --SELECT @I_ReturnMessage

        IF ISNULL(@AcquisitionStaPosition, '') <> '' AND ISNULL(@AcquisitionEndPosition, '') <> ''
        BEGIN
  
           --SET  @ItemValue = SUBSTRING(@ItemValue, @AcquisitionStaPosition, @AcquisitionEndPosition);
     --      SET @I_ReturnMessage = 'ServerMessage:该'+@ItemValue+ '采集项!'
		   --SELECT @I_ReturnMessage

		        
            SET @sqlset = '  SELECT @ItemValue= SUBSTRING(' + QUOTENAME(@ItemValue, '''') + ', ' + @AcquisitionStaPosition + ',' + @AcquisitionEndPosition + ')';
            EXEC sp_executesql
                @sqlset ,
                N'@ItemValue nVARCHAR(50) out' ,
                @ItemValue OUTPUT;

        END;

    END;


	------------------------------end   --------------




	--检查二维码项
    IF @NextItemName = 'BarcodeCheck'
    BEGIN
        DECLARE @issole BIT= 0;
        IF NOT EXISTS ( SELECT TOP 1
                                1
                        FROM    dbo.BarcodeCheck
                        WHERE   LEFT(OrderName, 10) = LEFT(@OrderName, 10) )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:该订单没有预置相应的二维码 !';
            SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
            SELECT  '' AS ItemValue, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'ItemValue';
            RETURN -1;	   
        END;












        IF EXISTS ( SELECT TOP 1
                            1
                    FROM    dbo.BarcodeCheck
                    WHERE   LEFT(OrderName, 10) = LEFT(@OrderName, 10) AND IsUse = 1 AND Barcode2d = @ItemValue )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:该二维码已使用，不能重复使用 !';
            SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
            SELECT  '' AS ItemValue, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'ItemValue';
            RETURN -1;	   
        END;

        IF NOT EXISTS ( SELECT TOP 1
                                1
                        FROM    dbo.BarcodeCheck
                        WHERE   LEFT(OrderName, 10) = LEFT(@OrderName, 10) AND IsUse = 0 AND Barcode2d = @ItemValue )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:没找要可用的二维码 !';
            SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
            SELECT  '' AS ItemValue, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'ItemValue';
            RETURN -1;	   
        END;
	   
	  
	  -- SELECT TOP 1
   --         @issole = a.IsSole
   --       FROM    Product_CollectSetting a WITH(NOLOCK)
   --       INNER JOIN CollectItem b WITH(NOLOCK) ON b.CollectItemId = a.CollectItemId
   --       WHERE   a.ProductId = @LotProductId AND  b.CollectItemName = @ItemName
	  --UPDATE BarcodeCheck SET IsUse = @issole,moid = @LotMOId,Productid = @LotProductId WHERE LEFT(OrderName,10)=LEFT(@OrderName,10) AND Barcode2d = @ItemValue AND IsUse = 0
    END;




	--获取订单信息
    SELECT  @OrderFieldSettingId = OrderFieldSettingId
    FROM    OrderFieldSetting
    WHERE   OrderName = @OrderName;

	--- 多余的检查，前面已有检查了，为什么又在这检查，2018-10-15
	--检查资源或者用户是否允许操作此规程
	--exec @return_value=dbo.[SysCheckSpecification]
	--	@I_ReturnMessage=@I_ReturnMessage output,
	--	@WorkcenterId=@WorkcenterId output,
	--	@LotId=@LotId,
	--	@I_OrBitUserId=@I_OrBitUserId,
	--	@I_OrBitUserName=@I_OrBitUserName,
	--	@I_ResourceId=@I_ResourceId,
	--	@I_ResourceName=@I_ResourceName,
	--	@SpecificationId=@LotSpecificationId,
	--	@MESTxnObjectName=@MESTxnObjectName

	--if @return_value=-1
	--begin
	--	select '' as ID,'' as CollectName,'' as CollectSN
	--	select '' as LotSN,'' as ItemValue,'' as CollectStr,'0' as IsPrint,'error.png' as WarnImage
	--	set @I_ReturnMessage=@I_ReturnMessage
	--	return -1
	--end

	--获取未完成采集的采集项
    SELECT TOP 1
            @CollectSettingId = Product_CollectSettingId, @Sequence = Sequence, @ItemName = CollectItem.CollectItemName
    FROM    Product_CollectSetting
    INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
    WHERE   ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId AND CollectItem.CollectItemName NOT IN (
            SELECT DISTINCT
                    CollectName AS CollectItemName
            FROM    #CollectTemp )
    ORDER BY Product_CollectSetting.Sequence;

	--检查是否已扫描完
    IF ISNULL(@CollectSettingId, '') = ''
    BEGIN
		--返回网格数据
        SELECT  Product_CollectSetting.Sequence, CollectItem.CollectItemName, #CollectTemp.CollectSN
        FROM    Product_CollectSetting
        INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
        LEFT JOIN #CollectTemp ON #CollectTemp.CollectName = CollectItem.CollectItemName
        WHERE   Product_CollectSetting.ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId
        ORDER BY Product_CollectSetting.Sequence;

        SELECT  '' AS ItemValue, '0' AS IsPrint, 'error.png' AS WarnImage;
				
        SET @I_ReturnMessage = 'ServerMessage:采集项已扫描完成，不允许再次扫描!';
        RETURN -1;
    END;

	--检查采集项是否符合检查规则
    EXEC @return_value= dbo.[Txn_CollectSettingSNCheck]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @CollectSettingId = @CollectSettingId ,
        @OrderName = @OrderName ,
        @MOId = @LotMOId ,
        @LotId = @LotId ,
        @LotSN = @LotSN ,
        @ItemValue = @ItemValue ,
        @CollectStr = @CollectStr;
		
    IF @return_value = -1
    BEGIN
		--返回网格数据
        SELECT  Product_CollectSetting.Sequence, CollectItem.CollectItemName, #CollectTemp.CollectSN
        FROM    Product_CollectSetting
        INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
        LEFT JOIN #CollectTemp ON #CollectTemp.CollectName = CollectItem.CollectItemName
        WHERE   Product_CollectSetting.ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId
        ORDER BY Product_CollectSetting.Sequence;

        SELECT  '' AS ItemValue, '0' AS IsPrint, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = @I_ReturnMessage;
        RETURN -1;
    END;

    IF ISNULL(@CollectStr, '') = ''
        SET @CollectStr = @ItemName + ',' + @ItemValue;
    ELSE
        SET @CollectStr = @CollectStr + ';' + @ItemName + ',' + @ItemValue;

	--获取主键ID，并插入临时表
    INSERT  INTO #CollectTemp ( CollectName, CollectSN )
    VALUES  ( @ItemName, @ItemValue );

	--检查是否已经扫描完成
	--查询中间表采集总数
    SELECT  @ScanTempCount = ISNULL(COUNT(DISTINCT CollectName), 0)
    FROM    #CollectTemp;

	--查询采集设置表维护采集项总数
    SELECT  @CollectCount = ISNULL(COUNT(Product_CollectSetting.Product_CollectSettingId), 0)
    FROM    Product_CollectSetting
    WHERE   Product_CollectSetting.ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId; 

    IF @ScanTempCount = @CollectCount AND (
                                            SELECT  COUNT(1)
                                            FROM    #CollectTemp
                                            WHERE   CollectName IN ( 'CAID', '十进制CAID' )
                                          ) = 2
    BEGIN

        DECLARE @CAID VARCHAR(20)= '';
        DECLARE @HEXCAID VARCHAR(20)= '';
        DECLARE @STRSQL NVARCHAR(MAX)= '';

        SELECT  @CAID = CollectSN
        FROM    #CollectTemp
        WHERE   CollectName = 'CAID';


        SELECT  @HEXCAID = CollectSN
        FROM    #CollectTemp
        WHERE   CollectName = '十进制CAID';

        IF ISNULL(@CAID, '') <> '' AND ISNULL(@HEXCAID, '') <> ''
        BEGIN
            DECLARE @T1 TABLE ( HEX VARCHAR(20) );
            SET @HEXCAID = '0X' + ISNULL(@HEXCAID,'')

            SET @STRSQL = 'select CONVERT(VARCHAR(50), CONVERT(bigint,' + @HEXCAID + ')) HEXID';

            INSERT  INTO @T1 ( HEX )
                    EXEC (
                           @STRSQL
                        );
            IF NOT EXISTS ( SELECT  *
                            FROM    @T1                      -- 327508822638
                            WHERE   HEX = LEFT(@CAID, 10) )  -- 3275088226
            BEGIN
                SELECT  '' AS ItemValue, '0' AS IsPrint, 'error.png' AS WarnImage;				
                SET @I_ReturnMessage = 'ServerMessage:CAID 与十进制CAID 不一致!';
                RETURN -1;
            END;
        END;  
    END;

	--如果扫描的采集项已等于设置项数
    IF @ScanTempCount = @CollectCount
    BEGIN
		--是否装配节点，是，则需要进行扣料倒冲
        IF EXISTS ( SELECT TOP 1
                            SpecificationId
                    FROM    Specification
                    WHERE   SpecificationId = @LotSpecificationId AND IsAssemblyStep = 1 )
        BEGIN
            EXEC @return_value= [dbo].[OtherBackflushDoMethod]
                @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
                @I_ResourceId = @I_ResourceId ,
                @I_OrBitUserId = @I_OrBitUserId ,
                @MOId = @LotMOId ,
                @ProductId = @LotProductId ,
                @WorkcenterId = @WorkcenterId ,
                @LotSN = @LotSN ,
                @MakeupNumber = 1;
		
			--倒冲扣数不成功，返回
            IF @return_value = -1
            BEGIN
				--如果扣数不成功，则删除最后一个采集项
                DELETE  #CollectTemp;
                SET @CollectStr = '';

                SELECT  Product_CollectSetting.Sequence, CollectItem.CollectItemName, #CollectTemp.CollectSN
                FROM    Product_CollectSetting
                INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
                LEFT JOIN #CollectTemp ON #CollectTemp.CollectName = CollectItem.CollectItemName
                WHERE   Product_CollectSetting.ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId
                ORDER BY Product_CollectSetting.Sequence;

                SELECT  '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
                SET @I_ReturnMessage = @I_ReturnMessage;
                SET @I_ExceptionFieldName = 'LotSN';
                RETURN -1;
            END;	
        END;

		--检查 Lot 是否已存在当前规程的采集项数据，如果已存在，则失效历史记录
        IF EXISTS ( SELECT TOP 1
                            DataChainAssemblyId
                    FROM    DataChainAssembly
                    WHERE   LotId = @LotId AND SpecificationId = @LotSpecificationId AND IsCancel = 0 )
        BEGIN
            DECLARE mycursor2 CURSOR
            FOR
            SELECT  DataChainAssemblyId
            FROM    DataChainAssembly
            WHERE   LotId = @LotId AND SpecificationId = @LotSpecificationId AND IsCancel = 0;
            OPEN mycursor2;
            FETCH NEXT FROM mycursor2 
			INTO @DataChainAssemblyId;
            WHILE @@fetch_status = 0
            BEGIN
                BEGIN TRAN;
                UPDATE  DataChainAssembly
                SET     IsCancel = 1
                WHERE   DataChainAssemblyId = @DataChainAssemblyId;
                COMMIT TRAN;
				
                FETCH NEXT FROM mycursor2 
				INTO @DataChainAssemblyId;
            END; 
            CLOSE mycursor2;
            DEALLOCATE mycursor2; 
        END;


		--检查采集项是否一致，（如 伴侣MAC和核对伴侣MAC）
        DECLARE cursorcheck CURSOR
        FOR
        SELECT  CollectItem.CollectItemId, CollectItem.CollectItemName AS ItemName, #CollectTemp.CollectSN
        FROM    #CollectTemp
        INNER JOIN CollectItem ON CollectItem.CollectItemName = #CollectTemp.CollectName; 
        OPEN cursorcheck;
        FETCH NEXT FROM cursorcheck 
		INTO @CollectItemId, @ItemName, @CollectSN;
        WHILE @@fetch_status = 0
        BEGIN
			
			--如果前两位为 “核对”,则检查后面一截的是否采集数据一致，不一致则提示
            IF LEFT(@ItemName, 2) = '核对' AND EXISTS ( SELECT    ID
                                                      FROM      #CollectTemp
                                                      WHERE     CollectName = REPLACE(@ItemName, '核对', '') )
            BEGIN
                SET @CheckCollectSN = '';
                SET @CheckCollectName = '';

                SELECT  @CheckCollectSN = ISNULL(CollectSN, ''), @CheckCollectName = CollectName
                FROM    #CollectTemp
                WHERE   CollectName = REPLACE(@ItemName, '核对', '');

                IF ISNULL(@CheckCollectSN, '') <> @CollectSN
                BEGIN
					--返回网格数据
                    SELECT  Product_CollectSetting.Sequence, CollectItem.CollectItemName, #CollectTemp.CollectSN
                    FROM    Product_CollectSetting
                    INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
                    LEFT JOIN #CollectTemp ON #CollectTemp.CollectName = CollectItem.CollectItemName
                    WHERE   Product_CollectSetting.ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId
                    ORDER BY Product_CollectSetting.Sequence;

                    SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
                    SET @I_ReturnMessage = 'ServerMessage:采集项 [' + @ItemName + '] 与 [' + @CheckCollectName + '] 数据不一致，检查不通过！';
                    SET @I_ExceptionFieldName = 'LotSN';
                    RETURN -1;
                END;
            END;

			--如果前三位为 “十进制”,则检查转化为10进制的采集数据是否一致，不一致则提示
            IF LEFT(@ItemName, 3) = '十进制' AND EXISTS ( SELECT   ID
                                                       FROM     #CollectTemp
                                                       WHERE    CollectName = REPLACE(@ItemName, '十进制', '') )
            BEGIN
                SET @CheckCollectSN = '';
                SET @CheckCollectName = '';

                SELECT  @CheckCollectSN = ISNULL(CollectSN, ''), @CheckCollectName = CollectName
                FROM    #CollectTemp
                WHERE   CollectName = REPLACE(@ItemName, '十进制', '');

                SET @CollectSN = [dbo].[ConvertDecimalTo10](16, @CollectSN);

                IF CHARINDEX(@CollectSN, @CheckCollectSN) = 0
                BEGIN
					--返回网格数据
                    SELECT  Product_CollectSetting.Sequence, CollectItem.CollectItemName, #CollectTemp.CollectSN
                    FROM    Product_CollectSetting
                    INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
                    LEFT JOIN #CollectTemp ON #CollectTemp.CollectName = CollectItem.CollectItemName
                    WHERE   Product_CollectSetting.ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId
                    ORDER BY Product_CollectSetting.Sequence;

                    SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
                    SET @I_ReturnMessage = 'ServerMessage:采集项 [' + @ItemName + '] 与 [' + @CheckCollectName + '] 数据不一致，检查不通过！';
                    SET @I_ExceptionFieldName = 'LotSN';
                    RETURN -1;
                END;
            END;
            FETCH NEXT FROM cursorcheck 
			INTO @CollectItemId, @ItemName, @CollectSN;
        END; 
        CLOSE cursorcheck;
        DEALLOCATE cursorcheck; 


		--游标循环写入采集项数据
        DECLARE mycursor CURSOR
        FOR
        SELECT  CollectItem.CollectItemId, CollectItem.CollectItemName AS ItemName, #CollectTemp.CollectSN
        FROM    #CollectTemp
        INNER JOIN CollectItem ON CollectItem.CollectItemName = #CollectTemp.CollectName; 
        OPEN mycursor;
        FETCH NEXT FROM mycursor 
		INTO @CollectItemId, @ItemName, @CollectSN;
        WHILE @@fetch_status = 0
        BEGIN
            IF ISNULL(@DataChainId, '') = ''
            BEGIN
				--产生DataChain返回数据链Id
                EXEC [dbo].[TxnBase_DataChainMainLine]
                    @DataChainId = @DataChainId OUTPUT ,
                    @TxnCode = @TxnCode ,
                    @I_PlugInCommand = @I_PlugInCommand ,
                    @I_OrBitUserId = @I_OrBitUserId ,
                    @I_ResourceId = @I_ResourceId ,
                    @LotId = @LotId ,
                    @MOId = @LotMOId ,
                    @ProductId = @LotProductId ,
                    @WorkcenterId = @WorkcenterId ,
                    @SpecificationId = @LotSpecificationId ,
                    @WorkflowStepId = @LotWorkflowStepId;
            END;

			--获取表主键Id
            EXEC SysGetObjectPKId
                '' ,
                'DataChainAssembly' ,
                @DataChainAssemblyId OUTPUT;
	
			--插入DataChainAssembly 表中
            INSERT  INTO DataChainAssembly ( DataChainAssemblyId, DataChainId, LotId, ProductId, MOId, ItemName,
                                             CollectSN, Operator, WorkflowId, SpecificationId, WorkflowStepId,
                                             WorkcenterId, ResourceId, UserId )
            VALUES  ( @DataChainAssemblyId, @DataChainId, @LotId, @LotProductId, @LotMOId, @ItemName, @CollectSN,
                      @Operator, @LotWorkflowId, @LotSpecificationId, @LotWorkflowStepId, @WorkcenterId, @I_ResourceId,
                      @I_OrBitUserId );
			
				--如果是订单字段，则检查订单字段是否存在，存在则回写订单字段数据  --add by She ZHENZHEN
            IF EXISTS ( SELECT  1
                        FROM    CollectItem
                        WHERE   CollectItemId = @CollectItemId AND IsField = 1 )
            BEGIN
					--检查是否预制表字段
                SET @FieldSettingId = '';
                SELECT  @FieldSettingId = FieldSettingId
                FROM    FieldSetting
                WHERE   FieldName = @ItemName;

                IF ISNULL(@FieldSettingId, '') <> ''
                BEGIN
						--是否预制字段
                    IF EXISTS ( SELECT  1
                                FROM    OrderFieldSettingItem
                                WHERE   OrderFieldSettingId = @OrderFieldSettingId AND FieldSettingId = @FieldSettingId AND Mode = '' )
                    BEGIN
							--更新当前 OrderSetItem 表数据
                        SET @sql = '';
                        SET @sql = 'UPDATE OrderSetItem SET ' + @ItemName + '=''' + @CollectSN + ''' WHERE LotId=''' + @LotId + ''' ';
                        EXEC (@sql);
                    END;
                END;
            END;
                
			   --- 更二维码
            IF @ItemName = 'BarcodeCheck'
            BEGIN
                SELECT TOP 1
                        @issole = a.IsSole
                FROM    Product_CollectSetting a WITH ( NOLOCK )
                INNER JOIN CollectItem b WITH ( NOLOCK ) ON b.CollectItemId = a.CollectItemId
                WHERE   a.ProductId = @LotProductId AND b.CollectItemName = @ItemName;
                UPDATE  BarcodeCheck
                SET     IsUse = @issole, Moid = @LotMOId, Productid = @LotProductId, lotsn = @LotSN
                WHERE   LEFT(OrderName, 10) = LEFT(@OrderName, 10) AND Barcode2d = @CollectSN AND IsUse = 0;
				

            END;


            FETCH NEXT FROM mycursor 
			INTO @CollectItemId, @ItemName, @CollectSN;
        END; 
        CLOSE mycursor;
        DEALLOCATE mycursor; 

		--统计在制品
        EXEC [dbo].[DataChainWIPDoMethod]
            @I_OrBitUserId = @I_OrBitUserId ,
            @I_ResourceId = @I_ResourceId ,
            @MOId = @LotMOId ,
            @LotId = @LotId ,
            @WorkcenterId = @WorkcenterId ,
            @MoveResult = 'P' ,
            @FinishQty = @FinishQty OUTPUT;

		--传送 LotSN 到工作流下一节点
        EXEC [dbo].[TxnBase_LotMove]
            @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
            @I_OrBitUserId = @I_OrBitUserId ,
            @I_ResourceId = @I_ResourceId ,
            @LotSN = @LotSN ,
            @LotInDate = @Date;

		--删除中间表数据
        DELETE  #CollectTemp;
        SET @CollectStr = '';

		--返回网格数据
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN, @FinishQty AS FinishQty;
        SELECT  @LotSN AS TLotSN, '' AS LotSN, '' AS ItemValue, @FinishQty AS FinishQty, '' AS CollectStr,
                '1' AS IsPrint, 'ok.png' AS WarnImage;
		
        SET @I_ExceptionFieldName = 'LotSN';
        SET @I_ReturnMessage = @I_ReturnMessage;

        RETURN 0;
    END;

	--获取下一个采集项
    SELECT TOP 1
            @NextItemName = CollectItem.CollectItemName
    FROM    Product_CollectSetting
    INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
    WHERE   ProductId = @LotProductId AND SpecificationId = @LotSpecificationId AND Sequence > @Sequence
    ORDER BY Product_CollectSetting.Sequence;

	--返回网格数据
    SELECT  Product_CollectSetting.Sequence, CollectItem.CollectItemName, #CollectTemp.CollectSN
    FROM    Product_CollectSetting
    INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
    LEFT JOIN #CollectTemp ON #CollectTemp.CollectName = CollectItem.CollectItemName
    WHERE   Product_CollectSetting.ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId
    ORDER BY Product_CollectSetting.Sequence;

    SELECT  @NextItemName AS NextItemName, '' AS ItemValue, @CollectStr AS CollectStr, '0' AS IsPrint,
            'right.png' AS WarnImage, @FinishQty AS FinishQty;

    SET @I_ReturnMessage = 'ServerMessage:采集项 [' + @ItemValue + '] 采集成功，请继续扫描! [' + @NextItemName + ']';
    RETURN 0;

END;















