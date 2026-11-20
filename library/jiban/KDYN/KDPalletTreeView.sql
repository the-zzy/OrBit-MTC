
-- =============================================
-- Author:		<benson>
-- Create date: <07  6 2016  5:59PM>
-- Description:	为KDPalletInfo创建导航树视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDPalletTreeView]
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_FiltCondition NVARCHAR(MAX) = '' ,	--过滤条件表达式
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKId CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = ''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.
AS
BEGIN
	-- This Stored Procedure is created by OrBit-MetaObject engine	
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	--执行TreeView,注意：以下过程必须根据业务的需求进行调整
	--如果您不了解TreeView过程如何编写，请参考我们提供的示例_SampleProjectTreeView
   
    IF @I_PKId <> ''
    BEGIN
	   SELECT KDPalletInfoId, PalletSN, CountQty, L, W, H, PNETWEIGHT, PGROSSWEIGHT, PrintCount
	   FROM dbo.KDPalletInfo
	   WHERE KDPalletInfoId = @I_PKId
	   AND IsCancel = 0
	   
	   RETURN 0;
	END
   
    IF @I_ParentPKId <> ''
    BEGIN
	   SELECT KDPalletInfoId, PalletSN, CountQty, L, W, H, PNETWEIGHT, PGROSSWEIGHT, PrintCount
	   FROM dbo.KDPalletInfo
	   WHERE KDOrderInfoId = @I_ParentPKId AND IsCancel=0
	   
	   RETURN 0;
	END
	
	




     
    RETURN 0;
END;


--SELECT * FROM vendor


