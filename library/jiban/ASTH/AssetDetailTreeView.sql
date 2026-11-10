
-- =============================================
-- Author:		<yf1002>
-- Create date: <08 29 2018  7:24PM>
-- Description:	为AssetDetail创建导航树视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[AssetDetailTreeView]
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

	if @I_PKId<>''  --当SaveData执行完成后刷新单行时执行
	begin
			SELECT  a.AssetDetailid,  a.Company,a.TypeName,a.AssetNum,a.Descriptionx,a.roomer,
			b.DivisionName,a.CostCenter,a.Createdate,a.ModifyUser,a.AssetRegistordate
			FROM        AssetDetail a
			   LEFT JOIN dbo.Division b ON b.DivisionId = a.DivisionId
			where RTRIM(AssetheadId)=RTRIM(@I_PKId) AND a.Activer = 1
			return 0
	END
    
	if @I_ParentPKId<>''  --当SaveData执行完成后刷新单行时执行
	begin
			SELECT  a.AssetDetailid,  a.Company,a.TypeName,a.AssetNum,a.Descriptionx,a.roomer,
			b.DivisionName,a.CostCenter,a.Createdate,a.ModifyUser,a.AssetRegistordate,a.IsDailyRemind AS '是否每日提醒',a.CheckResponsible AS '点检负责人'
			FROM        AssetDetail a
			   LEFT JOIN dbo.Division b ON b.DivisionId = a.DivisionId
			where RTRIM(AssetheadId)=RTRIM(@I_ParentPKId) AND a.Activer = 1
			return 0
	end
		
			SELECT  a.AssetDetailid,  a.Company,a.TypeName,a.AssetNum,a.Descriptionx,a.roomer,
			b.DivisionName,a.CostCenter,a.Createdate,a.ModifyUser,a.AssetRegistordate
			FROM        AssetDetail a
			   LEFT JOIN dbo.Division b ON b.DivisionId = a.DivisionId WHERE a.Activer = 1
			return 0
END
