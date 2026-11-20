
-- =============================================
-- Author:		<OrBit chay>
-- Create Date: <2017.06.26>
-- Description:	散件打印外箱箱号
-- =============================================
CREATE PROCEDURE  [dbo].[KDPrintMediumBoxSNDoMethod]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKid char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='',		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
@StartBoxSN nvarchar(50)='',
@EndBoxSN nvarchar(50)='',
@ParameterA nvarchar(100)='',
@ParameterB nvarchar(100)='',
@ParameterC nvarchar(100)=''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	declare @return_value int
	set @return_value=-1

	------检查元对象方法用户授权
	--exec @return_value=[dbo].[MetadataPermissionCheckDoMethod]
	--	@I_ReturnMessage=@I_ReturnMessage output,
	--	@I_OrBitUserId=@I_OrBitUserId,
	--	@I_OrBitUserName=@I_OrBitUserName,
	--	@I_Sender=@I_Sender

	--if @return_value=-1
	--begin
	--	set @I_ReturnMessage=@I_ReturnMessage
	--	return -1
	--end


	declare @KDOrderInfoId char(12)
	declare @OrderName nvarchar(50)
	declare @KDBoxInfoId char(12)
	declare @BoxLevel nvarchar(50)
	declare @BoxType nvarchar(50)
	declare @Client nvarchar(50)
	declare @Model nvarchar(50)
	declare @OrderQty int
	declare @Brand nvarchar(50)
	declare @BoxSN nvarchar(50)
	declare @BoxNumber nvarchar(50)
	declare @PartNO nvarchar(50)
	declare @VGCode nvarchar(50)

	declare @Description nvarchar(500)
	declare @StartKDBoxInfoId char(12)
	declare @EndKDBoxInfoId char(12)

	declare @ProductionDate nvarchar(20)
	declare @Country nvarchar(50)
	declare @PanelPO nvarchar(50)
	declare @SKDPO nvarchar(50)
	declare @CustomerPO nvarchar(50)
	declare @SupplierCode nvarchar(100)=''
	declare @ProjectNo nvarchar(100)=''
	declare @PoNo nvarchar(100)=''
	declare @LotNo nvarchar(100)=''
	declare @MadeCountry nvarchar(50)=''
	declare @RollingPlan nvarchar(100)=''
	declare @ModuleName nvarchar(50)=''
	declare @Explain nvarchar(max)=''


	set @KDBoxInfoId=''
	set @BoxLevel=''
	set @BoxType=''
	set @KDOrderInfoId=''
	set @OrderName=''
	set @Client=''
	set @Model=''
	set @OrderQty=0
	set @Brand=''
	set @BoxSN=''
	set @BoxNumber=''
	set @PartNO=''
	set @VGCode=''
	set @StartKDBoxInfoId=''
	set @EndKDBoxInfoId=''
	set @ProductionDate=CONVERT(varchar,GETDATE(),23)
	set @Brand=''
	set @Country=''
	set @PanelPO=''
	set @SKDPO=''
	set @CustomerPO=''
	set @Explain='说明：'

	--记录当前PKID,为了检测是不是同一层级、同一类别
    create table #BoxTemp(
		KDBoxInfoId char(12),
		BoxLevel varchar(20),
		BoxType varchar(20)
	)

	--不打印的箱号(没有包含全部不打印的)
	 create table #NotPrintBoxSN (
		KDBoxInfoId char(12)
	)
	--打印的箱号
	create table #PrintBoxSN (
		KDBoxInfoId char(12)
	)

	--中层级箱号信息
	create table #MiddlePrintData  (
		KDBoxInfoId char(12),
		BoxSN nvarchar(50),         --箱号
		BoxNumber nvarchar(50),     --箱编号
		TotalNet float,             --净重
		Gross float,                --毛重
		L float,                    --长
		W float,                    --宽
		H float                     --高
	)
	--内层级箱号信息
	create table  #InnerPrintData  (
		MiddleKDBoxInfoId char(12),
		InnerKDBoxInfoId char(12),
		BoxNumber nvarchar(50),     --箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		QTY float,                  --数量
		TotalNet float,             --净重
		Gross float,                --毛重
		L float,                    --长
		W float,                    --宽
		H float                     --高
	)
	--计算内箱物料种数,及装箱数量总和
		create table #InnerBoxMaterial  (
		InnerKDBoxInfoId char(12),
		MaterialQTY float,                  --物料种数
		SumQTY float
	)
	--中箱、内箱组合，
	create table #CombData  (
		BoxSN nvarchar(50),         --箱号
		A2BoxNumber nvarchar(50),     --A2箱编号
		A4BoxNumber nvarchar(50),     --A4箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		A2TotalNet float,             --净重
		A2Gross float,                --毛重
		A2L float,                    --长
		A2W float,                    --宽
		A2H float,                     --高
		MaterialQTY float,
		A4QTY float,                  --数量
		A4TotalNet float,             --净重
		A4Gross float,                --毛重
		A4L float,                    --长
		A4W float,                    --宽
		A4H float,                     --高
		A4BoxInfoId char(12),
		SumQTY float
	)
	--得到需处理数据
	create table #HandleData  (
		GroupNumberA2 int,
		GroupNumberA4 int,
		BoxSN nvarchar(50),         --箱号
		A2BoxNumber nvarchar(50),     --A2箱编号
		A4BoxNumber nvarchar(50),     --A4箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		QTY float,                  --数量
		TotalNet float,             --净重
		Gross float,                --毛重
		L float,                    --长
		W float,                    --宽
		H float,                     --高
		A4BoxInfoId char(12)
	)
	--处理内箱 装箱信息完全相同(两个及以上)
	create table #HandleSameBoxInfo 
	(
		GroupNumberA2 int,
		GroupNumberA4 int,
		MaxBoxInfoId char(12) ,
		MinBoxInfoId char(12)
	)

	--得到正式导出的唯一数据
	create table #FormalPrintData  (
		GroupNumberA2 int,
		GroupNumberA4 int,
		BoxSN nvarchar(50),         --箱号
		A2BoxNumber nvarchar(50),     --A2箱编号
		A4BoxNumber nvarchar(50),     --A4箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		QTY float,                  --数量
		TotalNet float,             --净重
		Gross float,                --毛重
		L float,                    --长
		W float,                    --宽
		H float                     --高
	)

	create table #GroupPrintData  (
		GroupNumberA2 int,
		GroupNumberA4 int,
		isSameModulName char(1),
		isSameVGCode char(1),
		isSameEnglishDesc char(1),
		isSameQTY  char(1),
		isSameFieldsA  char(1),
		isSameFieldsB char(1)
	)



	if ISNULL(@I_ParentPKId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请选择有效行项!'
		return -1
	end

	if ISNULL(@StartBoxSN,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入起始箱号!'
		return -1
	end

	if ISNULL(@EndBoxSN,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入截止箱号!'
		return -1
	end

	--获取订单id
	select top 1 
		@KDOrderInfoId=KDOrderInfoId
	from KDBoxInfo 
	where KDBoxInfoId=@I_ParentPKId and IsCancel=0

	--获取订单信息
	select 
		@OrderName=ISNULL(OrderName,''),
		@Client=ISNULL(CustomerName,''),
		@Description=ISNULL(OrderDescription,''),
		@OrderQty=ISNULL(OrderQty,0),
		@Model=ISNULL(CustomerModel,''),
		@Brand=ISNULL(Brand,''),
		@Country=ISNULL(Country,''),
		@PanelPO=ISNULL(Panel,''),
		@SKDPO=ISNULL(SKD,''),
		@SupplierCode=isnull(SupplierCode,''),
		@ProjectNo=isnull(ProjectNo,''),
		@PoNo=isnull(PoNo,''),
		@LotNo=isnull(LotNo,''),
		@MadeCountry=isnull(MadeCountry,''),
		@RollingPlan=isnull(RollingPlan,''),
		@ProductionDate=CONVERT(varchar,OrderDate,23)
	from KDOrderInfo 
	where KDOrderInfoId=@KDOrderInfoId

	if not exists(select 1 from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxNumber=@StartBoxSN and IsCancel=0)
	begin
		set @I_ReturnMessage='ServerMessage:起始箱 ['+@StartBoxSN+'] 无效，请检查!'
		return -1
	end

	if not exists(select 1 from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxNumber=@EndBoxSN and IsCancel=0)
	begin
		set @I_ReturnMessage='ServerMessage:截止箱 ['+@EndBoxSN+'] 无效，请检查!'
		return -1
	end

	select @StartKDBoxInfoId=KDBoxInfoId from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxNumber=@StartBoxSN and IsCancel=0
	select @EndKDBoxInfoId=KDBoxInfoId from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxNumber=@EndBoxSN and IsCancel=0

	if ISNULL(@StartKDBoxInfoId,'')>ISNULL(@EndKDBoxInfoId,'')
	begin
		set @I_ReturnMessage='ServerMessage:起始箱 ['+@StartBoxSN+'] 不允许大于截止箱 ['+@EndBoxSN+']，请检查!'
		return -1
	end






	--外箱层级是否一致
	if(select Count(distinct aa.BoxLevel) from 
		(select BoxLevel from KDBoxInfo where KDBoxInfoId=@StartKDBoxInfoId and IsCancel=0
		union all 
		select BoxLevel from KDBoxInfo where KDBoxInfoId=@EndKDBoxInfoId and IsCancel=0
		) aa
	)>1
	begin
		set @I_ReturnMessage='ServerMessage:不允许同时打印非同一层级的外箱标签，打印失败!'
		return -1
	end

	--外箱类别是否一致
	if(select Count(distinct aa.BoxType) from 
		(select BoxType from KDBoxInfo where KDBoxInfoId=@StartKDBoxInfoId and IsCancel=0
		union all 
		select BoxType from KDBoxInfo where KDBoxInfoId=@EndKDBoxInfoId and IsCancel=0
		) aa
	)>1
	begin
		set @I_ReturnMessage='ServerMessage:不允许同时打印非同一类别的外箱标签，打印失败!'
		return -1
	end


	--获取当前打印的箱号类别
	select @BoxType=BoxType from KDBoxInfo where KDBoxInfoId=@StartKDBoxInfoId and IsCancel=0
	--把信息写入表变量
	insert into #BoxTemp (KDBoxInfoId,BoxLevel,BoxType) 
	select KDBoxInfo.KDBoxInfoId,KDBoxInfo.BoxLevel,KDBoxInfo.BoxType
	from KDBoxInfo 
	where KDBoxInfo.KDOrderInfoId=@KDOrderInfoId 
	and KDBoxInfo.KDBoxInfoId>=@StartKDBoxInfoId and KDBoxInfo.KDBoxInfoId<=@EndKDBoxInfoId
	and KDBoxInfo.BoxType=@BoxType
	and KDBoxInfo.IsCancel=0
	order by KDBoxInfo.KDBoxInfoId

	if not exists(select 1 from #BoxTemp)
	begin
		set @I_ReturnMessage='ServerMessage:获取到的外箱数为零，打印失败!'
		return -1
	end 









	--打印的箱号
	begin
		insert into #PrintBoxSN
		select distinct a.KDBoxInfoId from #BoxTemp a
		inner join KDLoadBox b on a.KDBoxInfoId=b.ParentBoxInfoId where b.IsCancel=0
		and KDBoxInfoId not in
		(
		select distinct bb.KDBoxInfoId from
		(select distinct a.KDBoxInfoId ,b.BoxInfoId from #BoxTemp a
		inner join KDLoadBox b on a.KDBoxInfoId=b.ParentBoxInfoId where b.IsCancel=0
		) bb
		where bb.BoxInfoId  in (select ParentBoxInfoId from KDLoadBox where IsCancel=0 and KDOrderInfoId=@KDOrderInfoId)
		) 
	end

	 --不打印的箱号
	 begin
		 insert into #NotPrintBoxSN
			select distinct a.KDBoxInfoId
			 from #BoxTemp a
			where KDBoxInfoId not in (select ParentBoxInfoId from KDLoadBox where IsCancel=0 and KDOrderInfoId=@KDOrderInfoId)
		 union all
			 select distinct bb.KDBoxInfoId from
			(select distinct a.KDBoxInfoId ,b.BoxInfoId from #BoxTemp a
			inner join KDLoadBox b on a.KDBoxInfoId=b.ParentBoxInfoId where b.IsCancel=0
			) bb
			where bb.BoxInfoId  in (select ParentBoxInfoId from KDLoadBox where IsCancel=0 and KDOrderInfoId=@KDOrderInfoId)
	end
	
	


	--计算说明信息
	if  exists(select 1 from  #NotPrintBoxSN a)

	begin
		select @Explain=@Explain+b.BoxNumber+'、' from 
	    #NotPrintBoxSN a
	    inner join KDBoxInfo b on a.KDBoxInfoId=b.KDBoxInfoId where b.IsCancel=0

		set @Explain=left(rtrim(ltrim(@Explain)),len(rtrim(ltrim(@Explain)))-1)
		set @Explain=@Explain+'为最内箱 或 两层拼箱，请检查, 请用对应功能导出！'
	end 
	else
	begin
		set @Explain=@Explain+'…………………………'
	end


	--中层级箱号信息
	insert into #MiddlePrintData(KDBoxInfoId,BoxSN,BoxNumber,TotalNet,Gross,L,W,H)
	select b.KDBoxInfoId,b.BoxSN,b.BoxNumber,
	Convert(float,b.NetWeight) as TotalNet,
	Convert(float,b.GrossWeight) as Gross,
	Convert(float,b.BoxLength) as L,
	Convert(float,b.BoxWidth) as W, 
	Convert(float,b.BoxHeight) as H
	from #PrintBoxSN a
	inner  join KDBoxInfo b on a.KDBoxInfoId=b.KDBoxInfoId
	where b.IsCancel=0 
	--内层级箱号信息
	insert into #InnerPrintData(MiddleKDBoxInfoId,InnerKDBoxInfoId,BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet,Gross,L,W,H)
	select distinct a.KDBoxInfoId as MiddleKDBoxInfoId,
	b.BoxInfoId as InnerKDBoxInfoId,
	d.BoxNumber as BoxNumber,
	KDOrderItem.CustomerNumber as VGCode,
	c.ModuleName,
	[dbo].[RemoveZero](ProductRoot.ProductName) as PartNO,
	KDOrderItem.EnglishDescription as EnglishDesc,
	KDOrderItem.FieldsA,
	KDOrderItem.FieldsB,
	Convert(float,c.RealQty) as QTY,
	Convert(float,d.NetWeight) as TotalNet,
	Convert(float,d.GrossWeight) as Gross,
	Convert(float,d.BoxLength) as L,
	Convert(float,d.BoxWidth) as W, 
	Convert(float,d.BoxHeight) as H
	from #PrintBoxSN a
	inner join KDLoadBox b on a.KDBoxInfoId=b.ParentBoxInfoId
	inner join KDBoxItem c on b.BoxInfoId=c.KDBoxInfoId
	inner join KDBoxInfo d on b.BoxInfoId=d.KDBoxInfoId
	inner join KDOrderItem on KDOrderItem.ProductId=c.ProductId and KDOrderItem.ModuleName=c.ModuleName and KDOrderItem.KDOrderInfoId=@KDOrderInfoId
	inner join Product on Product.ProductId=KDOrderItem.ProductId
	inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
	where b.IsCancel=0 and c.IsCancel=0 and KDOrderItem.IsIgnore=0 and KDOrderItem.IsValidity=1
	
	--计算内箱物料种数
	insert into #InnerBoxMaterial(InnerKDBoxInfoId,MaterialQTY,SumQTY)
	select InnerKDBoxInfoId,Convert(float,count(DISTINCT a.PartNO)) as MaterialQTY,sum(QTY) as SumQTY
	from #InnerPrintData a
	group by a.InnerKDBoxInfoId


	--内箱、中箱信息合并
	insert into #CombData(BoxSN,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,
	A2TotalNet,A2Gross,A2L,A2W,A2H,MaterialQTY,A4QTY,A4TotalNet,A4Gross,A4L,A4W,A4H,A4BoxInfoId,SumQTY)
	select distinct a.BoxSN,a.BoxNumber as A2BoxNumber,b.BoxNumber as A4BoxNumber, b.VGCode,b.ModuleName,b.PartNO,b.EnglishDesc,b.FieldsA,b.FieldsB,
	a.TotalNet as A2TotalNet,a.Gross as A2Gross,a.L as A2L,a.W as A2W,a.H as A2H,
	c.MaterialQTY as MaterialQTY,b.QTY as A4QTY,
	b.TotalNet as A4TotalNet ,b.Gross as A4Gross,b.L as A4L,b.W as A4W,b.H as A4H,
	b.InnerKDBoxInfoId AS A4BoxInfoId,
	c.SumQTY
	FROM #MiddlePrintData a
	inner join #InnerPrintData b on a.KDBoxInfoId=b.MiddleKDBoxInfoId
	inner join #InnerBoxMaterial c on b.InnerKDBoxInfoId=c.InnerKDBoxInfoId

	--得到需处理数据
	insert into #HandleData
	(GroupNumberA2,GroupNumberA4,BoxSN,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,
	TotalNet,Gross,L,W,H,A4BoxInfoId)
	select distinct  dense_rank() over (ORDER BY a.BoxSN) as GroupNumberA2, 
	dense_rank() over (ORDER BY a.BoxSN,a.SumQTY,a.MaterialQTY,a.A4TotalNet,a.A4Gross,a.A4L,a.A4W,a.A4H) as GroupNumberA4,
	a.BoxSN,a.A2BoxNumber,a.A4BoxNumber,a.VGCode,a.ModuleName,a.PartNO,a.EnglishDesc,a.FieldsA,a.FieldsB,a.A4QTY,
	a.A2TotalNet,a.A2Gross,a.A2L,a.A2W,a.A2H,a.A4BoxInfoId
	from #CombData a

	--处理内箱 装箱信息完全相同(两个及以上)
	insert into #HandleSameBoxInfo
	 select a.GroupNumberA2,a.GroupNumberA4,max(a.A4BoxInfoId),min(a.A4BoxInfoId)
	 from #HandleData a
	 group by a.GroupNumberA2,a.GroupNumberA4
	 having max(a.A4BoxInfoId)<>min(A4BoxInfoId)

	 --更新#HandleData表
	update #HandleData  set A4BoxNumber=lll.minA4BoxNumber+'-'+substring(lll.maxA4BoxNumber,3,len(lll.maxA4BoxNumber)-2)
	from #HandleData aaa
	inner join 
		( 
		select xx.A4BoxNumber as minA4BoxNumber,yy.A4BoxNumber as maxA4BoxNumber,xx.GroupNumberA2,xx.GroupNumberA4 from  
		(select a.A4BoxNumber,b.GroupNumberA2,b.GroupNumberA4 from #HandleData a 
		inner join #HandleSameBoxInfo b on a.GroupNumberA2=b.GroupNumberA2 and a.GroupNumberA4=b.GroupNumberA4 and a.A4BoxInfoId=b.MinBoxInfoId) xx
		inner join
		(select a.A4BoxNumber,b.GroupNumberA2,b.GroupNumberA4 from #HandleData a 
		inner join #HandleSameBoxInfo b on a.GroupNumberA2=b.GroupNumberA2 and a.GroupNumberA4=b.GroupNumberA4 and a.A4BoxInfoId=b.MaxBoxInfoId) yy
		on xx.GroupNumberA2=yy.GroupNumberA2 and xx.GroupNumberA4=yy.GroupNumberA4
		) lll 
	on aaa.GroupNumberA2=lll.GroupNumberA2 and aaa.GroupNumberA4=lll.GroupNumberA4

	----得到正式导出的唯一数据
	insert into #FormalPrintData
	(GroupNumberA2,GroupNumberA4,BoxSN,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet
	,Gross,L,W,H)
	select distinct a.GroupNumberA2,a.GroupNumberA4,a.BoxSN,a.A2BoxNumber,a.A4BoxNumber,
	a.VGCode,a.ModuleName,a.PartNO,a.EnglishDesc,a.FieldsA,a.FieldsB,a.QTY,a.TotalNet,a.Gross,a.L,a.W,a.H
	from #HandleData a 
	



	if not exists(select 1 from #FormalPrintData)
	begin
		set @I_ReturnMessage='ServerMessage:您所输入的起止箱号全部为最内箱 或 两层拼箱，没有任何一层拼箱数据可打印，请检查!'
		return -1
	end


	insert into #GroupPrintData(GroupNumberA2,GroupNumberA4,isSameModulName,isSameVGCode,isSameEnglishDesc,isSameQTY,isSameFieldsA,isSameFieldsB)
	 select  
	 a.GroupNumberA2, 
	 a.GroupNumberA4,
	 case count(distinct a.ModuleName) when 1 then '1' else '0' end as isSameModulName,
	 case count(distinct a.VGCode) when 1 then '1' else '0' end as isSameVGCode,
	 case count(distinct a.EnglishDesc) when 1 then '1' else '0' end as isSameEnglishDesc,
	 case count(distinct a.QTY) when 1 then '1' else '0' end as isSameQTY,
	 case count(distinct a.FieldsA) when 1 then '1' else '0' end as isSameFieldsA,
	 case count(distinct a.FieldsB) when 1 then '1' else '0' end as isSameFieldsB  
	 FROM #FormalPrintData a
	 group by a.GroupNumberA2,a.GroupNumberA4





	if ISNULL(@BoxType,'')='A'
		set @CustomerPO=@PanelPO
	else 
		set @CustomerPO=@SKDPO


		--更新打印次数
	update KDBoxInfo set 
		IsPrint=1,
		PrintCount=PrintCount+1 
	where KDBoxInfoId in (select KDBoxInfoId from #PrintBoxSN)


	--如果为 MRZ 报表，则执行此打印

		--打印数据
		select @Client as Client,Substring(@OrderName,3,LEN(@OrderName)-2) as OrderNumber,@Model as Model,@OrderQty as OrderQty,
			@Brand as Brand,@ProductionDate as ProductionDate,@Country as Country,@CustomerPO as CustomerPO,
			@Description as Description,@SupplierCode as SupplierCode,@ProjectNo as ProjectNo,@PoNo as PoNo,
			@LotNo as LotNo,@RollingPlan  as RollingPlan ,@MadeCountry as MadeCountry,@Explain as Explain,
			@ParameterA as ParameterA,@ParameterB as ParameterB,@ParameterC as ParameterC,
			a.GroupNumberA2,
			 row_number() over (order by cast(case CHARINDEX('-',a.A4BoxNumber) when 0 then 
			SUBSTRING(a.A4BoxNumber,3,LEN(a.A4BoxNumber)-2)
			 else  SUBSTRING(a.A4BoxNumber,3,CHARINDEX('-',a.A4BoxNumber)-3) end as int)) as GroupNumberA4,
			b.isSameEnglishDesc,b.isSameModulName,b.isSameQTY,b.isSameVGCode,b.isSameFieldsA,b.isSameFieldsB,
			BoxSN,a.A2BoxNumber,a.A4BoxNumber,ModuleName,VGCode,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet,Gross,L,W,H 
		from #FormalPrintData a left join #GroupPrintData b on a.GroupNumberA2=b.GroupNumberA2 and a.GroupNumberA4=b.GroupNumberA4



--删除临时表
	drop table #BoxTemp
	drop table #NotPrintBoxSN
	drop table #PrintBoxSN
	drop table #MiddlePrintData
	drop table #InnerPrintData
	drop table #InnerBoxMaterial
	drop table #CombData
	drop table #HandleData
	drop table #HandleSameBoxInfo
	drop table #FormalPrintData 
	drop table  #GroupPrintData
	set @I_ReturnMessage='ServerMessage:箱号打印成功!从'+@StartBoxSN+'到'+@EndBoxSN
	return 0
END