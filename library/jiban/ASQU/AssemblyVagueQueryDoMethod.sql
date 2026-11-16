
-- =============================================
-- Author:		<gc3033>
-- Create date: 2017.17.08>
-- Description:采集项查询模糊查询
-- =============================================
CREATE PROCEDURE [dbo].[AssemblyVagueQueryDoMethod]
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

--@LotSN nvarchar(50)='',             --产品批号
--@CollectSN nvarchar(50)='',          --采集项SN
    @VagueCollectSN NVARCHAR(100) = '' , --模糊查询
    @TotalBits INT = 0 --总位数
AS
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        DECLARE @CollectSN NVARCHAR(50)= '';
        DECLARE @LotSNName NVARCHAR(50)= '';
        DECLARE @SqlOne NVARCHAR(MAX)= '';
        DECLARE @SqlJuge NVARCHAR(MAX)= '';


	--主批号字段名表
        DECLARE @LotSNTemp TABLE ( LotSNName NVARCHAR(50) );
	--MAC地址输出表
        DECLARE @OrderSetTemp TABLE
            (
              SOName NVARCHAR(50) ,
              ProductName NVARCHAR(50) ,
              LotSN NVARCHAR(50) ,
              WorkflowStepName NVARCHAR(60) ,
              CollectItemName NVARCHAR(50) ,
              CollectSN NVARCHAR(50)
            );
	--写号工位最近的操作员
        DECLARE @DataTEST TABLE
            (
              LotSN NVARCHAR(50) ,
              PersonNumber VARCHAR(30) ,
              AssemblyTime DATETIME
            );
	--计算写号工位,以第一个工位为准
        DECLARE @Workcenter TABLE
            (
              LotSN NVARCHAR(50) ,
              WorkcenterName NVARCHAR(50)
            );

        SET @VagueCollectSN = ISNULL(@VagueCollectSN, '');
        SET @CollectSN = RTRIM(LTRIM(@VagueCollectSN));
        IF RIGHT(@CollectSN, 1) <> '%'
        BEGIN
            SET @CollectSN = @CollectSN + '%';
        END;

		--SN 模糊查询
		if @I_Sender='AssemblyBySNQuery'
		begin	
			SELECT  MO.SOName AS SOName,
					ProductRoot.ProductName AS ProductName, Lot.LotSN, WorkflowStep.WorkflowStepName,
					TA.ItemName AS CollectItemName, TA.CollectSN, TA.Operator, PersonInfo.PersonName,
					Workcenter.WorkcenterName, TA.AssemblyTime
			FROM    DataChainAssembly TA WITH ( NOLOCK )
			LEFT JOIN Lot WITH ( NOLOCK ) ON Lot.LotId = TA.LotId
			LEFT JOIN MO WITH ( NOLOCK ) ON MO.MOId = TA.MOId
			LEFT JOIN Product WITH ( NOLOCK ) ON Product.ProductId = TA.ProductId
			LEFT JOIN ProductRoot WITH ( NOLOCK ) ON ProductRoot.ProductRootId = Product.ProductRootId
			LEFT JOIN WorkflowStep WITH ( NOLOCK ) ON WorkflowStep.WorkflowStepId = TA.WorkflowStepId
			LEFT JOIN PersonInfo WITH ( NOLOCK ) ON TA.Operator = PersonInfo.PersonNumber
			LEFT JOIN Workcenter WITH ( NOLOCK ) ON TA.WorkcenterId = Workcenter.WorkcenterId
			WHERE   TA.IsCancel = 0
					AND Lot.LotStatus = '1'
					AND Lot.LotSN LIKE @CollectSN
			RETURN 0;		
		end

	--判断是否输入头4位
        IF CHARINDEX('#', @CollectSN) <> 0
            BEGIN
                IF CHARINDEX('#', @CollectSN) <= 3
                    BEGIN
                        SET @I_ReturnMessage = 'ServerMessage:所输入的【模糊条件】必须大于4位，且头四位不能为【模糊通配符】，请检查！！。输入【模糊条件】例子为：515CA6380M06/1010149#5%  ，其中#表示1个字符，%表示0个或多个字符。请输入正确的、严格的模糊查询条件，以免查询数据太大，导致长时间无反应或查询失败！';
                        RETURN -1;
                    END;
            END;
        IF CHARINDEX('%', @CollectSN) <> 0
            BEGIN
                IF CHARINDEX('%', @CollectSN) <= 3
                    BEGIN
                        SET @I_ReturnMessage = 'ServerMessage:所输入的【模糊条件】必须大于4位，且头四位不能为【模糊通配符】，请检查！！。输入【模糊条件】例子为：515CA6380M06/1010149#5%  ，其中#表示1个字符，%表示0个或多个字符。请输入正确的、严格的模糊查询条件，以免查询数据太大，导致长时间无反应或查询失败！';
                        RETURN -1;
                    END;
            END;

        SET @CollectSN = REPLACE(@CollectSN, '#', '_');
	
        IF ISNULL(@TotalBits, 0) = 0
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:没有输入总位数，请检查！';
                RETURN -1;
            END;

        IF NOT EXISTS ( SELECT  1 FROM  OrderSetItem WITH ( NOLOCK ) WHERE   MAC LIKE @CollectSN AND LEN(MAC) = @TotalBits )
        BEGIN
			IF NOT EXISTS ( SELECT  1 FROM    DataChainAssembly WITH ( NOLOCK ) WHERE   CollectSN LIKE @CollectSN AND LEN(CollectSN) = @TotalBits )
			BEGIN
				SET @I_ReturnMessage = 'ServerMessage:输入的查询条件无数据，请检查！';
				RETURN -1;
			END;
        END;

	--MAC地址模糊查询
        IF EXISTS ( SELECT  1 FROM OrderSetItem WITH ( NOLOCK ) WHERE   MAC LIKE @CollectSN AND LEN(MAC) = @TotalBits )
        BEGIN
            INSERT  INTO @LotSNTemp ( LotSNName )
                    SELECT DISTINCT e.FieldName
                    FROM    OrderFieldSetting a
                    INNER JOIN OrderSetItem b WITH ( NOLOCK ) ON a.OrderFieldSettingId = b.OrderFieldSettingId
                    INNER JOIN ModelSetting c WITH ( NOLOCK ) ON a.ModelSettingId = c.ModelSettingId
                    INNER JOIN ModelFieldSetting d WITH ( NOLOCK ) ON c.ModelSettingId = d.ModelSettingId
                    INNER JOIN FieldSetting e WITH ( NOLOCK ) ON d.FieldSettingId = e.FieldSettingId
                    WHERE   b.MAC LIKE @CollectSN
                            AND d.IsMainSN = 1;
							
            DECLARE cursor1 CURSOR
            FOR
                SELECT  LotSNName FROM    @LotSNTemp WHERE   ISNULL(LotSNName, '') <> '';
            OPEN cursor1;
            FETCH NEXT FROM cursor1	 
					INTO @LotSNName;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @SqlOne = 'select distinct b.SOName,b.ProductName,' + @LotSNName
                    + ' as LotSN,''写号'' as WorkflowStepName,
					''MAC地址'' as CollectItemName,a.MAC as CollectSN from OrderSetItem a
					left join OrderFieldSetting b on a.OrderFieldSettingId=b.OrderFieldSettingId
					where convert(varchar(17),LEN(a.MAC))=''' + CONVERT(VARCHAR(17), @TotalBits)
                    + ''' and b.OrderType=''TV'' and a.MAC like ''' + @CollectSN + ''' and ISNULL(' + @LotSNName
                    + ','''')<>'''' and a.IsCancel=0';
                INSERT  INTO @OrderSetTemp ( SOName, ProductName, LotSN, WorkflowStepName, CollectItemName,CollectSN )
                        EXEC ( @SqlOne );

                FETCH NEXT FROM cursor1	 
				INTO @LotSNName;
            END;

            CLOSE cursor1;
            DEALLOCATE cursor1; 

	--输出显示
            SELECT  SOName, ProductName, TA.LotSN, WorkflowStepName, CollectItemName, CollectSN
            FROM    @OrderSetTemp TA;
            RETURN 0;		
        END;

	

	--采集项模糊查询
        IF EXISTS ( SELECT  1 FROM    DataChainAssembly WITH ( NOLOCK ) WHERE   CollectSN LIKE @CollectSN AND LEN(CollectSN) = @TotalBits )
        BEGIN
            SELECT  MO.SOName AS SOName,
		--[dbo].[RemoveZero](MO.MOName) AS MOName,
                    ProductRoot.ProductName AS ProductName, Lot.LotSN, WorkflowStep.WorkflowStepName,
                    TA.ItemName AS CollectItemName, TA.CollectSN, TA.Operator, PersonInfo.PersonName,
                    Workcenter.WorkcenterName, TA.AssemblyTime
            FROM    DataChainAssembly TA WITH ( NOLOCK )
            LEFT JOIN Lot WITH ( NOLOCK ) ON Lot.LotId = TA.LotId
            LEFT JOIN MO WITH ( NOLOCK ) ON MO.MOId = TA.MOId
            LEFT JOIN Product WITH ( NOLOCK ) ON Product.ProductId = TA.ProductId
            LEFT JOIN ProductRoot WITH ( NOLOCK ) ON ProductRoot.ProductRootId = Product.ProductRootId
            LEFT JOIN WorkflowStep WITH ( NOLOCK ) ON WorkflowStep.WorkflowStepId = TA.WorkflowStepId
            LEFT JOIN PersonInfo WITH ( NOLOCK ) ON TA.Operator = PersonInfo.PersonNumber
            LEFT JOIN Workcenter WITH ( NOLOCK ) ON TA.WorkcenterId = Workcenter.WorkcenterId
            WHERE   TA.IsCancel = 0
                    AND Lot.LotStatus = '1'
                    AND TA.CollectSN LIKE @CollectSN
                    AND LEN(TA.CollectSN) = @TotalBits;
		
            RETURN 0;
        END;	

        RETURN 0;

    END;

