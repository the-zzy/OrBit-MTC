
-- =============================================
-- Author:		<OrBit chay>
-- Create Date: <2017.06.26>
-- Description:	散件打印外箱箱号
-- =============================================
CREATE PROCEDURE  [dbo].[KDPrintOuterBoxSNDoMethod]
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
	--外层箱号信息，需打印
	create table #OuterPrintData(
		OuterBoxInfoId char(12),
		OuterBoxSN nvarchar(50),         --箱号
		OuterBoxNumber nvarchar(50),     --箱编号
		OuterTotalNet float,             --净重
		OuterGross float,                --毛重
		OuterL float,                    --长
		OuterW float,                    --宽
		OuterH float                     --高
	)

--得到各部分数据：
/*****************************************begin两种拼箱begin****************************/
/**************begin两层拼箱第一部分begin********/

	--中层箱号信息1，没有内层，直接装物料
	create table #MiddlePrintData1(
		OuterBoxInfoId char(12),
		MiddleBoxInfoId char(12),
		MiddleBoxNumber nvarchar(50),     --箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		MidQTY float,                  --数量
		MidTotalNet float,             --净重
		MidGross float,                --毛重
		MidL float,                    --长
		MidW float,                    --宽
		MidH float                     --高
	)
	--中层箱号信息1：中层物料种数，没有内层，直接装物料,计算装箱数量总和
		create table #MiddleBoxMaterial  (
		MiddleBoxInfoId char(12),
		MidMaterialQTY float,                  --物料种数
		MidSumQTY float
	)
/**************end两层拼箱第一部分end********/

/**************begin两层拼箱第二部分begin********/
	--中层箱号信息2，有内箱，内箱装物料
	create table #MiddlePrintData2(
		OuterBoxInfoId char(12),
		MiddleBoxInfoId char(12),
		MiddleBoxNumber nvarchar(50),     --箱编号
	)
	--内层详细信息 对应中层箱号
	create table  #InnerInMidPrintData  (
		MiddleBoxInfoId char(12),
		InnerBoxInfoId char(12),
		InnerBoxNumber nvarchar(50),     --箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		InnQTY float,                  --数量
		InnTotalNet float,             --净重
		InnGross float,                --毛重
		InnL float,                    --长
		InnW float,                    --宽
		InnH float                     --高
	)
	--内层箱号信息1：内层物料种数，内层直接装物料,计算装箱数量总和 及 物料种数
		create table #InnerBoxMaterial  (
		InnerBoxInfoId char(12),
		InnMaterialQTY float,                  --物料种数
		InnSumQTY float
	)
/**************end两层拼箱第二部分end********/
/*****************************************end两种拼箱end****************************/










