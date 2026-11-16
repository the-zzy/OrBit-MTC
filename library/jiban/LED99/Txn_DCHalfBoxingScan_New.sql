-- =============================================
-- Author:		<LZH>
-- Create date: <2023.6.14>
-- Description:	半成品装箱扫描
-- 组装的装箱标签打印
-- =============================================
CREATE PROCEDURE dbo.Txn_DCHalfBoxingScan_New
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
    @I_Parameter NVARCHAR(100) = '' ,       --插件参数

--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @IsSwitchTab BIT = 0 ,				--是否是切换页签（第一次打开是0）
    @StdQtyOfBox INT = 0 ,
    @ScanSN NVARCHAR(100) = '' ,
    @Operator NVARCHAR(50) = '' ,
    @LotStr NVARCHAR(MAX) = '' ,
    @IsOnLinePrint BIT = 0 , --是否在线打印
    @Print_ProductId CHAR(12) = '' , --在线打印页签的产品是否一致
    @PrintPassword NVARCHAR(50) = '' , --手动打印密码
    @VerNumber NVARCHAR(50) = '' ,   --版次
    @FLType NVARCHAR(10) = '' ,	  --装箱类型
    @FLTypeId NVARCHAR(4) = '' ,      --装箱类型编号
    @TypeStr NVARCHAR(10) = '' ,	   --类型字符
    @BoxType NVARCHAR(10) = '' ,
    @ProductName NVARCHAR(50) = '' ,
    @MOName NVARCHAR(50) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--通用变量
    DECLARE @return_value INT= -1;
    DECLARE @TxnCode VARCHAR(10)= 'DC';
    DECLARE @CurDate DATETIME= GETDATE();
    DECLARE @WorkcenterId CHAR(12)= '';
    DECLARE @WorkcenterName NVARCHAR(50)= '';
    DECLARE @DataChainId CHAR(12)= ''; 
    DECLARE @Cmd_Box NVARCHAR(50)= 'SUBMIT';
    DECLARE @TempIntQty INT= 0;
    DECLARE @PLotSN NVARCHAR(100)= '';  --临时批号
    DECLARE @ScanedQty INT= 0; --已扫描数
    DECLARE @AvailableQuantity INT = 0;  --759工单剩余可用批号数量

	--批号信息
    DECLARE @MOId CHAR(12) = '';
    DECLARE @LotId CHAR(12)= '';
    DECLARE @LotSN NVARCHAR(100)= '';
    DECLARE @MLotSN NVARCHAR(100)= ''; --575批号
    DECLARE @TLotSN NVARCHAR(100)= ''; --759批号
    DECLARE @LotStatus CHAR(1)= '';
    DECLARE @LotQty FLOAT;
    DECLARE @LotMOId CHAR(12)= '';
    DECLARE @LotMOName NVARCHAR(50)= '';
    DECLARE @LotProductId CHAR(12)= '';
    DECLARE @LotProductName NVARCHAR(50)= '';
    DECLARE @LotIsHybridPack BIT= 0; --是否允许混包：即不同工单是否允许装在一起
    DECLARE @LotWorkflowId CHAR(12)= '';
    DECLARE @LotWorkflowStepId CHAR(12)= '';
    DECLARE @LotWorkflowStepName NVARCHAR(50)= '';
    DECLARE @LotSpecificationId CHAR(12)= '';
    DECLARE @LotSpecificationName NVARCHAR(50)= '';
    DECLARE @LotMOItemTaskId CHAR(12)= '';
    DECLARE @LotMOItemId CHAR(12)= '';
    DECLARE @MOItemQtyRequired FLOAT= 0;

	--打印机设置的料号
    DECLARE @Print_ProductName NVARCHAR(50)= '';

	--装箱信息
    DECLARE @ShipBoxId CHAR(12)= '';
    DECLARE @BoxSN NVARCHAR(100)= '';
    DECLARE @CartonNo NVARCHAR(50)= '';    --中箱标签
    DECLARE @RuleTypeRChar NVARCHAR(100)= '';   --规则中的预留字符
    DECLARE @TempMoName NVARCHAR(50)= '';

	--获取已扫描产品批号中单个批号信息
    DECLARE @TopLotSN NVARCHAR(100)= '';
    DECLARE @TopProductId CHAR(12)= '';
    DECLARE @TopProductName NVARCHAR(50)= '';
    DECLARE @TopMOId CHAR(12)= '';
    DECLARE @TopMOName NVARCHAR(50)= '';
    DECLARE @TopWorkflowStepId CHAR(12)= '';
    DECLARE @TopWorkflowStepName NVARCHAR(50)= '';
    DECLARE @BatterySN NVARCHAR(100)= '';
    DECLARE @MESTxnObjectName NVARCHAR(50)= 'LEDHalfFinished Boxing Scan';
    DECLARE @TopLotId CHAR(12)= '';
    DECLARE @TOPLotSpecificationId CHAR(12)= '';

    DECLARE @ProLevel INT; --判定等级品
    DECLARE @TOPProLevel INT; --原等级

    SET @MOName = dbo.RemoveZero2(@MOName);

	
    DECLARE @OutPutTable TABLE
    (
      RowNO INT IDENTITY(1, 1) ,
      LotId CHAR(12) ,
      FLType_ NVARCHAR(10) ,
      LotSN_ NVARCHAR(100) NULL ,
      MOName_ NVARCHAR(50)
    );
       
    DECLARE @BoxDataTable TABLE
    (
      RowNO INT IDENTITY(1, 1) ,
      LotSN NVARCHAR(100)
    );

	--转换大写
    SET @LotSN = UPPER(LTRIM(RTRIM(@LotSN)));
    SET @Operator = UPPER(LTRIM(RTRIM(@Operator)));
    SET @I_ExceptionFieldName = 'ScanSN';
    SET @StdQtyOfBox = ISNULL(@StdQtyOfBox, 0);

    SET @FLType = '箱体';
    SET @FLTypeId = '01';
    SET @BoxType = '0';

	--如果参数不为空，则写入表变量
    IF ISNULL(@LotStr, '') <> ''
    BEGIN
        SET @PLotSN = '';
        DELETE  @OutPutTable;

        DECLARE cursor1 CURSOR LOCAL FAST_FORWARD
        FOR
        SELECT  parameter_Value
        FROM    dbo.ConvertParameterToTable(@LotStr, ';')
        WHERE   ISNULL(parameter_Value, '') <> '';
        OPEN cursor1;
        FETCH NEXT FROM cursor1 
		INTO @PLotSN;
        WHILE @@fetch_status = 0
        BEGIN
			--写入表变量数据
            INSERT  INTO @OutPutTable ( LotSN_ )
            VALUES  ( @PLotSN );
				
            FETCH NEXT FROM cursor1 
			INTO @PLotSN;
        END; 
        CLOSE cursor1;
        DEALLOCATE cursor1; 

        UPDATE  @OutPutTable
        SET     LotId = Lot.LotId, MOName_ = RIGHT(MO.MOName, 10), FLType_ = @FLType
        FROM    @OutPutTable A
        INNER JOIN dbo.Lot ON Lot.LotSN = A.LotSN_
        INNER JOIN dbo.MO ON Lot.MOId = MO.MOId

    END;

	-- 《功能按钮》一、界面加载方法
    IF @I_Sender = 'LoadExe'
    BEGIN
		--界面第一次打开
        IF @IsSwitchTab = 0
        BEGIN 
			--返回界面数据
            DELETE  @OutPutTable;
            SELECT  RowNO, FLType_, LotSN_, MOName_
            FROM    @OutPutTable
            ORDER BY RowNO DESC;

            SELECT  '' AS Operator, '' AS ScanSN, '' AS LotStr, 0 AS ScanedQty, '' AS VerNumber, '' AS ProductName,
                    '' AS StdQtyOfBox, @WorkcenterName AS WorkcenterName, '' AS TypeStr, '' AS IsPrint, '' AS TBoxSN,
                    'OK.png' AS WarnImage, CAST(1 AS BIT) IsSwitchTab;
            SET @I_ExceptionFieldName = 'BoxTypeDescription';
            SET @I_ReturnMessage = 'ServerMessage:请依次扫描内包装条码(等于产品条码)，扫描个数等于装箱数时则会自动打印外箱标签！！！！';	
            RETURN 0;
        END;	

        RETURN 0;
    END; 

	-- 《功能按钮》二、清空数据
    IF @I_Sender = 'PageClear'
    BEGIN
		--删除临时表数据
        DELETE  @OutPutTable;

		--返回界面数据
        SELECT  RowNO, FLType_, LotSN_, MOName_
        FROM    @OutPutTable
        ORDER BY RowNO DESC;
		
        SELECT  '' AS ScanSN, '' AS LotStr, 0 AS ScanedQty, '' AS VerNumber,
                '' AS IsPrint, '' AS TBoxSN, '' AS FLTypeId, '' AS FlType, '' AS Typestr, '' AS WorkcenterName,
                'ok.png' AS WarnImage, '' AS MOName;

        SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}数据清除成功，请重新装箱!';
        RETURN 0;
    END;


    IF ISNULL(@Operator, '') = ''
    BEGIN
		--返回界面数据
        DELETE  @OutPutTable;
        SELECT  RowNO, FLType_, LotSN_, MOName_
        FROM    @OutPutTable
        ORDER BY RowNO DESC;

        SELECT  '' AS Operator, '' AS ScanSN, '' AS LotStr, 0 AS ScanedQty, '' AS ProductName, '' AS StdQtyOfBox,
                '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}请扫描员工工号!';
        SET @I_ExceptionFieldName = 'Operator';
        RETURN -1;
    END;

	--检查工号是否存在
    IF NOT EXISTS ( SELECT  1
                    FROM    dbo.PersonInfo
                    WHERE   PersonNumber = @Operator )
    BEGIN
		--返回界面数据
        DELETE  @OutPutTable;
        SELECT  RowNO, FLType_, LotSN_, MOName_
        FROM    @OutPutTable
        ORDER BY RowNO DESC;

        SELECT  '' AS Operator, '' AS ScanSN, '' AS LotStr, 0 AS ScanedQty, '' AS ProductName, '' AS StdQtyOfBox,
                '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}员工工号【' + @Operator + '】无效，请检查!';
        SET @I_ExceptionFieldName = 'Operator';
        RETURN -1;
    END
   
    --检查工单
    IF NOT EXISTS ( SELECT 1
                    FROM    dbo.MO
                    WHERE   MOName = '00' + @MOName )
    BEGIN
        SELECT  RowNO, LotSN_, MOName_
        FROM    @OutPutTable
        ORDER BY RowNO DESC;
	
        SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
        SET @I_ExceptionFieldName = 'MOName';
        SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}工单不存在，请检查工单！';
        RETURN -1;  
    END;

	--计算已扫描数
    SET @ScanedQty = 0;
    SELECT  @ScanedQty = COUNT(1)
    FROM    @OutPutTable;
   
    SELECT @MOId = MOId FROM MO WHERE MOName = '00' + @MOName;

	--这个逻辑正产情况下是不会执行的，因为只要@ScanedQty大于0，那么一定已经获取到了标准装箱数了
    IF ISNULL(@StdQtyOfBox, 0) < 1 AND @ScanedQty > 0
    BEGIN
        DELETE  @OutPutTable;
        SELECT  RowNO, FLType_, LotSN_, MOName_
        FROM    @OutPutTable
        ORDER BY RowNO DESC;

        SELECT  '' AS ScanSN, '' AS LotStr, 0 AS ScanedQty, '' AS ProductName, '' AS StdQtyOfBox, '' AS IsPrint,
                '' AS TBoxSN, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}标准装箱数必须大于0，请检查产品是否已维护！';
        SET @I_ExceptionFieldName = 'RealBoxQty';
        RETURN -1;
    END;
   
    IF ISNULL(@StdQtyOfBox, 0) <= 0
    BEGIN
        SELECT  RowNO, FLType_, LotSN_, MOName_
        FROM    @OutPutTable
        ORDER BY RowNO DESC;
		
        SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}没有指定标准装箱数，请检查!';
        RETURN -1;
    END;
   
    IF ISNULL(@ScanedQty, 0) >= @StdQtyOfBox
    BEGIN
        SELECT  RowNO, FLType_, LotSN_, MOName_
        FROM    @OutPutTable
        ORDER BY RowNO DESC;
		
        SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;

        SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}已装箱数大于标准装箱数，请清空界面重新扫描!';
        RETURN -1;
    END;

	--以下的逻辑为
	--1.扫描数小于装箱数，则继续扫描
	--2.等于，则扫描箱号，并保存--改成自动标签打印
	--3.大于，则报错
	--4.尾数箱时手动打印

	---执行手动标签打印时
    IF @I_Sender = 'ManPrintLabel'
    BEGIN
        SET @ScanSN = 'SUBMIT';
    END;	
   
    IF ISNULL(@ScanSN, '') = ''
    BEGIN
        SELECT  RowNO, FLType_, LotSN_, MOName_
        FROM    @OutPutTable
        ORDER BY RowNO DESC;
		
        SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}请扫描产品批号!';
        RETURN -1;
    END;

	-- 三、扫描产品条码
    IF @ScanedQty <= @StdQtyOfBox
    BEGIN
        SET @LotSN = @ScanSN;
       
        --主工单料号
        SELECT @ProductName = ProductName 
        FROM MO a
        INNER JOIN ProductRoot b ON a.ProductId = b.DefaultProductId
        WHERE a.MOName = '00' + @MOName;

        --575装箱759
        IF @FLTypeId = '01'
        BEGIN 
	        IF LEFT(@ProductName, 3) <> '759'
	        BEGIN
	        	SELECT  RowNO, FLType_, LotSN_, MOName_
                FROM    @OutPutTable
                ORDER BY RowNO DESC;
			
                SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
                SET @I_ExceptionFieldName = 'ScanSN';
                SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}当前包装类型必须输入759工单，请检查！';
                RETURN -1;   
	        END	        
	        
	        --验证电源板是否已组装575
            IF NOT EXISTS ( SELECT TOP 1
                                    1
                            FROM    dbo.DataChainAssyIssue
                            WHERE   IssueLotSN = @ScanSN AND IsCancel = 0)
            BEGIN
                SELECT  RowNO, FLType_, LotSN_, MOName_
                FROM    @OutPutTable
                ORDER BY RowNO DESC;
			
                SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
                SET @I_ExceptionFieldName = 'ScanSN';
                SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}电源板条码未组装，不能装箱！';
                RETURN -1;  
            END;                  
           
            --找到575批号
            SELECT  @LotSN = b.LotSN
            FROM    dbo.DataChainAssyIssue a
            LEFT JOIN dbo.Lot b ON a.AssyLotId = b.LotId
            WHERE   a.IssueLotSN = @ScanSN AND a.IsCancel = 0;
           
            --判断是否已经扫描
            IF EXISTS ( SELECT 1 FROM @OutPutTable WHERE LotSN_ = @LotSN )
		    BEGIN
				SELECT  RowNO, FLType_, LotSN_, MOName_
		        FROM    @OutPutTable
		        ORDER BY RowNO DESC;
		       
		        SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
		        SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}产品批号【' + @ScanSN + '】【' + @LotSN + '】已扫描，不允许重复扫描!';
		        RETURN -1;
		    END;
           
            --查询575批号信息
            SELECT  @LotId = LotId, @LotProductId = a.ProductId, @LotMOId = a.MOId, @LotWorkflowStepId = a.WorkflowStepId,
                @LotSpecificationId = a.SpecificationId, @LotProductName = b.ProductName, @LotMOName = RIGHT(c.MOName, 10)
	        FROM    dbo.Lot a
	        INNER JOIN ProductRoot b ON a.ProductId = b.DefaultProductId
	        INNER JOIN MO c ON a.MOId = c.MOId
	        WHERE   LotSN = @LotSN;
	       
	        --验证该575组件是否已组装759
	        IF EXISTS ( SELECT  1
                            FROM    DataChainAssyIssue
                            WHERE IssueLotId = @LotId AND IsCancel = 0)
            BEGIN
                SELECT  RowNO, FLType_, LotSN_, MOName_
                FROM    @OutPutTable
                ORDER BY RowNO DESC;
               
                SELECT @TLotSN = b.LotSN
                FROM DataChainAssyIssue a
                INNER JOIN lot b ON a.AssyLotId = b.LotId
                WHERE a.IssueLotId = @LotId AND a.IsCancel = 0
			
                SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
                SET @I_ExceptionFieldName = 'ScanSN';
                SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}该箱体[' + @ScanSN + '/' + @LotSN + '/' + @TLotSN + ']已经组装759工单，请检查！';
                RETURN -1;   
            END;
           
	        --575必须点屏测试
            IF NOT EXISTS (
            	SELECT 1 FROM DataChainTEST WHERE LotSN = @LotSN AND TestItem = '晶显575点屏测试'
            )
            BEGIN
	            SELECT  RowNO, FLType_, LotSN_, MOName_
                FROM    @OutPutTable
                ORDER BY RowNO DESC;
	            
            	SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
                SET @I_ExceptionFieldName = 'ScanSN';
                SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}未经过晶显575点屏测试，不能装箱！';
                RETURN -1;  	
            END 
            
            --验证575是否属于该759工单
            IF NOT EXISTS ( SELECT TOP 1
                                    1
                            FROM    dbo.MO a
                            LEFT JOIN dbo.MOItem b ON b.MOId = a.MOId
                            WHERE   a.MOName = '00' + @MOName AND b.ProductId = @LotProductId )
            BEGIN
                SELECT  RowNO, FLType_, LotSN_, MOName_
                FROM    @OutPutTable
                ORDER BY RowNO DESC;
			
                SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
                SET @I_ExceptionFieldName = 'ScanSN';
                SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}批号[' + @LotSN + ']的物料[' + @LotProductName + ']在工单[' + @MOName + ']中不存在，请检查！';
                RETURN -1;   
            END; 
           
            --验证575批号工作流
            EXEC @return_value= dbo.[SysCheckSpecification]
                @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
                @WorkcenterId = @WorkcenterId OUTPUT ,
                @LotId = @LotId,
                @I_OrBitUserId = @I_OrBitUserId ,
            	@I_OrBitUserName = @I_OrBitUserName ,
                @I_ResourceId = @I_ResourceId ,
                @I_ResourceName = @I_ResourceName ,
                @SpecificationId = @LotSpecificationId ,
                @MESTxnObjectName = @MESTxnObjectName;
               
            IF @return_value = -1
            BEGIN
                SELECT  RowNO, FLType_, LotSN_, MOName_
                FROM    @OutPutTable
                ORDER BY RowNO DESC;
			
                SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;

                SET @I_ExceptionFieldName = 'ScanSN';
                SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}' + @I_ReturnMessage;
                RETURN -1;
            END;
           
            --检查759工单可用批号
			SELECT @AvailableQuantity = COUNT(b.LotId)
			FROM MO a
			LEFT JOIN dbo.MOItemLot b ON b.MOId = a.MOId 
			LEFT JOIN  DataChainAssyIssue c ON c.AssyLotId=b.LotId  AND c.IsCancel = 0
			WHERE MOName='00' + @MOName 
			AND ISNULL(c.DataChainAssyIssueId,'')=''
			
			IF @AvailableQuantity < @StdQtyOfBox
			BEGIN
				SELECT  RowNO, FLType_, LotSN_, MOName_
	            FROM    @OutPutTable
	            ORDER BY RowNO DESC;
				
				SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
			
				SET @I_ExceptionFieldName = 'ScanSN';
				SET @I_ReturnMessage = 'ServerMessage:当前759工单剩余可用批号数量[' + CAST(@AvailableQuantity AS VARCHAR(10)) + ']，小于当前装箱数量，请先检查工单!';
				RETURN -1;
			END;
        END;
       
        --添加当前扫描批号-575组件
        IF ISNULL(@LotStr, '') = ''
            SET @LotStr = @LotSN;
        ELSE
            SET @LotStr = @LotStr + ';' + @LotSN;
		
  		INSERT  INTO @OutPutTable ( LotId, FLType_, LotSN_, MOName_ )
        VALUES  ( @LotId, @FLType, @LotSN, @LotMOName);
       
		--获取已扫描数
        SELECT  @ScanedQty = COUNT(1)
        FROM    @OutPutTable;

		--未达到装箱数
        IF ISNULL(@ScanedQty, 0) < ISNULL(@StdQtyOfBox, 0)
        BEGIN
			--返回界面数据	                         
            SELECT  RowNO, FLType_, LotSN_, MOName_
            FROM    @OutPutTable
            ORDER BY RowNO DESC;
           
            SELECT  '' AS ScanSN, @LotStr AS LotStr, @ScanedQty AS ScanedQty, @ProductName AS ProductName,
                    @TypeStr AS TypeStr, '' AS IsPrint, '' AS TBoxSN, 'ok.png' AS WarnImage;
           
            SET @I_ExceptionFieldName = 'ScanSN';
            SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}请继续扫描成品批号! 已扫描 ' + CAST(@ScanedQty AS VARCHAR) + ' 个';
            RETURN 0;
        END;

		--已达到装箱数,开始装箱
        IF ISNULL(@ScanedQty, 0) = ISNULL(@StdQtyOfBox, 0) OR @ScanSN = 'SUBMIT'
        BEGIN     
	        --开始申请箱号
	        IF NOT EXISTS ( SELECT  1
                            FROM    BoxInfo
                            WHERE   ProductId = @LotProductId AND MOId = @LotMOId AND IsUsed = 0 AND IsCancel = 0 )
            BEGIN
                EXEC @return_value = [dbo].[Txn_ApplyBoxSNDoMethod]
                    @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
                    @I_Sender = 'ApplyBoxSN' ,  --箱号申请方法
                    @I_OrBitUserId = @I_OrBitUserId ,
                    @I_OrBitUserName = @I_OrBitUserName ,
                    @ApplyQty = 1 ,
                    @SNRuleName = 'XTZZBoxSN' ,     ---STDBoxSN
					@RuleTypeRChar = @MOName ,
                    @I_ParentPKId = @MOId ,
                    @BoxSN = @BoxSN OUTPUT;
                   
                IF @return_value < 0
                BEGIN
                    SELECT  RowNO, FLType_, LotSN_, MOName_
		            FROM    @OutPutTable
		            ORDER BY RowNO DESC;

                    SELECT  '' AS ScanSN, '' AS IsPrint, @LotStr AS LotStr, '' AS TBoxSN, 'error.png' AS WarnImage;
                    SET @I_ReturnMessage = 'ServerMessage: Say{FAIL.WAV}在线申请箱号有误！' + @I_ReturnMessage;
                    RETURN -1;            
                END;
            END;

            --是否混合装箱
            IF @LotIsHybridPack = 0
            BEGIN
				----获取同产品、工单 中任意的一个箱号
                SELECT TOP 1
                        @BoxSN = BoxSN
                FROM    dbo.BoxInfo
                WHERE   ProductId = @LotProductId AND MOId = @LotMOId AND IsUsed = 0 AND IsCancel = 0
                ORDER BY CreateDate;
            END;
            ELSE
            BEGIN 
				--获取同产品 中任意的一个箱号
                SELECT TOP 1
                        @BoxSN = BoxSN
                FROM    dbo.BoxInfo
                WHERE   ProductId = @LotProductId AND IsUsed = 0 AND IsCancel = 0
                ORDER BY CreateDate, MOId;
            END;
           
            --未获取到箱号
            IF ISNULL(@BoxSN, '') = ''
            BEGIN
                SELECT  RowNO, FLType_, LotSN_, MOName_
	            FROM    @OutPutTable
	            ORDER BY RowNO DESC;

                SELECT  '' AS ScanSN, @LotStr AS LotStr, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
                SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}当前系统没有预备箱号，无法自动分配箱号，请按 ' + IIF(@LotIsHybridPack = 0, '工单', '产品') + ' 启动箱号！' + @ProductName + '/' + @MOId;
                RETURN -1;
            END;
	        
            --575组装759
	        IF @FLType = '01'
	        BEGIN
	        	--再次检查759工单可用批号
				SELECT @AvailableQuantity = COUNT(b.LotId)
				FROM MO a
				LEFT JOIN dbo.MOItemLot b ON b.MOId = a.MOId 
				LEFT JOIN  DataChainAssyIssue c ON c.AssyLotId=b.LotId  AND c.IsCancel = 0
				WHERE MOName='00' + @MOName 
				AND ISNULL(c.DataChainAssyIssueId,'')=''
				
				IF @AvailableQuantity < @StdQtyOfBox
				BEGIN
					SELECT  RowNO, FLType_, LotSN_, MOName_
		            FROM    @OutPutTable
		            ORDER BY RowNO DESC;
					
					SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
				
					SET @I_ExceptionFieldName = 'ScanSN';
					SET @I_ReturnMessage = 'ServerMessage:当前759工单剩余可用批号数量[' + CAST(@AvailableQuantity AS VARCHAR(10)) + ']，小于当前装箱数量，请先检查工单!';
					RETURN -1;
				END;
			
				--开始遍历扫描的575组件
				DECLARE LotCursor CURSOR FOR
				SELECT LotSN_ FROM @OutPutTable
				OPEN LotCursor
				FETCH NEXT FROM LotCursor INTO @LotSN
				WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT  @LotId = a.LotId, @LotProductId = a.ProductId, @LotMOId = a.MOId, @LotWorkflowStepId = a.WorkflowStepId,
		                @LotSpecificationId = a.SpecificationId, @LotProductName = b.ProductName, @LotMOName = RIGHT(c.MOName, 10)
			        FROM    dbo.Lot a
			        INNER JOIN ProductRoot b ON a.ProductId = b.DefaultProductId
			        INNER JOIN MO c ON a.MOId = c.MOId
			        WHERE   LotSN = @LotSN;
			       
			        --保存下575批号
			        SET @MLotSN = @LotSN;
					
					--验证575批号工作流
			        EXEC @return_value= dbo.[SysCheckSpecification]
			            @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
			            @WorkcenterId = @WorkcenterId OUTPUT ,
			            @LotId = @LotId,
			            @I_OrBitUserId = @I_OrBitUserId ,
			        	@I_OrBitUserName = @I_OrBitUserName ,
			            @I_ResourceId = @I_ResourceId ,
			            @I_ResourceName = @I_ResourceName ,
			            @SpecificationId = @LotSpecificationId ,
			            @MESTxnObjectName = @MESTxnObjectName;
			           
			        IF @return_value = -1
			        BEGIN
			            SELECT  RowNO, FLType_, LotSN_, MOName_
			            FROM    @OutPutTable
			            ORDER BY RowNO DESC;
					
			            SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
			
			            SET @I_ExceptionFieldName = 'ScanSN';
			            SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}' + @I_ReturnMessage;
			            RETURN -1;
			        END;
					
			        --开始绑定759
					EXEC @return_value = dbo.PDA_LED_MOAssPowerTo759_Submit_DoMethod @I_Sender = N'LOAD02',                                      -- nvarchar(200)
	                                                 @I_ReturnMessage = @I_ReturnMessage OUTPUT,           -- nvarchar(max)
	                                                 @I_ExceptionFieldName = '', -- nvarchar(100)
	                                                 @I_PlugInCommand = '',                                -- varchar(5)
	                                                 @I_OrBitUserId = @I_OrBitUserId,                      -- char(12)
	                                                 @I_OrBitUserName = N'',                               -- nvarchar(100)
	                                                 @I_ResourceId = @I_ResourceId,                        -- char(12)
	                                                 @I_ResourceName = N'',                                -- nvarchar(100)
	                                                 @I_PKId = '',                                 -- char(12)
	                                                 @I_ParentPKId = '',                                   -- char(12)
	                                                 @I_Parameter = N'',                                   -- nvarchar(100)
	                                                 @Operator = @Operator,                     --操作员
												     @MOName = @MOName,                       --759工单号
												     @PowerLotSN = @LotSN;                   --575组件号
					IF @return_value = -1
					BEGIN 
						SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
			            SET @I_ReturnMessage = 'ServerMessage:绑定759工单失败！' + @I_ReturnMessage;
			            RETURN -1; 
					END;
				
					--575批号替换为759批号
					SELECT  @LotId =b.LotId, @LotSN = b.LotSN, @LotProductId = b.ProductId, @LotMOId = b.MOId, @LotWorkflowStepId = b.WorkflowStepId, @LotSpecificationId = b.SpecificationId
			        FROM    dbo.DataChainAssyIssue a
			        LEFT JOIN dbo.Lot b ON a.AssyLotId = b.LotId
			        WHERE   a.IssueLotSN = @LotSN AND a.IsCancel = 0;
			       
			        --验证759批号工作流
			        EXEC @return_value= dbo.[SysCheckSpecification]
			            @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
			            @WorkcenterId = @WorkcenterId OUTPUT ,
			            @LotId = @LotId,
			            @I_OrBitUserId = @I_OrBitUserId ,
			        	@I_OrBitUserName = @I_OrBitUserName ,
			            @I_ResourceId = @I_ResourceId ,
			            @I_ResourceName = @I_ResourceName ,
			            @SpecificationId = @LotSpecificationId ,
			            @MESTxnObjectName = @MESTxnObjectName;
			           
			        IF @return_value = -1
			        BEGIN
			            SELECT  RowNO, FLType_, LotSN_, MOName_
			            FROM    @OutPutTable
			            ORDER BY RowNO DESC;
					
			            SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
			
			            SET @I_ExceptionFieldName = 'ScanSN';
			            SET @I_ReturnMessage = 'ServerMessage:Say{FAIL.WAV}' + @I_ReturnMessage;
			            RETURN -1;
			        END;
			       
			        IF EXISTS (
			        	SELECT 1 FROM ShipBox WHERE LotSN = @LotSN AND IsCancel = 0
			        )
			        BEGIN
			        	SELECT  '' AS ScanSN, @ScanedQty AS ScanedQty, '' AS IsPrint, '' AS TBoxSN, 'error.png' AS WarnImage;
			            SET @I_ReturnMessage = 'ServerMessage: 装箱失败，请清空界面重试！';
			            RETURN -1;
			        END
			        
			        INSERT INTO @BoxDataTable(LotSN) VALUES (@LotSN);
			        
				
				    FETCH NEXT FROM LotCursor INTO @LotSN
				END
				CLOSE LotCursor
				DEALLOCATE LotCursor				
	        END
	        
	        --保存数据，批量写入
			--申请主键：批量
	        DECLARE @Table_PKId TABLE ( RowNO INT, PKId CHAR(12) );
			--申请主键：批量
	        INSERT  INTO @Table_PKId ( RowNO, PKId )
	                EXEC [dbo].[SysGetObjectPKIdBatch]
	                    @ObjectId = '' ,
	                    @ObjectName = N'ShipBox' ,
	                    @RowCount = @ScanedQty;
	
	        INSERT  INTO dbo.ShipBox ( ShipBoxId, LotId, LotSN, Qty, BoxSN, MOId, ProductId, WorkcenterId, ResourceId,
	                                   UserId, CreateDate, FLType )
	                SELECT  B.PKId, C.LotId, C.LotSN, C.Qty, @BoxSN, @MOId, C.ProductId, @WorkcenterId, @I_ResourceId,
	                        @I_OrBitUserId, GETDATE(), @FLTypeId
	                FROM    @BoxDataTable A
	                INNER JOIN @Table_PKId B ON B.RowNO = A.RowNO
	                LEFT JOIN dbo.Lot C ON C.LotSN = A.LotSN;
	               
	        --更新箱号为已使用
	        UPDATE  dbo.BoxInfo
	        SET     IsUsed = 1
	        WHERE   BoxSN = @BoxSN;
	       
	        DECLARE @Min INT= 0;
	        DECLARE @Max INT= 0;
	        DECLARE @TPLotId CHAR(12)= '';
	        DECLARE @TPMoId CHAR(12)= '';
	        DECLARE @TPLotSN NVARCHAR(50)= '';
	        DECLARE @AssyLotId CHAR(12)= '';
	        DECLARE @TempBoxSN NVARCHAR(50)= '';
	
	        SET @Min = 1;
	        SELECT  @Max = MAX(RowNO)
	        FROM    @BoxDataTable; 
	        WHILE @Min <= @Max
	        BEGIN
	            SET @TPMoId = '';
	            SET @TPLotSN = '';
	            SET @TPLotId = '';
	
	            SELECT  @TPLotSN = LotSN
	            FROM    @BoxDataTable a
	            WHERE   RowNO = @Min;
	
	            SELECT  @FLType = FLType
	            FROM    ShipBox
	            WHERE   LotId = @TPLotId;
	
	            SELECT  @TPMoId = MOId, @LotSpecificationId = SpecificationId, @LotWorkflowStepId = WorkflowStepId,
	                    @TPLotSN = LotSN
	            FROM    Lot
	            WHERE   LotSN = @TPLotSN;
	
	            IF @FLTypeId IN ( '01')
	            BEGIN
					--写数据链
					--产生DataChain返回数据链Id
	                EXEC dbo.TxnBase_DataChainMainLine
	                    @DataChainId = @DataChainId OUTPUT ,
	                    @TxnCode = @TxnCode ,
	                    @I_OrBitUserId = @I_OrBitUserId ,
	                    @I_ResourceId = @I_ResourceId ,
	                    @LotId = @TPLotId ,
	                    @MOId = @TPMoId ,
	           			@ProductId = @LotProductId ,
	                    @WorkcenterId = @WorkcenterId ,
	                    @SpecificationId = @LotSpecificationId ,
	                    @WorkflowStepId = @LotWorkflowStepId;
	
					--统计在制品
	                EXEC dbo.DataChainWIPDoMethod
	                    @I_OrBitUserId = @I_OrBitUserId ,
	                    @I_ResourceId = @I_ResourceId ,
	                    @LotId = @TPLotId ,
	                    @WorkcenterId = @WorkcenterId ,
	                    @MoveResult = 'P'; --PASS
	
												
					----传送 LotSN 到工作流下一节点
	                EXEC dbo.TxnBase_LotMove
	                    @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
	                    @I_OrBitUserId = @I_OrBitUserId ,
	                    @I_ResourceId = @I_ResourceId ,
	                    @LotSN = @TPLotSN ,
	                    @LotInDate = @CurDate;	 
	            END;
	
	            SET @TPLotId = '';
	
	            SET @Min = @Min + 1;
	        END;
	       
	        --返回界面数据
		    DELETE  @OutPutTable;
		    SELECT  RowNO, FLType_, LotSN_, MOName_
		    FROM    @OutPutTable
		    ORDER BY RowNO DESC;
		   
		    SELECT  '' AS ScanSN, '' AS LotStr, 0 AS ScanedQty, '' AS ProductName, @WorkcenterName AS WorkcenterName,
		            '' AS PrintPassword, '' AS Typestr, CAST(@IsOnLinePrint AS VARCHAR) AS IsPrint, @BoxSN AS TBoxSN,
		            'ok.png' AS WarnImage;
		
		    SET @I_ReturnMessage = 'ServerMessage:Say{PASS.WAV}外箱【' + @BoxSN + '】装箱扫描完成，请继续装下一箱!';
		    RETURN 0;
        END;
    END;
END;