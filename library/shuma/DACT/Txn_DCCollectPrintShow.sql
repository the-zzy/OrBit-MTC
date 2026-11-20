-- =============================================
-- Author:		<OrBit benson>
-- Create date: <2016.09.02>
-- Description:	<采集打印-显示>
-- =============================================
/*
	修改日志： 
	2019.05.25 增加扫描装箱字段识别主批号

*/

CREATE PROCEDURE [dbo].[Txn_DCCollectPrintShow]
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
    @LotSN NVARCHAR(500) = '' ,             --产品批号
    @ItemValue NVARCHAR(500) = '' ,         --采集项
    @CollectStr NVARCHAR(MAX) = '' ,
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
    DECLARE @MESTxnObjectName NVARCHAR(50);  --事务对象名称
    DECLARE @MONameOld NVARCHAR(50);             ---------原来的是@MOName 全部替换成了 @MONameOld，共四处替换了，2021.7.22 李鲜
    DECLARE @ProductName NVARCHAR(50);
    DECLARE @WorkcenterId CHAR(12);
    DECLARE @WorkcenterName NVARCHAR(50);
    DECLARE @LotId CHAR(12);	
    DECLARE @LotStatus VARCHAR(10);
    DECLARE @LotProductId CHAR(12);
    DECLARE @LotMOId CHAR(12);
    DECLARE @LotSpecificationId CHAR(12);
    DECLARE @LotSpecificationName NVARCHAR(50);
    DECLARE @LotWorkflowStepId CHAR(12);
    DECLARE @LotOrderName NVARCHAR(50);
    DECLARE @CollectCount INT;        --采集项的项数
    DECLARE @ScanCount INT;            --扫描的采集项个数
    DECLARE @NextItemName NVARCHAR(50);
    DECLARE @MOQtyRequired DECIMAL(18, 2);
    DECLARE @ChipId NVARCHAR(50)= '';
    DECLARE @ModelSettingId CHAR(12)= '';

    SET @return_value = -1;
    SET @I_ExceptionFieldName = 'LotSN';	
    SET @TxnCode = 'DC';
    SET @MESTxnObjectName = 'DC CollectPrint';
    SET @Date = GETDATE();
    SET @WorkcenterId = '';
    SET @WorkcenterName = '';
    SET @MONameOld = '';
    SET @ProductName = '';
    SET @WorkcenterId = '';
    SET @LotId = '';
    SET @LotProductId = '';
    SET @LotMOId = '';
    SET @LotSpecificationId = '';
    SET @LotSpecificationName = '';
    SET @LotStatus = '';
    SET @LotOrderName = '';
    SET @LotWorkflowStepId = '';
    SET @CollectCount = 0;
    SET @ScanCount = 0;
    SET @NextItemName = '';
    SET @MOQtyRequired = 0;

	--转换大写
    SET @LotSN = UPPER(RTRIM(LTRIM(@LotSN)));

	--检查资源是否已维护
    IF ISNULL(@I_ResourceId, '') = ''
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:资源 [' + @I_ResourceName + '] 未在 MES 系统中登记，请检查!';
        RETURN -1;
    END;

	--检查是否为空
    IF ISNULL(@OrderName, '') = ''
    BEGIN	
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
		
        SET @I_ReturnMessage = 'ServerMessage:请输入工单号!';
        SET @I_ExceptionFieldName = 'OrderName';
        RETURN -1;
    END;

	--检查工号是否存在
    IF NOT EXISTS ( SELECT  1
                    FROM    PersonInfo
                    WHERE   PersonNumber = @Operator AND IsActivity = 1 )
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS Operator, '' AS LotSN, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:操作员工号 [' + @Operator + '] 无效，请检查!';
        SET @I_ExceptionFieldName = 'Operator';
        RETURN -1;
    END;
	
	-- Add by Wang AL 2019.05.25 
