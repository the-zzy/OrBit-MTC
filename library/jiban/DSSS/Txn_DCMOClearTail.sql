

-- =============================================
-- Author:		<Wang AL>
-- Create date: <2019.06.06>
-- Description:	工单清尾
-- =============================================
/*
	修改日志：
	2019.06.06 增加清尾功能
	1. 清尾不检查钢网， 刮刀， 
	2. 只有生产了订单的90%以上才能进行清尾，剩下工单的最后100块才能清尾

	2019.07.29
	
	1，工单和扫描批号一致
	2. 线体那里变成可选项，扫描的工单必须是在这条线体上做过，没做过，不允许扫描而且面别也要一致
	3. 扫描的数量总的不能超过批号启动的数量
	4. 取消100块限制
	5. 取消密码输入
	6. 其它灰色框，根据工单带出来
	7. 这个插件只针对下线工单扫描，如果这个工单是我在线正在生产的，不允许扫描(机台卸料， SMT转工单)

*/
CREATE PROCEDURE [dbo].[Txn_DCMOClearTail]
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
    @IsClearTail BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	-----------------2021.01.25 alter by wang rt,周甜甜说要停用一周-----------------------
	SET @I_ReturnMessage = 'ServerMessage:工单清尾暂时停用！'
	RETURN -1;

    DECLARE @return_value INT;
    DECLARE @Date DATETIME;
    DECLARE @TxnCode VARCHAR(10);
    DECLARE @LotId CHAR(12);
    DECLARE @LotStatus CHAR(1);
    DECLARE @LotProductId CHAR(12);
    DECLARE @LotProductName NVARCHAR(50);
    DECLARE @LotMOId CHAR(12);
    DECLARE @LotWorkflowStepId CHAR(12);
    DECLARE @LotSpecificationId CHAR(12);
    DECLARE @ParentLotId CHAR(12);
    DECLARE @ParentLotSN NVARCHAR(100); 
    DECLARE @DataChainId CHAR(12);
    DECLARE @WorkcenterId CHAR(12); 
    DECLARE @MOProductId CHAR(12);  
    DECLARE @DCStoveStationScanId CHAR(12);
    DECLARE @PLotId CHAR(12);
    DECLARE @PLotSN NVARCHAR(50);
    DECLARE @PLotStatus CHAR(1);
    DECLARE @PMOId CHAR(12);
    DECLARE @PProductId CHAR(12);
    DECLARE @PSpecificationId CHAR(12);
    DECLARE @PWorkflowId CHAR(12);
    DECLARE @PWorkflowStepId CHAR(12);
    DECLARE @LotStepBackflushId CHAR(12);
    DECLARE @FinishQty INT= 0;
    DECLARE @MESTxnObjectName NVARCHAR(50);
    DECLARE @SubmitBarCode NVARCHAR(50);
    DECLARE @ScanQty INT= 0;
    DECLARE @StartTime DATETIME;
    DECLARE @EndTime DATETIME;
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
    DECLARE @MOQtyRequired NUMERIC(18, 2)= 0;
    DECLARE @MOQtyDone NUMERIC(18, 2)= 0;

    SET @I_ExceptionFieldName = 'LotSN';
    SET @MESTxnObjectName = 'DC StoveStation Scan';
    SET @return_value = -1;
    SET @TxnCode = 'DC';
    SET @Date = GETDATE();
    SET @LotId = '';
    SET @LotMOId = '';
    SET @LotProductId = '';
    SET @LotProductName = '';
    SET @ParentLotId = '';
    SET @WorkcenterId = '';
    SET @DataChainId = '';
    SET @ParentLotSN = '';
    SET @MOProductId = '';
    SET @DCStoveStationScanId = '';
    SET @PLotId = '';
    SET @PLotSN = '';
    SET @PLotStatus = '';
    SET @PMOId = '';
    SET @PProductId = '';
    SET @LotStepBackflushId = '';
    SET @PSpecificationId = '';
    SET @PWorkflowId = '';
    SET @PWorkflowStepId = '';
    SET @SubmitBarCode = 'SUBMIT';
    SET @StartTime = GETDATE();
    SET @EndTime = GETDATE();

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
        SELECT  '' AS LotSN, '' AS HideList, '' AS FinishQty, 'ok.png' AS WarnImage;--,--30 as Remaintime
        SET @I_ReturnMessage = 'ServerMessage:数据清除成功，请重新扫描产品条码!' + CAST(@Remaintime AS CHAR);
        SET @I_ExceptionFieldName = 'LotSN';	
        RETURN 0;
    END;

	--检查是否为空
    IF ISNULL(@MOId, '') = ''
    BEGIN		
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入工单号!';

        SELECT  '' AS CombineList;
        SELECT  '' AS LotSN, '' AS HideList, 'error.png' AS WarnImage;
        SET @I_ExceptionFieldName = 'MOName';
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
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
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
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
        RETURN -1;
    END;

	--操作员是否为空
    IF ISNULL(@Operator, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:say{OK.wav}请输入操作员工号!';

        SELECT  '' AS CombineList;
        SELECT  '' AS Operator, '' AS LotSN, 'ok.png' AS WarnImage;
        SET @I_ExceptionFieldName = 'Operator';
        RETURN 0;
    END;

	--检查人员工号是否存在
    IF NOT EXISTS ( SELECT  PersonInfoId
                    FROM    PersonInfo(NOLOCK)
                    WHERE   PersonNumber = @Operator AND IsActivity = 1 )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:say{OK.wav}操作员工号 [' + @Operator + '] 不存在或已离职!';
		
        SELECT  '' AS CombineList;
        SELECT  '' AS Operator, '' AS LotSN, 'error.png' AS WarnImage;
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
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
        RETURN -1;
    END;

	--获取Lot信息
    SELECT  @LotId = LotId, @LotMOId = MOId, @LotStatus = LotStatus, @LotSpecificationId = SpecificationId
    FROM    Lot(NOLOCK)
    WHERE   LotSN = @LotSN;


	--检查条码是否重复扫描--
    IF EXISTS ( SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   parameter_Value <> '' AND parameter_Value = @LotSN )
    BEGIN
        SELECT  parameter_Value AS CombineList
        FROM    ConvertParameterToTable(@HideList, ';')
        WHERE   parameter_Value <> '';
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}重复扫描条码[' + @LotSN + ']!';
        RETURN -1;    
    END;


	---------------------------------------增加清尾数量判断Begin------------------------------------------------------------

    SELECT  @MOQtyRequired = MOQtyRequired
    FROM    dbo.MO(NOLOCK)
    WHERE   MOId = @MOId;

    SELECT  @MOQtyDone = COUNT(1)
    FROM    dbo.DCStoveStationScan
    WHERE   MOId = @MOId;

	-- 工单数量超过100， 并且未生产数量超过100， 不能进行清尾。
    --IF ISNULL(@MOQtyRequired, 0) > 100 AND ISNULL(@MOQtyRequired, 0) - ISNULL(@MOQtyDone, 0) > 100
    --BEGIN 
    --    SET @I_ReturnMessage = 'ServerMessage:剩余数量超过100，不能进行清尾 ';

    --    SELECT  '' AS CombineList, 0 AS Remaintime;
    --    SELECT  '' AS LotSN, '' AS HideList, 'error.png' AS WarnImage;

    --    RETURN -1; 
    --END; 
	---------------------------------------增加清尾数量判断Begin------------------------------------------------------------
	--把submit提交命令排除--
    IF ISNULL(@LotSN, '') <> ISNULL(@SubmitBarCode, '')
    BEGIN
		--检查 LotSN 是否存在
        IF NOT EXISTS ( SELECT  LotId
                        FROM    Lot(NOLOCK)
                        WHERE   LotSN = @LotSN )
        BEGIN	
            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable(@HideList, ';')
            WHERE   parameter_Value <> '';
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;

            SET @I_ExceptionFieldName = 'LotSN';
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 不存在!';

            RETURN -1;
        END;

        IF ISNULL(@LotStatus, '0') <> '1'
        BEGIN
			
            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable(@HideList, ';')
            WHERE   parameter_Value <> '';
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
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
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
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

        IF @return_value = -1
        BEGIN	
            SET @I_ReturnMessage = @I_ReturnMessage;

            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable(@HideList, ';')
            WHERE   parameter_Value <> '';
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
            RETURN -1;
        END;

		--检查线别是否为空
        IF ISNULL(@WorkcenterId, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}用户 [' + @I_OrBitUserName + '] 未维护线别!';

            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable(@HideList, ';')
            WHERE   parameter_Value <> '';
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;

            RETURN -1;
        END;

		-- 检查该工单是否在此生产线生产
        IF NOT EXISTS ( SELECT  *
                        FROM    dbo.DCStoveStationScan(NOLOCK)
                        WHERE   MOId = @LotMOId  AND Side=@Side AND WorkcenterId = @WorkcenterId AND ISNULL(IsClear, 0) = 0 )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:say{OK.wav} 该批号的工单未在此生产线生产，不能用此生产线清尾[' + @LotSN + '] !';
		
            SELECT  '' AS CombineList;
            SELECT  '' AS Operator, '' AS LotSN, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'LotSN';
            RETURN -1;
        END;


	-- 检查该工单是否仍在生产
        IF EXISTS ( SELECT  *
                    FROM    dbo.LotOnSMT(NOLOCK)
                    WHERE   MOId = @LotMOId AND WorkcenterId = @WorkcenterId  AND Side=@Side)
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:say{OK.wav} 该工单仍在生产，不能进行清尾[' + @LotSN + '] !';
		
            SELECT  '' AS CombineList;
            SELECT  '' AS Operator, '' AS LotSN, 'error.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'LotSN';
            RETURN -1;
        END;

    END;

	--获取工作中心编号
    SELECT  @WorkcenterId = WorkcenterId
    FROM    SysUser
    WHERE   UserId = @I_OrBitUserId;

	-- 检查是否是设备保养 
		 

    IF NOT EXISTS ( SELECT  1
                    FROM    ToolCollect t1 ( NOLOCK )
                    LEFT JOIN ToolManage t2 ( NOLOCK ) ON t1.ToolNumber = t2.ToolNumber
                    WHERE   t1.MOId = @MOId AND t1.WorkcenterId = @WorkcenterId AND t2.ToolTypeId IN ( 'URC1000000O9',
                                                                                                       'URC1000000T8' ) ) AND ISNULL(@IsClearTail,
                                                                                                        0) = 0 -- 不是清尾的才检查
		--if @uplinetiem  <= getdate() - 4
    BEGIN			
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}工单号 【' + @MOName + '】 在线别【' + @WorkcenterId + '】无钢网上料记录!';
        RETURN -1;
    END;

		-----判断是否有上刮刀
    DECLARE @count INT; 
    SET @count = 0;
    SELECT  @count = COUNT(ToolCollectId)
    FROM    ToolCollect t1 ( NOLOCK )
    LEFT JOIN ToolManage t2 ( NOLOCK ) ON t1.ToolNumber = t2.ToolNumber
    WHERE   t1.MOId = @MOId AND t1.WorkcenterId = @WorkcenterId AND t2.ToolTypeId = 'URC1000000OB';
    IF ( @count < 2 ) AND ISNULL(@IsClearTail, 0) = 0 -- 不是清尾的才检查
    BEGIN
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}工单号 【' + @MOName + '】 在线别【' + @WorkcenterId + '】无刮刀上料记录!';
        RETURN -1;
    END;
	--end

	-- 钢网清洗检查
    SET @uplinetiem = NULL;
    SELECT TOP 1
            @uplinetiem = t1.CreateDate
    FROM    ToolCollect t1 ( NOLOCK )
    LEFT JOIN ToolManage t2 ( NOLOCK ) ON t1.ToolNumber = t2.ToolNumber
    WHERE   t1.MOId = @MOId AND t1.WorkcenterId = @WorkcenterId AND t2.ToolTypeId IN ( 'URC1000000O9', 'URC1000000T8' )
    ORDER BY t1.CreateDate DESC;
 
    SET @check = 1;
    SET @CloseClear = 0;
    SET @Servicesfrom = NULL;
    SET @CloseCleartime = NULL;
    SET @message = '';
	---select convert(char,getdate(),108)-- 如果是保养，哪就增加时间。
    SELECT  @Servicesfrom = Servicefrom, @CloseClear = ISNULL(CloseClear, 0), @CloseCleartime = CloseCleartime
    FROM    Workcenter(NOLOCK)
    WHERE   WorkcenterId = @WorkcenterId;

    IF ISNULL(@Servicesfrom, '') <> ''
    BEGIN
        SET @CloseClear = 1;
        SET @CloseCleartime = @Servicesfrom;
    END;
    IF @CloseClear = 1
    BEGIN
	      --set @ServicesMinute = datediff(Minute,@CloseCleartime,Getdate())

		 --select datediff(Minute,'2018-03-29 10:43:56.110',Getdate()),

		-- select * from toolclear
        SELECT TOP 1
                @toolclearid = ToolClearId
        FROM    ToolClear(NOLOCK)
        WHERE   WorkcenterId = @WorkcenterId AND Side = @Side AND MOId = @MOId AND IsActive = 1
        ORDER BY CreateDate DESC;
        IF ISNULL(@toolclearid, '') = ''
        BEGIN
		     ----select '0' as Remaintime
            SET @message = '清洗报警已关闭,可以扫描下线!' + ISNULL(@toolclearid, '');
			
        END;
		  
    --   set @I_ReturnMessage='ServerMessage:say{Erorr.wav}钢网扫描清洗产出111!'
			 --return -1

		 
        IF CAST(ISNULL(@Remaintime, '0') AS FLOAT) <> 0
        BEGIN
		   ----set @intminute = cast(isnull(isnull(@Remaintime,''),0) as int)
            IF @Remaintime > 60
                SET @Remaintime = 1;
     	  --update toolclear set   clearscantime = createdate,CreateDate = dateadd(MINUTE, @Remaintime -60 ,getdate() ) where ToolClearId = @toolclearid

           --update toolclear set   cleartime = createdate,CreateDate = dateadd(MINUTE,0-30 ,getdate() ) where ToolClearId = @toolclearid
        END;
        SET @check = 0;
		  
    END;
    ELSE
    BEGIN
        UPDATE  ToolClear
        SET     IsActive = 0
        WHERE   DATEDIFF(MINUTE, CreateDate, GETDATE()) >= 60 AND MOId = @MOId AND @WorkcenterId = @WorkcenterId AND Side = @Side;  
    END;

    IF DATEDIFF(MINUTE, @uplinetiem, GETDATE()) <= 60
    BEGIN
        SET @check = 0;
    END;
    ELSE
    BEGIN
        SET @check = 1;
    END;
    IF CONVERT(CHAR, GETDATE(), 108) >= '07:30:00' AND CONVERT(CHAR, GETDATE(), 108) <= '08:30:00'
    BEGIN
        SET @check = 0;
    END;
    ELSE
    BEGIN
        SET @check = 1;
    END;
    IF CONVERT(CHAR, GETDATE(), 108) >= '19:30:00' AND CONVERT(CHAR, GETDATE(), 108) <= '20:30:00'
    BEGIN
        SET @check = 0;
    END;
    ELSE
    BEGIN
        SET @check = 1;
    END;

    IF @check = 1
    BEGIN
        IF NOT EXISTS ( SELECT  ToolClearId
                        FROM    ToolClear(NOLOCK)
                        WHERE   Side = @Side AND MOId = @MOId AND WorkcenterId = @WorkcenterId AND IsActive = 1 ) AND ISNULL(@IsClearTail,
                                                                                                        0) = 0 -- 不是清尾的才检查
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}钢网没有进行清洗扫描,请做清洗扫描后再产出!';
            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable(@HideList, ';')
            WHERE   parameter_Value <> '';
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
            RETURN -1;
        END;
        IF EXISTS ( SELECT  ToolClearId
                    FROM    ToolClear(NOLOCK)
                    WHERE   Side = @Side AND MOId = @MOId AND WorkcenterId = @WorkcenterId AND DATEDIFF(MINUTE,
                                                                                                        ClearScanTime,
                                                                                                        GETDATE()) >= 61 AND IsActive = 1 ) AND ISNULL(@IsClearTail,
                                                                                                        0) = 0 -- 不是清尾的才检查
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}钢网已经超过60分钟未清洗,请清洗钢网后再进行扫描!';
            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable(@HideList, ';')
            WHERE   parameter_Value <> '';
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
            RETURN -1;
        END;
    END;

	--拼板数大于 1

	--set @remainminute = 0
	--select top 1 @remainminute = datediff(minute,createdate,Getdate())  from ToolClear 
	--   where side = @side and moid = @moid  and Workcenterid = @Workcenterid and isactive = 1  order by createdate desc
	--if isnull(@remainminute,0) = 0
	--begin
	--  set @remainminute =  datediff(minute,@uplinetiem,Getdate())
	--  select top 1 @remainminute = datediff(minute,createdate,Getdate())  from ToolClear 
	--   where side = @side and moid = @moid  and Workcenterid = @Workcenterid  order by createdate desc
	--end
	--set @remainminute = 60 - isnull(@remainminute,0)     


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
                    SELECT  '' AS LotSN, @HideList AS HideList, 'SUBMIT.png' AS WarnImage;--,5 as Remaintime
                    RETURN 0;
                END;	
				--返回界面数据--
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   ISNULL(parameter_Value, '') <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'right.png' AS WarnImage;--,'1 ' as Remaintime
                RETURN 0;
            END;
			--当已完成拼板扫描，并且没有扫描提交条码
            IF @ScanQty = @MakeupNumber
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}上次扫描已达到拼板数 [' + CAST(@MakeupNumber AS VARCHAR) + '],请先扫描条码[Submit]提交,此次扫描批号[' + @LotSN + ']失效!';
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable(@HideList, ';')
                WHERE   ISNULL(parameter_Value, '') <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'SUBMIT.png' AS WarnImage;
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
                SELECT  '' AS LotSN, @HideList AS HideList, 'right.png' AS WarnImage;--,'1 ' as Remaintime
                RETURN 0;
            END;
            ELSE
            BEGIN
				--申请 ParentId
                EXEC SysGetObjectPKId
                    '' ,
                    'Lot' ,
                    @ParentLotId OUTPUT; 
            END;
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

	--定义一个表变量
    DECLARE @TempLotSN TABLE
        (
          LotId CHAR(12) ,
          LotSN NVARCHAR(50) ,
          LotStatus CHAR(1) ,
          MOId CHAR(12) ,
          ProductId CHAR(12) ,
          WorkflowId CHAR(12) ,
          SpecificationId CHAR(12) ,
          WorkflowStepId CHAR(12)
        );

	--给表变量赋值
    INSERT  INTO @TempLotSN
            SELECT  LotId, LotSN, LotStatus, MOId, ProductId, WorkflowId, SpecificationId, WorkflowStepId
            FROM    Lot(NOLOCK)
            WHERE   LotSN IN ( SELECT   parameter_Value AS LotSn
                               FROM     ConvertParameterToTable(@HideList, ';')
                               WHERE    parameter_Value <> '' );
	
	--重新获取工作中心--
    SELECT  @WorkcenterId = WorkcenterId
    FROM    SysUser(NOLOCK)
    WHERE   UserId = @I_OrBitUserId;

	--获取其中一个Lot信息--	
    SELECT TOP 1
            @LotSN = LotSN, @MOId = MOId, @MOProductId = ProductId, @LotSpecificationId = SpecificationId
    FROM    @TempLotSN;  
		
    SET @StartTime = GETDATE();

	--从工作中心里面控制是否核料扣料--
    --IF EXISTS ( SELECT  1
    --            FROM    Workcenter(NOLOCK)
    --            WHERE   WorkcenterId = @WorkcenterId AND IsClosed = 0 )
    --BEGIN
		--检查是否装配节点
        --IF EXISTS ( SELECT  1
        --            FROM    Specification(NOLOCK)
        --            WHERE   SpecificationId = @LotSpecificationId AND IsAssemblyStep = 1 )
        --BEGIN
		    --- update 2017.07.13 for billy   注消第一次的检查
			--炉后目检核对料站表
			--检查上料记录与料站表是否一致
			--exec @return_value=[dbo].[SMTStoveStationCheckDoMethod]
			--	@I_ReturnMessage=@I_ReturnMessage output,
			--	@I_ResourceId=@I_ResourceId,
			--	@I_ResourceName=@I_ResourceName,
			--	@I_OrBitUserId=@I_OrBitUserId,
			--	@I_OrBitUserName=@I_OrBitUserName,
			--	@LotSN=@LotSN,
			--	@MOId=@MOId,                 
			--	@ProductId=@MOProductId,             
			--	@WorkcenterId=@WorkcenterId, 
			--	@Side=@Side

			--if @return_value=-1
			--begin
			--	set @I_ReturnMessage=@I_ReturnMessage
			--	select parameter_Value as CombineList from ConvertParameterToTable(@HideList,';') where parameter_Value<>''
			--	select '' as LotSN,@HideList as HideList,'error.png' as WarnImage
			--	return -1
			--end  

			--检查是否满足扣料，满足则扣料 
			-- 清尾不需要扣料
            --EXEC @return_value= [dbo].[SMTBackflushDoMethod]
            --    @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
            --    @I_ResourceId = @I_ResourceId ,
            --    @I_ResourceName = @I_ResourceName ,
            --    @I_OrBitUserId = @I_OrBitUserId ,
            --    @I_OrBitUserName = @I_OrBitUserName ,
            --    @LotSN = @LotSN ,
            --    @MOId = @MOId ,
            --    @ProductId = @MOProductId ,
            --    @WorkcenterId = @WorkcenterId ,
            --    @Side = @Side ,
            --    @STDMakeupNumber = @STDMakeupNumber ,
            --    @MakeupNumber = @MakeupNumber;     
		
            --IF @return_value = -1
            --BEGIN
            --    SET @I_ReturnMessage = @I_ReturnMessage;
            --    SELECT  parameter_Value AS CombineList
            --    FROM    ConvertParameterToTable(@HideList, ';')
            --    WHERE   parameter_Value <> '';
            --    SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
            --    RETURN -1;
            --END;  
        --END;  				
    --END;

	--游标循环，数据采集，传送
    DECLARE cursor2 CURSOR
    FOR
    SELECT  LotId, LotSN, LotStatus, MOId, ProductId, SpecificationId, WorkflowId, WorkflowStepId
    FROM    @TempLotSN;
    OPEN cursor2; 
    FETCH NEXT FROM cursor2 
	INTO @PLotId, @PLotSN, @PLotStatus, @PMOId, @PProductId, @PSpecificationId, @PWorkflowId, @PWorkflowStepId;
    WHILE @@FETCH_STATUS = 0
    BEGIN 
		--写入 LotStepBackflush 表数据
        EXEC SysGetObjectPKId
            '' ,
            'LotStepBackflush' ,
            @LotStepBackflushId OUTPUT;
        INSERT  INTO LotStepBackflush ( LotStepBackflushId, LotId, LotSN, WorkcenterId, WorkflowId, WorkflowStepId,
                                        SpecificationId )
        VALUES  ( @LotStepBackflushId, @PLotId, @PLotSN, @WorkcenterId, @PWorkflowId, @PWorkflowStepId,
                  @PSpecificationId );

		--产生DataChain返回数据链Id
        EXEC [dbo].[TxnBase_DataChainMainLine]
            @DataChainId = @DataChainId OUTPUT ,
            @TxnCode = @TxnCode ,
            @I_PlugInCommand = @I_PlugInCommand ,
            @I_OrBitUserId = @I_OrBitUserId ,
            @I_ResourceId = @I_ResourceId ,
            @LotId = @PLotId ,
            @MOId = @PMOId ,
            @ProductId = @PProductId ,
            @WorkcenterId = @WorkcenterId ,
            @SpecificationId = @PSpecificationId ,
            @WorkflowStepId = @PWorkflowStepId;

		--写入一行数据
        EXEC SysGetObjectPKId
            '' ,
            'DCStoveStationScan' ,
            @DCStoveStationScanId OUTPUT;
        INSERT  INTO DCStoveStationScan ( DCStoveStationScanId, DataChainId, LotId, LotSN, MOId, ProductId, Operator,
                                          Side, SpecificationId, WorkflowId, WorkflowStepId, WorkcenterId, ResourceId,
                                          UserId, CreateDate, MakeupNumber, LockDate, IsClear )
        VALUES  ( @DCStoveStationScanId, @DataChainId, @PLotId, @PLotSN, @PMOId, @PProductId, @Operator, @Side,
                  @PSpecificationId, @PWorkflowId, @PWorkflowStepId, @WorkcenterId, @I_ResourceId, @I_OrBitUserId,
                  GETDATE(), @MakeupNumber, GETDATE(), 1 );

		--传送到下一节点
        EXEC [dbo].[TxnBase_LotMove]
            @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
            @I_PlugInCommand = @I_PlugInCommand ,
            @I_OrBitUserId = @I_OrBitUserId ,
            @I_ResourceId = @I_ResourceId ,
            @LotSN = @PLotSN;

		--试投物料
        EXEC [dbo].[TrialProduceMaterialData]
            @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
            @I_OrBitUserId = @I_OrBitUserId ,
            @I_ResourceId = @I_ResourceId ,
            @MOId = @PMOId ,
            @LotId = @PLotId;

		-- 更新绑定关系--
        UPDATE  Lot
        SET     ParentLotId = @ParentLotId
        WHERE   LotId = @PLotId;

        IF @ParentLotSN = ''
            SET @ParentLotSN = @PLotSN;
        ELSE
            SET @ParentLotSN = @ParentLotSN + ',' + @PLotSN;

        FETCH NEXT FROM cursor2 
		INTO @PLotId, @PLotSN, @PLotStatus, @PMOId, @PProductId, @PSpecificationId, @PWorkflowId, @PWorkflowStepId;
    END;
    CLOSE cursor2; 
    DEALLOCATE cursor2; 

	-- 判断是否要扣除钢网清洗次数
	
    SET @remainminute = 0;
    SELECT TOP 1
            @remainminute = DATEDIFF(MINUTE, ClearScanTime, GETDATE())
    FROM    ToolClear
    WHERE   Side = @Side AND MOId = @MOId AND WorkcenterId = @WorkcenterId AND IsActive = 1
    ORDER BY CreateDate DESC;
    IF ISNULL(@remainminute, 0) = 0 AND @IsClearTail =0 
    BEGIN
        SET @remainminute = DATEDIFF(MINUTE, @uplinetiem, GETDATE());
        SELECT TOP 1
                @remainminute = DATEDIFF(MINUTE, CreateDate, GETDATE())
        FROM    ToolClear(NOLOCK)
        WHERE   Side = @Side AND MOId = @MOId AND WorkcenterId = @WorkcenterId
        ORDER BY CreateDate DESC;
    END;
    SET @remainminute = 60 - ISNULL(@remainminute, 0);        

	--if @CloseClear = 1 
	  --set @remainminute=0

    SET @EndTime = GETDATE();
    SET @I_ReturnMessage = 'ServerMessage:产品批号 [' + @ParentLotSN + '] 过站扫描成功，成功传送到下一站. 耗时 ' + RTRIM(CAST(DATEDIFF(SECOND,
                                                                                                        @StartTime,
                                                                                                        @EndTime) AS VARCHAR)) + ' 秒.' + RTRIM(@message) + CAST(@remainminute AS CHAR);
    SELECT  @FinishQty = SUM(qty)
    FROM    (
              SELECT DISTINCT
                        LotId, 1 AS qty
              FROM      DCStoveStationScan(NOLOCK)
              WHERE     MOId = @MOId AND WorkcenterId = @WorkcenterId
            ) b;
    SELECT  '' AS CombineList, CAST(ISNULL(@remainminute, 0) AS FLOAT) AS Remaintime;
    SELECT  '' AS LotSN, @FinishQty AS FinishQty, '' AS HideList, 'ok.png' AS WarnImage;

    RETURN 0;    
END;