--处理各个部分数据：
/**************************************************begin两种拼箱：两部分拼箱 各个部分组合begin********************************/
	/****第一部分：外箱、中箱组合（中箱直接装物料）*****/
	create table #CombDataOne  (
		A0BoxSN nvarchar(50),         --A0箱号
		A0BoxNumber nvarchar(50),     --A0箱编号
		A2BoxNumber nvarchar(50),     --A2箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		A0TotalNet float,             --净重
		A0Gross float,                --毛重
		A0L float,                    --长
		A0W float,                    --宽
		A0H float,                     --高
		A2MaterialQTY float,
		A2QTY float,                  --数量
		A2TotalNet float,             --净重
		A2Gross float,                --毛重
		A2L float,                    --长
		A2W float,                    --宽
		A2H float,                     --高
		A2BoxInfoId char(12),
		A2SumQTY float
	)
	--第一部分：得到第一部分的数据处理，为了合并A2箱号（中层箱号）
	create table #HandleDataOne  (
		GroupNumberA0 int,
		GroupNumberA2 int,
		A0BoxSN nvarchar(50),         --A0箱号
		A0BoxNumber nvarchar(50),     --A0箱编号
		A2BoxNumber nvarchar(50),     --A2箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		QTY float,                  --A2数量
		TotalNet float,             --A0净重
		Gross float,                --A0毛重
		L float,                    --A0长
		W float,                    --A0宽
		H float,                     --A0高
		A2BoxInfoId char(12)
	)
	--第一部分：处理中箱 装箱信息完全相同，为了处理合并(两个及以上)
	create table #HandleSameBoxInfoOne 
	(
		GroupNumberA0 int,
		GroupNumberA2 int,
		MaxBoxInfoId char(12) ,
		MinBoxInfoId char(12)
	)
	--第一部分：得到正式导出的唯一数据, 主要是处理合并后，得到唯一数据行（通过distinct处理就行）
	create table #FormalPrintDataOne  (
		GroupNumberA0 int,
		GroupNumberA2 int,
		A0BoxSN nvarchar(50),         --箱号
		A0BoxNumber nvarchar(50),     --A0箱编号
		A2BoxNumber nvarchar(50),     --A2箱编号
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
	--第一部分：组合外箱、中箱、内箱（为''） ,得到正式导出的唯一数据
	create table #FormalPrintOne  (
		A0BoxSN nvarchar(50),
		A0BoxNumber nvarchar(50),     --A0箱编号
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
		isSameModulName char(1),
		isSameVGCode char(1),
		isSameEnglishDesc char(1),
		isSameQTY  char(1),
		isSameFieldsA  char(1),
		isSameFieldsB char(1),
		A4InA2 char(1)
	)






	/****第二部分：中箱、内箱组合（内箱直接装物料）*****/
	create table #CombDataTwo  (
		MiddleBoxInfoId char(12),
		A2BoxSN nvarchar(50),         --A2箱号
		A2BoxNumber nvarchar(50),     --A2箱编号
		A4BoxNumber nvarchar(50),     --A4箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		A4MaterialQTY float,
		A4QTY float,                  --数量
		A4TotalNet float,             --净重
		A4Gross float,                --毛重
		A4L float,                    --长
		A4W float,                    --宽
		A4H float,                     --高
		A4BoxInfoId char(12),
		A4SumQTY float
	)
	--为了合并第二部分的A2箱,不管重复，计算A2箱的物料种数、净重、毛重、长、宽、高、QTY的的总数。即按A2箱分组，把A4箱的信息相加
	create table #CombMiddleDataTwo  (
		MiddleBoxInfoId char(12),   --A2箱
		A2BoxNumber nvarchar(50),     --A2箱编号
		A2SumMaterialQTY float,   --不管重复，计算A2箱中每种小箱子里的物料总数
		A2SumTotalNet float,             --总净重
		A2SumGross float,                --总毛重
		A2SumL float,                    --总长
		A2SumW float,                    --总宽
		A2SumH float,                     --总高
		A2SumQTY float
	)
	--第二部分：得到第二部分的数据处理，为了合并A2箱号
	create table #HandleMiddleDataTwo  (
		MiddleBoxInfoId char(12),
		A2BoxNumber nvarchar(50),     --A2箱编号
		GroupNumberA2 int,

	)
	--第二部分：处理A2箱合并，为了处理合并(两个及以上)
	create table #HandleSameMiddleBoxInfoTwo
	(
		GroupNumberA2 int,
		MaxA2BoxInfoId char(12) ,
		MinA2BoxInfoId char(12)
	)
	--第二部分：得到第二部分的数据处理，为了合并A4箱号（内层箱号）
	create table #HandleDataTwo  (
		MiddleBoxInfoId char(12),
		A2BoxSN nvarchar(50),         --箱号
		GroupNumberA2 int,
		GroupNumberA4 int,
		A2BoxNumber nvarchar(50),     --A2箱编号
		A4BoxNumber nvarchar(50),     --A4箱编号
		VGCode nvarchar(100),        --客户编号
		ModuleName nvarchar(100),	--组件号
		PartNO nvarchar(50),        --物料品号
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA nvarchar(500),
		FieldsB nvarchar(500),
		QTY float,                  --A4数量
		A4BoxInfoId char(12)
	)
	--第二部分：处理内箱 装箱信息完全相同，为了处理合并(两个及以上)
	create table #HandleSameBoxInfoTwo
	(
		GroupNumberA2 int,
		GroupNumberA4 int,
		MaxBoxInfoId char(12) ,
		MinBoxInfoId char(12)
	)

	--第二部分：组合外箱、中箱、内箱 ,得到正式导出的唯一数据
	create table #FormalPrintTwo  (
		A0BoxSN nvarchar(50),
		A0BoxNumber nvarchar(50),     --A0箱编号
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
		isSameModulName char(1),
		isSameVGCode char(1),
		isSameEnglishDesc char(1),
		isSameQTY  char(1),
		isSameFieldsA  char(1),
		isSameFieldsB char(1),
		A4InA2 char(1)
	)

/**************************************************end两种拼箱：两部分拼箱 各个部分组合end********************************/





--第一部分
	create table #GroupPrintDataOne(
		GroupNumberA0 int,
		GroupNumberA2 int,
		isSameModulName char(1),
		isSameVGCode char(1),
		isSameEnglishDesc char(1),
		isSameQTY  char(1),
		isSameFieldsA  char(1),
		isSameFieldsB char(1)
	)
--第二部分
	create table #GroupPrintDataTwo(
		MiddleBoxInfoId char(12),
		GroupNumberA2 int,
		GroupNumberA4 int,
		isSameModulName char(1),
		isSameVGCode char(1),
		isSameEnglishDesc char(1),
		isSameQTY  char(1),
		isSameFieldsA  char(1),
		isSameFieldsB char(1)
	)
