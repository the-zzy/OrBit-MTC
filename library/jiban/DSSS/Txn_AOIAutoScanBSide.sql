
-- =============================================
-- Author:		<Wang RT>
-- Create date: <2020.5.19>
-- Description:	SMT炉后目检B面拼版自动采集
-- =============================================
CREATE PROCEDURE [dbo].[Txn_AOIAutoScanBSide]
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = 'LotSN' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKId CHAR(12) = '' ,				--主键
    @I_SourcePKId CHAR(12) = '' ,			--执行拷贝时传入的源主键  
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' ,		--插件参数	
    @MOId CHAR(12) = '' ,
    @MOName NVARCHAR(50) = '' ,
    @Operator NVARCHAR(50) = '' ,
    @STDMakeupNumber INT = 0 ,             --标准拼板数
    @MakeupNumber INT = 0 ,                --拼板数
    @LotSN NVARCHAR(50) = '' ,
    @HideList NVARCHAR(MAX) = '' ,
    @Side VARCHAR(10) = '' ,
    @Remaintime INT = 0 ,
    @IsMakeupNumber INT = 0 ,
    @PCBType VARCHAR(20) = '' ,
    @WorkcenterName VARCHAR(20) = '' ,
    @PathWay VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @return_value INT= -1;
    DECLARE @now DATETIME = GETDATE();
    DECLARE @Date DATETIME= GETDATE();
    DECLARE @TxnCode VARCHAR(10)= 'DC';
    DECLARE @LotId CHAR(12);
    DECLARE @LotStatus CHAR(1);
    DECLARE @LotProductId CHAR(12);
    DECLARE @LotProductName NVARCHAR(50);
    DECLARE @LotMOId CHAR(12);
    DECLARE @LotWorkflowStepId CHAR(12);
    DECLARE @LotSpecificationId CHAR(12) = '';
    --DECLARE @ParentLotId CHAR(12);
    DECLARE @ParentLotSN NVARCHAR(2000); 
    DECLARE @DataChainId CHAR(12);
    DECLARE @WorkcenterId CHAR(12); 
    DECLARE @MOProductId CHAR(12);  
    DECLARE @DCStoveStationScanId CHAR(12);
    DECLARE @PLotId CHAR(12);
    DECLARE @PLotSN NVARCHAR(50);
    DECLARE @PProductName NVARCHAR(50) = '';
    DECLARE @PLotStatus CHAR(1);
    DECLARE @PMOId CHAR(12);
    DECLARE @PProductId CHAR(12);
    DECLARE @PSpecificationId CHAR(12);
    DECLARE @PWorkflowId CHAR(12);
    DECLARE @PWorkflowStepId CHAR(12);
    DECLARE @LotStepBackflushId CHAR(12);
    DECLARE @FinishQty INT= 0;
    DECLARE @MESTxnObjectName NVARCHAR(50)= 'DC StoveStation Scan';
    DECLARE @SubmitBarCode NVARCHAR(50)= 'SUBMIT';
    DECLARE @ScanQty INT= 0;
    DECLARE @StartTime DATETIME= GETDATE();
    DECLARE @EndTime DATETIME= GETDATE();
    DECLARE @uplinetiem DATETIME;
    DECLARE @check BIT = 0;
    DECLARE @remainminute DECIMAL(10, 2); 
    DECLARE @Servicesfrom DATETIME;
    DECLARE @ServicesMinute INT;
    DECLARE @toolclearid NVARCHAR(12);
    DECLARE @CloseClear BIT = 0;
    DECLARE @message NVARCHAR(20);
    DECLARE @CloseCleartime DATETIME; 
    DECLARE @intminute INT= 0;
    DECLARE @BOTBackflushId CHAR(12) = '';
    DECLARE @DCBotMinScanId CHAR(12) = '';
    DECLARE @Customerid VARCHAR(12)= '';
    DECLARE @CloseBackflush BIT = 0;
    DECLARE @PCBOnSMTId CHAR(12) = '';

	--A面直接退出程序
    IF @Side <> 'B'
    BEGIN
		SET @I_ReturnMessage = '';
        RETURN 0;
    END;

    IF @Side = 'AB' AND @I_OrBitUserName NOT IN ( 'SC1227', 'SC1228', 'SC1229', 'SC1230' )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:只有27-30线可以选择AB面，请重新选择！';
        RETURN -1;
    END;

	--转换为大写
    SET @LotSN = UPPER(RTRIM(LTRIM(@LotSN)));
    SET @Operator = UPPER(@Operator);

	--定义表变量
    DECLARE @TempTable TABLE
        (
          MOItemId CHAR(12) ,
          ItemLocation NVARCHAR(2000)
        );

	--重置扫描
    IF @I_Sender = 'BtnClear'
    BEGIN		
        SELECT  '' CombineList;
        SELECT  '' AS LotSN, '' AS HideList, '' AS FinishQty, 'ok.png' AS WarnImage, 0 AS ReturnValue; --,--30 as Remaintime
        SET @I_ReturnMessage = 'ServerMessage:数据清除成功，请重新扫描产品条码!' + CAST(@Remaintime AS CHAR);
        SET @I_ExceptionFieldName = 'LotSN';	
        RETURN 0;
    END;

    IF @I_Sender = 'btnPCBType'
    BEGIN		
        SELECT  '' CombineList;
        SELECT  '' AS LotSN, '' AS HideList, '' AS FinishQty, 'ok.png' AS WarnImage, 0 AS ReturnValue; --,--30 as Remaintime
        SET @I_ReturnMessage = 'ServerMessage:请扫描产品条码!' + CAST(@Remaintime AS CHAR);
        SET @I_ExceptionFieldName = 'LotSN';	
        RETURN 0;
    END;
	--检查拼板数是否足够
    IF @IsMakeupNumber = -1
    BEGIN		
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}AOI检测PCB板 块数不足['+@LotSN+']!';

        SELECT  '' AS CombineList;
        SELECT  '' AS LotSN, '' AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        SET @I_ExceptionFieldName = 'IsMakeupNumber';
        RETURN -1;
    END;


	--检查是否为空
    IF ISNULL(@MOId, '') = ''
    BEGIN		
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入工单号!';

        SELECT  '' AS CombineList;
        SELECT  '' AS LotSN, '' AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        SET @I_ExceptionFieldName = 'MOName';
        RETURN -1;
    END;

	--检查PCBType是否为空
    IF ISNULL(@PCBType, '') NOT IN ( 'M', 'C', 'JS', '' )    ---- ISNULL(@PCBType, '') <> ''  AND
    BEGIN		
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}厂商编号[' + ISNULL(@PCBType, '') + ']不正确!';

        SELECT  '' AS CombineList;
        SELECT  '' AS LotSN, '' AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        SET @I_ExceptionFieldName = 'PCBType';
        RETURN -1;
    END;

	--标准拼板数必须大于零
    IF ISNULL(@STDMakeupNumber, 0) <= 0
    BEGIN		
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}标准拼板数 [' + CAST(@STDMakeupNumber AS VARCHAR) + '] 必须大于零!';
        SET @I_ExceptionFieldName = 'STDMakeupNumber';

        SELECT  parameter_Value AS CombineList
        FROM    ConvertParameterToTable(@HideList, ';')
        WHERE   parameter_Value <> '';
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        RETURN -1;
    END;

	--拼板数必须大于零
    IF ISNULL(@MakeupNumber, 0) <= 0
    BEGIN		
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}拼板数 [' + CAST(@MakeupNumber AS VARCHAR) + '] 必须大于零!';
        SET @I_ExceptionFieldName = 'MakeupNumber';

        SELECT  parameter_Value AS CombineList
        FROM    ConvertParameterToTable(@HideList, ';')
        WHERE   parameter_Value <> '';
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        RETURN -1;
    END;

	--操作员是否为空
    IF ISNULL(@Operator, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入操作员工号!';

        SELECT  '' AS CombineList;
        SELECT  '' AS Operator, '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        SET @I_ExceptionFieldName = 'Operator';
        RETURN -1;
    END;

	--检查人员工号是否存在
    IF NOT EXISTS ( SELECT  PersonInfoId
                    FROM    PersonInfo(NOLOCK)
                    WHERE   PersonNumber = @Operator AND IsActivity = 1 )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}操作员工号 [' + @Operator + '] 不存在或已离职!';
		
        SELECT  '' AS CombineList;
        SELECT  '' AS Operator, '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        SET @I_ExceptionFieldName = 'Operator';
        RETURN -1;
    END;

	--LotSN 不能为空
    IF ISNULL(@LotSN, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入产品条码!';
        SELECT  parameter_Value AS CombineList
        FROM    ConvertParameterToTable(@HideList, ';')
        WHERE   parameter_Value <> '';
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        RETURN -1;
    END;

	--检查条码是否重复扫描--
    IF EXISTS ( SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   parameter_Value <> '' AND parameter_Value = @LotSN )
    BEGIN
        SELECT  parameter_Value AS CombineList
        FROM    ConvertParameterToTable(@HideList, ';')
        WHERE   parameter_Value <> '';
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}重复扫描条码[' + @LotSN + ']!';
        RETURN -1;    
    END;

    DECLARE @MOReqQty INT= 0 ,
        @HadOffLineQty INT= 0 ,
        @DiffQty INT= 0;

    SELECT  @MOReqQty = MOQtyRequired
    FROM    dbo.MO(NOLOCK)
    WHERE   MOId = @MOId;

    SELECT  @HadOffLineQty = SUM(FrameQnty)
    FROM    DCBotMinScan(NOLOCK)
    WHERE   MOId = @MOId AND Side = @Side AND SpecificationId = 'SPE10000019B';

    SELECT  @DiffQty = CASE WHEN ( @HadOffLineQty + @MakeupNumber - @MOReqQty ) > 0
                            THEN ( @HadOffLineQty + @MakeupNumber - @MOReqQty )
                            ELSE 0
                       END; 

    IF @HadOffLineQty + @MakeupNumber > @MOReqQty
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:工单：' + @MOName + ' 已提交数大于总需求数，不需要再提交！超出数为：' + CAST(@DiffQty AS VARCHAR(30));
        SELECT  parameter_Value AS CombineList
        FROM    ConvertParameterToTable(@HideList, ';')
        WHERE   parameter_Value <> '';
        SELECT  '' AS FrameSN, @HideList AS HideList, 'error.png' AS WarnImage;
        RETURN -1;
    END;

	--把submit提交命令排除--
    IF ISNULL(@LotSN, '') <> ISNULL(@SubmitBarCode, '')
    BEGIN
		
        IF NOT EXISTS ( SELECT  1
                        FROM    dbo.Lot
                        WHERE   LotSN = @LotSN )
        BEGIN
            IF ISNULL(@Side, '') <> 'B'
            BEGIN
                SELECT  '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                SET @I_ReturnMessage = 'ServerMessage:请选择B面再进行扫描！';
                SET @I_ExceptionFieldName = 'LotSN';
                RETURN -1;
            END;
		
            IF LEN(@LotSN) <> 16
            BEGIN
                SELECT  '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                SET @I_ReturnMessage = 'ServerMessage:批号无效，请检查！';
                SET @I_ExceptionFieldName = 'LotSN';
                RETURN -1;
            END;

            IF LEFT(@LotSN, 10) <> @MOName
            BEGIN
                SELECT  '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                SET @I_ReturnMessage = 'ServerMessage:批号[' + @LotSN + ']不属于当前工单[' + @MOName + ']，请检查！';
                SET @I_ExceptionFieldName = 'LotSN';
                RETURN -1;
            END;

            IF SUBSTRING(@LotSN, 11, 1) <> '-'
            BEGIN
                SELECT  '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                SET @I_ReturnMessage = 'ServerMessage:批号无效，请检查！';
                SET @I_ExceptionFieldName = 'LotSN';
                RETURN -1;
            END;

            IF RIGHT(@LotSN, 5) NOT BETWEEN 00001 AND 99999
            BEGIN
                SELECT  '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                SET @I_ReturnMessage = 'ServerMessage:批号无效，请检查！';
                SET @I_ExceptionFieldName = 'LotSN';
                RETURN -1;
            END;

        END;

        IF EXISTS ( SELECT  1
                    FROM    dbo.Lot
                    WHERE   LotSN = @LotSN )
        BEGIN
			--获取Lot信息
            SELECT  @LotId = LotId, @LotMOId = MOId, @LotStatus = LotStatus, @LotSpecificationId = SpecificationId
            FROM    Lot(NOLOCK)
            WHERE   LotSN = @LotSN;

            IF @LotSpecificationId <> 'SPE10000019B' --AND @LotSpecificationId <> 'SPE10000025P' -- 炉前
            BEGIN
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 

                SET @I_ExceptionFieldName = 'LotSN';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + ']不在炉后目检节点';

				IF @LotSN LIKE '%1011272906%'
				BEGIN
					SELECT  '' AS CombineList, CAST(ISNULL(@remainminute, 0) AS FLOAT) AS Remaintime;
					SELECT  '' AS LotSN, @FinishQty AS FinishQty, '' AS HideList, 'ok.png' AS WarnImage, 0 AS ReturnValue; 
					RETURN 0;
				END;
				ELSE 
					RETURN -1;
            END;

            IF ISNULL(@LotStatus, '0') <> '1'
            BEGIN
			
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                SET @I_ExceptionFieldName = 'LotSN';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 状态不可用!';

                RETURN -1;
            END;
			
			--获取工单信息
            SELECT  @MOProductId = MO.ProductId
            FROM    MO(NOLOCK)
            WHERE   MOId = @LotMOId;

            IF ISNULL(@LotMOId, '') <> @MOId
            BEGIN
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                SET @I_ExceptionFieldName = 'LotSN';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 不属于该工单';
                RETURN -1;
            END;

			---获取工单产品信息
            SELECT  @LotProductName = ProductName
            FROM    ProductRoot(NOLOCK)
            INNER JOIN Product ON Product.ProductRootId = ProductRoot.ProductRootId
            WHERE   Product.ProductId = @MOProductId;

			--检查是否允许操作此规程
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

            IF @return_value = -1 AND @LotSpecificationId <> 'SPE10000025P' -- 炉前
            BEGIN	
                SET @I_ReturnMessage = @I_ReturnMessage + '111';

                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;
        END;

        SELECT  @LotSpecificationId = a.SpecificationId, @PProductName = b.prdname
        FROM    dbo.Lot a
        INNER JOIN dbo.Product b ON b.ProductId = a.ProductId
        WHERE   LotSN = @LotSN;

        IF EXISTS ( SELECT  1
                    FROM    dbo.BOTBackflush
                    WHERE   lotSN = @LotSN ) OR EXISTS ( SELECT 1
                                                         FROM   dbo.DCBotMinScan
                                                         WHERE  LotSN = @LotSN AND Side = @Side AND SpecificationId = 'SPE10000019B' ) AND @LotSN NOT LIKE '5JB%'
        BEGIN
            SELECT  '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
            SET @I_ReturnMessage = '批号已扫描过，请检查！';
            SET @I_ExceptionFieldName = 'LotSN';
            RETURN -1;
        END;
        
		--获取工作中心编号
        SELECT  @WorkcenterId = WorkcenterId
        FROM    SysUser(NOLOCK)
        WHERE   UserId = @I_OrBitUserId;

		--检查线别是否为空
        IF ISNULL(@WorkcenterId, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}用户 [' + @I_OrBitUserName + '] 未维护线别!';

            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable(@HideList, ';')
            WHERE   parameter_Value <> '';
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 

            RETURN -1;
        END;
    END;

	--获取工作中心编号
    SELECT  @WorkcenterId = WorkcenterId
    FROM    SysUser
    WHERE   UserId = @I_OrBitUserId;

    IF ISNULL(@WorkcenterId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}该操作员没有定义作业生产线别!';	
        SELECT  '' AS Operator, '' AS FrameSN, 'error.png' AS WarnImage;
        SET @I_ExceptionFieldName = 'Operator';
        RETURN -1; 
    END;

    IF NOT EXISTS ( SELECT  1
                    FROM    dbo.MOLotOnRecord
                    WHERE   MOId = @MOId AND WorkcenterId = @WorkcenterId AND Side = @Side )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:面别[' + @Side + ']不存在对应的上料记录，请重新选择面别！';
        RETURN -1;
    END;
		 
    IF NOT EXISTS ( SELECT  1
                    FROM    ToolCollect t1
                    LEFT JOIN ToolManage t2 ON t1.ToolNumber = t2.ToolNumber
                    WHERE   t1.MOId = @MOId AND t1.WorkcenterId = @WorkcenterId AND t2.ToolTypeId IN ( 'URC1000000O9',
                                                                                                       'URC1000000T8' ) ) AND @MOId <> 'MOD100005B1M'  -- 001010289470
    BEGIN			
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}工单号 【' + @MOName + '】 在线别【' + @WorkcenterId + '】无钢网上料记录!';
        RETURN -1;
    END;

	--IF NOT EXISTS ( SELECT TOP 1
	--                        ToolClearId
	--                FROM    ToolClear(NOLOCK)
	--                WHERE   WorkcenterId = @WorkcenterId AND DATEDIFF(MINUTE, CreateDate, GETDATE()) < 60 AND IsActive = 1 )
	--BEGIN
	--    SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}钢网没有进行清洗扫描,请做清洗扫描后再产出!' + @MOName + '/' + @WorkcenterName;
	--    SELECT  parameter_Value AS CombineList
	--    FROM    ConvertParameterToTable(@HideList, ';')
	--    WHERE   parameter_Value <> '';
	--    SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
	
	--    RETURN -1;
	--END;

	-----判断是否有上刮刀
    DECLARE @count INT; 
    SET @count = 0;
    SELECT  @count = COUNT(ToolCollectId)
    FROM    ToolCollect t1
    LEFT JOIN ToolManage t2 ON t1.ToolNumber = t2.ToolNumber
    WHERE   t1.MOId = @MOId AND t1.WorkcenterId = @WorkcenterId AND t2.ToolTypeId = 'URC1000000OB';
    IF ( @count < 2 ) AND @MOId <> 'MOD100005B1M'
    BEGIN
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}工单号 【' + @MOName + '】 在线别【' + @WorkcenterId + '】无刮刀上料记录!';
        RETURN -1;
    END;

	--获取工作中心编号
    SELECT TOP 1
            @WorkcenterId = SysUser.WorkcenterId, @WorkcenterName = Workcenter.WorkcenterName
    FROM    SysUser
    INNER JOIN Workcenter ON Workcenter.WorkcenterId = SysUser.WorkcenterId
    WHERE   UserId = @I_OrBitUserId;

	--获取产品ID
    SELECT TOP 1
            @PProductId = ProductId, @MOName = MOName
    FROM    MO
    WHERE   MOId = @MOId;

	--检查线别是否为空
    IF ISNULL(@WorkcenterId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}用户 [' + @I_OrBitUserName + '] 未维护线别!';
        SELECT  parameter_Value AS CombineList
        FROM    ConvertParameterToTable(@HideList, ';')
        WHERE   parameter_Value <> '';
        SELECT  '' AS FrameSN, @HideList AS HideList, 'error.png' AS WarnImage;
        RETURN -1;
    END;

    IF ISNULL(@WorkcenterName, '') = ''
    BEGIN
        SELECT  @WorkcenterName AS workcentername, @WorkcenterId AS Workcenterid;
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请选择线别!';	
        SELECT  '' AS Operator, '' AS FrameSN, 'error.png' AS WarnImage;
        SET @I_ExceptionFieldName = 'FrameSN';
        RETURN -1;
    END;

    IF ISNULL(@MakeupNumber, 0) > 1
    BEGIN	
		--如果扫描的不是提交条码
        IF ISNULL(@LotSN, '') <> ISNULL(@SubmitBarCode, '')
        BEGIN
			--获取已扫描的拼板SN个数
            SELECT  @ScanQty = ISNULL(COUNT(parameter_Value), 0)
            FROM    ConvertParameterToTable(@HideList, ';')
            WHERE   ISNULL(parameter_Value, '') <> '';
			--未达到拼板数
            IF @ScanQty < @MakeupNumber
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:请继续扫描产品批号!';
				--拼接字符串
                IF @HideList = ''
                    SET @HideList = @LotSN;
                ELSE
                    SET @HideList = @HideList + ';' + @LotSN;	
				--重新统计数量--
                SELECT  @ScanQty = ISNULL(COUNT(parameter_Value), 0)
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   ISNULL(parameter_Value, '') <> '';
                IF @ScanQty = @MakeupNumber
                BEGIN
                    SET @I_ReturnMessage = 'ServerMessage:产品批号扫描已达到拼板数 [' + CAST(@MakeupNumber AS VARCHAR) + '] ，请扫描提交条码[Submit]!';
                    SELECT  parameter_Value AS CombineList
                    FROM    ConvertParameterToTable(@HideList, ';')
                    WHERE   ISNULL(parameter_Value, '') <> '';
                    SELECT  '' AS LotSN, @HideList AS HideList, 'SUBMIT.png' AS WarnImage, 0 AS ReturnValue; 
                    SET @I_ExceptionFieldName = 'LotSN';
                    RETURN 0;
                END;	
				--返回界面数据--
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   ISNULL(parameter_Value, '') <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'right.png' AS WarnImage, 0 AS ReturnValue; 
                SET @I_ExceptionFieldName = 'LotSN';
                RETURN 0;
            END;
			--当已完成拼板扫描，并且没有扫描提交条码
            IF @ScanQty = @MakeupNumber
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}上次扫描已达到拼板数 [' + CAST(@MakeupNumber AS VARCHAR) + '],请先扫描条码[Submit]提交,此次扫描批号[' + @LotSN + ']失效!';
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   ISNULL(parameter_Value, '') <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'SUBMIT.png' AS WarnImage, 0 AS ReturnValue; 
                RETURN -1;
            END;
        END;

		--如果扫描的是提交条码
        IF ISNULL(@LotSN, '') = @SubmitBarCode
        BEGIN
			--获取已扫描的拼板SN个数
            SELECT  @ScanQty = ISNULL(COUNT(parameter_Value), 0)
            FROM    ConvertParameterToTable(@HideList, ';')
            WHERE   ISNULL(parameter_Value, '') <> '';
			--未达到拼板数
            IF @ScanQty < @MakeupNumber
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:批号扫描未达到拼板数[' + CAST(@MakeupNumber AS VARCHAR) + '],请扫描产品条码!';
				--返回界面数据--
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   ISNULL(parameter_Value, '') <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'right.png' AS WarnImage, 0 AS ReturnValue; 
                SET @I_ExceptionFieldName = 'LotSN';
                RETURN 0;
            END;
            --ELSE
    --        BEGIN
				----申请 ParentId
    --            EXEC SysGetObjectPKId
    --                '' ,
    --                'Lot' ,
    --                @ParentLotId OUTPUT; 
    --        END;
        END;
    END;
    ELSE
    BEGIN
		--不是拼板的拼接字符串--
        IF @HideList = ''
            SET @HideList = @LotSN;
        ELSE
            SET @HideList = @HideList + ';' + @LotSN;	
    END;

	--重新获取工作中心--
    SELECT  @WorkcenterId = WorkcenterId
    FROM    SysUser(NOLOCK)
    WHERE   UserId = @I_OrBitUserId;

	---- ADD BY WANG RT 2020.12.11 针对中兴客户，PCB上料时间到B面产出不超过2小时，到A面产出不超过24小时 BEGIN ----
    SELECT  @Customerid = b.CustomerId
    FROM    dbo.MO a
    LEFT JOIN dbo.SO b ON b.SOName = a.SOName
    WHERE   a.MOId = @MOId;

    DECLARE @PCBONTime DATETIME = NULL;
	
	--IF @Customerid IN ( 'CUS1000002LM','CUS1000002MI' ) AND ISNULL(@MOId,'') = ''
	----IF (@WorkcenterId = 'WKC100000098' OR @WorkcenterId = 'WKC100000083') AND @MOId = ''
	--BEGIN
	--	IF (SELECT ISNULL(MIN(CreateDate),GETDATE()) FROM dbo.DCBotMinScan WHERE MOId = @MOId AND Side = 'B' AND ISNULL(LotSN,'') <> '' ) < ( SELECT ISNULL(MIN(CreateDate),GETDATE()) FROM DCStoveStationScan WHERE MOId = @MOId )
	--	BEGIN
	--		SELECT @PCBOnSMTId = MIN(PCBOnSMTId) FROM dbo.PCBOnSMT WHERE MOId = @MOId AND BeginQty > BUsedQty
	--	    SELECT @PCBONTime = CreateDate FROM dbo.PCBOnSMT WHERE PCBOnSMTId = @PCBOnSMTId

	--		IF DATEDIFF(MINUTE,@PCBONTime,GETDATE()) > 120
	--		BEGIN
	--			SET @I_ReturnMessage = 'ServerMessage:工单 [' + @MOName + '] PCB上料时间已超过2小时，不可使用!'
	--			RETURN -1;
	--		END
	--	END
	--	ELSE 
	--	BEGIN
	--		SELECT @PCBOnSMTId = MIN(PCBOnSMTId) FROM dbo.PCBOnSMT WHERE MOId = @MOId AND BeginQty > BUsedQty
	--	    SELECT @PCBONTime = CreateDate FROM dbo.PCBOnSMT WHERE PCBOnSMTId = @PCBOnSMTId

	--		IF DATEDIFF(MINUTE,@PCBONTime,GETDATE()) > 1440
	--		BEGIN
	--			SET @I_ReturnMessage = 'ServerMessage:工单 [' + @MOName + '] PCB上料时间已超过24小时，不可使用!'
	--			RETURN -1;
	--		END
	--	END

	--END
	---- ADD BY WANG RT 2020.12.11 针对中兴客户，PCB上料时间到B面产出不超过2小时，到A面产出不超过24小时  END  ----

	--定义一个表变量
    DECLARE @TempLotSN TABLE
        (
          LotId CHAR(12) DEFAULT '' ,
          LotSN NVARCHAR(50) DEFAULT '' ,
          LotStatus CHAR(1) DEFAULT '' ,
          MOId CHAR(12) DEFAULT '' ,
          MOItemId CHAR(12) DEFAULT '' ,
          ProductId CHAR(12) DEFAULT '' ,
          WorkflowId CHAR(12) DEFAULT '' ,
          SpecificationId CHAR(12) DEFAULT '' ,
          WorkflowStepId CHAR(12) DEFAULT '' ,
          Qty DECIMAL(18, 4) DEFAULT 0
        );

	--给表变量赋值
    INSERT  INTO @TempLotSN ( LotId, LotSN, LotStatus, MOId, MOItemId, ProductId, WorkflowId, SpecificationId,
                              WorkflowStepId, Qty )
            SELECT   DISTINCT
                    ISNULL(b.LotId, '') AS LotId, parameter_Value AS LotSN, '' AS LotStatus, @MOId AS MOId, b.MOItemId,
                    @PProductId AS ProductId, '' AS WorkflowId, ISNULL(b.SpecificationId, '') AS SpecificationId,
                    ISNULL(b.WorkflowStepId,'') AS WorkflowStepId, b.Qty
            FROM    ConvertParameterToTable(@HideList, ';') a
            LEFT JOIN dbo.Lot b ON b.LotSN = a.parameter_Value
            WHERE   parameter_Value <> '' AND parameter_Value <> 'SUBMIT';
	
	--重新获取工作中心--
    SELECT  @WorkcenterId = WorkcenterId
    FROM    SysUser(NOLOCK)
    WHERE   UserId = @I_OrBitUserId;

	--获取其中一个Lot信息--	
    SELECT TOP 1
            @LotSN = LotSN, @MOId = MOId, @MOProductId = ProductId, @LotSpecificationId = SpecificationId,
            @LotId = LotId
    FROM    @TempLotSN;  
		
    SET @StartTime = GETDATE();

	--IF @WorkcenterName >= 'S19' AND @WorkcenterName <= 'S19'
           --     BEGIN
    EXEC @return_value= [dbo].[SMTBackflushDoMethodNew]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @I_ResourceId = @I_ResourceId ,
        @I_ResourceName = @I_ResourceName ,
        @I_OrBitUserId = @I_OrBitUserId ,
        @I_OrBitUserName = @I_OrBitUserName ,
        @LotSN = @LotSN ,
        @MOId = @MOId ,
        @Lotid = @Lotid ,
        @ProductId = @MOProductId ,
        @WorkcenterId = @WorkcenterId ,
        @Side = @Side ,
        @STDMakeupNumber = @STDMakeupNumber ,
        @MakeupNumber = @MakeupNumber ,
        @LotsnStr = @HideList;

    PRINT @HideList + '/' + @MOProductId + '/' + @MOId + '/' + @LotSN;

      -- END;

	--SELECT @CloseBackflush = IsClosed FROM dbo.Workcenter WITH(NOLOCK) WHERE WorkcenterId = @WorkcenterId
 --   IF @Customerid IN('CUS1000002LM','CUS1000002MI')   -- 中兴的一不能关闭扣料！
	--  SET @CloseBackflush = 0

	----从工作中心里面控制是否核料扣料--
 --   IF @CloseBackflush =0
 --   BEGIN
	--	--检查是否装配节点
 --       IF EXISTS ( SELECT  1
 --                   FROM    Specification(NOLOCK)
 --                   WHERE   SpecificationId = @LotSpecificationId AND IsAssemblyStep = 1 )
 --       BEGIN
	--	    --- update 2017.07.13 for billy   注消第一次的检查
	--		--炉后目检核对料站表
	--		--检查上料记录与料站表是否一致
	--		--exec @return_value=[dbo].[SMTStoveStationCheckDoMethod]
	--		--	@I_ReturnMessage=@I_ReturnMessage output,
	--		--	@I_ResourceId=@I_ResourceId,
	--		--	@I_ResourceName=@I_ResourceName,
	--		--	@I_OrBitUserId=@I_OrBitUserId,
	--		--	@I_OrBitUserName=@I_OrBitUserName,
	--		--	@LotSN=@LotSN,
	--		--	@MOId=@MOId,                 
	--		--	@ProductId=@MOProductId,             
	--		--	@WorkcenterId=@WorkcenterId, 
	--		--	@Side=@Side

	--		--if @return_value=-1
	--		--begin
	--		--	set @I_ReturnMessage=@I_ReturnMessage
	--		--	select parameter_Value as CombineList from ConvertParameterToTable(@HideList,';') where parameter_Value<>''
	--		--	select '' as LotSN,@HideList as HideList,'error.png' as WarnImage,-1 AS ReturnValue
	--		--	return -1
	--		--end  

	--		--检查是否满足扣料，满足则扣料
 --           EXEC @return_value= [dbo].[SMTBackflushDoMethod]
 --               @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
 --               @I_ResourceId = @I_ResourceId ,
 --               @I_ResourceName = @I_ResourceName ,
 --               @I_OrBitUserId = @I_OrBitUserId ,
 --               @I_OrBitUserName = @I_OrBitUserName ,
 --               @LotSN = @LotSN ,
 --               @MOId = @MOId ,
 --               @ProductId = @MOProductId ,
 --               @WorkcenterId = @WorkcenterId ,
 --               @Side = @Side ,
 --               @STDMakeupNumber = @STDMakeupNumber ,
 --               @MakeupNumber = @MakeupNumber;     
		
 --           IF @return_value = -1
 --           BEGIN
 --               SET @I_ReturnMessage = @I_ReturnMessage;
 --               SELECT  parameter_Value AS CombineList
 --               FROM    ConvertParameterToTable(@HideList, ';')
 --               WHERE   parameter_Value <> '';
 --               SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
 --               RETURN -1;
 --           END;  
 --       END;  				
 --   END;
 		
    DECLARE @spiid CHAR(12)= '';
    DECLARE @SPIItemLotId CHAR(12)= '';
    DECLARE @MOItemId CHAR(12) = '';
    DECLARE @CurrSpecificationId CHAR(12)= '';
    DECLARE @Qty DECIMAL(18, 4) = 0;

	--游标循环，数据采集，传送
    DECLARE cursor2 CURSOR
    FOR
    SELECT  LotId, LotSN, LotStatus, MOId, MOItemId, ProductId, SpecificationId, WorkflowId, WorkflowStepId, Qty
    FROM    @TempLotSN
    ORDER BY LotSN;
	--WHERE SpecificationId='SPE10000019B'
    OPEN cursor2; 
    FETCH NEXT FROM cursor2 
	INTO @PLotId, @PLotSN, @PLotStatus, @PMOId, @MOItemId, @PProductId, @PSpecificationId, @PWorkflowId,
        @PWorkflowStepId, @Qty;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF ISNULL(@PSpecificationId, '') = 'SPE10000019B' --aoi 炉前
        BEGIN
            EXEC dbo.TxnBase_DataChainMainLine
                @DataChainId = @DataChainId OUTPUT , -- char(12)
                @TxnCode = 'DC' , -- varchar(10)
                @I_PlugInCommand = @I_PlugInCommand , -- varchar(5)
                @I_OrBitUserId = @I_OrBitUserId , -- char(12)
                @I_ResourceId = @I_ResourceId , -- char(12)
                @LotId = @PLotId , -- char(12)
                @MOId = @MOId , -- char(12)
                @MOItemId = @MOItemId , -- char(12)
                @ProductId = @PProductId , -- char(12)
                @Qty = @Qty , -- float
                @WorkcenterId = @WorkcenterId , -- char(12)
                @SpecificationId = @PSpecificationId , -- char(12)
                @WorkflowStepId = @PWorkflowStepId; -- char(12)

            --EXEC [dbo].[TxnBase_LotMove]
            --    @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
            --    @I_PlugInCommand = @I_PlugInCommand ,
            --    @I_OrBitUserId = @I_OrBitUserId ,
            --    @I_ResourceId = @I_ResourceId ,
            --    @LotSN = @PLotSN;

			-- 2026/11/6 AB翻转工单，B面只落记录不过站，等A面过站
			IF NOT EXISTS ( SELECT 1 FROM dbo.MOLink WITH (NOLOCK)
							WHERE MainMOId = @PMOId AND LinkType = 0 )
			BEGIN
				EXEC [dbo].[TxnBase_LotMove]
					@I_ReturnMessage = @I_ReturnMessage OUTPUT ,
					@I_PlugInCommand = @I_PlugInCommand ,
					@I_OrBitUserId = @I_OrBitUserId ,
					@I_ResourceId = @I_ResourceId ,
					@LotSN = @PLotSN;
			END

        END; 

		-- 写入过账数量
        EXEC SysGetObjectPKId
            '' ,
            'DCBotMinScan' ,
            @DCBotMinScanId OUTPUT; 

        INSERT  INTO DCBotMinScan ( DCBotMinScanId, DataChainId, LotId, LotSN, MOId, FrameQnty, ProductId, Operator,
                                    Side, SpecificationId, WorkflowId, WorkflowStepId, WorkcenterId, ResourceId, UserId,
                                    Fixlotsn, CreateDate, Qty )
        VALUES  ( @DCBotMinScanId, @DataChainId, @PLotId, @PLotSN, @MOId, 1, @PProductId, @Operator, @Side,
                  @PSpecificationId, @PWorkflowId, @PWorkflowStepId, @WorkcenterId, @I_ResourceId, @I_OrBitUserId,
                  LEFT(@PLotSN, CHARINDEX('-', @PLotSN) - 1), @now, @Qty );

        SELECT  @PCBOnSMTId = MIN(PCBOnSMTId)
        FROM    PCBOnSMT
        WHERE   MOId = @MOId AND ISNULL(BeginQty, 0) > ISNULL(BUsedQty, 0);

        IF @Side = 'B' AND ISNULL(@LotSN, '') <> ''
        BEGIN
            UPDATE  PCBOnSMT
            SET     BUsedQty = ISNULL(BUsedQty, 0) + 1
            WHERE   PCBOnSMTId = @PCBOnSMTId; 
        END;

        SET @EndTime = GETDATE();
        SET @I_ReturnMessage = 'ServerMessage:产品批号 [' + @ParentLotSN + '] 过站扫描成功. 耗时 ' + CAST(DATEDIFF(SECOND,
                                                                                                       @StartTime,
                                                                                                       @EndTime) AS VARCHAR) + ' 秒.';
        SELECT  @FinishQty = SUM(FrameQnty)
        FROM    DCBotMinScan
        WHERE   MOId = @MOId; -- AND WorkcenterId = @WorkcenterId; 把线别去掉 modify by Wang AL 2019.04.02
        SELECT  '' AS CombineList;
        SELECT  '' AS FrameSN, @FinishQty AS FinishQty, '' AS HideList, 'ok.png' AS WarnImage;

        UPDATE  MOItemLot
        SET     ProductDate = GETDATE()
        WHERE   LotSN = @PLotSN;
		
        FETCH NEXT FROM cursor2 
		INTO @PLotId, @PLotSN, @PLotStatus, @PMOId, @MOItemId, @PProductId, @PSpecificationId, @PWorkflowId,
            @PWorkflowStepId, @Qty;
    END;
    CLOSE cursor2; 
    DEALLOCATE cursor2; 

    IF ISNULL(@ParentLotSN, '') = ''
        SET @ParentLotSN = @PLotSN;

    IF ISNULL(@PCBType, '') = ''
        SET @PCBType = '';

    SET @EndTime = GETDATE();
    SET @I_ReturnMessage = 'ServerMessage:产品批号 [' + ISNULL(@ParentLotSN, '') + '] 过站扫描成功，成功传送到下一站. 耗时 ' + RTRIM(CAST(DATEDIFF(SECOND,
                                                                                                        @StartTime,
                                                                                                        @EndTime) AS VARCHAR)) + ' 秒.';
    SELECT  @FinishQty = COUNT(FrameQnty)
    FROM    dbo.DCBotMinScan
    WHERE   MOId = @MOId AND Side = @Side;

    SELECT  '' AS CombineList, CAST(ISNULL(@remainminute, 0) AS FLOAT) AS Remaintime;
    SELECT  '' AS LotSN, @FinishQty AS FinishQty, '' AS HideList, 'ok.png' AS WarnImage, 0 AS ReturnValue; 
    SET @I_ExceptionFieldName = 'PCBType';	
    RETURN 0;    
END;







