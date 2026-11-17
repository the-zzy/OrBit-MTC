-- =============================================
-- Author:		<Wang RT>
-- Create date: <2023-06-17>
-- Description:	执行_SampleProject元数据的示例事件
-- =============================================
CREATE PROCEDURE [dbo].[StocktakeDoMethod]
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
    @I_Parameter NVARCHAR(100) = ''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @return_value INT;
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

    IF @I_Sender = 'CloseStocktake'
    BEGIN
		
        IF EXISTS ( SELECT  1
                    FROM    dbo.Stocktake
                    WHERE   StocktakeId = @I_PKid AND StocktakeStatus = '30' )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:固定资产盘点单号已关闭，请勿重复操作！';
            RETURN -1;
        END;

        UPDATE  dbo.Stocktake
        SET     StocktakeStatus = '30'
        WHERE   StocktakeId = @I_PKid;

        RETURN 0;
    END;

    RETURN 0;

END;




