-- =============================================
-- Author:		<Wang AnLiang>
-- Create date: <2018.04.28>
-- Description:	SMT炉后目检拼版自动采集
-- =============================================
CREATE PROCEDURE [dbo].[Txn_AOIAutoScan_before]
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
    @PathWay VARCHAR(20) = '' ,
    @FilePath NVARCHAR(100) = '' ,
    @txtCreateTime NVARCHAR(50) = ''
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SET @LotSN = UPPER(RTRIM(LTRIM(@LotSN)));
    SET @Operator = UPPER(@Operator);


    IF @LotSN = 'submit'
        INSERT  INTO dbo.tmpAOILog ( MOName, WorkcenterName, txtCreateTime, LotSN, HideList, createTime, FilePath )
        VALUES  ( @MOName,       -- MOName - nvarchar(20)
                  @WorkcenterName,       -- WorkcenterName - nvarchar(20)
                  @txtCreateTime, -- txtCreateTime - datetime
                  @LotSN,       -- LotSN - nvarchar(50)
                  @HideList      -- HideList - nvarchar(500)
                  , GETDATE(), @FilePath );


    DECLARE @SubmitBarCode NVARCHAR(50)= 'SUBMIT';
    DECLARE @TxnCode VARCHAR(10)= 'DC';
    DECLARE @MESTxnObjectName NVARCHAR(50)= 'DC StoveStation Scan';

    DECLARE @LotId CHAR(12)= '';
    DECLARE @LotMOId CHAR(12) = '';
    DECLARE @LotStatus CHAR(1) = '';
    DECLARE @ScanQty INT= 0;
    DECLARE @LotSpecificationId CHAR(12) = '';
    DECLARE @MOProductId CHAR(12) = '';  
    DECLARE @CustomerId CHAR(12)= '';
    DECLARE @LotProductName NVARCHAR(50) = '';
    DECLARE @return_value INT= -1;
    DECLARE @WorkcenterId CHAR(12) = ''; 
    DECLARE @IsIPQCCheck BIT = 0;
    DECLARE @UpLinetime DATETIME;
    DECLARE @Check BIT = 0;
    DECLARE @CloseClear BIT = 0;
    DECLARE @Servicesfrom DATETIME;
    DECLARE @CloseCleartime DATETIME; 
    DECLARE @Message NVARCHAR(20) = '';
    DECLARE @ToolClearId CHAR(12) = '';
    DECLARE @StartTime DATETIME= GETDATE();
    DECLARE @CloseBackflush BIT = 0;

    DECLARE @PLotId CHAR(12) = '';
    DECLARE @PLotSN NVARCHAR(50) = '';
    DECLARE @PLotStatus CHAR(1) = '';
    DECLARE @PMOId CHAR(12) = '';
    DECLARE @PProductId CHAR(12) = '';
    DECLARE @PSpecificationId CHAR(12) = '';
    DECLARE @PWorkflowId CHAR(12) = '';
    DECLARE @PWorkflowStepId CHAR(12) = '';
    DECLARE @LotStepBackflushId CHAR(12) = '';
    DECLARE @DataChainId CHAR(12) = '';
    DECLARE @DCStoveStationScanId CHAR(12) = '';
    DECLARE @SPIId CHAR(12) = '';
    DECLARE @SPIItemLotId CHAR(12) = '';
    DECLARE @ParentLotSN NVARCHAR(2000) = ''; 
    DECLARE @Remainminute DECIMAL(10, 2); 
    DECLARE @EndTime DATETIME= GETDATE();
    DECLARE @NowTime DATETIME = NULL;
    DECLARE @FinishQty INT= 0;
    DECLARE @count INT = 0;
    DECLARE @sendPerson NVARCHAR(MAX) = '';
    DECLARE @sendMsg NVARCHAR(MAX) = '';

    DECLARE @HadOffLineQty INT = 0;
    DECLARE @MOReqQty INT = 0;
    DECLARE @DCStoveStationScanQty INT = 0;
    DECLARE @DiffQty INT = 0;
    DECLARE @PQty DECIMAL(18, 4) = 0;

    DECLARE @PCBOnSMTId CHAR(12) = '';
    DECLARE @PCBONTime DATETIME = NULL;
    DECLARE @AOutPutTime DATETIME= '';
    DECLARE @BOutPutTime DATETIME= '';

    DECLARE @CurrSpecificationId CHAR(12)= '';

	--不是A面，直接返回
    IF @Side NOT IN ( 'A', 'AB' )
    BEGIN
        --SET @I_ReturnMessage = 'ServerMessage:AB面选择不对，只能是A面，或者AB面！！';
        RETURN -1;
    END;

    IF @Side = 'AB' AND @I_OrBitUserName NOT IN ( 'SC1227', 'SC1228', 'SC1229', 'SC1230', 'SC1219', 'SC1220' )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:只有27-30线可以选择AB面，请重新选择！！';
        RETURN -1;
    END;

    IF @I_Sender = 'BtnClear'
    BEGIN		
        SELECT  '' CombineList;
        SELECT  '' AS LotSN, '' AS HideList, '' AS FinishQty, 'ok.png' AS WarnImage, 0 AS ReturnValue; --,--30 as Remaintime
        SET @I_ReturnMessage = 'ServerMessage:数据清除成功，请重新扫描产品条码A!' + CAST(@Remaintime AS CHAR);
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
                    FROM    PersonInfo WITH ( NOLOCK )
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
        FROM    ConvertParameterToTable_N(@HideList, ';')
        WHERE   parameter_Value <> '';
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        RETURN -1;
    END;

	--检查拼板数是否足够
    IF @IsMakeupNumber = -1
    BEGIN		
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}AOI检测PCB板 块数不足!';
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

	--Add 2022-07-07 工单为建立时不允许生产
    IF EXISTS ( SELECT TOP 1
                        1
                FROM    dbo.MO
                WHERE   MOId = @MOId AND MOERPStatus = '建立' )
    BEGIN	
        SELECT  '' AS CombineList;
        SELECT  '' AS LotSN, '' AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        SET @I_ExceptionFieldName = 'MOName';
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}工单 [' + @MOName + '] 未释放，不允许下线!';
        RETURN -1;	
    END;

	--标准拼板数必须大于零
    IF ISNULL(@STDMakeupNumber, 0) <= 0
    BEGIN		
        SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}标准拼板数 [' + CAST(@STDMakeupNumber AS VARCHAR) + '] 必须大于零!';
        SET @I_ExceptionFieldName = 'STDMakeupNumber';

        SELECT  parameter_Value AS CombineList
        FROM    ConvertParameterToTable_N(@HideList, ';')
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
        FROM    ConvertParameterToTable_N(@HideList, ';')
        WHERE   parameter_Value <> '';
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        RETURN -1;
    END;
   
    --add by LZH 2023.08.11 首件确认审批限制
    /*IF EXISTS (
    	SELECT 1 
    	FROM dbo.FirstToConfirm 
    	WHERE MoId = @MOId AND [Type] = 'M' AND IsLinkOA = 1
    	AND ConfirmStuas <> '50'
    	AND GETDATE() > DATEADD(MINUTE, 60, CreateDate)
    )
    BEGIN
	    SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}工单' + @MOName + '首件审批流程未通过，无法扫描！';
        SET @I_ExceptionFieldName = 'LotSN';
       
        SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
        RETURN -1;
	END */


		-- Add by Wang AL 2023.12.27 添加QMS停线功能
    DECLARE @LineStopNo VARCHAR(39)= '';
    DECLARE @AlarmReasonDesc NVARCHAR(300)= '';
    DECLARE @AlarmSOName VARCHAR(20)= '';

    IF EXISTS ( SELECT  1
                FROM    dbo.QMSLineStop(NOLOCK)
                WHERE   WorkcenterName = @WorkcenterName AND AlarmType IN ( '21' ) )
    BEGIN 
        SELECT TOP 1
                @LineStopNo = LineStopNo, @AlarmReasonDesc = AlarmReasonDesc, @AlarmSOName = SOName
        FROM    dbo.QMSLineStop(NOLOCK)
        WHERE   WorkcenterName = @WorkcenterName AND AlarmType IN ( '21' )
        ORDER BY CreateDate DESC;

        SET @I_ReturnMessage = 'ServerMessage:QMS系统发起停线，不能下线扫描，线体[' + @WorkcenterName + ']单号[' + @LineStopNo + '],原因：[' + @AlarmReasonDesc + ']';

        RETURN -1; 
    END; 


    BEGIN TRY 
		
        IF EXISTS ( SELECT  1
                    FROM    MOLink
                    WHERE   MainMOId = @MOId AND LinkTypeDesc = 'AB反转' ) AND LEN(@LotSN) > 16 AND @Side = 'A' AND @LotSN <> 'SUBMIT'
        BEGIN
            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable_N(@HideList, ';')
            WHERE   parameter_Value <> '';
	       
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
            SET @I_ReturnMessage = 'ServerMessage: 当前工单A面只能扫描副条码['+@LotSN+']!';
            RETURN -1;   
        END;
	    
        IF EXISTS ( SELECT  1
                    FROM    MOLink
                    WHERE   MainMOId = @MOId AND LinkTypeDesc = 'AB反转' ) AND LEN(@LotSN) <= 16 AND @Side = 'B' AND @LotSN <> 'SUBMIT'
        BEGIN
            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable_N(@HideList, ';')
            WHERE   parameter_Value <> '';
	       
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage;
            SET @I_ReturnMessage = 'ServerMessage: 当前工单B面只能扫描主条码['+@LotSN+']!';
            RETURN -1;   
        END;
	    
        SELECT @LotProductName = b.prdname
		FROM dbo.MO a
		INNER JOIN dbo.Product b ON b.ProductId = a.ProductId
		WHERE a.MOId = @MOId

        IF EXISTS ( SELECT  1
                    FROM    MOLink
                    WHERE   MainMOId = @MOId AND LinkTypeDesc = 'AB反转' ) AND LEN(@LotSN) <= 16 AND @LotSN <> 'SUBMIT' AND @LotProductName NOT LIKE '5JB%'
        BEGIN
            SET @LotSN = dbo.BSideLotSNToASide(@LotSN);
        END;

		--检查条码是否重复扫描--
        IF EXISTS ( SELECT  parameter_Value AS CombineList
                    FROM    ConvertParameterToTable_N(@HideList, ';')
                    WHERE   parameter_Value = @LotSN AND parameter_Value <> '' )
        BEGIN
            SELECT  parameter_Value AS CombineList
            FROM    ConvertParameterToTable_N(@HideList, ';')
            WHERE   parameter_Value <> '';
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}重复扫描 条 码[' + @LotSN + ']!';
            RETURN -1;
        END;

        PRINT '340';
				------------------------------关联逻辑 ---------------------------------

		--DECLARE @tid INT=0;
		--DECLARE @lotsnB NVARCHAR(50)='';
		--DECLARE @relateFlag BIT =0;
		--IF @LotSN='submit' and   EXISTS(SELECT 1 FROM dbo.TmpPCBAutoCollect WHERE --MOId=@MOId AND
		-- WorkcenterName=@WorkcenterName AND CreateDate > DATEADD(SECOND,-10,@txtCreateTime) 
		--					AND CreateDate < @txtCreateTime AND ISNULL(RelateSN ,'')='' )
		--BEGIN
			
		--	SET @relateFlag =1 
		--	SELECT TOP 1  @tid=Id FROM dbo.TmpPCBAutoCollect WHERE WorkcenterName=@WorkcenterName AND CreateDate > DATEADD(SECOND,-10,@txtCreateTime) AND ISNULL(RelateSN ,'')=''
		--	AND CreateDate < @txtCreateTime  ORDER BY CreateDate DESC

		--END

  --       IF @LotSN='submit' and  @relateFlag=0 AND   EXISTS(SELECT 1 FROM dbo.TmpPCBAutoCollect WHERE WorkcenterName=@WorkcenterName AND CreateDate > DATEADD(SECOND,-15,@txtCreateTime) 
		--					AND CreateDate < @txtCreateTime AND ISNULL(RelateSN ,'')='' )
		--BEGIN
			
			
		--	SELECT TOP 1  @tid=Id FROM dbo.TmpPCBAutoCollect WHERE  WorkcenterName=@WorkcenterName AND CreateDate > DATEADD(SECOND,-15,@txtCreateTime) AND ISNULL(RelateSN ,'')=''
		--	AND CreateDate < @txtCreateTime  ORDER BY CreateDate DESC

		--END

		--IF @LotSN='submit' and  @relateFlag=0 AND   EXISTS(SELECT 1 FROM dbo.TmpPCBAutoCollect WHERE WorkcenterName=@WorkcenterName AND CreateDate > DATEADD(SECOND,-20,@txtCreateTime) 
		--					AND CreateDate < @txtCreateTime AND ISNULL(RelateSN ,'')='' )
		--BEGIN
			
			
		--	SELECT TOP 1  @tid=Id FROM dbo.TmpPCBAutoCollect WHERE WorkcenterName=@WorkcenterName AND CreateDate > DATEADD(SECOND,-20,@txtCreateTime) AND ISNULL(RelateSN ,'')=''
		--	AND CreateDate < @txtCreateTime  ORDER BY CreateDate DESC

		--END
		--	IF @relateFlag=0 AND   EXISTS(SELECT 1 FROM dbo.TmpPCBAutoCollect WHERE WorkcenterName=@WorkcenterName AND CreateDate > DATEADD(SECOND,-25,@txtCreateTime) 
		--					AND CreateDate < @txtCreateTime AND ISNULL(RelateSN ,'')='' )
		--BEGIN
			
			
		--	SELECT TOP 1  @tid=Id FROM dbo.TmpPCBAutoCollect WHERE WorkcenterName=@WorkcenterName AND CreateDate > DATEADD(SECOND,-25,@txtCreateTime) AND ISNULL(RelateSN ,'')=''
		--	AND CreateDate < @txtCreateTime  ORDER BY CreateDate DESC

		--END

		--UPDATE dbo.TmpPCBAutoCollect SET RelateSN=@LotSN,RelateDate=GETDATE(),txttime=@txtCreateTime WHERE Id=@tid;



			------------------------------关联逻辑 ---------------------------------

		--把submit提交命令排除--
        IF ISNULL(@LotSN, '') <> ISNULL(@SubmitBarCode, '')
        BEGIN

            PRINT '399';
			--检查 LotSN 是否存在
            IF NOT EXISTS ( SELECT  LotId
                            FROM    Lot(NOLOCK)
                            WHERE   LotSN = @LotSN )
            BEGIN	
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable_N(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 

                SET @I_ExceptionFieldName = 'LotSN';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + ISNULL(@LotSN, '') + '] 不存在11!';

                RETURN -1;
            END;

            PRINT '410';
			--获取Lot信息
            SELECT  @LotId = LotId, @LotMOId = MOId, @LotStatus = LotStatus, @LotSpecificationId = SpecificationId
            FROM    Lot WITH ( NOLOCK )
            WHERE   LotSN = @LotSN;

            IF @LotSpecificationId <> 'SPE10000019B' AND 1 = 2
            BEGIN
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable_N(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 

                SET @I_ExceptionFieldName = 'LotSN';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + ']不在炉后目检节点';

                IF NOT EXISTS ( SELECT  1
                                FROM    dbo.lotStartCheckLog
                                WHERE   MOId = @LotMOId AND remark = 'SMT' AND createdate > CONVERT(VARCHAR(100), GETDATE(), 23) AND lotsn = @LotSN )
                BEGIN
                    INSERT  dbo.lotStartCheckLog ( lotsn, errormsg, MOId, createdate, remark )
                    VALUES  ( @LotSN,      -- lotsn - nvarchar(50)
                              @I_ReturnMessage,      -- errormsg - nvarchar(200)
                              @LotMOId, GETDATE(), -- createdate - datetime
                              'SMT' );


                    IF EXISTS ( SELECT  1
                                FROM    dbo.lotStartCheckLog
                                WHERE   MOId = @LotMOId AND remark = 'SMT' AND createdate > CONVERT(VARCHAR(100), GETDATE(), 23) AND lotsn = @LotSN )
                    BEGIN
                        DECLARE @tcount INT = 0;
						
						 --SELECT @tcount = COUNT(1) FROM dbo.lotStartCheckLog WHERE moid=@LotMOId AND createdate >  CONVERT(varchar(100), GETDATE(), 23)  AND remark ='SMT'
                        SELECT  @tcount = COUNT(1)
                        FROM    dbo.lotStartCheckLog
                        WHERE   MOId = @LotMOId AND createdate > DATEADD(HOUR, -1, GETDATE()) AND remark = 'SMT'; 

                        DECLARE @tmsg NVARCHAR(MAX) = '[' + CONVERT(VARCHAR(100), GETDATE(), 25) + ']注意拉别：' + @WorkcenterName + '产品条码[' + @LotSN + ']不在炉后目检节点！此工单[' + @MOName + '] 1小时已累计报错' + CONVERT(VARCHAR(20), @tcount) + 'PCS！请检查！';
							
						--A班拉长 必须在7点30前打卡。
                        IF @tcount > 30
                        BEGIN 
                            IF EXISTS ( SELECT  1
                                        FROM    dbo.ClockRecord
                                        WHERE   PersonNumber IN ( '2026949', '2045533', '2000661', '2014597', '2061898',
                                                                  '2082092', '2014486', '2026392' ) AND createDateTime > CONVERT(VARCHAR(20), GETDATE(), 23) + ' 6:30:00' AND createDateTime < CONVERT(VARCHAR(20), GETDATE(), 23) + ' 7:30:00' )
                            BEGIN
                                IF (
                                     GETDATE() > CONVERT(VARCHAR(20), GETDATE(), 23) + ' 7:30:00' AND GETDATE() < CONVERT(VARCHAR(20), GETDATE(), 23) + ' 19:30:00'
                                   )
                                BEGIN
                                
                                    EXEC dbo.SendMsgToOADoMethod
                                        @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
                                        @TriggerProcedure = N'' ,                    -- nvarchar(50)
                                        @SendMsg = @tmsg ,                             -- nvarchar(max)
                                        @UserName = N'2061399|2026949|2045533|2000661|2014597|2061898|2082092|2014486|2026392|2027602|1001317';                             -- nvarchar(max)
                                END;
                                ELSE
                                BEGIN
                                    EXEC dbo.SendMsgToOADoMethod
                                        @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
                                        @TriggerProcedure = N'' ,                    -- nvarchar(50)
                                        @SendMsg = @tmsg ,                             -- nvarchar(max)
                                        @UserName = N'2061399|1000389|1002996|2072437|2075588|2016127|1001475|2054836|2055235|2017774';        
                                END;
                                
     
                            END;
                            ELSE
                            BEGIN
                                IF (
                                     GETDATE() > CONVERT(VARCHAR(20), GETDATE(), 23) + ' 7:30:00' AND GETDATE() < CONVERT(VARCHAR(20), GETDATE(), 23) + ' 19:30:00'
                                   )
                                BEGIN
                                
                                    EXEC dbo.SendMsgToOADoMethod
                                        @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
                                        @TriggerProcedure = N'' ,                    -- nvarchar(50)
                                        @SendMsg = @tmsg ,                             -- nvarchar(max)
                                        @UserName = N'2061399|1000389|1002996|2072437|2075588|2016127|1001475|2054836|2055235|2017774';        
                                END;
                                ELSE
                                BEGIN
                                    EXEC dbo.SendMsgToOADoMethod
                                        @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
                                        @TriggerProcedure = N'' ,                    -- nvarchar(50)
                                        @SendMsg = @tmsg ,                             -- nvarchar(max)
                                        @UserName = N'2061399|2026949|2045533|2000661|2014597|2061898|2082092|2014486|2026392|2027602|1001317';                             -- nvarchar(max)
                                END;
                                
						

                            END;
                        END;
                        
							

                        IF @tcount > 60
                        BEGIN

                            EXEC dbo.SendMsgToOADoMethod
                                @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
                                @TriggerProcedure = N'' ,                    -- nvarchar(50)
                                @SendMsg = @tmsg ,                             -- nvarchar(max)
                                @UserName = N'2061399|2009202|1001821';   

                        END;

                    END;


                END;

				

                RETURN -1;
            END;

            IF ISNULL(@LotStatus, '0') <> '1'
            BEGIN
			
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable_N(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                SET @I_ExceptionFieldName = 'LotSN';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 状态不可用!';

                RETURN -1;
            END;

			--------------------------ADD BY Wang RT 2020.6.20 BEGIN 投入数加已扫描数不能超过工单总数-------------------------------------------------------------
			----投入数
            SELECT  @HadOffLineQty = ISNULL(SUM(FrameQnty), 0)
            FROM    DCBotMinScan(NOLOCK)
            WHERE   MOId = @MOId AND Side = @Side;

			--已扫描数
            SELECT  @DCStoveStationScanQty = ISNULL(COUNT(DISTINCT LotSN), 0)
            FROM    dbo.DCStoveStationScan WITH ( NOLOCK )
            WHERE   MOId = @MOId AND Side = @Side AND SpecificationId = 'SPE10000025P';

			--工单数
            SELECT  @MOReqQty = MOQtyRequired
            FROM    dbo.MO(NOLOCK)
            WHERE   MOId = @MOId;

            SELECT  @DiffQty = CASE WHEN ( @HadOffLineQty + @DCStoveStationScanQty + @MakeupNumber - @MOReqQty ) > 0
                                    THEN ( @HadOffLineQty + @DCStoveStationScanQty + @MakeupNumber - @MOReqQty )
                                    ELSE 0
                               END; 

            IF @HadOffLineQty + @DCStoveStationScanQty + @MakeupNumber > @MOReqQty
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:工单：' + @MOName + ' 已提交数大于总需求数，不需要再提交！超出数为：' + CAST(@DiffQty AS VARCHAR(30));
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable_N(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS FrameSN, @HideList AS HideList, 'error.png' AS WarnImage;

                RETURN -1;
            END;
			--------------------------ADD BY Wang RT 2020.6.20  END  投入数加已扫描数不能超过工单总数-------------------------------------------------------------
	
			--获取工单信息
            SELECT  @MOProductId = MO.ProductId, @CustomerId = CustomerId
            FROM    MO WITH ( NOLOCK )
            WHERE   MOId = @LotMOId;

            IF ISNULL(@LotMOId, '') <> @MOId
            BEGIN
                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable_N(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                SET @I_ExceptionFieldName = 'LotSN';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 不属于该工单';

                RETURN -1;
            END;

            DECLARE @WorkcenterId2 CHAR(12)= '';

            SELECT  @WorkcenterId = WorkcenterId
            FROM    dbo.Workcenter
            WHERE   WorkcenterName = @WorkcenterName;

            INSERT  INTO dbo.TempSMTOffLine ( MOId, ProductId, WorkcenterId, ABSide, LotId, LotSN, SpecificationId,
                                              WorkflowId, WorkflowStepId, UserId, ResourceId, Operator, MakeupNumber,
                                              CreateDate )
                    SELECT  @MOId, @MOProductId, @WorkcenterId, @Side, b.LotId, parameter_Value, b.SpecificationId,
                            b.WorkflowId, b.WorkflowStepId, @I_OrBitUserId, @I_ResourceId, @Operator, @MakeupNumber,
                            GETDATE()
                    FROM    ConvertParameterToTable_N(@HideList, ';') a
                    LEFT JOIN dbo.Lot b ON b.LotSN = a.parameter_Value
                    WHERE   parameter_Value <> '';

			--获取工单产品信息
            SELECT  @LotProductName = ProductName
            FROM    Product WITH ( NOLOCK )
            INNER JOIN dbo.ProductRoot WITH ( NOLOCK ) ON Product.ProductRootId = ProductRoot.ProductRootId
            WHERE   Product.ProductId = @MOProductId;

			--检查是否允许操作此规程  
			-- 炉后暂时取消校验规程 2023.03.4 Modify by Wang AL 
            --EXEC @return_value= dbo.[SysCheckSpecification]
            --    @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
            --    @WorkcenterId = @WorkcenterId OUTPUT ,
            --    @LotId = @LotId ,
            --    @I_OrBitUserId = @I_OrBitUserId ,
            --    @I_OrBitUserName = @I_OrBitUserName ,
            --    @I_ResourceId = @I_ResourceId ,
            --    @I_ResourceName = @I_ResourceName ,
            --    @SpecificationId = @LotSpecificationId ,
            --    @MESTxnObjectName = @MESTxnObjectName;

            --IF @return_value = -1
            --BEGIN	
            --    SET @I_ReturnMessage = @I_ReturnMessage;

            --    SELECT  parameter_Value AS CombineList
            --    FROM  ConvertParameterToTable_N(@HideList, ';')
            --    WHERE   parameter_Value <> '';
            --    SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
            --    RETURN -1;
            --END;

			--检查线别是否为空
            IF ISNULL(@WorkcenterId, '') = ''
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}用户 [' + @I_OrBitUserName + '] 未维护线别!';

                SELECT  parameter_Value AS CombineList
                FROM    ConvertParameterToTable_N(@HideList, ';')
                WHERE   parameter_Value <> '';
                SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 

                RETURN -1;
            END;
        END;

		
		--获取工作中心编号
        SELECT  @WorkcenterId = WorkcenterId
        FROM    SysUser WITH ( NOLOCK )
        WHERE   UserId = @I_OrBitUserId;

        SELECT  @IsIPQCCheck = IsIPQCCheck
        FROM    dbo.Workcenter WITH ( NOLOCK )
        WHERE   WorkcenterId = @WorkcenterId;
        PRINT '663';
        IF NOT EXISTS ( SELECT  1
                        FROM    dbo.MOLotOnRecord
                        WHERE   MOId = @MOId AND WorkcenterId = @WorkcenterId AND Side = @Side )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:面别[' + @Side + ']不存在对应的上料记录，请重新选择面别！';

            RETURN -1;
        END;
        PRINT '666';
  --  IF ISNULL(@IsIPQCCheck, 0) = 1 --AND ISNULL(@WorkcenterId,'') IN ( 'WKC100000099','WKC100000141' ) 
  --  BEGIN
		
  --      DECLARE @SLMOId CHAR(12) = '';  ----当前线体最新上料的工单ID
  --      SELECT TOP 1
  --              @SLMOId = MOId
  --      FROM    dbo.MOLotOnRecord WITH ( NOLOCK )
  --      WHERE   WorkcenterId = @WorkcenterId
  --      ORDER BY CreateDate DESC;

		----如果上料工单跟炉后工单一致则检查是否核对上料记录
  --      SELECT TOP 1
  --              @MOId = MOId
  --      FROM    dbo.Lot WITH ( NOLOCK )
  --      WHERE   LotSN = @LotSN;
		
  --      IF @SLMOId = @MOId
  --      BEGIN
		---- 如果超过30分钟品质部没有进行核对上料， 则不能产出。  Add by Wang AL 2020.08.18
			

  --          IF EXISTS ( SELECT  a.MOLotOnRecordId
  --                      FROM    MOLotOnRecord a WITH ( NOLOCK )
  --                      LEFT JOIN dbo.SMTOnLineVerify b WITH ( NOLOCK ) ON a.LotSN = b.LotSN AND b.CreateDate > a.CreateDate
  --                      WHERE   a.CreateDate > CONVERT(VARCHAR(10), GETDATE() - 1, 120) --AND a.CreateDate > '2020-09-03 14:30:00' 
  --                              AND a.MOId = @MOId AND a.WorkcenterId = @WorkcenterId AND ISNULL(QCCheckFlag, 0) = 0 AND b.SMTOnLineVerifyId IS NULL AND ISNULL(a.MachineNumber,
  --                                                                                                      '') <> '' AND DATEDIFF(MINUTE,
  --                                   a.CreateDate,
 --                   GETDATE()) > 30 AND DATEDIFF(MINUTE,
  --                                                                                                      a.CreateDate,
  --                                                                                                      GETDATE()) < 120 )
  --          BEGIN 
  --              DECLARE @MachineNumber VARCHAR(50) = '';
  --              DECLARE @SLotNO VARCHAR(50) = '';
  --              SELECT TOP 1
  --                      @MachineNumber = a.MachineNumber, @SLotNO = a.SLotNO
  --              FROM    dbo.MOLotOnRecord a WITH ( NOLOCK )
  --              LEFT JOIN dbo.SMTOnLineVerify b WITH ( NOLOCK ) ON a.LotSN = b.LotSN AND b.CreateDate > a.CreateDate
  --              WHERE   a.CreateDate > CONVERT(VARCHAR(10), GETDATE() - 1, 120) --AND a.CreateDate > '2020-09-03 14:30:00' 
  --                      AND a.MOId = @MOId AND a.WorkcenterId = @WorkcenterId AND ISNULL(QCCheckFlag, 0) = 0 AND b.SMTOnLineVerifyId IS NULL AND ISNULL(a.MachineNumber,
  --                                                                                                      '') <> '' AND DATEDIFF(MINUTE,
  --                                                                                                      a.CreateDate,
  --                                                                                                      GETDATE()) > 30 AND DATEDIFF(MINUTE,
  --                                   a.CreateDate,
  --                                                                                         GETDATE()) < 120;

  --              SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav} 机型【' + @MachineNumber + '】，站位【' + @SLotNO + '】上料超过30分钟品质未复核， 不能产出！';

  --              SELECT  '' AS CombineList;        
  --              SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 

  --              RETURN -1;
  --          END; 
  --      END;
  --  END;
 
		--检查是否是设备保养
        IF NOT EXISTS ( SELECT  1
                        FROM    ToolCollect t1 WITH ( NOLOCK )
                        LEFT JOIN ToolManage t2 WITH ( NOLOCK ) ON t1.ToolNumber = t2.ToolNumber
                        WHERE   t1.MOId = @MOId AND t1.WorkcenterId = @WorkcenterId AND t2.ToolTypeId IN (
                                'URC1000000O9', 'URC1000000T8' ) )
        BEGIN		
            SELECT  '' AS CombineList;	
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}工单号 【' + @MOName + '】 在线别【' + @WorkcenterId + '】无钢网上料记录!';

            RETURN -1;
        END;

        SELECT  @count = COUNT(ToolCollectId)
        FROM    ToolCollect t1 WITH ( NOLOCK )
        LEFT JOIN ToolManage t2 WITH ( NOLOCK ) ON t1.ToolNumber = t2.ToolNumber
        WHERE   t1.MOId = @MOId AND t1.WorkcenterId = @WorkcenterId AND t2.ToolTypeId = 'URC1000000OB';
        IF ( @count < 2 )
        BEGIN
            SELECT  '' AS CombineList;
            SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
            SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}工单号 【' + @MOName + '】 在线别【' + @WorkcenterId + '】无刮刀上料记录!';

            RETURN -1;
        END;

		-- 钢网清洗检查
        SET @UpLinetime = NULL;
        SELECT TOP 1
                @UpLinetime = t1.CreateDate
        FROM    ToolCollect t1 WITH ( NOLOCK )
        LEFT JOIN ToolManage t2 WITH ( NOLOCK ) ON t1.ToolNumber = t2.ToolNumber
        WHERE   t1.MOId = @MOId AND t1.WorkcenterId = @WorkcenterId AND t2.ToolTypeId IN ( 'URC1000000O9',
                                                                                           'URC1000000T8' )
        ORDER BY t1.CreateDate DESC;
 
        SET @Check = 1;
        SET @CloseClear = 0;
        SET @Servicesfrom = NULL;
        SET @CloseCleartime = NULL;
        SET @Message = '';
		---select convert(char,getdate(),108)-- 如果是保养，哪就增加时间。
        SELECT  @Servicesfrom = Servicefrom, @CloseClear = ISNULL(CloseClear, 0), @CloseCleartime = CloseCleartime
        FROM    Workcenter WITH ( NOLOCK )
        WHERE   WorkcenterId = @WorkcenterId;


        IF ISNULL(@Servicesfrom, '') <> ''
        BEGIN
            SET @CloseClear = 1;
            SET @CloseCleartime = @Servicesfrom;
        END;

        IF @CloseClear = 1
        BEGIN      

            SELECT TOP 1
                    @ToolClearId = ToolClearId
            FROM    ToolClear(NOLOCK)
            WHERE   WorkcenterId = @WorkcenterId AND Side = @Side AND MOId = @MOId AND IsActive = 1
            ORDER BY CreateDate DESC;
            IF ISNULL(@ToolClearId, '') = ''
            BEGIN
		     ----select '0' as Remaintime
                SET @Message = '清洗报警已关闭,可以扫描下线!' + ISNULL(@ToolClearId, '');
			
            END;
		  
            --IF CAST(ISNULL(@Remaintime, '0') AS FLOAT) <> 0
            --BEGIN
            --    IF @Remaintime > 60
            --        SET @Remaintime = 1;
            --    UPDATE  ToolClear
            --    SET     ClearScanTime = CreateDate, CreateDate = DATEADD(MINUTE, @Remaintime - 60, GETDATE())
            --    WHERE   ToolClearId = @ToolClearId;
            --END;
            SET @Check = 0;
		  
        END;
        ELSE
        BEGIN
            UPDATE  ToolClear
            SET     IsActive = 0
            WHERE   MOId = @MOId AND @WorkcenterId = @WorkcenterId AND Side = @Side AND DATEDIFF(MINUTE, CreateDate,
                                                                                                 GETDATE()) >= 60;
        END;

        --IF NOT EXISTS ( SELECT TOP 1
        --                        ToolClearId
        --                FROM    ToolClear(NOLOCK)
        --                WHERE   WorkcenterId = @WorkcenterId AND DATEDIFF(MINUTE, CreateDate, GETDATE()) < 60 AND IsActive = 1 )
        --BEGIN
        --    SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}钢网没有进行清洗扫描,请做清洗扫描后再产出!' + @MOName + '/' + @WorkcenterName;
        --    SELECT  parameter_Value AS CombineList
        --    FROM    ConvertParameterToTable_N(@HideList, ';')
        --    WHERE   parameter_Value <> '';
        --    SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 

        --    RETURN -1;
        --END;
        PRINT '833';
        IF ISNULL(@MakeupNumber, 0) > 1
        BEGIN		
			--如果扫描的不是提交条码
            IF ISNULL(@LotSN, '') <> ISNULL(@SubmitBarCode, '')
            BEGIN
			--拼板数大于 1

				--获取已扫描的拼板SN个数
                SELECT  @ScanQty = ISNULL(COUNT(parameter_Value), 0)
                FROM    ConvertParameterToTable_N(@HideList, ';')
                WHERE   ISNULL(parameter_Value, '') <> '';
				--未达到拼板数
                IF @ScanQty < @MakeupNumber
                BEGIN
                    --SET @I_ReturnMessage = 'ServerMessage:请继续扫描产品批号!';
					--拼接字符串
                    IF @HideList = ''
                        SET @HideList = @LotSN;
                    ELSE
                        SET @HideList = @HideList + ';' + @LotSN;	
					--重新统计数量--
                    SELECT  @ScanQty = ISNULL(COUNT(parameter_Value), 0)
                    FROM    ConvertParameterToTable_N(@HideList, ';')
                    WHERE   ISNULL(parameter_Value, '') <> '';
                    IF @ScanQty = @MakeupNumber
                    BEGIN
                        --SET @I_ReturnMessage = 'ServerMessage:产品批号扫描已达到拼板数 [' + CAST(@MakeupNumber AS VARCHAR) + '] ，请扫描提交条码[Submit]!';
                        SELECT  parameter_Value AS CombineList
                        FROM    ConvertParameterToTable_N(@HideList, ';')
                        WHERE   ISNULL(parameter_Value, '') <> '';
                        SELECT  '' AS LotSN, @HideList AS HideList, 'SUBMIT.png' AS WarnImage, 0 AS ReturnValue; 
                        SET @I_ExceptionFieldName = 'LotSN';
                        RETURN 0;
                    END;	

					--返回界面数据--
                    SELECT  parameter_Value AS CombineList
                    FROM    ConvertParameterToTable_N(@HideList, ';')
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
                    FROM    ConvertParameterToTable_N(@HideList, ';')
                    WHERE   ISNULL(parameter_Value, '') <> '';
                    --SELECT  '' AS LotSN, @HideList AS HideList, 'SUBMIT.png' AS WarnImage, 0 AS ReturnValue; 

                    SELECT  '' AS LotSN, @HideList AS HideList, '' AS WarnImage, 0 AS ReturnValue; 

                    RETURN -1;
                END;
            END;

			--如果扫描的是提交条码
            IF ISNULL(@LotSN, '') = @SubmitBarCode
            BEGIN
				--获取已扫描的拼板SN个数
                SELECT  @ScanQty = ISNULL(COUNT(parameter_Value), 0)
                FROM    ConvertParameterToTable_N(@HideList, ';')
                WHERE   ISNULL(parameter_Value, '') <> '';
				--未达到拼板数
                IF @ScanQty < @MakeupNumber
                BEGIN
                    SET @I_ReturnMessage = 'ServerMessage:批号扫描未达到拼板数[' + CAST(@MakeupNumber AS VARCHAR) + '],请扫描产品条码!';
					--返回界面数据--
                    SELECT  parameter_Value AS CombineList
                    FROM    ConvertParameterToTable_N(@HideList, ';')
                    WHERE   ISNULL(parameter_Value, '') <> '';
                    SELECT  '' AS LotSN, @HideList AS HideList, 'right.png' AS WarnImage, 0 AS ReturnValue; 
                    SET @I_ExceptionFieldName = 'LotSN';
                    RETURN 0;
                END;
     --           ELSE
     --           BEGIN
					----申请 ParentId
     --               EXEC SysGetObjectPKId
     --                   '' ,
     --                   'Lot' ,
     --                   @ParentLotId OUTPUT; 
     --           END;
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

		-- ADD BY WANG RT 2020.12.11 针对中兴客户，PCB上料时间到B面产出不超过2小时，到A面产出不超过24小时 BEGIN ----
        SELECT  @CustomerId = b.CustomerId
        FROM    dbo.MO a WITH ( NOLOCK )
        LEFT JOIN dbo.SO b WITH ( NOLOCK ) ON b.SOName = a.SOName
        WHERE   a.MOId = @MOId;

        SET @BOutPutTime = GETDATE();
		--拼板数大于 1

		--定义一个表变量
        DECLARE @TempLotSN TABLE
            (
              Seq INT DEFAULT 0 ,
              LotId CHAR(12) DEFAULT '' ,
              LotSN NVARCHAR(50) DEFAULT '' ,
              LotStatus CHAR(1) DEFAULT '' ,
              MOId CHAR(12) DEFAULT '' ,
              ProductId CHAR(12) DEFAULT '' ,
              WorkflowId CHAR(12) DEFAULT '' ,
              SpecificationId CHAR(12) DEFAULT '' ,
              WorkflowStepId CHAR(12) DEFAULT '' ,
              Qty DECIMAL(18, 4) DEFAULT 0
            );

		--给表变量赋值
        INSERT  INTO @TempLotSN ( LotId, LotSN, LotStatus, MOId, ProductId, WorkflowId, SpecificationId, WorkflowStepId,
                                  Qty )
                SELECT  DISTINCT
                        LotId, LotSN, LotStatus, MOId, ProductId, WorkflowId, SpecificationId, WorkflowStepId, Qty
                FROM    Lot WITH ( NOLOCK )
                WHERE   LotSN IN ( SELECT   parameter_Value AS LotSn
                                   FROM     ConvertParameterToTable_N(@HideList, ';')
                                   WHERE    parameter_Value <> '' );
	
		--重新获取工作中心--
        SELECT  @WorkcenterId = WorkcenterId
        FROM    SysUser WITH ( NOLOCK )
        WHERE   UserId = @I_OrBitUserId;

		--获取其中一个Lot信息--	
        SELECT TOP 1
                @LotSN = LotSN, @MOId = MOId, @MOProductId = ProductId, @LotSpecificationId = SpecificationId,
                @LotId = LotId
        FROM    @TempLotSN;  
		
        SET @StartTime = GETDATE();

        DECLARE @I_ReturnMessage2 NVARCHAR(MAX);
	

	--IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.SPI WHERE MOId = @MOId AND WorkcenterId = @WorkcenterId AND IsUse = 0 AND Result IN ('PASS','GOOD')) AND @I_OrBitUserName = 'SC1202'
	--BEGIN
	--	SET @I_ReturnMessage = 'ServerMessage:无对应线体SPI数据，请检查！'
	--	RETURN -1
	--END

		--从工作中心里面控制是否核料扣料--
        SELECT  @CloseBackflush = IsClosed
        FROM    dbo.Workcenter WITH ( NOLOCK )
        WHERE   WorkcenterId = @WorkcenterId;

        IF @CustomerId IN ( 'CUS1000002LM', 'CUS1000002MI' )   -- 中兴的一不能关闭扣料！
            SET @CloseBackflush = 0;

        IF @CloseBackflush = 0
        BEGIN
		--检查是否装配节点
            IF EXISTS ( SELECT  1
                        FROM    Specification(NOLOCK)
                        WHERE   SpecificationId = @LotSpecificationId AND IsAssemblyStep = 1 )
            BEGIN
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
			--	select parameter_Value as CombineList from ConvertParameterToTable_N(@HideList,';') where parameter_Value<>''
			--	select '' as LotSN,@HideList as HideList,'error.png' as WarnImage,-1 AS ReturnValue
			--	return -1
			--end  

                IF @WorkcenterName >= 'S01' AND @WorkcenterName <= 'S99'
                BEGIN
					
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
                       
                    SET @return_value = 0;   

                    PRINT @HideList + '/' + @MOProductId + '/' + @MOId + '/' + @LotSN;

                END;
                ELSE
                BEGIN
				
                    EXEC @return_value= [dbo].[SMTBackflushDoMethod]
                        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
                        @I_ResourceId = @I_ResourceId ,
                        @I_ResourceName = @I_ResourceName ,
                        @I_OrBitUserId = @I_OrBitUserId ,
                        @I_OrBitUserName = @I_OrBitUserName ,
                        @LotSN = @LotSN ,
                        @MOId = @MOId ,
                        @ProductId = @MOProductId ,
                        @WorkcenterId = @WorkcenterId ,
                        @Side = @Side ,
                        @STDMakeupNumber = @STDMakeupNumber ,
                        @MakeupNumber = @MakeupNumber;    
                       
                    SET @return_value = 0;
                END;
                IF @return_value = -1
                BEGIN
                    SET @I_ReturnMessage = ISNULL(@I_ReturnMessage, '');
                    SELECT  parameter_Value AS CombineList
                    FROM    ConvertParameterToTable_N(@HideList, ';')
                    WHERE   parameter_Value <> '';

                    INSERT  INTO dbo.AOIUploadError ( LotSN, LotId, MOId, WorkcenterId, Side, Operator, ErrorMsg,
                                                      ResourceId, CreateUserId, CreateDate )
                    VALUES  ( @LotSN, @LotId, @MOId, @WorkcenterId, @Side, @Operator, @I_ReturnMessage, @I_ResourceId,
                              @I_OrBitUserId, GETDATE() );

                    SELECT  '' AS LotSN, @HideList AS HideList, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                    RETURN -1;
                END; 
			 
            END;  				
        END;

		---- add by wangruitao 2020.11.16 AOI 绑定 SPI  end  ----
		--游标循环，数据采集，传送
        DECLARE cursor2 CURSOR FAST_FORWARD LOCAL
        FOR
        SELECT  LotId, LotSN, LotStatus, MOId, ProductId, SpecificationId, WorkflowId, WorkflowStepId, Qty
        FROM    @TempLotSN;
        OPEN cursor2; 
        FETCH NEXT FROM cursor2 
		INTO @PLotId, @PLotSN, @PLotStatus, @PMOId, @PProductId, @PSpecificationId, @PWorkflowId, @PWorkflowStepId,
            @PQty;
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

            IF NOT EXISTS ( SELECT  1
                            FROM    dbo.DCStoveStationScan
                            WHERE   LotSN = @PLotSN AND Side = @Side AND SpecificationId = ISNULL(@PSpecificationId,'') )
            BEGIN
				--写入一行数据
                EXEC SysGetObjectPKId
                    '' ,
                    'DCStoveStationScan' ,
                    @DCStoveStationScanId OUTPUT;

                INSERT  INTO dbo.DCStoveStationScan ( DCStoveStationScanId, DataChainId, LotId, LotSN, MOId, ProductId,
                                                      Operator, Side, SpecificationId, WorkflowId, WorkflowStepId,
                                                      WorkcenterId, ResourceId, UserId, CreateDate, MakeupNumber,
                                                      LockDate, Fixlotsn, Qty )
                VALUES  ( @DCStoveStationScanId, @DataChainId, @PLotId, @PLotSN, @PMOId, @PProductId, @Operator, @Side,
                          @PSpecificationId, @PWorkflowId, @PWorkflowStepId, @WorkcenterId, @I_ResourceId,
                          @I_OrBitUserId, GETDATE(), @MakeupNumber, GETDATE(),
                          LEFT(@PLotSN, CHARINDEX('-', @PLotSN) - 1), @PQty );
            END;
			
            IF ISNULL(@SPIId, '') <> ''
            BEGIN
                EXEC [dbo].[SysGetObjectPKId]
                    '' ,
                    'SPIItemLot' ,
                    @SPIItemLotId OUTPUT;
                INSERT  INTO dbo.SPIItemLot ( SPIItemLotId, SPIId, LotId, CreateDate )
                VALUES  ( @SPIItemLotId, @SPIId, @PLotId, GETDATE() );
            END;

            IF @PSpecificationId = 'SPE10000025P'
            BEGIN
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

                EXEC [dbo].[TxnBase_LotMove]
                    @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
                    @I_PlugInCommand = @I_PlugInCommand ,
                    @I_OrBitUserId = @I_OrBitUserId ,
                    @I_ResourceId = @I_ResourceId ,
                    @LotSN = @PLotSN;
            END; 

			--试投物料
            EXEC [dbo].[TrialProduceMaterialData]
                @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
                @I_OrBitUserId = @I_OrBitUserId ,
                @I_ResourceId = @I_ResourceId ,
                @MOId = @PMOId ,
                @LotId = @PLotId;

			-- 更新绑定关系--
            UPDATE  MOItemLot
            SET     ProductDate = GETDATE()
            WHERE   LotSN = @PLotSN;

            IF @ParentLotSN = ''
                SET @ParentLotSN = @PLotSN;
            ELSE
                SET @ParentLotSN = @ParentLotSN + ',' + @PLotSN;

            FETCH NEXT FROM cursor2 
		INTO @PLotId, @PLotSN, @PLotStatus, @PMOId, @PProductId, @PSpecificationId, @PWorkflowId, @PWorkflowStepId,
                @PQty;
        END;
        CLOSE cursor2; 
        DEALLOCATE cursor2; 

		-- 判断是否要扣除钢网清洗次数
        SET @Remainminute = 0;
        SELECT TOP 1
                @Remainminute = DATEDIFF(MINUTE, CreateDate, GETDATE())
        FROM    ToolClear(NOLOCK)
        WHERE   Side = @Side AND MOId = @MOId AND WorkcenterId = @WorkcenterId AND IsActive = 1
        ORDER BY CreateDate DESC;

        IF ISNULL(@Remainminute, 0) = 0
        BEGIN
            SET @Remainminute = DATEDIFF(MINUTE, @UpLinetime, GETDATE());
            SELECT TOP 1
                    @Remainminute = DATEDIFF(MINUTE, CreateDate, GETDATE())
            FROM    ToolClear(NOLOCK)
            WHERE   Side = @Side AND MOId = @MOId AND WorkcenterId = @WorkcenterId
            ORDER BY CreateDate DESC;
        END;
        SET @Remainminute = 60 - ISNULL(@Remainminute, 0);        

	--if @CloseClear = 1 
	  --set @remainminute=0
	  /* 保存AOI数据 */

        IF ISNULL(@PCBType, '') = ''
            SET @PCBType = '';

		-- 行号
        DECLARE @RowQty INT = 0;
        DECLARE @Seq INT = 0;

        SELECT  @RowQty = COUNT(*)
        FROM    @TempLotSN;

        DECLARE @TempPKID TABLE
            (
              Seq INT ,
              AOIUploadDataId CHAR(12)
            );

        UPDATE  @TempLotSN
        SET     @Seq = @Seq + 1, Seq = @Seq;

        INSERT  INTO @TempPKID ( Seq, AOIUploadDataId )
                EXEC dbo.SysGetObjectPKIdBatch
                    @ObjectId = '' , -- char(12)
                    @ObjectName = N'AOIUploadData' , -- nvarchar(100)
                    @RowCount = @RowQty; -- int
		
        INSERT  INTO dbo.AOIUploadData ( AOIUploadDataId, LineNum, PathWay, PCB_SN, PCBA_SN, MOName, PCB_Type,
                                         CheckStatus, CheckDesc, CheckDate, WholeString, Remark, CreateDate )
                SELECT  b.AOIUploadDataId, @WorkcenterName LineNum, @PathWay PathWay, LotSN,
                        REPLACE(SUBSTRING(LotSN, CHARINDEX('/', LotSN) + 1, LEN(LotSN) - CHARINDEX('/', LotSN) + 1), '-',
                                '') PCBA_SN,
                        SUBSTRING(LotSN, CHARINDEX('/', LotSN) + 1, CHARINDEX('-', LotSN) - CHARINDEX('/', LotSN) - 1) MOName,
                        UPPER(@PCBType) PCB_Type, 'OK' CheckStatus, '' CheckDesc, GETDATE() CheckDate, '' WholeString,
                        '炉后测试自动生成' Remark, GETDATE() CreateDate
                FROM    @TempLotSN a
                INNER JOIN @TempPKID b ON b.Seq = a.Seq;	 

        SET @EndTime = GETDATE();
        SET @I_ReturnMessage = 'ServerMessage:产品批号 [' + @ParentLotSN + '] 过站扫描成功，成功传送到下一站. 耗时 ' + RTRIM(CAST(DATEDIFF(SECOND,
                                                                                                        @StartTime,
                                                                                                        @EndTime) AS VARCHAR)) + ' 秒.' + RTRIM(@Message) + CAST(@Remainminute AS CHAR);
    
 --炉后AOI首件确认 add by LZH 2023.08.07
        IF NOT EXISTS ( SELECT  1
                        FROM    dbo.FirstToConfirm
                        WHERE   MoId = @MOId AND [Type] = 'M' )
        BEGIN
            DECLARE @FirstToConfirmId CHAR(12);
            DECLARE @SOName VARCHAR(20);
	       
            SELECT  @SOName = SOName
            FROM    dbo.MO
            WHERE   MOId = @MOId;
	
            EXEC SysGetObjectPKId
                '' ,
                'FirstToConfirm' ,
                @FirstToConfirmId OUTPUT;                                              
            INSERT  INTO dbo.FirstToConfirm ( FirstToConfirmId, SoName, MoId, MoName, CustomerId, WorkcenterGroup,
                                              Operator, OperatorConfirmTime, ConfirmUserName, CustomerConfirmTime,
                                              ConfirmStuas, MOStuas, IsOverdue, CreateDate, [Type], IsLinkOA,
                                              WorkcenterName )
            VALUES  ( @FirstToConfirmId, -- FirstToConfirmId - char(12)
                      @SOName,-- SoName - nvarchar(50)
                      @MOId, -- MoId - char(12)
                      @MOName, -- MoName - nvarchar(50)
                      @CustomerId, 'SMT', -- WorkcenterGroup - nvarchar(50)
                      @Operator, -- Operator - nvarchar(50)
                      NULL, -- OperatorConfirmTime - datetime
                      N'', -- ConfirmUserName - nvarchar(50)
                      NULL, -- CustomerConfirmTime - datetime
                      N'20', -- ConfirmStuas - nvarchar(50)
                      '30', 0, GETDATE(),  -- CreateDate - datetime
                      'M', 0, @WorkcenterName );
        END;  
                                                                                                       
        SET @NowTime = GETDATE();
        SELECT  @FinishQty = COUNT(DISTINCT LotId)
        FROM    DCStoveStationScan(NOLOCK)
        WHERE   MOId = @MOId AND WorkcenterId = @WorkcenterId AND SpecificationId = 'SPE10000025P';

        EXEC dbo.CheckAndWarnMaterialLack
            @moid = @moid ,           -- nvarchar(50)
            @FinishQty = @FinishQty ,        -- int
            @workcentername = @workcentername , -- nvarchar(50)
            @workcenterid = @workcenterid;    -- nvarchar(50)
		

        SELECT  '' AS CombineList, CAST(ISNULL(@Remainminute, 0) AS FLOAT) AS Remaintime;
        SELECT  '' AS LotSN, @FinishQty AS FinishQty, '' AS HideList, 'ok.png' AS WarnImage, 0 AS ReturnValue; 
        SET @I_ExceptionFieldName = 'PCBType';	

        RETURN 0;

    END TRY
	
    BEGIN CATCH	
		
        SET @I_ReturnMessage = ERROR_MESSAGE();

        RETURN -1;
		
    END CATCH;
END;