---------------------------------------------根据装箱字段识别主批号BEGIN----------------------------------------------------------------

    DECLARE @ScanLotSN VARCHAR(100)= '';
    DECLARE @FieldName VARCHAR(30)= '';
    DECLARE @SqlStr NVARCHAR(2000)= '';
    DECLARE @MinId INT= 0;
    DECLARE @MaxId INT= 0;

    DECLARE @TempFieldName TABLE
        (
          Seq INT IDENTITY(1, 1) ,
          FieldName VARCHAR(30)
        );


    DECLARE @TempLotSN TABLE
        (
          Seq INT IDENTITY(1, 1) ,
          FiledName VARCHAR(30) ,
          LotSN VARCHAR(100)
        );

    INSERT  INTO @TempFieldName ( FieldName )
            SELECT  c.FieldName
            FROM    dbo.OrderFieldSetting a ( NOLOCK )
            LEFT JOIN dbo.OrderFieldSettingItem b ( NOLOCK ) ON b.OrderFieldSettingId = a.OrderFieldSettingId
            LEFT JOIN dbo.FieldSetting c ( NOLOCK ) ON c.FieldSettingId = b.FieldSettingId
            WHERE   a.OrderName = @OrderName AND b.PackField = 1;





			
		--------------- add  采集扫描show  李鲜 2021.7.22 多码合一，分格符-------
	---------在OrderFieldSetting表中MOName只有null和10位       @MOId是根据值列表获取的，已经去除了前面的0   [dbo].[RemoveZero](MO.MOName) as MOName,

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




    IF ISNULL(@LotSN, '') <> 'SUBMIT' AND NOT EXISTS ( SELECT   1
                                                       FROM     Lot(NOLOCK)
                                                       WHERE    LotSN = @LotSN )
    BEGIN
        SELECT  @ScanLotSN = ISNULL(LotSN, '')
        FROM    dbo.Lot(NOLOCK)
        WHERE   LotSN = @LotSN;

        IF ISNULL(@ScanLotSN, '') = ''
        BEGIN 

            SELECT  @MinId = MIN(Seq), @MaxId = MAX(Seq)
            FROM    @TempFieldName;

            WHILE @MinId <= @MaxId
            BEGIN 
                SELECT  @FieldName = FieldName, @ScanLotSN = ''
                FROM    @TempFieldName
                WHERE   Seq = @MinId;

                SET @MinId = @MinId + 1;

                SET @SqlStr = 'SELECT   @ScanLotSN = ISNULL(b.LotSN, '''')  FROM dbo.OrderSetItem a(NOLOCK) LEFT JOIN dbo.Lot b(NOLOCK) ON b.LotId = a.LotId  WHERE  a.' + @FieldName + '=''' + @LotSN + ''' ';

                EXEC sp_executesql
                    @SqlStr ,
                    N'@ScanLotSN VARCHAR(100) OUT' ,
                    @ScanLotSN OUTPUT;  

                IF ISNULL(@ScanLotSN, '') <> ''
                BEGIN 
                    INSERT  INTO @TempLotSN ( FiledName, LotSN )
                    VALUES  ( @FieldName, ISNULL(@ScanLotSN, '') );
                    BREAK;
                END; 
            END; 		
        
        END;     

        IF EXISTS ( SELECT  *
                    FROM    @TempLotSN
                    WHERE   ISNULL(LotSN, '') <> '' )
        BEGIN 
            SELECT  @LotSN = LotSN
            FROM    @TempLotSN
            WHERE   ISNULL(LotSN, '') <> '';
        END; 

    END; 


---------------------------------------------根据装箱字段识别主批号END  ----------------------------------------------------------------

	--LotSN 是否有效
    IF NOT EXISTS ( SELECT  1
                    FROM    Lot
                    WHERE   LotSN = @LotSN )
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:产品条码 [' + @LotSN + '] 无效，请检查!';
        RETURN -1;
    END;

	--查询整机 Lot 信息
    SELECT  @LotId = LotId, @LotStatus = LotStatus, @LotProductId = ProductId, @LotMOId = MOId,
            @LotSpecificationId = SpecificationId, @LotWorkflowStepId = WorkflowStepId, @LotOrderName = OrderName
    FROM    Lot
    WHERE   LotSN = @LotSN;

    IF ISNULL(@LotStatus, '') <> '1'
    BEGIN
		--返回界面
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:产品批号 [' + @LotSN + '] 状态不可用!';
        RETURN -1;
    END;

    IF ISNULL(@OrderName, '') <> ISNULL(@LotOrderName, '')
    BEGIN
		--返回界面
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:产品批号 [' + @LotSN + '] 不属于此订单 [' + @OrderName + ']，应为订单 [' + @LotOrderName + ']，请检查!';
        RETURN -1;
    END;

	--检查资源或者用户是否允许操作此规程
    EXEC @return_value= dbo.[SysCheckSpecification]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @WorkcenterId = @WorkcenterId OUTPUT ,
        @LotId = @LotId ,
        @I_OrBitUserId = @I_OrBitUserId ,
        @I_OrBitUserName = @I_OrBitUserName ,
        @I_ResourceId = @I_ResourceId ,
        @I_ResourceName = @I_ResourceName ,
        @SpecificationId = @LotSpecificationId ,
        @MESTxnObjectName = @MESTxnObjectName;

    IF @return_value = -1
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = @I_ReturnMessage;
        RETURN -1;
    END;

    IF ISNULL(@WorkcenterId, '') = ''
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:用户 [' + @I_OrBitUserName + '] 或者资源 [' + @I_ResourceName + '] 未绑定线体，不允许操作![' + @WorkcenterId;
        RETURN -1;
    END;

	--检查订单字段规则
    EXEC @return_value= dbo.[CheckOrderFieldAV]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @LotId = @LotId ,
        @I_OrBitUserId = @I_OrBitUserId ,
        @I_OrBitUserName = @I_OrBitUserName ,
        @I_ResourceId = @I_ResourceId ,
        @I_ResourceName = @I_ResourceName ,
        @SpecificationId = @LotSpecificationId ,
        @MESTxnObjectName = @MESTxnObjectName;

    IF @return_value = -1
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = @I_ReturnMessage;
        RETURN -1;
    END;

	--全部检查ChipId 
	--select @ChipId =ISNULL (ChipId,'') from  OrderSetItem where LotId=@LotId

	--if (select  COUNT(OrderSetItemId) from OrderSetItem where ChipId= @ChipId  and ChipId <>'')>=2
	--begin
	--	set @I_ReturnMessage='ServerMessage:批号 ['+@LotSN+'] 对应的字段ChipId：'+@ChipId+' 重复'
	--	return -1
	--end		

    SELECT  @WorkcenterName = WorkcenterName
    FROM    Workcenter
    WHERE   WorkcenterId = @WorkcenterId;

    SELECT  @MONameOld = MO.MOName, @MOQtyRequired = MO.MOQtyRequired
    FROM    MO
    WHERE   MOId = @LotMOId;

    SELECT  @ProductName = ProductRoot.ProductName
    FROM    Product
    INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
    WHERE   Product.ProductId = @LotProductId;
	
	--获取规程信息
    SELECT  @LotSpecificationName = SpecificationRoot.SpecificationName
    FROM    Specification
    INNER JOIN SpecificationRoot ON SpecificationRoot.SpecificationRootId = Specification.SpecificationRootId
    WHERE   Specification.SpecificationId = @LotSpecificationId;

	--检查产品中是否有维护组装上线采集项内容
    IF NOT EXISTS ( SELECT  1
                    FROM    Product_CollectSetting
                    WHERE   ProductId = @LotProductId AND SpecificationId = @LotSpecificationId )
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:产品 [' + @ProductName + '] 未维护规程 [' + @LotSpecificationName + '] 的采集项，请检查!';
        RETURN -1;
    END;

	--如果不需要维护采集项
    IF EXISTS ( SELECT  1
                FROM    Product_CollectSetting
                INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
                WHERE   Product_CollectSetting.ProductId = @LotProductId AND SpecificationId = @LotSpecificationId AND CollectItem.CollectItemName = 'NULL' )
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
                SET @I_ReturnMessage = @I_ReturnMessage;	

                SELECT  '' AS Info;
                SELECT  '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'error.png' AS WarnImage;
                SET @I_ExceptionFieldName = 'LotSN';
                RETURN -1;
            END;	
        END;
	
		--传送 LotSN 到工作流下一节点
        EXEC [dbo].[TxnBase_LotMove]
            @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
            @I_OrBitUserId = @I_OrBitUserId ,
            @I_ResourceId = @I_ResourceId ,
            @LotSN = @LotSN ,
            @LotInDate = @Date;

		--统计在制品
        EXEC [dbo].[DataChainWIPDoMethod]
            @I_OrBitUserId = @I_OrBitUserId ,
            @I_ResourceId = @I_ResourceId ,
            @MOId = @LotMOId ,
            @LotId = @LotId ,
            @WorkcenterId = @WorkcenterId ,
            @MoveResult = 'P';
					
		--返回网格数据
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectStr, '' AS CollectSN;
        SELECT  @LotSN AS TLotSN, '' AS LotSN, '' AS ItemValue, '1' AS IsPrint, 'right.png' AS WarnImage;
		
        SET @I_ReturnMessage = @I_ReturnMessage;

        RETURN 0;
    END;
	
	--检查采集项是否都已维护检查规则
    EXEC @return_value= [dbo].[Txn_CollectSettingRuleCheck]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @ProductId = @LotProductId ,
        @SpecificationId = @LotSpecificationId;

    IF @return_value = -1
    BEGIN
        SELECT  '' AS ID, '' AS CollectName, '' AS CollectStr, '' AS CollectSN;
        SELECT  '' AS LotSN, '' AS ItemValue, '0' AS IsPrint, 'error.png' AS WarnImage;
		
        SET @I_ReturnMessage = @I_ReturnMessage;
        RETURN -1;
    END;
	
	--获取当前站第一个采集项
    SELECT TOP 1
            @NextItemName = CollectItem.CollectItemName
    FROM    Product_CollectSetting
    INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
    WHERE   ProductId = @LotProductId AND SpecificationId = @LotSpecificationId
    ORDER BY Sequence;

	--返回网格数据
    SELECT  Product_CollectSetting.Sequence, CollectItem.CollectItemName, '' AS CollectSN
    FROM    Product_CollectSetting
    INNER JOIN CollectItem ON CollectItem.CollectItemId = Product_CollectSetting.CollectItemId
    WHERE   Product_CollectSetting.ProductId = @LotProductId AND Product_CollectSetting.SpecificationId = @LotSpecificationId
    ORDER BY Product_CollectSetting.Sequence;	

    SELECT  @MONameOld AS MOName, @ProductName AS ProductName, @MOQtyRequired AS MOQtyRequired,
            @NextItemName AS NextItemName, '' AS ItemValue, '' AS CollectStr, '0' AS IsPrint, 'right.png' AS WarnImage,
            @LotSN AS TLotSN;

    SET @I_ReturnMessage = 'ServerMessage:请扫描 [' + ISNULL(@NextItemName, '') + ']!';

    SET @I_ExceptionFieldName = 'ItemValue';

    RETURN 0;
	
END;






