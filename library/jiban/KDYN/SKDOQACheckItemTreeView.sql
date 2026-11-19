
-- =============================================
-- Author:		<LZH>
-- Create date: <2024.07.30>
-- Description:	为SKDOQACheckItem创建导航树视图
-- =============================================
CREATE PROCEDURE [dbo].[SKDOQACheckItemTreeView]
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_FiltCondition	nvarchar(max)='',	--过滤条件表达式
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)=''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.
AS
BEGIN
	-- This Stored Procedure is created by OrBit-MetaObject engine	
	SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	--执行TreeView,注意：以下过程必须根据业务的需求进行调整
	--如果您不了解TreeView过程如何编写，请参考我们提供的示例_SampleProjectTreeView

	SELECT a.OrderName, a.PalletSN, a.BoxSN, a.LotSN, a.CheckResult, a.CheckDefect, a.CheckUser, a.CreateDate
	FROM SKDOQACheckItem a
	INNER JOIN KDOrderInfo b ON a.OrderName = b.OrderName
	WHERE b.KDOrderInfoId = @I_ParentPKId
	
	RETURN 0;
END