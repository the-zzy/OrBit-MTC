
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016  1:55PM>
-- Description:	为KDBoxInfo创建导航树视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDBoxInfoTreeView]
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
	BEGIN
		select 
			KDBoxInfoId,
			BoxNumber,
			BoxLevel,
			BoxSN,			
			BoxType,
			BoxLength,
			BoxWidth,
			BoxHeight,
			NetWeight,
			GrossWeight
		from KDBoxInfo 
		where KDBoxInfoId = @I_PKId
		
		return 0
	end
    
   IF @I_PlugInCommand = 'KDYN'
    BEGIN
    	select 
			KDBoxInfoId,
			BoxNumber,
			BoxLevel,
			BoxSN,			
			BoxType,
			BoxLength,
			BoxWidth,
			BoxHeight,
			NetWeight,
			GrossWeight
		from KDBoxInfo 
		where KDOrderInfoId = @I_ParentPKId
		ORDER BY BoxSN
		
		RETURN 0
    END
    

	select *  into #tb from KDBoxInfo (NOLOCK) where KDOrderInfoId=@I_ParentPKId and IsCancel=0

	select  BoxLevel,BoxType,min(KDBoxInfoid) as KDBoxInfoid,max(KDBoxInfoid) as maxKDBoxInfoid,
	count(KDOrderInfoId) BoxQty
	into #temp  from #tb 
	group by  BoxLevel,BoxType order by BoxLevel,BoxType

	select a.KDBoxInfoid,
	a.BoxLevel,
	a.BoxType,
	b.BoxTypeDesc,
	a.BoxQty,
	c.BoxNumber as StartBoxSN,
	d.BoxNumber as EndBoxSN  from #temp a 
	left join KDBoxType b (NOLOCK) on a.BoxType=b.BoxType
	left join  #tb  c on a.KDBoxInfoid=c.KDBoxInfoId
	left join  #tb  d on a.maxKDBoxInfoid=d.KDBoxInfoId
	order by a.BoxLevel,a.BoxType

	drop table #tb 
	drop table #temp 

	return 0

END
