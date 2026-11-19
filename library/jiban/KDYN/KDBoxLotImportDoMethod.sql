
-- =============================================
-- Author:		<OrBit benson>
-- Create Date: <2016.12.15>
-- Description:	散件外箱成品号导入
-- =============================================
CREATE PROCEDURE  [dbo].[KDBoxLotImportDoMethod]
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
@OrderName nvarchar(50)='',
@ImportQty int=0

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @return_value int
	declare @LotQty int
	declare @StartTime datetime
	declare @EndTime datetime
	declare @KDBoxInfoId char(12)
	declare @KDOrderName nvarchar(50)
	declare @MESTxnObjectName nvarchar(50)  --事务名称
	declare @WorkcenterId char(12)
	declare @LotId char(12)
	declare @LotSN nvarchar(50)
	declare @LotStatus varchar(10)
	declare @LotSpecificationId char(12)
	declare @ShipBoxId char(12)
	declare @KDOrderInfoId char(12)
	declare @BoxLevel nvarchar(30)
	declare @BoxTyep nvarchar(30)
	declare @BoxSN nvarchar(50)
	declare @LotProductId char(12)

	set @return_value=-1
	set @LotQty=0
	set @StartTime=GETDATE()
	set @EndTime=GETDATE()
	set @KDBoxInfoId=''
	set @KDOrderName=''
	set @MESTxnObjectName='KD Lot Box Scan' --成品包装采集事务
	set @WorkcenterId=''
	set @LotId=''
	set @LotSN=''
	set @LotStatus=''
	set @LotSpecificationId=''
	set @ShipBoxId=''
	set @KDOrderInfoId=''
	set @BoxLevel=''
	set @BoxTyep=''
	set @BoxSN=''
	set @LotProductId=''

	declare @LotTemp table(
		LotId char(12),
		LotSN nvarchar(50),
		ProductId char(12)
	)

	declare @BoxTemp table(
		KDBoxInfoId char(12),
		BoxSN nvarchar(50)
	)

	if ISNULL(@I_PKid,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请选择有效行项!'
		return -1
	end

	if ISNULL(@OrderName,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入要装箱的整机订单!'
		return -1
	end

	if ISNULL(@ImportQty,0)<1
	begin
		set @I_ReturnMessage='ServerMessage:导入装箱的批号数量必须大于零!'
		return -1
	end

	select 
		@KDOrderInfoId=KDOrderInfo.KDOrderInfoId,
		@KDBoxInfoId=KDBoxInfo.KDBoxInfoId,
		@KDOrderName=KDOrderInfo.OrderName,
		@BoxLevel=KDBoxInfo.BoxLevel,
		@BoxTyep=KDBoxInfo.BoxType
	from KDBoxInfo 
	inner join KDOrderInfo on KDOrderInfo.KDOrderInfoId=KDBoxInfo.KDOrderInfoId
	where KDBoxInfoId=@I_PKid

	if ISNULL(@KDOrderName,'')=ISNULL(@OrderName,'')
	begin
		set @I_ReturnMessage='ServerMessage:输入的订单 ['+@OrderName+'] 不能为当前订单 ['+@KDOrderName+']'
		return -1
	end

	if not exists(select 1 from OrderFieldSetting where OrderName=@OrderName and IsClose=0)
	begin
		set @I_ReturnMessage='ServerMessage:订单 ['+@OrderName+'] 无效或者已关闭，请检查!'
		return -1
	end

	--检查订单中是否存在LotSN
	if not exists(select 1 from Lot where OrderName=@OrderName)
	begin
		set @I_ReturnMessage='ServerMessage:订单 ['+@OrderName+'] 不存在 Lot 批号，无法操作导入装箱'
		return -1
	end

	insert into @LotTemp(LotId,LotSN,ProductId)
	select LotId,LotSN,ProductId from Lot where OrderName=@OrderName and LotStatus<>'0'

	insert into @BoxTemp(KDBoxInfoId,BoxSN)
	select KDBoxInfoId,BoxSN from KDBoxInfo where KDOrderInfoId=@KDOrderInfoId and BoxLevel=@BoxLevel and BoxType=@BoxTyep

	if not exists(select 1 from @LotTemp)
	begin
		set @I_ReturnMessage='ServerMessage:未获取到成品批号，无法操作导入装箱'
		return -1
	end

	--游标写入数据
	DECLARE cursor1 CURSOR FOR  
	SELECT LotId,LotSN from @LotTemp
	order by LotSN
	OPEN cursor1
	fetch next from cursor1 
	into @LotId,@LotSN
	while @@FETCH_STATUS = 0 
	begin	
		set @LotSpecificationId=''
		select 
			@LotStatus=Lot.LotStatus,
			@LotSpecificationId=Lot.SpecificationId 
		from Lot 
		where LotId=@LotId

		if ISNULL(@LotStatus,'')<>'1'
		begin
			delete @LotTemp where LotSN=@LotSN
		end

		--去除已装箱部分
		if exists(select 1 from ShipBox where LotSN=@LotSN and IsCancel=0)
		begin
			delete @LotTemp where LotSN=@LotSN
		end
		
		fetch next from cursor1 
		into @LotId,@LotSN
	end
	CLOSE cursor1
	DEALLOCATE cursor1 

	if not exists(select 1 from @LotTemp)
	begin
		set @I_ReturnMessage='ServerMessage:未获取到可以装箱的成品批号，无法操作导入装箱'
		return -1
	end

	--游标写入数据
	DECLARE cursor2 CURSOR FOR  
	select KDBoxInfoId,BoxSN from @BoxTemp
	order by BoxSN
	OPEN cursor2
	fetch next from cursor2 
	into @KDBoxInfoId,@BoxSN
	while @@FETCH_STATUS = 0 
	begin	
		if @ImportQty>0
		begin
			set @LotId=''
			set @LotSN=''

			if not exists(select 1 from ShipBox where BoxSN=@BoxSN and IsCancel=0)
			begin		
				set @LotId=''
				set @LotSN=''
				set @LotProductId=''

				select top 1 
					@LotId=LotId,
					@LotSN=LotSN,
					@LotProductId=ProductId 
				from @LotTemp

				if ISNULL(@LotSN,'')<>''
				begin
					Exec SysGetObjectPKId '','ShipBox',@ShipBoxId output
					insert into ShipBox(
							ShipBoxId,
							BoxSN,
							LotId,
							LotSN,
							ProductId,
							ResourceId,
							UserId)
						values(
							@ShipBoxId,
							@BoxSN,
							@LotId,
							@LotSN,
							@LotProductId,
							@I_ResourceId,
							@I_OrBitUserId
							)
				end
			
				--移除批号
				delete @LotTemp where LotId=@LotId

				set @LotQty=@LotQty+1
				set @ImportQty=@ImportQty-1
			end
		end

		fetch next from cursor2 
		into @KDBoxInfoId,@BoxSN
	end
	CLOSE cursor2
	DEALLOCATE cursor2 
	
	set @EndTime=GETDATE()
	set @I_ReturnMessage='ServerMessage:外箱成品导入成功，数量 ['+CAST(@LotQty as varchar)+'] 个，耗时 '+CAST(DATEDIFF(SECOND,@StartTime,@EndTime) as varchar)+' 秒.'
	return 0
END
 









