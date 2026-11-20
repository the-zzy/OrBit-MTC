
-- =============================================
-- Author:		<FZP>
-- Create date: <2024.11.5>
-- Description:阻容物料误差查询
-- =============================================
CREATE PROCEDURE [dbo].[PDA_CapacityErrorValueDoMethod]
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,			--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKid CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(MAX) = '' ,  	--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @ProductName NVARCHAR(50) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


	-- 扫描料号，检查存在性
    IF NOT EXISTS (SELECT 1 FROM dbo.Capacity WHERE ProductName = @ProductName)
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:料号[' + @ProductName + ']错误，请检查！';
        RETURN -1;
    END
	ELSE 
	BEGIN
	 --获取阻容物料的信息	 
    DECLARE @Lower VARCHAR(20);
    DECLARE @Upper VARCHAR(20);
    DECLARE @Description NVARCHAR(200);
    DECLARE @ErrorValue NVARCHAR(20);
	DECLARE @Specification NVARCHAR(20);

    SELECT
    @Lower = c.Lower,         
    @Upper = c.Upper,          
    @Description = c.Description,
    @ErrorValue = c.ErrorValue,  
    @Specification = c.Specification 
    FROM dbo.Capacity c
    WHERE  c.ProductName=  @ProductName;

        SET @I_ReturnMessage = 'ServerMessage:料号： '+@ProductName+'  规格描述：'+@Description+ '  规格是'+@Specification+'Ω,  '+'误差'+@ErrorValue+'Ω,  '+'上限是'+@Upper+'Ω,'+
	' 下限是'+@Upper+'Ω';
        RETURN 0;
    END;

END;