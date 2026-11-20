-- =============================================
-- Author:		<Wang RT>
-- Create date: <2024-01-01>
-- Description:	工单发料撤销扫描
-- =============================================
CREATE PROCEDURE [dbo].[Txn_PanelDefectCollect]
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
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' ,		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @Operator NVARCHAR(50) = '' ,
    @LotSN NVARCHAR(50) = '' ,
    @DefectCodeName NVARCHAR(50) = '' ,
    @DefectQty INT = 0 ,
    @NGListStr NVARCHAR(MAX) = ''
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @LotId CHAR(12) = '';
    DECLARE @MOId CHAR(12) = '';
    DECLARE @ProductId CHAR(12) = '';
    DECLARE @SpecificationId CHAR(12) = '';
    DECLARE @WorkflowDefectId CHAR(12) = '';
    DECLARE @WorkflowId CHAR(12) = '';
    DECLARE @WorkflowStepId CHAR(12) = '';
    DECLARE @WorkcenterId CHAR(12) = '';	
	
    DECLARE @LotStatus CHAR(1) = '';
    DECLARE @MOName NVARCHAR(50) = '';
    DECLARE @ProductName NVARCHAR(50) = '';
    DECLARE @SpecificationName NVARCHAR(50) = '';

    DECLARE @LotQty DECIMAL(18, 4) = 0;
    DECLARE @OrigDefectQty INT = 0;
    DECLARE @PassQty INT = 0;
    DECLARE @FailQty INT = 0;
	DECLARE @BadQty INT = 0;

    DECLARE @TempDefectCode TABLE
        (
		  Seq INT IDENTITY ,
          DefectCodeName NVARCHAR(50) DEFAULT '' ,
          DefectCodeDescription NVARCHAR(200) DEFAULT '' ,
          DefectQty INT DEFAULT 0
        );

    DECLARE @TempNGList TABLE
        (
          DefectCodeName NVARCHAR(50) DEFAULT '' ,
          DefectQty INT DEFAULT 0
        );

    IF @I_Sender = 'GetSNInfo'
    BEGIN
		
        IF NOT EXISTS ( SELECT  1
                        FROM    dbo.PersonInfo
                        WHERE   PersonNumber = @Operator AND IsActivity = 1 )
        BEGIN
            SELECT  '' AS Operator;
            SET @I_ExceptionFieldName = 'Operator';
            SET @I_ReturnMessage = 'ServerMessage:操作员工号[' + @Operator + ']在系统中无效！';
            RETURN -1;
        END;

        IF NOT EXISTS ( SELECT  1
                        FROM    dbo.Lot
                        WHERE   LotSN = @LotSN )
        BEGIN
            SELECT  '' AS LotSN;
            SET @I_ExceptionFieldName = 'LotSN';
            SET @I_ReturnMessage = 'ServerMessage:条码[' + @LotSN + ']在系统中不存在！';
            RETURN -1;
        END;

        SELECT  @LotId = LotId, @MOId = MOId, @ProductId = ProductId, @SpecificationId = SpecificationId, @LotQty = Qty,
                @LotStatus = LotStatus
        FROM    dbo.Lot
        WHERE   LotSN = @LotSN;

        SELECT  @MOName = MOName
        FROM    dbo.MO
        WHERE   MOId = @MOId;

        SELECT  @ProductName = prdname
        FROM    dbo.Product
        WHERE   ProductId = @ProductId;

        SELECT  @SpecificationName = b.SpecificationName
        FROM    dbo.Specification a
        INNER JOIN dbo.SpecificationRoot b ON b.SpecificationRootId = a.SpecificationRootId
        WHERE   a.SpecificationId = @SpecificationId;

        INSERT  INTO @TempDefectCode ( DefectCodeName, DefectCodeDescription, DefectQty )
                SELECT  b.DefectCodeName, b.DefectCodeDescription, 0
                FROM    dbo.Specification_DefectCode a
                INNER JOIN dbo.DefectCode b ON b.DefectCodeId = a.DefectCodeId
                WHERE   a.SpecificationId = @SpecificationId
                ORDER BY a.Sequence;

        SELECT  *
        FROM    @TempDefectCode;

        SELECT  @MOName AS MOName, @ProductName AS ProductName, @SpecificationName AS SpecificationName,
                @LotQty AS LotQty, @LotQty AS PassQty, 0 AS FailQty;
        SET @I_ExceptionFieldName = 'DefectQty';
        SET @I_ReturnMessage = 'ServerMessage:请选择对应的不良代码，录入不良数量！';
        RETURN 0;
    END;

	--不良扫描
    IF @I_Sender = 'DefectScan'
    BEGIN
        SELECT  @SpecificationId = SpecificationId, @LotQty = Qty
        FROM    dbo.Lot
        WHERE   LotSN = @LotSN;

        INSERT  INTO @TempDefectCode ( DefectCodeName, DefectCodeDescription, DefectQty )
                SELECT  b.DefectCodeName, b.DefectCodeDescription, 0
                FROM    dbo.Specification_DefectCode a
                INNER JOIN dbo.DefectCode b ON b.DefectCodeId = a.DefectCodeId
                WHERE   a.SpecificationId = @SpecificationId
                ORDER BY a.Sequence;

        INSERT  INTO @TempNGList ( DefectCodeName, DefectQty )
                SELECT  dbo.ConvertStrToClumn(parameter_Value, ',', 1), dbo.ConvertStrToClumn(parameter_Value, ',', 2)
                FROM    dbo.ConvertParameterToTable(@NGListStr, ';')
                WHERE   parameter_Value <> '';

        UPDATE  a
        SET     a.DefectQty = b.DefectQty
        FROM    @TempDefectCode a
        INNER JOIN @TempNGList b ON b.DefectCodeName = a.DefectCodeName;

        SELECT  @OrigDefectQty = DefectQty
        FROM    @TempDefectCode
        WHERE   DefectCodeName = @DefectCodeName;

        IF ISNULL(@DefectCodeName, '') = ''
        BEGIN
            SELECT  DefectCodeName, DefectCodeDescription, DefectQty
            FROM    @TempDefectCode;

            SELECT  'NGface.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'DefectCodeName';
            SET @I_ReturnMessage = 'ServerMessage:不良代码不能为空！';
            RETURN -1;
        END;

        IF ISNULL(@DefectQty, 0) <= 0
        BEGIN
            SELECT  DefectCodeName, DefectCodeDescription, DefectQty
            FROM    @TempDefectCode;

            SELECT  '' AS DefectSNORQty, 'NGface.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'DefectSNORQty';
            SET @I_ReturnMessage = 'ServerMessage:录入的不良数量不能小于0！';
            RETURN -1;
        END;

        SET @DefectQty = CAST(@DefectQty AS INT);

        UPDATE  @TempDefectCode
        SET     DefectQty = @DefectQty
        WHERE   DefectCodeName = @DefectCodeName;

        IF (
             SELECT SUM(DefectQty)
             FROM   @TempDefectCode
           ) > @LotQty
        BEGIN
            UPDATE  @TempDefectCode
            SET     DefectQty = @OrigDefectQty
            WHERE   DefectCodeName = @DefectCodeName;

            SELECT  DefectCodeName, DefectCodeDescription, DefectQty
            FROM    @TempDefectCode;

            SELECT  '' AS DefectSNORQty, 'NGface.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'DefectSNORQty';
            SET @I_ReturnMessage = 'ServerMessage:不良总数量超过了SN当前数量！';
            RETURN -1;
        END;

        SELECT  DefectCodeName, DefectCodeDescription, DefectQty
        FROM    @TempDefectCode;

        SELECT  @DefectQty = SUM(DefectQty)
        FROM    @TempDefectCode;

        SET @FailQty = @DefectQty;
        SET @PassQty = @LotQty - @FailQty;

        SET @NGListStr = '';
        SELECT  @NGListStr = IIF(@NGListStr <> '', @NGListStr + ';', @NGListStr) + DefectCodeName + ',' + CAST(DefectQty AS NVARCHAR(10))
        FROM    @TempDefectCode;

        SELECT  '' AS DefectQty, @NGListStr AS NGListStr, @PassQty AS PassQty, @FailQty AS FailQty;
        SET @I_ExceptionFieldName = 'DefectQty';
        SET @I_ReturnMessage = 'ServerMessage:不良录入成功，请继续录入或者提交过站！';
        RETURN 0;
    END;

    IF @I_Sender = 'Submit'
    BEGIN
		
        IF ISNULL(@NGListStr, '') = ''
        BEGIN
            SELECT  DefectCodeName, DefectCodeDescription, DefectQty
            FROM    @TempDefectCode;

            SELECT  'NGface.png' AS WarnImage;
            SET @I_ExceptionFieldName = 'IsDefectGoods';
            SET @I_ReturnMessage = 'ServerMessage:未勾选是不良品，请清空不良明细后再提交过账！';
            RETURN -1;
        END;

        INSERT  INTO @TempNGList ( DefectCodeName, DefectQty )
                SELECT  dbo.ConvertStrToClumn(parameter_Value, ',', 1), dbo.ConvertStrToClumn(parameter_Value, ',', 2)
                FROM    dbo.ConvertParameterToTable(@NGListStr, ';')
                WHERE   parameter_Value <> '';

        DELETE  FROM @TempNGList
        WHERE   DefectQty <= 0;

        SELECT  @DefectQty = ISNULL(SUM(ISNULL(DefectQty, 0)), 0)
        FROM    @TempNGList
        WHERE   DefectCodeName <> 'WS00';

        SELECT  @BadQty = ISNULL(SUM(ISNULL(DefectQty, 0)), 0)
        FROM    @TempNGList
        WHERE   DefectCodeName = 'WS00';

        SELECT  @LotId = LotId, @MOId = MOId, @WorkflowId = WorkflowId, @WorkflowStepId = WorkflowStepId,
                @SpecificationId = SpecificationId, @WorkcenterId = WorkcenterId
        FROM    dbo.Lot
        WHERE   LotSN = @LotSN;

		INSERT  INTO @TempDefectCode ( DefectCodeName, DefectCodeDescription, DefectQty )
                SELECT  b.DefectCodeName, b.DefectCodeDescription, 0
                FROM    dbo.Specification_DefectCode a
                INNER JOIN dbo.DefectCode b ON b.DefectCodeId = a.DefectCodeId
                WHERE   a.SpecificationId = @SpecificationId
                ORDER BY a.Sequence;

        SET @WorkflowDefectId = dbo.Fn_GetObjectPKId(12, 'WorkflowDefect',NEXT VALUE FOR dbo.WorkflowDefect_PK);
				
        INSERT  INTO dbo.WorkflowDefect ( WorkflowDefectId, LotId, LotSN, Qty, MOId, DefectWorkflowId,
                                          DefectWorkflowStepId, DefectSpecificationId, IsExe, WorkcenterId, ResourceId,
                                          UserId, CreateDate )
        VALUES  ( @WorkflowDefectId, @LotId, @LotSN, @DefectQty, @MOId, @WorkflowId, @WorkflowStepId, @SpecificationId,
                  1, @WorkcenterId, @I_ResourceId, @I_OrBitUserId, GETDATE() );
				
        INSERT  INTO dbo.WorkflowDefectItem ( WorkflowDefectItemId, WorkflowDefectId, DefectLocation, DefectQty,
                                              DefectCode, DefectDescription, CreateDate )
                SELECT  dbo.Fn_GetObjectPKId(12, 'WorkflowDefectItem',NEXT VALUE FOR dbo.WorkflowDefectItem_PK),
                        @WorkflowDefectId, '', a.DefectQty, a.DefectCodeName, b.DefectCodeDescription, GETDATE()
                FROM    @TempNGList a
                INNER JOIN @TempDefectCode b ON b.DefectCodeName = a.DefectCodeName
                WHERE   a.DefectQty > 0;
				
        UPDATE  dbo.Lot
        SET     Qty = Qty - @DefectQty - @BadQty, DefectQty = @DefectQty, BadQty = @BadQty
        WHERE   LotId = @LotId;
		
        SELECT  *
        FROM    @TempDefectCode
        WHERE   1 = 0;

        SELECT  '' AS LotSN, '' AS NGListStr;
        SET @I_ExceptionFieldName = 'LotSN';
        SET @I_ReturnMessage = 'ServerMessage:不良录入成功！';
        RETURN 0;
    END;

    RETURN 0;

END;




