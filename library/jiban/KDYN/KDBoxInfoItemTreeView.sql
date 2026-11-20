
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016  1:55PM>
-- Description:	为KDBoxInfo创建导航树视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDBoxInfoItemTreeView]
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
	
	declare @KDOrderInfoId char(12)=''
	declare @BoxLevel nvarchar(30)=''
	declare @BoxType nvarchar(30)=''
	
	select 
		@KDOrderInfoId=KDOrderInfoId,
		@BoxLevel=BoxLevel,
		@BoxType=BoxType 
	from KDBoxInfo where KDBoxInfoId=@I_ParentPKId
	
	IF @I_PKId <> ''
	BEGIN
		select
			KDBoxInfo.KDBoxInfoId, 
			KDBoxInfo.BoxSN,
			KDBoxInfo.BoxNumber,
			KDBoxInfo.BoxLength,
			KDBoxInfo.BoxWidth,
			KDBoxInfo.BoxHeight,
			KDBoxInfo.NetWeight,
			KDBoxInfo.GrossWeight,
			KDBoxInfo.IsPrint,
			KDBoxInfo.PrintCount
		--into #KDBoxtemp 
		from KDBoxInfo
		WHERE KDBoxInfoId = @I_PKId
		order by KDBoxInfo.BoxSN
		
		RETURN 0;
	END	


	

	select
		KDBoxInfo.KDBoxInfoId, 
		KDBoxInfo.BoxSN,
		KDBoxInfo.BoxNumber,
		KDBoxInfo.BoxLength,
		KDBoxInfo.BoxWidth,
		KDBoxInfo.BoxHeight,
		KDBoxInfo.NetWeight,
		KDBoxInfo.GrossWeight,
		KDBoxInfo.IsPrint,
		KDBoxInfo.PrintCount
	into #KDBoxtemp from KDBoxInfo
	left join KDBoxItem on  KDBoxInfo.KDBoxInfoId=KDBoxItem.KDBoxInfoId
	where KDBoxInfo.KDOrderInfoId=@KDOrderInfoId and KDBoxInfo.BoxLevel=@BoxLevel and KDBoxInfo.BoxType=@BoxType and KDBoxInfo.IsCancel=0
	order by KDBoxInfo.BoxSN

	
	 SELECT isnull(count(distinct b.LotSN),0) AS PackQty, b.LotSN,b.BoxSN  into #Shipboxtemp
	 FROM  #KDBoxtemp a left join  ShipBox b on a.BoxSN=b.BoxSN WHERE b.IsCancel=0 GROUP BY b.BoxSN,b.LotSN

	
	SELECT ISNULL(count(distinct ProductId),0) AS PCount, KDBoxInfoId into #BoxItemtemp
	FROM  KDBoxItem  where KDOrderInfoId=@KDOrderInfoId and  IsCancel=0 GROUP BY KDBoxInfoId

	SELECT ShipPalletId,a.BoxSN into #Pallettemp
	FROM #KDBoxtemp a left join ShipPallet  b on  a.BoxSN=b.BoxSN where b.IsCancel=0 


	select
		distinct
		a.KDBoxInfoId, 
		a.BoxSN,
		a.BoxNumber,
		b.LotSN,
		b.PackQty,
		c.PCount,
		case when d.ShipPalletId<>'' then 'Y' else '' end as IsPallet,
		a.BoxLength,
		a.BoxWidth,
		a.BoxHeight,
		a.NetWeight,
		a.GrossWeight,
		a.IsPrint,
		a.PrintCount
	from #KDBoxtemp a 
	left join #Shipboxtemp b on a.BoxSN=b.BoxSN
	left join #BoxItemtemp c on a.KDBoxInfoId=c.KDBoxInfoId
	left join #Pallettemp d on a.BoxSN=d.BoxSN
	order by a.BoxSN

	drop table #KDBoxtemp,
	#Shipboxtemp, 
	#BoxItemtemp,
	#Pallettemp


	return 0

END