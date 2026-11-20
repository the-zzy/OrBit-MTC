
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016  1:55PM>
-- Description:	为KDBoxInfo创建导航树视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDLoadBoxTreeView]
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

	declare @KDOrderInfoId char(12)
	declare @BoxLevel nvarchar(30)
	declare @BoxType nvarchar(30)

	set @KDOrderInfoId=''
	set @BoxLevel=''
	set @BoxType=''

	select 
		@KDOrderInfoId=KDOrderInfoId,
		@BoxLevel=BoxLevel,
		@BoxType=BoxType 
	from KDBoxInfo 
	where KDBoxInfoId=@I_ParentPKId and IsCancel=0

	select PBox.BoxNumber as OuterBox,CBox.BoxNumber as InnerBox,CBox.BoxType,CBox.BoxLevel 
	from KDLoadBox
	inner join KDBoxInfo PBox on PBox.KDBoxInfoId=KDLoadBox.ParentBoxInfoId
	inner join KDBoxInfo CBox on CBox.KDBoxInfoId=KDLoadBox.BoxInfoId
	where PBox.KDOrderInfoId=@KDOrderInfoId and PBox.BoxLevel=@BoxLevel and PBox.BoxType=@BoxType 
	and PBox.IsCancel=0 and CBox.IsCancel=0 and KDLoadBox.IsCancel=0

	return 0

END