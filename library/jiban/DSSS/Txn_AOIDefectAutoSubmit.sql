
-- =============================================
-- Author:		<Wang AnLiang>
-- Create date: <2018.04.28>
-- Description:	SMT炉后AOI不良采集自动提交
-- =============================================
CREATE  PROCEDURE [dbo].[Txn_AOIDefectAutoSubmit]
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
    @LotSN NVARCHAR(50) = '' ,
    @DefectLocation NVARCHAR(100) = '' ,
    @DefectCode NVARCHAR(50) = '' ,
    @HideInfo NVARCHAR(500) = '' ,
    @Side VARCHAR(10) = ''
AS
    BEGIN
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        DECLARE @return_value INT= -1;
        DECLARE @TxnCode VARCHAR(10)= 'DC';
        DECLARE @LotId CHAR(12)= '';
        DECLARE @LotStatus CHAR(1)= '';
        DECLARE @LotProductId CHAR(12)= '';
        DECLARE @LotMOId CHAR(12)= '';
        DECLARE @LotWorkcenterId CHAR(12)= '';
        DECLARE @WorkcenterId CHAR(12)= '';
        DECLARE @LotWorkflowId CHAR(12)= '';
        DECLARE @LotSpecificationId CHAR(12)= '';
        DECLARE @LotWorkflowStepId CHAR(12)= '';
       -- DECLARE @DefectInfo NVARCHAR(100)= '';
        DECLARE @DefectCodeId CHAR(12)= '';
        DECLARE @DefectDescription NVARCHAR(200)= '';
        DECLARE @TempLen INT= 0;
        DECLARE @DataChainId CHAR(12)= '';
        DECLARE @WorkflowDefectId CHAR(12)= '';
        DECLARE @WorkflowDefectItemId CHAR(12)= '';
        DECLARE @WorkcenterName NVARCHAR(50)= '';
        DECLARE @DefectDataId CHAR(12)= '';
        DECLARE @PSpecificationName NVARCHAR(50)= '';
        DECLARE @DCStoveStationScanId CHAR(12)= '';
        DECLARE @AOINGDesc NVARCHAR(20);

        SET @LotSN = UPPER(RTRIM(@LotSN));


	--重置扫描
        IF @I_Sender = 'DefectClear'
            BEGIN
                SELECT  '' AS CombineList;
                SELECT  '' AS DefectLocation, '' AS DefectCode, '' AS HideInfo, '' AS LableNo, 0 AS ReturnValue; 

                SET @I_ExceptionFieldName = 'LotSN';
                SET @I_ReturnMessage = 'ServerMessage:数据清除成功，请重新输入不良位置!';
                RETURN 0;
            END;

	-- 检查不良代码是否有效

        DECLARE @TempDefectCode TABLE
            (
              DefectLocation VARCHAR(20) ,
              DefectCodeName NVARCHAR(20) ,
              AOINGDesc NVARCHAR(20)
            );

        INSERT  INTO @TempDefectCode ( DefectLocation, DefectCodeName, AOINGDesc )
                SELECT  UPPER(SUBSTRING(parameter_Value, 1, CHARINDEX(',', parameter_Value, 1) - 1)) AS DefectLocation,
                        '' DefectCodeName,
                        UPPER(SUBSTRING(parameter_Value, CHARINDEX(',', parameter_Value, 1) + 1,
                                        LEN(parameter_Value) - CHARINDEX(',', parameter_Value, 1))) AS AOINGDesc
                FROM    ConvertParameterToTable(@HideInfo, ';')
                WHERE   parameter_Value <> '';	 

        UPDATE  a
        SET     a.DefectCodeName = b.DefectCodeName
        FROM    @TempDefectCode a
        INNER JOIN DefectCode b ( NOLOCK ) ON b.AOINGDesc = a.AOINGDesc;

        IF EXISTS ( SELECT  *
                    FROM    @TempDefectCode a
                    LEFT JOIN DefectCode b ( NOLOCK ) ON b.DefectCodeName = a.DefectCodeName
                    WHERE   b.DefectCodeName IS NULL )
            BEGIN		
                SELECT TOP 1
                        @AOINGDesc = a.DefectCodeName
                FROM    @TempDefectCode a
                LEFT JOIN DefectCode b ON b.DefectCodeName = a.DefectCodeName
                WHERE   b.DefectCodeName IS NULL;

                SET @I_ExceptionFieldName = 'DefectCode';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}不良描述 [' + @AOINGDesc + '] 无效!';
                SELECT  '' AS CombineList;
                SELECT  '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;

	--检查MOID是否为空
        IF ISNULL(@MOId, '') = ''
            BEGIN		
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入工单号!';

                SELECT  '' AS CombineList;
                SELECT  '' AS Operator, '' AS LotSN, '' AS HideInfo, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;

	--操作员不能为空
        IF ISNULL(@Operator, '') = ''
            BEGIN		
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入操作员编号!';
                SET @I_ExceptionFieldName = 'Operator';

                SELECT  '' AS CombineList;
                SELECT  '' AS Operator, '' AS LotSN, '' AS HideInfo, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;


	--LotSN 不能为空
        IF ISNULL(@LotSN, '') = ''
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入产品条码!';
                SET @I_ExceptionFieldName = 'LotSN';
                SELECT  '' AS Operator, '' AS LotSN, '' AS HideInfo, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;

	--不良信息不能为空
        IF ISNULL(@HideInfo, '') = ''
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}请输入不良信息!';
                SET @I_ExceptionFieldName = 'DefectLocation';
                SELECT  '' AS Operator, '' AS LotSN, '' AS HideInfo, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;


		--检查人员工号是否存在
        IF NOT EXISTS ( SELECT  PersonInfoId
                        FROM    PersonInfo(NOLOCK)
                        WHERE   PersonNumber = @Operator
                                AND IsActivity = 1 )
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}操作员工号 [' + @Operator + '] 不存在或已离职!';
                SET @I_ExceptionFieldName = 'Operator';
		
                SELECT  '' AS CombineList;
                SELECT  '' AS Operator, '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;

			PRINT @MOId

	        IF EXISTS ( SELECT  1
                    FROM    MOLink
                    WHERE   MainMOId = @MOId AND LinkTypeDesc = 'AB反转' ) AND LEN(@LotSN) <= 16 AND @LotSN <> 'SUBMIT'
			BEGIN
				

				SET @LotSN = dbo.BSideLotSNToASide(@LotSN);
			ENd
            

				--检查 LotSN 是否存在
        IF NOT EXISTS ( SELECT  LotId
                        FROM    Lot(NOLOCK)
                        WHERE   LotSN = @LotSN )
            BEGIN	
                SELECT  '' AS CombineList;
                SELECT  '' AS LotSN, '' AS HideInfo, -1 AS ReturnValue; 	

                SET @I_ExceptionFieldName = 'DefectCode';
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 不存在!';

                RETURN -1;
            END;


	--检查工单是否存在
        IF ISNULL(@MOId, '') = ''
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}工单号 [' + @MOName + '] 输入有误!';
                SET @I_ExceptionFieldName = 'DefectCode';

                SELECT  '' AS CombineList;
                SELECT  '' AS MOName, '' AS ProductName, '' AS MOQtyRequired, '' AS Operator, '' AS LotSN,
                        '' AS HideInfo, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;


	--获取Lot信息
        SELECT  @LotId = LotId, @LotMOId = MOId, @LotStatus = LotStatus, @LotProductId = ProductId,
                @LotWorkcenterId = WorkcenterId, @LotWorkflowId = WorkflowId, @LotWorkflowStepId = WorkflowStepId,
                @LotSpecificationId = SpecificationId
        FROM    Lot(NOLOCK)
        WHERE   LotSN = @LotSN;


        IF ISNULL(@LotStatus, '0') <> '1'
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}产品条码 [' + @LotSN + '] 状态不可用!';
                SET @I_ExceptionFieldName = 'LotSN';
                SELECT  '' AS CombineList;
                SELECT  '' AS MOName, '' AS ProductName, '' AS MOQtyRequired, '' AS NowWoorkflowStep, '' AS LotSN,
                        'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;


        DECLARE @MESTxnObjectName VARCHAR(50)= 'DC StoveStation DefectScan';

	--检查是否允许操作此规程
        EXEC @return_value= dbo.[SysCheckSpecification]
            @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
            @WorkcenterId = @WorkcenterId OUTPUT ,
            @I_OrBitUserId = @I_OrBitUserId ,
            @LotId = @LotId ,
            @I_OrBitUserName = @I_OrBitUserName ,
            @I_ResourceId = @I_ResourceId ,
            @I_ResourceName = @I_ResourceName ,
            @SpecificationId = @LotSpecificationId ,
            @MESTxnObjectName = @MESTxnObjectName;

        IF @return_value = -1
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}' + @I_ReturnMessage;
                SELECT  '' AS CombineList;
                SELECT  '' AS DefectCode, '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue;;
                RETURN -1;
            END;

	----检查是否允许操作此规程
 --       EXEC @return_value= dbo.[SysCheckSpecification]
 --           @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
 --           @WorkcenterId = @WorkcenterId OUTPUT ,
 --           @I_OrBitUserId = @I_OrBitUserId ,
 --           @LotId = @LotId ,
 --           @I_OrBitUserName = @I_OrBitUserName ,
 --           @I_ResourceId = @I_ResourceId ,
 --           @I_ResourceName = @I_ResourceName ,
 --           @SpecificationId = @LotSpecificationId;

	--		--PRINT ('I_OrBitUserId:'+@I_OrBitUserId)
	--		--PRINT ('LotId:'+@LotId)
	--		--PRINT ('I_OrBitUserName:'+@I_OrBitUserName)
	--		--PRINT ('I_ResourceId:'+@I_ResourceId)
	--		--PRINT ('LotSpecificationId:'+@I_ResourceName)
	--		--PRINT ('LotSpecificationId:'+@LotSpecificationId)

 --       IF @return_value = -1
 --           BEGIN
 --               SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}' + @I_ReturnMessage;
 --               SELECT  '' AS CombineList;
 --               SELECT  '' AS DefectCode, '' AS LotSN, 'error.png' AS WarnImage, -1 AS ReturnValue;;
 --               RETURN -1;
 --           END;

			

	--线别不能为空
        IF ISNULL(@WorkcenterId, '') = ''
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:用户 [' + @I_OrBitUserName + '] 或者资源 [' + @I_ResourceName
                    + '] 未绑定线别，不允许操作!';
                SELECT  '' AS CombineList;
                SELECT  '' AS Operator, '' AS LotSN, '' AS HideInfo, 'error.png' AS WarnImage, -1 AS ReturnValue; 
                RETURN -1;
            END;

	--从工作中心里面控制是否扣料--
        IF EXISTS ( SELECT  1
                    FROM    Workcenter(NOLOCK)
                    WHERE   WorkcenterId = @WorkcenterId
                            AND IsClosed = 0 )
            BEGIN
		--检查是否装配节点
                IF EXISTS ( SELECT  1
                            FROM    Specification(NOLOCK)
                            WHERE   SpecificationId = @LotSpecificationId
                                    AND IsAssemblyStep = 1 )
                    BEGIN
			--检查是否满足扣料，满足则扣料
                        EXEC @return_value= [dbo].[SMTBackflushDoMethod]
                            @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
                            @I_ResourceId = @I_ResourceId ,
                            @I_ResourceName = @I_ResourceName ,
                            @I_OrBitUserId = @I_OrBitUserId ,
                            @I_OrBitUserName = @I_OrBitUserName ,
                            @LotSN = @LotSN ,
                            @MOId = @MOId ,
                            @ProductId = @LotProductId ,
                            @WorkcenterId = @WorkcenterId ,
                            @Side = @Side ,
                            @MakeupNumber = 1;      
		
                        IF @return_value = -1
                            BEGIN
                                SET @I_ReturnMessage = 'ServerMessage:say{Erorr.wav}' + @I_ReturnMessage;
                                SELECT  '' AS LotSN, '' AS ItemValue, 'error.png' AS WarnImage, -1 AS ReturnValue;
                                RETURN -1;
                            END;  
                    END; 
            END;

	--数据采集
        DECLARE cursor1 CURSOR
        FOR
            SELECT  DefectLocation, DefectCodeName
            FROM    @TempDefectCode
            WHERE   DefectCodeName <> '';

        OPEN cursor1; 
        FETCH NEXT FROM cursor1 
	INTO @DefectLocation, @DefectCode;
        WHILE @@FETCH_STATUS = 0
            BEGIN 
		--获取不良代码ID
                SET @DefectCodeId = '';
                SELECT  @DefectCodeId = DefectCodeId, @DefectDescription = DefectCodeDescription
                FROM    DefectCode(NOLOCK)
                WHERE   DefectCodeName = @DefectCode;

		--申请采集表主键
                EXEC SysGetObjectPKId
                    '' ,
                    'DCStoveStationScan' ,
                    @DCStoveStationScanId OUTPUT;
                SET @DefectDataId = @DCStoveStationScanId;

		--申请数据链ID
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

			--更新不良记录为1
                        IF EXISTS ( SELECT  WorkflowDefectId
                                    FROM    WorkflowDefect(NOLOCK)
                                    WHERE   LotId = @LotId )
                            BEGIN
                                BEGIN TRAN;
                                UPDATE  WorkflowDefect
                                SET     IsExe = 1
                                WHERE   LotId = @LotId;
                                COMMIT TRAN;
                            END;

			--写入不良记录表
                        EXEC SysGetObjectPKId
                            '' ,
                            'WorkflowDefect' ,
                            @WorkflowDefectId OUTPUT;
                        INSERT  INTO WorkflowDefect ( WorkflowDefectId, LotId, LotSN, MOId, WorkcenterId,
                                                      DefectWorkflowStepId, DefectSpecificationId, DefectDataId )
                        VALUES  ( @WorkflowDefectId, @LotId, @LotSN, @LotMOId, @LotWorkcenterId, @LotWorkflowStepId,
                                  @LotSpecificationId, @DefectDataId );
                    END;

                EXEC SysGetObjectPKId
                    '' ,
                    'WorkflowDefectItem' ,
                    @WorkflowDefectItemId OUTPUT;
                INSERT  INTO WorkflowDefectItem ( WorkflowDefectItemId, WorkflowDefectId, DefectLocation, DefectCode )
                VALUES  ( @WorkflowDefectItemId, @WorkflowDefectId, @DefectLocation, @DefectCode );

		--写入一行数据
                INSERT  INTO DCStoveStationScan ( DCStoveStationScanId, DataChainId, LotId, LotSN, MOId, ProductId,
                                                  Operator, Side, DefectLocation, DefectCode, DefectDescription,
                                                  WorkflowId, SpecificationId, WorkflowStepId, WorkcenterId, ResourceId,
                                                  UserId , LockDate,Fixlotsn)
                VALUES  ( @DCStoveStationScanId, @DataChainId, @LotId, @LotSN, @LotMOId, @LotProductId, @Operator, @Side,
                          @DefectLocation, @DefectCode, @DefectDescription, @LotWorkflowId, @LotSpecificationId,
                          @LotWorkflowStepId, @WorkcenterId, @I_ResourceId, @I_OrBitUserId, GETDATE(),LEFT(@lotsn,CHARINDEX('-',@lotsn) -1) );
		
                FETCH NEXT FROM cursor1 
		INTO @DefectLocation, @DefectCode;
            END;
        CLOSE cursor1; 
        DEALLOCATE cursor1; 

	--统计在制品
        EXEC [dbo].[DataChainWIPDoMethod]
            @I_OrBitUserId = @I_OrBitUserId ,
            @I_ResourceId = @I_ResourceId ,
            @MOId = @LotMOId ,
            @LotId = @LotId ,
            @WorkcenterId = @WorkcenterId ,
            @MoveResult = 'F' ,
            @Side = @Side;

	--传送到下一节点
        EXEC [dbo].[TxnBase_LotMove]
            @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
            @I_PlugInCommand = @I_PlugInCommand ,
            @I_OrBitUserId = @I_OrBitUserId ,
            @I_ResourceId = @I_ResourceId ,
            @LotSN = @LotSN; 

	  ---更新下线时间
	    UPDATE moitemlot SET ProductDate = GETDATE() WHERE lotsn = @lotsn

        SET @I_ReturnMessage = 'ServerMessage:产品条码 [' + @LotSN + '] 不良采集成功!';

        SELECT  '' AS CombineList;
        SELECT  '' AS LotSN, '' AS DefectLocation, '' AS DefectCode, '' AS HideInfo, 0 AS ReturnValue;;

        RETURN 0;    
    END;










