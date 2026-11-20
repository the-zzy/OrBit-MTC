
-- =============================================
-- Author:		<OrBit benson>
-- Create Date: <2016.07.18>
-- Description:	散件打印外箱箱号
-- =============================================
CREATE PROCEDURE  [dbo].[KDPrintBoxSNDoMethod]
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
@IsInvertedOrderPrint char(1)='1'

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	declare @return_value int
	set @return_value=-1

	/*------检查元对象方法用户授权
	exec @return_value=[dbo].[MetadataPermissionCheckDoMethod]
		@I_ReturnMessage=@I_ReturnMessage output,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_Sender=@I_Sender

	if @return_value=-1
	begin
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end*/

	declare @sql nvarchar(max)
	declare @i int
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
	declare @A4KDBoxInfoId char(12)
	declare @A2KDBoxInfoId char(12)
	declare @PartNO nvarchar(50)
	declare @VGCode nvarchar(50)
	declare @Description nvarchar(500)
	declare @EnglishDesc nvarchar(500)
	declare @QTY nvarchar(50)
	declare @TotalNet nvarchar(50)
	declare @Gross nvarchar(50)
	declare @L nvarchar(50)
	declare @W nvarchar(50)
	declare @H nvarchar(50)
	declare @StartKDBoxInfoId char(12)
	declare @EndKDBoxInfoId char(12)
	declare @ProductionDate nvarchar(20)
	declare @Country nvarchar(50)
	declare @PanelPO nvarchar(50)
	declare @SKDPO nvarchar(50)
	declare @CustomerPO nvarchar(50)
	declare @SupplierCode nvarchar(100)=''
	declare @ProjectNo nvarchar(100)=''
	declare @PoNo nvarchar(50)=''
	declare @LotNo nvarchar(50)=''
	declare @MadeCountry nvarchar(50)=''
	declare @RollingPlan nvarchar(100)=''
	declare @ModuleName nvarchar(50)=''
	declare @FieldsA  nvarchar(500)=''			  --附件字段A
	declare @FieldsB  nvarchar(500)=''			  --附件字段B
	declare @SingleWeight nvarchar(50)=''          --单机重量

	set @sql=''
	set @i=0
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
	set @A4KDBoxInfoId=''
	set @A2KDBoxInfoId=''
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

	--记录当前PKID
    declare @BoxTemp table(
		KDBoxInfoId char(12),
		BoxLevel varchar(20),
		BoxType varchar(20),
		PCount int
	)

	declare @PrintData table (
		BoxSN nvarchar(50),         --箱号
		BoxNumber nvarchar(50),     --箱编号
		VGCode nvarchar(50),        --客户编号
		ModuleName nvarchar(50),	--组件号
		PartNO nvarchar(50),        --物料品号
		Description nvarchar(500),  --物料描述
		EnglishDesc nvarchar(500),  --英文描述
		FieldsA  nvarchar(500),		--附件字段A
		FieldsB  nvarchar(500),		--附件字段B
		SingleWeight float,			 --单机重量
		QTY float,                  --数量
		TotalNet float,             --净重
		Gross float,            --毛重
		L float,                    --长
		W float,                    --宽
		H float                     --高
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

	--获取外箱信息
	select top 1 
		@KDBoxInfoId=KDBoxInfoId,
		@KDOrderInfoId=KDOrderInfoId,
		@BoxType=BoxType,
		@BoxLevel=BoxLevel
	from KDBoxInfo 
	where KDBoxInfoId=@I_ParentPKId

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

	--外箱层级是否一致
	if (select  BoxLevel from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxSN in (@StartBoxSN) and IsCancel=0)!=
		(select  BoxLevel from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxSN in (@EndBoxSN) and IsCancel=0)
	begin
		set @I_ReturnMessage='ServerMessage:不允许同时打印非同一层级的外箱标签，打印失败!'
		return -1
	end

	--外箱类别是否一致
	if (select  BoxType from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxSN in (@StartBoxSN) and IsCancel=0)!=
		(select  BoxType from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxSN in (@EndBoxSN) and IsCancel=0)
	begin
		set @I_ReturnMessage='ServerMessage:不允许同时打印非同一类别的外箱标签，打印失败!'
		return -1
	end

	select @StartKDBoxInfoId=KDBoxInfoId from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxNumber=@StartBoxSN and IsCancel=0
	select @EndKDBoxInfoId=KDBoxInfoId from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxNumber=@EndBoxSN and IsCancel=0

	if ISNULL(@StartKDBoxInfoId,'')>ISNULL(@EndKDBoxInfoId,'')
	begin
		set @I_ReturnMessage='ServerMessage:起始箱 ['+@StartBoxSN+'] 不允许大于截止箱 ['+@EndBoxSN+']，请检查!'
		return -1
	end

	--把信息写入表变量
	insert into @BoxTemp (KDBoxInfoId,BoxLevel,BoxType,PCount) 
	select KDBoxInfo.KDBoxInfoId,KDBoxInfo.BoxLevel,KDBoxInfo.BoxType,COUNT(KDBoxItem.ProductId) as PCount
	from KDBoxInfo 
	left join KDBoxItem on KDBoxItem.KDBoxInfoId=KDBoxInfo.KDBoxInfoId
	where KDBoxInfo.KDOrderInfoId=@KDOrderInfoId and KDBoxInfo.KDBoxInfoId>=@StartKDBoxInfoId and KDBoxInfo.KDBoxInfoId<=@EndKDBoxInfoId
	and BoxLevel=@BoxLevel and BoxType=@BoxType  and KDBoxInfo.IsCancel=0
	group by KDBoxInfo.KDBoxInfoId,KDBoxInfo.BoxLevel,KDBoxInfo.BoxType
	order by KDBoxInfo.KDBoxInfoId

	if not exists(select 1 from @BoxTemp)
	begin
		set @I_ReturnMessage='ServerMessage:获取到的外箱数为零，打印失败!'
		return -1
	end 

	--外箱层级是否一致
	if(select Count(distinct BoxLevel) from @BoxTemp)>1
	begin
		set @I_ReturnMessage='ServerMessage:不允许同时打印非同一层级的外箱标签，打印失败!'
		return -1
	end

	--外箱类别是否一致
	if(select Count(distinct BoxType) from @BoxTemp)>1
	begin
		set @I_ReturnMessage='ServerMessage:不允许同时打印非同一类别的外箱标签，打印失败!'
		return -1
	end

	--外箱物料种数是否一致
	if(select count(distinct PCount) from @BoxTemp)>1
	begin
		set @I_ReturnMessage='ServerMessage:外箱中，存在装载的物料种数不一致的情况，打印失败!'
		return -1
	end

	--更新打印次数
	update KDBoxInfo set 
		IsPrint=1,
		PrintCount=PrintCount+1 
	where KDBoxInfoId in (select KDBoxInfoId from @BoxTemp)

	--遍历所有箱号
	declare cursor1 cursor for 
	select distinct KDBoxInfoId from @BoxTemp
	open cursor1
	fetch next from cursor1 
	into @KDBoxInfoId
	while @@fetch_status=0     
	begin	
		set @BoxType=''
		set @BoxLevel=''
		set @BoxSN=''
		set @BoxLevel=''

		select  
			@BoxType=BoxType,
			@BoxLevel=BoxLevel,
			@BoxSN=BoxSN,
			@BoxNumber=BoxNumber
		from KDBoxInfo 
		where KDBoxInfoId=@KDBoxInfoId

		insert into @PrintData(BoxSN,BoxNumber,VGCode,ModuleName,PartNO,Description,EnglishDesc,FieldsA,FieldsB,SingleWeight,QTY,TotalNet,Gross,L,W,H)
		select 
			isnull(KDBoxInfo.BoxSN,'') as BoxSN,
			isnull(KDBoxInfo.BoxNumber,'') as BoxNumber,			
			isnull(KDOrderItem.CustomerNumber,'') as VGCode,
			isnull(KDBoxItem.ModuleName,'') as ModuleName,
			isnull([dbo].[RemoveZero](ProductRoot.ProductName),'') as PartNO,
			isnull(Product.ProductDescription,'') as Description,
			isnull(KDOrderItem.EnglishDescription,'') as EnglishDesc,
			isnull(KDOrderItem.FieldsA,'') as FieldsA,
			isnull(KDOrderItem.FieldsB,'') as FieldsB,
			Convert(float,KDOrderItem.SingleWeight) as SingleWeight,
			Convert(float,KDBoxItem.RealQty) as QTY,
			Convert(float,KDBoxInfo.NetWeight) as TotalNet,
			Convert(float,KDBoxInfo.GrossWeight) as Gross,
			Convert(float,KDBoxInfo.BoxLength) as L,
			Convert(float,KDBoxInfo.BoxWidth) as W, 
			Convert(float,KDBoxInfo.BoxHeight) as H
		from KDBoxInfo
		inner join KDBoxItem on KDBoxItem.KDBoxInfoId=KDBoxInfo.KDBoxInfoId
		inner join KDOrderItem on KDOrderItem.ProductId=KDBoxItem.ProductId and KDOrderItem.KDOrderInfoId=@KDOrderInfoId and KDBoxItem.ModuleName=KDOrderItem.ModuleName
		inner join Product on Product.ProductId=KDOrderItem.ProductId
		inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
		where KDBoxInfo.KDBoxInfoId=@KDBoxInfoId and KDBoxInfo.KDBoxInfoId>=@StartKDBoxInfoId and KDBoxInfo.KDBoxInfoId<=@EndKDBoxInfoId and KDBoxInfo.IsCancel=0 
		order by KDBoxInfo.BoxSN

		fetch next from cursor1 
		into @KDBoxInfoId
	end 
	close cursor1
	deallocate cursor1 

	if not exists(select 1 from @PrintData)
	begin
		set @I_ReturnMessage='ServerMessage:没有任何数据可打印，请检查!'
		return -1
	end

	if ISNULL(@BoxType,'')='A'
		set @CustomerPO=@PanelPO
	else 
		set @CustomerPO=@SKDPO

	--如果为 MRZ 报表，则执行此打印
	--if SUBSTRING(@BoxLabelName,CHARINDEX('.',@BoxLabelName)+1,LEN(@BoxLabelName))='mrz'
	--begin
	--	--打印数据
	--	select @Client as Client,Substring(@OrderName,3,10) as OrderNumber,@Model as Model,@OrderQty as OrderQty,
	--		@Brand as Brand,@ProductionDate as ProductionDate,@Country as Country,@CustomerPO
	--		BoxSN,BoxNumber,VGCode,PartNO,Description,EnglishDesc,QTY,TotalNet,Gross,L,W,H 
	--	from @PrintData

	--	set @I_ReturnMessage='ServerMessage:箱号打印成功!'
	--	return 0
	--end

	if @IsInvertedOrderPrint='0'
	begin
		DECLARE cursor1 CURSOR FOR  
		select distinct BoxNumber,BoxSN from @PrintData
		order by BoxSN
	end
	else
	begin
		DECLARE cursor1 CURSOR FOR  
		select distinct BoxNumber,BoxSN from @PrintData
		order by BoxSN desc
	end

	--游标写入数据
	OPEN cursor1
	fetch next from cursor1 
	into @BoxNumber,@BoxSN
	while @@FETCH_STATUS = 0 
	begin		
		set @i=0
	
		if ISNULL(@sql,'')<>''
			set @sql=@sql+' UNION ALL '

		set @sql=@sql+' SELECT '
		set @sql=@sql+''''+CAST(Substring(@OrderName,3,len(@OrderName)) as varchar)+''' AS OrderNumber,'
		set @sql=@sql+''''+CAST(@Client as varchar)+''' AS Client,'
		set @sql=@sql+''''+CAST(@Description as  nvarchar(500))+''' AS Description,'
		set @sql=@sql+''''+CAST(@Model as varchar)+''' AS Model,'
		set @sql=@sql+''''+CAST(@OrderQty as varchar)+''' AS OrderQty,'
		set @sql=@sql+''''+CAST(@Brand as varchar)+''' AS Brand,'
		set @sql=@sql+''''+CAST(@ProductionDate as varchar)+''' AS ProductionDate,'
		set @sql=@sql+''''+CAST(@Country as varchar)+''' AS Country,'
		set @sql=@sql+''''+CAST(@CustomerPO as varchar)+''' AS CustomerPO,'
		set @sql=@sql+''''+CAST(@BoxNumber as varchar)+''' AS BoxNumber,'
		set @sql=@sql+''''+CAST(@BoxSN as varchar)+''' AS BoxSN,'
		set @sql=@sql+''''+CAST(@SupplierCode as nvarchar(100))+''' AS SupplierCode,'
		set @sql=@sql+''''+CAST(@ProjectNo as nvarchar(100))+''' AS ProjectNo,'
		set @sql=@sql+''''+CAST(@PoNo as nvarchar(50))+''' AS PoNo,'
		set @sql=@sql+''''+CAST(@LotNo as nvarchar(50))+''' AS LotNo,'
		set @sql=@sql+''''+CAST(@MadeCountry as nvarchar(50))+''' AS MadeCountry,'
		set @sql=@sql+''''+CAST(@RollingPlan as nvarchar(100))+''' AS RollingPlan,'

		DECLARE cursor2 CURSOR FOR  
		select VGCode,ModuleName,PartNO,EnglishDesc,FieldsA,FieldsB,SingleWeight,QTY,TotalNet,Gross,L,W,H from @PrintData where BoxNumber=@BoxNumber
		order by BoxSN
		OPEN cursor2
		fetch next from cursor2 
		into @VGCode,@ModuleName,@PartNO,@EnglishDesc,@FieldsA,@FieldsB,@SingleWeight,@QTY,@TotalNet,@Gross,@L,@W,@H
		while @@FETCH_STATUS = 0 
		begin
			if CHARINDEX('''',@EnglishDesc,1)>0
			begin
				set @EnglishDesc=REPLACE(@EnglishDesc,'''','''''')
			end
			if CHARINDEX('''',@FieldsA,1)>0
			begin
				set @FieldsA=REPLACE(@FieldsA,'''','''''')
			end
				if CHARINDEX('''',@FieldsB,1)>0
			begin
				set @FieldsB=REPLACE(@FieldsB,'''','''''')
			end
			set @i=@i+1		
			if @i>1
				set @sql=@sql+','

			set @sql=@sql+''''+CAST(@VGCode as nvarchar(50))+''' AS VGCode'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@ModuleName as nvarchar(50))+''' AS ModuleName'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@PartNO as nvarchar(50))+''' AS PartNO'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@EnglishDesc as nvarchar(500))+''' AS EnglishDesc'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@FieldsA as nvarchar(500))+''' AS FieldsA'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@FieldsB as nvarchar(500))+''' AS FieldsB'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@SingleWeight as varchar)+''' AS SingleWeight'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@QTY as varchar)+''' AS QTY'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@TotalNet as varchar)+''' AS TotalNet'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@Gross as varchar)+''' AS Gross'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@L as varchar)+''' AS L'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@W as varchar)+''' AS W'+CAST(@i as varchar)+','
			set @sql=@sql+''''+CAST(@H as varchar)+''' AS H'+CAST(@i as varchar)

			fetch next from cursor2 
			into @VGCode,@ModuleName,@PartNO,@EnglishDesc,@FieldsA,@FieldsB,@SingleWeight,@QTY,@TotalNet,@Gross,@L,@W,@H
		end
		CLOSE cursor2
		DEALLOCATE cursor2

		fetch next from cursor1 
		into @BoxNumber,@BoxSN
	end
	CLOSE cursor1
	DEALLOCATE cursor1 

	exec (@sql)
	set @I_ReturnMessage='ServerMessage:箱号打印成功!从'+@StartBoxSN+'到'+@EndBoxSN
	return 0
END
 









