
-- =============================================
-- Author:		<OBit Team benson>
-- Create date: <2016.08.19>
-- Description:	<启动采购单Item批号>
-- Rev: 10.00
-- =============================================
CREATE PROCEDURE [dbo].[MoToSapCovertDoMethod]
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,      --返回的信息,支持多语言
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
    @I_Parameter NVARCHAR(MAX) = '' ,	--插件参数	
    @Workflowname NVARCHAR(50) = '' ,
    @Soname VARCHAR(12) = '' ,
    @Productname VARCHAR(50) = '' ,
    @Moname VARCHAR(12) = '' ,
    @SpecificationName NVARCHAR(30) = '' ,
    @Password VARCHAR(100) = ''
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @overQty DECIMAL(18, 2)= 0;
    DECLARE @OldMOName VARCHAR(50)= '';
    DECLARE @PredictInStorageId VARCHAR(12)= '';
    DECLARE @remainqty DECIMAL(18, 2)= 0;
    DECLARE @moid VARCHAR(12)= '';
    DECLARE @toworkflowid VARCHAR(12)= '';
    DECLARE @WorkFlowid NVARCHAR(12)= '';
    DECLARE @Productid VARCHAR(12)= '';
    DECLARE @NextWorkFlowstepid VARCHAR(12)= '';
    DECLARE @return_value INT;
    DECLARE @specificationid VARCHAR(12)= '';
    DECLARE @lotsn VARCHAR(50)= '';
    DECLARE @lotid VARCHAR(12)= '';
    DECLARE @InDate DATETIME = GETDATE();
    DECLARE @NonStdMoveReasonId VARCHAR(12)= 'URC1000002JC';
    DECLARE @cnt INT = 0;

    SET @return_value = -1;
	--检查元对象方法用户授权
    EXEC @return_value= [dbo].[MetadataPermissionCheckDoMethod]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @I_OrBitUserId = @I_OrBitUserId ,
        @I_OrBitUserName = @I_OrBitUserName ,
        @I_Sender = @I_Sender;

    IF @return_value = -1
    BEGIN
        SET @I_ReturnMessage = @I_ReturnMessage;
        RETURN -1;
    END;

    IF @I_PlugInCommand = 'ODFTV'
    BEGIN
        IF ISNULL(@Moname, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:请输入有效的工单号！';
            RETURN -1;
        END;
        IF NOT EXISTS ( SELECT TOP 1
                                1
                        FROM    MO WITH ( NOLOCK )
                        WHERE   SOName = @Soname )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:请输入有效的订单号！';
            RETURN -1;
        END;
        IF NOT EXISTS ( SELECT TOP 1
                                1
                        FROM    MO a
                        INNER JOIN dbo.ProductRoot b ON b.DefaultProductId = a.ProductId AND b.ProductName = @Productname
                        WHERE   a.MOName='00'+ RIGHT(@Moname, 10) AND a.SOName = @Soname )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:订单与工单不匹配，请检查！';
            RETURN -1;
        END;
        SELECT  @moid = MOId
        FROM    MO WITH ( NOLOCK )
        WHERE   MOName='00'+ RIGHT(@Moname, 10);
        IF ISNULL(@moid, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:找不到工单号';
            RETURN -1;
        END;
    END;

    IF @I_Sender = 'CovertMO'
    BEGIN
        SET @NonStdMoveReasonId = 'URC1000002JC';
        DECLARE @ToWorkflowstepid VARCHAR(12)= '';
        IF ISNULL(@Workflowname, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:工作流不能为空';
            RETURN -1;
        END;
        SET @toworkflowid = '';
        SELECT  @toworkflowid = DefaultWorkflowId
        FROM    dbo.WorkflowRoot
        WHERE   WorkflowName = @Workflowname;
        IF ISNULL(@toworkflowid, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:工作流ID不能为空';
            RETURN -1;
        END;
        SELECT  @specificationid = DefaultSpecificationId
        FROM    dbo.SpecificationRoot
        WHERE   SpecificationName = @SpecificationName;

        IF ISNULL(@specificationid, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:节点规程ID不能为空';
            RETURN -1;
        END;
        SET @ToWorkflowstepid = '';
        SELECT  @ToWorkflowstepid = WorkflowStepId
        FROM    dbo.WorkflowStep
        WHERE   WorkflowId = @toworkflowid AND SpecificationId = @specificationid;
        IF ISNULL(@ToWorkflowstepid, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:节点ID 不能为空' + @SpecificationName;
            RETURN -1;
        END;

        DECLARE @TempMOItemLotId TABLE ( MOItemLotId CHAR(12) );

        INSERT  INTO @TempMOItemLotId ( MOItemLotId )
                SELECT  parameter_Value
                FROM    dbo.ConvertParameterToTable(@I_Parameter, ';')
                WHERE   parameter_Value <> '';
			
        SELECT  @cnt = COUNT(1)
        FROM    @TempMOItemLotId; 

		---SELECT * FROM dbo.UserCode WHERE UserCodeDescription ='节点变更跳转'

        DECLARE user_cur CURSOR
        FOR
        SELECT DISTINCT
                b.LotSN, b.LotId
        FROM    @TempMOItemLotId a
        INNER JOIN MOItemLot b ON b.MOItemLotId = a.MOItemLotId;
        OPEN user_cur; 
        WHILE @@fetch_status = 0
        BEGIN
            FETCH NEXT FROM user_cur INTO @lotsn, @lotid;
            EXEC @return_value = [dbo].[TxnBase_LotNonStdMove]
                @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
                @I_PlugInCommand = @I_PlugInCommand ,
                @I_OrBitUserId = @I_OrBitUserId ,
                @I_ResourceId = @I_ResourceId ,
                @LotSN = @LotSN ,
                @LotInDate = @InDate ,
                @NonStdMoveReasonId = @NonStdMoveReasonId ,
                @TargetWorkflowId = @toworkflowid ,
                @TargetWorkflowStepId = @ToWorkflowstepid ,
                @TargetStack = '' ,
                @UserComment = '变更工作流' ,
                @IsMoveIn = 0;
            IF @return_value = -1
            BEGIN
                SET @I_ReturnMessage = @I_ReturnMessage;
                RETURN -1;
            END;
        END;  
        CLOSE user_cur; 
        DEALLOCATE user_cur;
        SET @I_ReturnMessage = 'ServerMessage:共转换：【' + CONVERT(CHAR, @cnt) + '】个批号转换为：' + RTRIM(@Workflowname) + '/' + @SpecificationName + '/' + @toworkflowid + '/' + @ToWorkflowstepid;
        RETURN 0;

    END;

    IF @I_Sender = 'CovertWorkFlow'
    BEGIN
	   --SET @I_ReturnMessage ='ServerMessage:'+ @Workflowname
	   --RETURN -1
	  -- WorkFlowName
        IF ISNULL(@Workflowname, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:工作流不能为空';
            RETURN -1;
        END;
        SELECT  @toworkflowid = DefaultWorkflowId
        FROM    dbo.WorkflowRoot
        WHERE   WorkflowName = @Workflowname;
        IF ISNULL(@toworkflowid, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:工作流ID不能为空';
            RETURN -1;
        END;
        SELECT DISTINCT
                SpecificationId
        INTO    #LotSpecifictid
        FROM    Lot WITH ( NOLOCK )
        WHERE   MOId = @I_PKId;
        IF NOT EXISTS ( SELECT TOP 1
                                1
                        FROM    dbo.#LotSpecifictid a
                        LEFT JOIN dbo.WorkflowStep b ON b.SpecificationId = a.SpecificationId
                        WHERE   b.WorkflowId = @toworkflowid AND b.SpecificationId IS NULL )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:目标工作流没有对庆的节点，不能转换';
            RETURN -1;
        END;


        IF @I_PlugInCommand = 'MOSTD'
        BEGIN
            --DECLARE @specificationid VARCHAR(12)= '';
            SELECT DISTINCT
                    WorkflowId, SpecificationId, @toworkflowid AS RWorkFlowid, CAST ('' AS VARCHAR(12)) RWorkFlowSteupid,
                    CAST ('' AS VARCHAR(12)) AS NextWorkFlowStepid, SpecificationId AS rSpecificationId
            INTO    #spec2
            FROM    Lot
            WHERE   MOId = @I_PKId AND WorkflowId <> @WorkFlowid;

	   
            UPDATE  #spec2
            SET     rSpecificationId = 'SPE10000024W', RWorkFlowSteupid = ''
            WHERE   SpecificationId IN ( 'SPE10000019G', 'SPE10000024T', 'SPE10000024M' );

	  -- 变更对应的节点	   
            UPDATE  a
            SET     a.RWorkFlowSteupid = b.WorkflowStepId
            FROM    #spec2 a
            INNER JOIN dbo.WorkflowStep b ON b.WorkflowId = a.RWorkFlowid AND b.SpecificationId = a.rSpecificationId;
	   ---更新下一个节点
            UPDATE  b
            SET     b.NextWorkFlowStepid = a.ToWorkflowStepId
            FROM    dbo.WorkflowPath a
            INNER JOIN #spec2 b ON b.RWorkFlowid = a.WorkflowId AND b.RWorkFlowSteupid = a.WorkflowStepId AND a.IsDefaultWorkflowPath = 1;
      ---更换批号节点
            DELETE  #spec2
            WHERE   RWorkFlowSteupid = '';
         
	  
            UPDATE  a
            SET     a.WorkflowId = b.RWorkFlowid, a.SpecificationId = b.SpecificationId,
                    a.NextWorkflowStepId = b.NextWorkFlowStepid
            FROM    Lot a
            INNER JOIN #spec2 b ON b.SpecificationId = a.SpecificationId
            WHERE   MOId = @I_PKId AND a.WorkflowId <> @toworkflowid;

        END;

        IF @I_PlugInCommand = 'ODFTV'
        BEGIN
		   
            UPDATE  dbo.OrderFieldSetting
            SET     WorkflowId = @toworkflowid, MOId = @moid
            WHERE   OrderFieldSettingId = @I_PKId AND WorkflowId <> @toworkflowid;
        END;
        SET @I_ReturnMessage = 'ServerMessage:工作流转换成功！请检查';
        RETURN 0;

    END;

    IF @I_Sender = 'ConvertLotsnSpecifi'
    BEGIN
		
		IF ISNULL(@I_OrBitUserName,'') NOT IN ( 'GC1003', '1001942','SC1903' )
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage:账号无权限操作！'
			RETURN -1;
		END

		IF ISNULL(@I_ResourceId,'') = ''
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage:电脑资源未在系统里登记，不允许操作！'
			RETURN -1;
		END 
        IF ISNULL(@Password, '') <> '5E2C1816-3B08-4E2F-895B-6DDEEBB2C545'
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:密码错误，请检查';
            RETURN -1;
        END;

        DECLARE @workflowstepid VARCHAR(12)= '';
        DECLARE @itemlist TABLE ( itemid VARCHAR(50) );
        INSERT  INTO @itemlist
                SELECT  RTRIM(parameter_Value)
                FROM    dbo.ConvertParameterToTable(@I_Parameter, ';')
                WHERE   ISNULL(parameter_Value, '') <> '';
        IF NOT EXISTS ( SELECT TOP 1
                                1
                        FROM    @itemlist )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:没有选择上要变更的记录！请选择，如多行可用Shift + 选择';
            RETURN -1;
        END;
        IF @SpecificationName = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:没有选定作业规程，请选择';
            RETURN -1;
        END;
        IF @Workflowname = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:没有选定工作流，请选择';
            RETURN -1;
        END;
        SELECT  @specificationid = DefaultSpecificationId
        FROM    dbo.SpecificationRoot WITH ( NOLOCK )
        WHERE   SpecificationName = @SpecificationName;
        IF @specificationid = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:没有找到作业规程ID，不能更换';
            RETURN -1;
        END;
        SELECT  @WorkFlowid = DefaultWorkflowId
        FROM    dbo.WorkflowRoot WITH ( NOLOCK )
        WHERE   WorkflowName = @Workflowname;
        IF @WorkFlowid = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:没有找到工作流ID，不能更换';
            RETURN -1;
        END;
        IF NOT EXISTS ( SELECT TOP 1
                                1
                        FROM    dbo.WorkflowStep WITH ( NOLOCK )
                        WHERE   WorkflowId = @WorkFlowid AND SpecificationId = @specificationid )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:该工作流中不包含:' + RTRIM(@SpecificationName) + '节点，不能更换！';
            RETURN -1;
        END;
        SET @cnt = 0;
        SELECT  @workflowstepid = WorkflowStepId
        FROM    dbo.WorkflowStep
        WHERE   WorkflowId = @WorkFlowid AND SpecificationId = @specificationid;
        IF @workflowstepid = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:该工作流中没有选定的规程ID，不能更换';
            RETURN -1;
        END;
	 
        SELECT  @NextWorkFlowstepid = ToWorkflowStepId
        FROM    dbo.WorkflowPath
        WHERE   WorkflowId = @WorkFlowid AND WorkflowStepId = @workflowstepid AND IsDefaultWorkflowPath = 1;

        IF @workflowstepid <> ''
        BEGIN
            SELECT  b.LotId
            INTO    #updatelotid
            FROM    @itemlist a
            INNER JOIN MOItemLot b WITH ( NOLOCK ) ON b.MOItemLotId = a.itemid;
            SELECT  @cnt = COUNT(1)
            FROM    #updatelotid;

            UPDATE  c
            SET     c.WorkflowId = @WorkFlowid, c.WorkflowStepId = @workflowstepid,
                    c.NextWorkflowStepId = @NextWorkFlowstepid, c.SpecificationId = @specificationid
            FROM    Lot c
            INNER JOIN #updatelotid b ON b.LotId = c.LotId;
        END;
       
        DECLARE @LogMsg NVARCHAR(MAX);
        SET @LogMsg = @I_OrBitUserName + '/' + @I_OrBitUserId + '/' + @I_ResourceId + '/' + @I_ParentPKId + '/' + @WorkFlowid + '/' + @specificationid;
        
        INSERT  INTO InterfaceExecLog ( ItemName, LogContent )
        VALUES  ( 'MoToSapCovertDoMethod_ConvertLotsnSpecifi', @LogMsg );
         
        SET @I_ReturnMessage = 'ServerMessage:' + RTRIM(CONVERT(CHAR, @cnt)) + '个批号！更新为：' + RTRIM(@Workflowname) + '/' + RTRIM(@SpecificationName) + '节点';
        RETURN 0;

    END;

    IF ISNULL(@I_ParentPKId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选取SAP入库信息SHEET 中的入库失败行，再进行MO号码更换';
        RETURN -1;
    END;

    IF @I_Sender = 'CovertMoSapPost'
    BEGIN
     
        IF EXISTS ( SELECT  1
                    FROM    dbo.Interface_MOInStorage
                    WHERE   Interface_MOInStorageId = @I_ParentPKId AND ExecStatus = '2' )
        BEGIN
            SELECT  @overQty = InStorageQty, @OldMOName = MOName, @PredictInStorageId = PredictInStorageId
            FROM    dbo.Interface_MOInStorage
            WHERE   Interface_MOInStorageId = @I_ParentPKId AND ExecStatus = '2';


            IF NOT EXISTS ( SELECT  MOId
                            FROM    MO(NOLOCK)
                            WHERE   MOId = @I_PKId AND MOQtyRequired - ISNULL(MOQtyDone, 0) >= ISNULL(@overQty, 0) )
            BEGIN
                SELECT  @I_ReturnMessage = 'ServerMessage:入库数量超出工单的余量！' + @I_PKId;
                RETURN -1;           
            END;

            SET @Moname = '';
            SELECT  @Moname = MOName, @remainqty = MOQtyRequired - MOQtyDone
            FROM    MO(NOLOCK)
            WHERE   MOId = @I_PKId; 

            IF ISNULL(@Moname, '') <> ''
            BEGIN
                BEGIN TRAN tr1;

				-- SAP中入库存失败的记录， 更换订单
                UPDATE  Interface_MOInStorage
                SET     MOName = @Moname, ExecStatus = 0
                WHERE   Interface_MOInStorageId = @I_ParentPKId AND ExecStatus = '2';

                IF @remainqty < @overQty
                    SET @overQty = @remainqty;

				-- 新订单的入库数 增加
                UPDATE  dbo.MO
                SET     MOQtyDone = MOQtyDone + @overQty
                WHERE   MOName = @Moname; 

                COMMIT TRAN tr1;


            END;
            SELECT  @I_ReturnMessage = 'ServerMessage: PO号码还原成功！！' + @I_PKId;
            RETURN 0;
        END;
        ELSE
        BEGIN
            SELECT  @I_ReturnMessage = 'ServerMessage: 没有找到失败的入库号！！' + @I_PKId;
            RETURN -1;
        END;  
    END;

END;




