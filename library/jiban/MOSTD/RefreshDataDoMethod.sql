
-- =============================================
-- Author:		<OrBit benson>
-- Create date: <2016.09.23>
-- Description:	刷新数据 MES-SAP
-- =============================================
CREATE PROCEDURE [dbo].[RefreshDataDoMethod]
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
    @DataValue NVARCHAR(50) = ''
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
    DECLARE @return_value INT;
    DECLARE @serviceStat INT = 99;
    DECLARE @serviceMsg NVARCHAR(MAX)= '';
    DECLARE @LGORT VARCHAR(10)= '';
    DECLARE @FactoryName NVARCHAR(30)= '';
    DECLARE @InterfaceAutoExecId CHAR(12);
    DECLARE @ItemName NVARCHAR(50);

    SET @return_value = -1;
    SET @InterfaceAutoExecId = '';
    SET @ItemName = '';

    IF ISNULL(@DataValue, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入要刷新的数据值(如：单据号)!';
        RETURN -1;	
    END;

	--交货单
    IF @I_PlugInCommand = 'DLO'
    BEGIN
        UPDATE  dbo.DeliveryOrder
        SET     ModifyDate = GETDATE(), Createdate = GETDATE() - 10
        WHERE   DeliveryOrderName = @DataValue; 
    END;

    IF @I_PlugInCommand = 'STOCK'
    BEGIN
        SET @ItemName = RTRIM(@DataValue);
        EXEC [dbo].[Proc_CallWebServiceItemStock]
            @I_ReturnMessage = @serviceMsg OUTPUT ,
            @Factory = @FactoryName ,
            @Material = @ItemName ,
            @Lgort = @Lgort ,
            @MethodName = N'GetSapMaterialStock';	
    END;

	--BOM
    IF @I_PlugInCommand = 'BOM'
    BEGIN
		
        SET @ItemName = RTRIM(@DataValue);
		EXEC dbo.Proc_CallWebServiceDoId
			@I_ReturnMessage = @serviceMsg OUTPUT ,
		    @parameter = @ItemName , -- varchar(20)
		    @methodName = 'GetSAPBOM' -- varchar(100)

		-----------raoym 20240614 拷贝工艺路线
        EXEC dbo.CopyProcessRouteDate
            @parameter_name = @ItemName; -- int
    END;

	--销售单
    IF @I_PlugInCommand = 'SO'
        SET @ItemName = 'SO';

	--进货通知单
    IF @I_PlugInCommand = 'INOD'
    BEGIN
        SET @ItemName = RTRIM(@DataValue);
        EXEC ADC_GETGWVendorDeliveryNum
            @I_ReturnMessage = @serviceMsg OUTPUT ,
            @GWDeliveryorder = @ItemName;
    END;

	--产品
    IF @I_PlugInCommand IN ( 'PROD', 'PROD1' )
    BEGIN
        SET @ItemName = RTRIM(@DataValue);
        EXEC [dbo].[Proc_CallWebServiceDoId]
            @I_ReturnMessage = @serviceMsg OUTPUT ,
            @parameter = @ItemName ,
            @methodName = N'GetSapMaterial';	
        RETURN 0;
    END;

    IF @I_PlugInCommand = 'PUVES'
    BEGIN
        SET @ItemName = @DataValue;
        UPDATE  dbo.VendorDelivery
        SET     ModifyDate = GETDATE() - 20
        WHERE   VendorDeliveryName = RTRIM(@DataValue);
        RETURN 0;
    END;
	--SELECT * FROM dbo.VendorDelivery WHERE VendorDeliveryName ='N120042900532'
	--采购单
    IF @I_PlugInCommand = 'PO'
    BEGIN
        SET @ItemName = RTRIM(@DataValue);
        EXEC [dbo].[Proc_CallWebServiceDoId]
            @I_ReturnMessage = @serviceMsg OUTPUT ,
            @parameter = @ItemName ,
            @methodName = N'GetSAPPO';	
        DECLARE @postr NVARCHAR(200)= '';
		
        SELECT  @postr = CASE WHEN @postr = '' THEN RTRIM(POName) + ''''
                              ELSE RTRIM(@postr) + ''',''''' + RTRIM(POName) + ''''
                         END
        FROM    PO
        WHERE   POName = @ItemName AND ISNULL(SRMAffrie, 0) <> 2;
        IF ISNULL(@postr, '') <> ''
        BEGIN
            EXEC [dbo].[ADC_SRMPO]
                @Postr = @Postr;
        END;
        RETURN 0;

    END;

	--工单
    IF @I_PlugInCommand IN ( 'MOSTD', 'PRWK' )
    BEGIN
        SET @ItemName = RTRIM(@DataValue);
        EXEC [dbo].[Proc_CallWebServiceDoId]
            @I_ReturnMessage = @serviceMsg OUTPUT ,
            @parameter = @ItemName ,
            @methodName = N'UpDateMO';	
    END;

	--发货指令
    IF @I_PlugInCommand = 'DLRS'
    BEGIN
        SET @ItemName = RTRIM(@DataValue);
        EXEC [dbo].[Proc_CallWebServiceDoId]
            @parameter = @ItemName ,
            @methodName = N'GetDeliveryOrderName';	
    END;

    IF @I_PlugInCommand IN ( 'DLCD', 'DLCS', 'DLCL' )
    BEGIN
        SET @ItemName = RTRIM(@DataValue);
        EXEC @serviceStat= [dbo].[Proc_CallWebServiceDo]
            @I_ReturnMessage = @serviceMsg OUTPUT ,
            @parameter = @ItemName ,
            @methodName = 'GetDo ';
        IF @I_PlugInCommand = 'DLCL'
        BEGIN
            EXEC [dbo].[Sync_BmtcDOdataDoMethod]
                @DeliveryNumber = @ItemName;
        END;
      --  SET @I_ReturnMessage = 'ServerMessage: SAP错误信息' + @serviceMsg + 'Status:' + CAST(@serviceStat AS VARCHAR(30));

  --      IF ISNULL(@serviceStat, 99) = 0    --weservices 执行成功
  --      BEGIN
  --       SET @I_ReturnMessage = 'ServerMessage:下载成功' +  + '单号:' + CAST(@ItemName AS VARCHAR(30));
		-- UPDATE dbo.DeliveryOrder SET ModifyDate = GETDATE() WHERE DeliveryOrderName = @ItemName
		---- SELECT * FROM dbo.DeliveryOrder WHERE DeliveryOrderName ='0080135151'
  --        RETURN 0
		--END
		--ELSE
  --      BEGIN
  --         SET @I_ReturnMessage = 'ServerMessage:下载失败' +  + '单号:' + CAST(@ItemName AS VARCHAR(30));
  --         RETURN 0
		--end
	   
    END;

	--送货单
    IF @I_PlugInCommand = 'SVDLY'
    BEGIN
      
        IF NOT EXISTS ( SELECT TOP 1
                                1
                        FROM    dbo.VendorDelivery WITH ( NOLOCK )
                        WHERE   VendorDeliveryName = @DataValue AND ModifyDate <= GETDATE() - 90 )
        BEGIN
            UPDATE  dbo.VendorDelivery
            SET     ModifyDate = GETDATE(), CreateDate = GETDATE() - 30
            WHERE   VendorDeliveryName = @DataValue;
            SET @I_ReturnMessage = 'ServerMessage:送货单 [' + @DataValue + '] 刷新数据成功.';

            IF @return_value = -1
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:送货单 [' + @DataValue + '] 刷新数据失败. ';
                RETURN -1;
            END;

        END;
        UPDATE  dbo.VendorDelivery
        SET     ModifyDate = GETDATE(), CreateDate = GETDATE()
        WHERE   VendorDeliveryName = @DataValue;

        SET @I_ReturnMessage = 'ServerMessage:送货单 [' + @DataValue + '] 刷新数据成功.';
        RETURN  0;
    END;

    IF ISNULL(@ItemName, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:未找到接口项!';
        RETURN -1;
    END;

    EXEC SysGetObjectPKId
        '' ,
        'InterfaceAutoExec' ,
        @InterfaceAutoExecId OUTPUT;
    INSERT  INTO InterfaceAutoExec ( InterfaceAutoExecId, ItemName, ItemValue, CreateUserId )
    VALUES  ( @InterfaceAutoExecId, @ItemName, @DataValue, @I_OrBitUserId );

    SET @I_ReturnMessage = 'ServerMessage:已把此数据添加到刷新列表，请等待执行(约 1 分钟)!';

    RETURN  0;

END;