--两部分合并


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
			 select distinct bb.KDBoxInfoId from
			(select distinct a.KDBoxInfoId ,b.BoxInfoId from #BoxTemp a
			inner join KDLoadBox b on a.KDBoxInfoId=b.ParentBoxInfoId where b.IsCancel=0
			) bb
			where bb.BoxInfoId  in (select ParentBoxInfoId from KDLoadBox where IsCancel=0 and KDOrderInfoId=@KDOrderInfoId)
	end

	 --不打印的箱号
	 begin
		 insert into #NotPrintBoxSN
			select distinct a.KDBoxInfoId
			 from #BoxTemp a
			where KDBoxInfoId not in (select ParentBoxInfoId from KDLoadBox where IsCancel=0 and KDOrderInfoId=@KDOrderInfoId)
		 union all
			select distinct a.KDBoxInfoId from #BoxTemp a
			inner join KDLoadBox b on a.KDBoxInfoId=b.ParentBoxInfoId
			where b.IsCancel=0 and a.KDBoxInfoId not in
				(
				select distinct bb.KDBoxInfoId from
				(select distinct a.KDBoxInfoId ,b.BoxInfoId from #BoxTemp a
				inner join KDLoadBox b on a.KDBoxInfoId=b.ParentBoxInfoId where b.IsCancel=0
				) bb
				where bb.BoxInfoId  in (select ParentBoxInfoId from KDLoadBox where IsCancel=0 and KDOrderInfoId=@KDOrderInfoId)
				) 
			and a.KDBoxInfoId not in
				(
				select ccc.BoxInfoId from 
					(
					select distinct bb.KDBoxInfoId from
						(select distinct a.KDBoxInfoId ,b.BoxInfoId from #BoxTemp a
						inner join KDLoadBox b on a.KDBoxInfoId=b.ParentBoxInfoId where b.IsCancel=0
						)bb
					where bb.BoxInfoId  in (select ParentBoxInfoId from KDLoadBox where IsCancel=0 and KDOrderInfoId=@KDOrderInfoId)
					)bbb
					inner join KDLoadBox ccc on bbb.KDBoxInfoId=ccc.ParentBoxInfoId where ccc.IsCancel=0
				)
	end
	
	


	--计算说明信息
	if  exists(select 1 from  #NotPrintBoxSN a)

	begin
		select @Explain=@Explain+b.BoxNumber+'、' from 
	    #NotPrintBoxSN a
	    inner join KDBoxInfo b on a.KDBoxInfoId=b.KDBoxInfoId where b.IsCancel=0

		set @Explain=left(rtrim(ltrim(@Explain)),len(rtrim(ltrim(@Explain)))-1)
		set @Explain=@Explain+'为最内箱 或 一层拼箱，请检查, 请用对应功能导出！'
	end 
	else
	begin
		set @Explain=@Explain+'…………………………'
	end


	--外层箱号信息，需打印
	insert into #OuterPrintData(OuterBoxInfoId,OuterBoxSN,OuterBoxNumber,OuterTotalNet,OuterGross,OuterL,OuterW,OuterH)
	select b.KDBoxInfoId as OuterBoxInfoId,
	b.BoxSN as OuterBoxSN,
	b.BoxNumber as OuterBoxNumber,
	Convert(float,b.NetWeight) as OuterTotalNet,
	Convert(float,b.GrossWeight) as OuterGross,
	Convert(float,b.BoxLength) as OuterL,
	Convert(float,b.BoxWidth) as OuterW, 
	Convert(float,b.BoxHeight) as OuterH
	from #PrintBoxSN a
	inner  join KDBoxInfo b on a.KDBoxInfoId=b.KDBoxInfoId
	where b.IsCancel=0 



--得到各个部分的数据
/*****************************************begin两种拼箱begin****************************/

/**************begin两层拼箱第一部分begin********/
	--中层箱号信息1，没有内层，直接装物料
	insert into #MiddlePrintData1(OuterBoxInfoId,MiddleBoxInfoId,MiddleBoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,MidQTY,MidTotalNet,MidGross,MidL,MidW,MidH)
	select distinct
	b.OuterBoxInfoId as OuterBoxInfoId,
	b.MiddleBoxInfoId as MiddleBoxInfoId,
	d.BoxNumber as MiddleBoxNumber,
	KDOrderItem.CustomerNumber as VGCode,
	c.ModuleName,
	[dbo].[RemoveZero](ProductRoot.ProductName) as PartNO,
	KDOrderItem.EnglishDescription as EnglishDesc,
	KDOrderItem.FieldsA,
	KDOrderItem.FieldsB,
	Convert(float,c.RealQty) as MidQTY,
	Convert(float,d.NetWeight) as MidTotalNet,
	Convert(float,d.GrossWeight) as MidGross,
	Convert(float,d.BoxLength) as MidL,
	Convert(float,d.BoxWidth) as MidW, 
	Convert(float,d.BoxHeight) as MidH
	from 
	(select ccc.OuterBoxInfoId,ddd.BoxInfoId as MiddleBoxInfoId from #OuterPrintData ccc
			inner join KDLoadBox ddd on ccc.OuterBoxInfoId=ddd.ParentBoxInfoId
			where ddd.IsCancel=0 and ddd.BoxInfoId not in (select ParentBoxInfoId from KDLoadBox where IsCancel=0 and KDOrderInfoId=@KDOrderInfoId)
	)b
	inner join KDBoxItem c on b.MiddleBoxInfoId=c.KDBoxInfoId
	inner join KDBoxInfo d on b.MiddleBoxInfoId=d.KDBoxInfoId
	inner join KDOrderItem on KDOrderItem.ProductId=c.ProductId and KDOrderItem.ModuleName=c.ModuleName and KDOrderItem.KDOrderInfoId=@KDOrderInfoId
	inner join Product on Product.ProductId=KDOrderItem.ProductId
	inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
	where c.IsCancel=0 and d.IsCancel=0 and KDOrderItem.IsIgnore=0 and KDOrderItem.IsValidity=1
	--中层箱号信息1：中层物料种数，没有内层，直接装物料,计算装箱数量总和
	insert into #MiddleBoxMaterial(MiddleBoxInfoId,MidMaterialQTY,MidSumQTY)
		select a.MiddleBoxInfoId,Convert(float,count(DISTINCT a.PartNO)) as MidMaterialQTY,sum(a.MidQTY) as MidSumQTY
		from #MiddlePrintData1 a
		group by a.MiddleBoxInfoId
/**************end两层拼箱第一部分end********/

	
/**************begin两层拼箱第二部分begin********/
	--中层箱号信息2，有内箱，内箱装物料
	insert into #MiddlePrintData2(OuterBoxInfoId,MiddleBoxInfoId,MiddleBoxNumber)
	select distinct ccc.OuterBoxInfoId,ddd.BoxInfoId as MiddleBoxInfoId,eee.BoxNumber as MiddleBoxNumber from #OuterPrintData ccc
			inner join KDLoadBox ddd on ccc.OuterBoxInfoId=ddd.ParentBoxInfoId
			inner join KDBoxInfo eee on ddd.BoxInfoId=eee.KDBoxInfoId
			where ddd.IsCancel=0 and eee.IsCancel=0 and ddd.BoxInfoId  in (select ParentBoxInfoId from KDLoadBox where IsCancel=0 and KDOrderInfoId=@KDOrderInfoId)
	--内层详细信息 对应中层箱号
	insert into #InnerInMidPrintData(MiddleBoxInfoId,InnerBoxInfoId,InnerBoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,InnQTY,InnTotalNet,InnGross,InnL,InnW,InnH)
	select distinct
	a.MiddleBoxInfoId as MiddleBoxInfoId,
	b.BoxInfoId as InnerBoxInfoId,
	d.BoxNumber as InnerBoxNumber,
	KDOrderItem.CustomerNumber as VGCode,
	c.ModuleName,
	[dbo].[RemoveZero](ProductRoot.ProductName) as PartNO,
	KDOrderItem.EnglishDescription as EnglishDesc,
	KDOrderItem.FieldsA,
	KDOrderItem.FieldsB,
	Convert(float,c.RealQty) as InnQTY,
	Convert(float,d.NetWeight) as InnTotalNet,
	Convert(float,d.GrossWeight) as InnGross,
	Convert(float,d.BoxLength) as InnL,
	Convert(float,d.BoxWidth) as InnW, 
	Convert(float,d.BoxHeight) as InnH
	from #MiddlePrintData2 a
	inner join KDLoadBox b on a.MiddleBoxInfoId=b.ParentBoxInfoId
	inner join KDBoxItem c on b.BoxInfoId=c.KDBoxInfoId
	inner join KDBoxInfo d on b.BoxInfoId=d.KDBoxInfoId
	inner join KDOrderItem on KDOrderItem.ProductId=c.ProductId and KDOrderItem.ModuleName=c.ModuleName and KDOrderItem.KDOrderInfoId=@KDOrderInfoId
	inner join Product on Product.ProductId=KDOrderItem.ProductId
	inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
	where b.IsCancel=0 and c.IsCancel=0 and d.IsCancel=0 and KDOrderItem.IsIgnore=0 and KDOrderItem.IsValidity=1
	--内层箱号信息1：内层物料种数，内层直接装物料,计算装箱数量总和 及 物料种数
	insert into #InnerBoxMaterial(InnerBoxInfoId,InnMaterialQTY,InnSumQTY)
	select a.InnerBoxInfoId,Convert(float,count(DISTINCT a.PartNO)) as InnMaterialQTY,sum(a.InnQTY) as InnSumQTY
	from #InnerInMidPrintData a
	group by a.InnerBoxInfoId
/**************end两层拼箱第二部分end********/

/*****************************************end两种拼箱end****************************/










--组合数据并处理：

/********************************************begin两种拼箱：两部分 拼箱各个部分组合begin********************************/
	/****第一部分：外箱、中箱组合（中箱直接装物料）*****/
	insert into #CombDataOne
	(A0BoxSN,A0BoxNumber,A2BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,
	A0TotalNet,A0Gross,A0L,A0W,A0H,A2MaterialQTY,A2QTY,A2TotalNet,A2Gross,A2L,A2W,A2H,A2BoxInfoId,A2SumQTY)
	select distinct 
	a.OuterBoxSN as A0BoxSN,
	a.OuterBoxNumber as A0BoxNumber,
	b.MiddleBoxNumber as A2BoxNumber, 
	b.VGCode,b.ModuleName,b.PartNO,b.EnglishDesc,b.FieldsA,b.FieldsB,
	a.OuterTotalNet as A0TotalNet,a.OuterGross as A0Gross,a.OuterL as A0L,a.OuterW as A0W,a.OuterH as A0H,
	c.MidMaterialQTY as A2MaterialQTY,b.MidQTY as A2QTY,
	b.MidTotalNet as A2TotalNet ,b.MidGross as A2Gross,b.MidL as A2L,b.MidW as A2W,b.MidH as A2H,
	b.MiddleBoxInfoId AS A2BoxInfoId,
	c.MidSumQTY as A2SumQTY
	FROM #OuterPrintData a
	inner join #MiddlePrintData1 b on a.OuterBoxInfoId=b.OuterBoxInfoId
	inner join #MiddleBoxMaterial c on b.MiddleBoxInfoId=c.MiddleBoxInfoId

	--第一部分：得到第一部分的数据处理，为了合并A2箱号（中层箱号）
	insert into #HandleDataOne
	(GroupNumberA0,GroupNumberA2,A0BoxSN,A0BoxNumber,A2BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,
	TotalNet,Gross,L,W,H,A2BoxInfoId)
	select distinct  dense_rank() over (ORDER BY a.A0BoxSN) as GroupNumberA0, 
	dense_rank() over (ORDER BY a.A0BoxSN,a.A2SumQTY,a.A2MaterialQTY,a.A2TotalNet,a.A2Gross,a.A2L,a.A2W,a.A2H) as GroupNumberA2,
	a.A0BoxSN,a.A0BoxNumber,a.A2BoxNumber,a.VGCode,a.ModuleName,a.PartNO,a.EnglishDesc,a.FieldsA,a.FieldsB,
	a.A2QTY as QTY,
	a.A0TotalNet as TotalNet,a.A0Gross as Gross,a.A0L as L,a.A0W as W,a.A0H as H,a.A2BoxInfoId
	from #CombDataOne a
	--第一部分：处理中箱 装箱信息完全相同，为了处理合并(两个及以上)
	insert into #HandleSameBoxInfoOne
	 select a.GroupNumberA0,a.GroupNumberA2,max(a.A2BoxInfoId) as MaxBoxInfoId,min(a.A2BoxInfoId)as MaxBoxInfoId
	 from #HandleDataOne a
	 group by a.GroupNumberA0,a.GroupNumberA2
	 having max(a.A2BoxInfoId)<>min(A2BoxInfoId)

	 --更新#HandleDataOne表
	update #HandleDataOne  set A2BoxNumber=lll.minA2BoxNumber+'-'+substring(lll.maxA2BoxNumber,3,len(lll.maxA2BoxNumber)-2)
	from #HandleDataOne aaa
	inner join 
		( 
		select xx.A2BoxNumber as minA2BoxNumber,yy.A2BoxNumber as maxA2BoxNumber,xx.GroupNumberA0,xx.GroupNumberA2 from  
		(select a.A2BoxNumber,b.GroupNumberA0,b.GroupNumberA2 from #HandleDataOne a 
		inner join #HandleSameBoxInfoOne b on a.GroupNumberA0=b.GroupNumberA0 and a.GroupNumberA2=b.GroupNumberA2 and a.A2BoxInfoId=b.MinBoxInfoId) xx
		inner join
		(select a.A2BoxNumber,b.GroupNumberA0,b.GroupNumberA2 from #HandleDataOne a 
		inner join #HandleSameBoxInfoOne b on a.GroupNumberA0=b.GroupNumberA0 and a.GroupNumberA2=b.GroupNumberA2 and a.A2BoxInfoId=b.MaxBoxInfoId) yy
		on xx.GroupNumberA0=yy.GroupNumberA0 and xx.GroupNumberA2=yy.GroupNumberA2
		) lll 
	on aaa.GroupNumberA0=lll.GroupNumberA0 and aaa.GroupNumberA2=lll.GroupNumberA2

	--第一部分：得到正式导出的唯一数据, 主要是处理合并后，得到唯一数据行（通过distinct处理就行）
	----得到正式导出的唯一数据
	insert into #FormalPrintDataOne
	(GroupNumberA0,GroupNumberA2,A0BoxSN,A0BoxNumber,A2BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet
	,Gross,L,W,H)
	select distinct a.GroupNumberA0,a.GroupNumberA2,a.A0BoxSN,a.A0BoxNumber,a.A2BoxNumber,
	a.VGCode,a.ModuleName,a.PartNO,a.EnglishDesc,a.FieldsA,a.FieldsB,a.QTY,a.TotalNet,a.Gross,a.L,a.W,a.H
	from #HandleDataOne a 
	--第一部分
	insert into #GroupPrintDataOne(GroupNumberA0,GroupNumberA2,isSameModulName,isSameVGCode,isSameEnglishDesc,isSameQTY,isSameFieldsA,isSameFieldsB)
	 select  
	 a.GroupNumberA0, 
	 a.GroupNumberA2,
	 case count(distinct a.ModuleName) when 1 then '1' else '0' end as isSameModulName,
	 case count(distinct a.VGCode) when 1 then '1' else '0' end as isSameVGCode,
	 case count(distinct a.EnglishDesc) when 1 then '1' else '0' end as isSameEnglishDesc,
	 case count(distinct a.QTY) when 1 then '1' else '0' end as isSameQTY,
	 case count(distinct a.FieldsA) when 1 then '1' else '0' end as isSameFieldsA,
	 case count(distinct a.FieldsB) when 1 then '1' else '0' end as isSameFieldsB  
	 FROM #FormalPrintDataOne a
	 group by a.GroupNumberA0,a.GroupNumberA2
	 --第一部分：组合外箱、中箱、内箱（为''） ,得到正式导出的唯一数据
	insert into #FormalPrintOne(
	A0BoxSN,A0BoxNumber,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet,
	Gross,L,W,H,isSameModulName,isSameVGCode,isSameEnglishDesc,isSameQTY,isSameFieldsA,isSameFieldsB,A4InA2
	)
	select distinct a.A0BoxSN,a.A0BoxNumber,a.A2BoxNumber,'' as A4BoxNumber,
	a.VGCode,a.ModuleName,a.PartNO,a.EnglishDesc,a.FieldsA,a.FieldsB,a.QTY,a.TotalNet,a.Gross,a.L,a.W,a.H,
	b.isSameModulName,
	b.isSameVGCode,
	b.isSameEnglishDesc,
	b.isSameQTY,
	b.isSameFieldsA,
	b.isSameFieldsB,
	'0' as A4InA2
	 from #FormalPrintDataOne a inner join #GroupPrintDataOne b on a.GroupNumberA0=b.GroupNumberA0 and a.GroupNumberA2=b.GroupNumberA2








	/****第二部分：中箱、内箱组合（内箱直接装物料）*****/
		insert into #CombDataTwo
		(MiddleBoxInfoId,A2BoxSN,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,
		A4MaterialQTY,A4QTY,A4TotalNet,A4Gross,A4L,A4W,A4H,A4BoxInfoId,A4SumQTY
		)
		select distinct 
		a.MiddleBoxInfoId as MiddleBoxInfoId,
		a.MiddleBoxNumber as A2BoxSN,
		a.MiddleBoxNumber as A2BoxNumber,
		b.InnerBoxNumber as  A4BoxNumber,
		b.VGCode,b.ModuleName,b.PartNO,b.EnglishDesc,b.FieldsA,b.FieldsB,
		c.InnMaterialQTY as A4MaterialQTY,b.InnQTY as A4QTY,
		b.InnTotalNet as A4TotalNet ,b.InnGross as A4Gross,b.InnL as A4L,b.InnW as A4W,b.InnH as A4H,
		b.InnerBoxInfoId AS A4BoxInfoId,
		c.InnSumQTY as A4SumQTY
		FROM #MiddlePrintData2 a
		inner join #InnerInMidPrintData b on a.MiddleBoxInfoId=b.MiddleBoxInfoId
		inner join #InnerBoxMaterial c on b.InnerBoxInfoId=c.InnerBoxInfoId

	--第二部分：为了合并第二部分的A2箱。不管重复，计算A2箱的物料种数、净重、毛重、长、宽、高、QTY的的总数。即按A2箱分组，把A4箱的信息相加
	insert into #CombMiddleDataTwo(MiddleBoxInfoId,A2BoxNumber,A2SumMaterialQTY,A2SumTotalNet,A2SumGross,
	A2SumL,A2SumW,A2SumH,A2SumQTY)
	select a.MiddleBoxInfoId,a.A2BoxNumber,sum(a.A4MaterialQTY) as  A2SumMaterialQTY,
	sum(a.A4TotalNet) as A2SumTotalNet,sum(a.A4Gross) as A2SumGross,
	sum(a.A4L) as A2SumL,sum(a.A4W) as A2SumW,sum(a.A4H) as A2SumH,sum(a.A4SumQTY) as A2SumQTY
	from 
	(select distinct b.MiddleBoxInfoId,b.A2BoxNumber,b.A4BoxInfoId,b.A4MaterialQTY,b.A4TotalNet,b.A4Gross
	,b.A4L,b.A4W,b.A4H,b.A4SumQTY  from 
	#CombDataTwo b) a
	group by a.MiddleBoxInfoId,a.A2BoxNumber

	--第二部分：得到第二部分的数据处理，为了合并A2箱号
	insert into #HandleMiddleDataTwo(MiddleBoxInfoId,A2BoxNumber,GroupNumberA2)
	select a.MiddleBoxInfoId,A2BoxNumber,dense_rank() over (ORDER BY c.OuterBoxInfoId,a.A2SumMaterialQTY,a.A2SumTotalNet,a.A2SumGross
	,a.A2SumL,a.A2SumW,a.A2SumH,a.A2SumQTY) as GroupNumberA2 
	from #CombMiddleDataTwo a 
	inner join #MiddlePrintData2 b on b.MiddleBoxInfoId=a.MiddleBoxInfoId
	inner join #OuterPrintData c on b.OuterBoxInfoId=c.OuterBoxInfoId

	--第二部分：处理A2箱合并，为了处理合并(两个及以上)
	insert into #HandleSameMiddleBoxInfoTwo(GroupNumberA2,MaxA2BoxInfoId,MinA2BoxInfoId)
	 select a.GroupNumberA2,max(a.MiddleBoxInfoId) as  MaxA2BoxInfoId,min(a.MiddleBoxInfoId)as MinA2BoxInfoId
	 from #HandleMiddleDataTwo a
	 group by a.GroupNumberA2
	 having max(a.MiddleBoxInfoId)<>min(MiddleBoxInfoId)
	 --更新##CombDataTwo表
	update #HandleMiddleDataTwo  set A2BoxNumber=lll.minA2BoxNumber+'-'+substring(lll.maxA2BoxNumber,3,len(lll.maxA2BoxNumber)-2)
	from #HandleMiddleDataTwo aaa
	inner join 
		( 
		select xx.A2BoxNumber as minA2BoxNumber,yy.A2BoxNumber as maxA2BoxNumber,xx.GroupNumberA2 from  
		(select a.A2BoxNumber,b.GroupNumberA2 from #HandleMiddleDataTwo a 
		inner join #HandleSameMiddleBoxInfoTwo b on a.GroupNumberA2=b.GroupNumberA2 and a.MiddleBoxInfoId=b.MinA2BoxInfoId) xx
		inner join
		(select a.A2BoxNumber,b.GroupNumberA2 from #HandleMiddleDataTwo a 
		inner join #HandleSameMiddleBoxInfoTwo b on a.GroupNumberA2=b.GroupNumberA2  and a.MiddleBoxInfoId=b.MaxA2BoxInfoId) yy
		on xx.GroupNumberA2=yy.GroupNumberA2
		) lll 
	on aaa.GroupNumberA2=lll.GroupNumberA2

	--第二部分：得到第二部分的数据处理，为了合并A4箱号（内层箱号）
	insert into #HandleDataTwo
		(MiddleBoxInfoId,A2BoxSN,GroupNumberA2,GroupNumberA4,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,
		QTY,A4BoxInfoId)
		select distinct
		aa.MiddleBoxInfoId,aa.A2BoxSN,
		dense_rank() over (ORDER BY 
				cast(case CHARINDEX('-',aa.A2BoxNumber) when 0 then 
				SUBSTRING(aa.A2BoxNumber,3,LEN(aa.A2BoxNumber)-2)
				else  SUBSTRING(aa.A2BoxNumber,3,CHARINDEX('-',aa.A2BoxNumber)-3) end as int)) as GroupNumberA2, 
		dense_rank() over (ORDER BY 
				cast(case CHARINDEX('-',aa.A2BoxNumber) when 0 then 
				SUBSTRING(aa.A2BoxNumber,3,LEN(aa.A2BoxNumber)-2)
				else  SUBSTRING(aa.A2BoxNumber,3,CHARINDEX('-',aa.A2BoxNumber)-3) end as int)
		,aa.A4SumQTY,aa.A4MaterialQTY,aa.A4TotalNet,aa.A4Gross,aa.A4L,aa.A4W,aa.A4H) as GroupNumberA4,
		aa.A2BoxNumber,aa.A4BoxNumber,aa.VGCode,aa.ModuleName,aa.PartNO,aa.EnglishDesc,aa.FieldsA,aa.FieldsB,
		aa.A4QTY as QTY,aa.A4BoxInfoId
		from 
		(select distinct a.MiddleBoxInfoId,a.A2BoxSN,b.A2BoxNumber,a.A4SumQTY,a.A4MaterialQTY,a.A4TotalNet,a.A4Gross,a.A4L,a.A4W,a.A4H
		,a.A4BoxNumber,a.VGCode,a.ModuleName,a.PartNO,a.EnglishDesc,a.FieldsA,a.FieldsB,a.A4QTY,a.A4BoxInfoId
		 from #CombDataTwo a
		inner join #HandleMiddleDataTwo b on a.MiddleBoxInfoId=b.MiddleBoxInfoId) aa
	--第二部分：处理内箱 装箱信息完全相同，为了处理合并(两个及以上)
	insert into #HandleSameBoxInfoTwo
	 select a.GroupNumberA2,a.GroupNumberA4,max(a.A4BoxInfoId) as MaxBoxInfoId,min(a.A4BoxInfoId)as MaxBoxInfoId
	 from #HandleDataTwo a
	 group by a.GroupNumberA2,a.GroupNumberA4
	 having max(a.A4BoxInfoId)<>min(A4BoxInfoId)
	 --更新#HandleDataTwo表
	update #HandleDataTwo  set A4BoxNumber=lll.minA4BoxNumber+'-'+substring(lll.maxA4BoxNumber,3,len(lll.maxA4BoxNumber)-2)
	from #HandleDataTwo aaa
	inner join 
		( 
		select xx.A4BoxNumber as minA4BoxNumber,yy.A4BoxNumber as maxA4BoxNumber,xx.GroupNumberA2,xx.GroupNumberA4 from  
		(select a.A4BoxNumber,b.GroupNumberA2,b.GroupNumberA4 from #HandleDataTwo a 
		inner join #HandleSameBoxInfoTwo b on a.GroupNumberA2=b.GroupNumberA2 and a.GroupNumberA4=b.GroupNumberA4 and a.A4BoxInfoId=b.MinBoxInfoId) xx
		inner join
		(select a.A4BoxNumber,b.GroupNumberA2,b.GroupNumberA4 from #HandleDataTwo a 
		inner join #HandleSameBoxInfoTwo b on a.GroupNumberA2=b.GroupNumberA2 and a.GroupNumberA4=b.GroupNumberA4 and a.A4BoxInfoId=b.MaxBoxInfoId) yy
		on xx.GroupNumberA2=yy.GroupNumberA2 and xx.GroupNumberA4=yy.GroupNumberA4
		) lll 
	on aaa.GroupNumberA2=lll.GroupNumberA2 and aaa.GroupNumberA4=lll.GroupNumberA4
	--第二部分
	insert into #GroupPrintDataTwo(MiddleBoxInfoId,GroupNumberA2,GroupNumberA4,isSameModulName,isSameVGCode,isSameEnglishDesc,isSameQTY,isSameFieldsA,isSameFieldsB)
		 select
		 a.MiddleBoxInfoId,  
		 a.GroupNumberA2, 
		 a.GroupNumberA4,
		 case count(distinct a.ModuleName) when 1 then '1' else '0' end as isSameModulName,
		 case count(distinct a.VGCode) when 1 then '1' else '0' end as isSameVGCode,
		 case count(distinct a.EnglishDesc) when 1 then '1' else '0' end as isSameEnglishDesc,
		 case count(distinct a.QTY) when 1 then '1' else '0' end as isSameQTY,
		 case count(distinct a.FieldsA) when 1 then '1' else '0' end as isSameFieldsA,
		 case count(distinct a.FieldsB) when 1 then '1' else '0' end as isSameFieldsB  
		 FROM #HandleDataTwo a
		 group by a.MiddleBoxInfoId,a.GroupNumberA2,a.GroupNumberA4
	--第二部分：组合外箱、中箱、内箱 ,得到正式导出的唯一数据
	insert into #FormalPrintTwo(
	A0BoxSN,A0BoxNumber,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet,
	Gross,L,W,H,isSameModulName,isSameVGCode,isSameEnglishDesc,isSameQTY,isSameFieldsA,isSameFieldsB,A4InA2
	)
	select distinct d.BoxSN as A0BoxSN,d.BoxNumber as A0BoxNumber,
	a.A2BoxNumber,a.A4BoxNumber,a.VGCode,a.ModuleName,a.PartNO,a.EnglishDesc,a.FieldsA,a.FieldsB,a.QTY,
	Convert(float,d.NetWeight) as TotalNet,
	Convert(float,d.GrossWeight) as Gross,
	Convert(float,d.BoxLength) as L,
	Convert(float,d.BoxWidth) as W, 
	Convert(float,d.BoxHeight) as H,
	b.isSameModulName,
	b.isSameVGCode,
	b.isSameEnglishDesc,
	b.isSameQTY,
	b.isSameFieldsA,
	b.isSameFieldsB,
	'1' as A4InA2
	from  #HandleDataTwo a
	inner join #GroupPrintDataTwo b on  a.GroupNumberA4=b.GroupNumberA4 and a.GroupNumberA2=b.GroupNumberA2 and a.MiddleBoxInfoId=b.MiddleBoxInfoId
	inner join #MiddlePrintData2 c on a.MiddleBoxInfoId=c.MiddleBoxInfoId
	inner join KDBoxInfo d on c.OuterBoxInfoId=d.KDBoxInfoId
	where  d.IsCancel=0



/********************************************end两种拼箱：两部分拼箱各个部分组合end********************************/	



	if not exists(select 1 from 
	(select * from #FormalPrintTwo
	union all
	select * from #FormalPrintOne)a)
	begin
		set @I_ReturnMessage='ServerMessage:您所输入的起止箱号全部为最内箱 或 一层拼箱，没有任何两层拼箱数据可打印，请检查!'
		return -1
	end

	






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
		--select @Client as Client,Substring(@OrderName,3,LEN(@OrderName)-2) as OrderNumber,@Model as Model,@OrderQty as OrderQty,
		--	@Brand as Brand,@ProductionDate as ProductionDate,@Country as Country,@CustomerPO as CustomerPO,
		--	@Description as Description,@SupplierCode as SupplierCode,@ProjectNo as ProjectNo,@PoNo as PoNo,
		--	@LotNo as LotNo,@RollingPlan  as RollingPlan ,@MadeCountry as MadeCountry,@Explain as Explain,
		--	@ParameterA as ParameterA,@ParameterB as ParameterB,@ParameterC as ParameterC,
		--	a.GroupNumberA0,
		--	 row_number() over (order by cast(case CHARINDEX('-',a.A2BoxNumber) when 0 then 
		--	SUBSTRING(a.A2BoxNumber,3,LEN(a.A2BoxNumber)-2)
		--	 else  SUBSTRING(a.A2BoxNumber,3,CHARINDEX('-',a.A2BoxNumber)-3) end as int)) as GroupNumberA2,
		--	b.isSameEnglishDesc,b.isSameModulName,b.isSameQTY,b.isSameVGCode,b.isSameFieldsA,b.isSameFieldsB,
		--	a.A0BoxSN,a.A0BoxNumber,a.A2BoxNumber,ModuleName,VGCode,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet,Gross,L,W,H 
		--	,cast('0' as char(1)) as A4InA2,'' as A4BoxNumber
		--from #FormalPrintDataOne a left join #GroupPrintDataOne b on a.GroupNumberA0=b.GroupNumberA0 and a.GroupNumberA2=b.GroupNumberA2

/**************************合并打印*************************/
		select @Client as Client,Substring(@OrderName,3,LEN(@OrderName)-2) as OrderNumber,@Model as Model,@OrderQty as OrderQty,
			@Brand as Brand,@ProductionDate as ProductionDate,@Country as Country,@CustomerPO as CustomerPO,
			@Description as Description,@SupplierCode as SupplierCode,@ProjectNo as ProjectNo,@PoNo as PoNo,
			@LotNo as LotNo,@RollingPlan  as RollingPlan ,@MadeCountry as MadeCountry,@Explain as Explain,
			@ParameterA as ParameterA,@ParameterB as ParameterB,@ParameterC as ParameterC,
			DENSE_RANK() over(order by A0BoxSN) as GroupNumberA0,

			 row_number() over (order by cast(case CHARINDEX('-',aa.A2BoxNumber) when 0 then 
			SUBSTRING(aa.A2BoxNumber,3,LEN(aa.A2BoxNumber)-2)
			 else  SUBSTRING(aa.A2BoxNumber,3,CHARINDEX('-',aa.A2BoxNumber)-3) end as int)) as GroupNumberA2,
			  -- 1 as GroupNumberA2,
			row_number() over (order by 
				cast(case CHARINDEX('-',aa.A2BoxNumber) when 0 then 
				SUBSTRING(aa.A2BoxNumber,3,LEN(aa.A2BoxNumber)-2)
				 else  SUBSTRING(aa.A2BoxNumber,3,CHARINDEX('-',aa.A2BoxNumber)-3) end as int)
			 ,
				cast(case aa.A4BoxNumber when '' then '0' else
				(case CHARINDEX('-',aa.A4BoxNumber) when 0 then 
				SUBSTRING(aa.A4BoxNumber,3,LEN(aa.A4BoxNumber)-2)
				else  SUBSTRING(aa.A4BoxNumber,3,CHARINDEX('-',aa.A4BoxNumber)-3) end ) end as int) 
			) as GroupNumberA4,
			 --1  as GroupNumberA4,
			A0BoxSN,A0BoxNumber,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet,Gross,L,W,H ,
			isSameModulName,isSameVGCode,isSameEnglishDesc,isSameQTY,isSameFieldsA,isSameFieldsB,A4InA2
		from 
		(select
			A0BoxSN,A0BoxNumber,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet,
			Gross,L,W,H,isSameModulName,isSameVGCode,isSameEnglishDesc,isSameQTY,isSameFieldsA,isSameFieldsB,A4InA2
			from #FormalPrintOne
		union all
		select
			A0BoxSN,A0BoxNumber,A2BoxNumber,A4BoxNumber,VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,QTY,TotalNet,
			Gross,L,W,H,isSameModulName,isSameVGCode,isSameEnglishDesc,isSameQTY,isSameFieldsA,isSameFieldsB,A4InA2
			from #FormalPrintTwo
		) aa


--删除临时表
	drop table #BoxTemp
	drop table #NotPrintBoxSN
	drop table #PrintBoxSN
	drop table #OuterPrintData

	drop table #MiddlePrintData1
	drop table #MiddleBoxMaterial

	drop table #MiddlePrintData2
	drop table #InnerInMidPrintData
	drop table #InnerBoxMaterial

	drop table #CombDataOne
	drop table #HandleDataOne
	drop table #HandleSameBoxInfoOne
	drop table #FormalPrintDataOne
	drop table #FormalPrintOne
	 
	drop table #CombMiddleDataTwo
	drop table #HandleMiddleDataTwo
	drop table #HandleSameMiddleBoxInfoTwo
	drop table #CombDataTwo
	drop table #HandleDataTwo
    drop table #HandleSameBoxInfoTwo
	drop table #FormalPrintTwo


	drop table  #GroupPrintDataOne
	drop table  #GroupPrintDataTwo

	set @I_ReturnMessage='ServerMessage:箱号打印成功!从'+@StartBoxSN+'到'+@EndBoxSN
	return 0
END