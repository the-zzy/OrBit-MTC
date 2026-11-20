
-- =============================================
-- Author:		<OrBit benson>
-- Create date: <2016.08.01>
-- Description:	成品拆箱
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_DCBoxSNSplit]
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
@I_Parameter nvarchar(100)='',      --插件参数

--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
@BoxSN nvarchar(50)='',
@AffirmBoxSN nvarchar(50)='',
@SplitCommand nvarchar(50)=''

AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @ShipBoxId char(12)
	declare @LotId char(12)
	declare @LotSN nvarchar(50)

	set @I_ExceptionFieldName='BoxSN'
	set @ShipBoxId=''
	set @LotId=''
	set @LotSN=''

	if ISNULL(@BoxSN,'')=''
	begin
		select '' as SplitCommand,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:箱号不能为空!'
		return -1
	end

	if ISNULL(@AffirmBoxSN,'')=''
	begin
		select '' as SplitCommand,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:确认箱号不能为空!'
		set @I_ExceptionFieldName='AffirmBoxSN'
		return -1
	end

	--检查栈板号是否一致
	if ISNULL(@I_Sender,'')='AffirmBoxSN'
	begin
		if ISNULL(@BoxSN,'')<>ISNULL(@AffirmBoxSN,'')
		begin
			select '' as SplitCommand,'error.png' as WarnImage
			set @I_ReturnMessage='ServerMessage:箱号 ['+@BoxSN+']、['+@AffirmBoxSN+'] 不一致!'
			set @I_ExceptionFieldName='AffirmBoxSN'
			return -1
		end

		select '' as SplitCommand,'ok.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:请输入拆箱指令!'
		set @I_ExceptionFieldName='SplitCommand'
		return 0
	end

	if ISNULL(@SplitCommand,'')=''
	begin
		select '' as SplitCommand,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:解除指令不能为空!'
		set @I_ExceptionFieldName='SplitCommand'
		return -1
	end

	if ISNULL(@BoxSN,'')<>ISNULL(@AffirmBoxSN,'')
	begin
		select '' as SplitCommand,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:箱号 ['+@BoxSN+']、['+@AffirmBoxSN+'] 不一致!'
		set @I_ExceptionFieldName='AffirmBoxSN'
		return -1
	end

	--是否存在装箱记录
	if not exists(select 1 from ShipBox where BoxSN=@BoxSN and IsCancel=0)
	begin
		select '' as AffirmBoxSN,'' as SplitCommand,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:箱号 ['+@BoxSN+'] 无效，没找到相关记录，请检查!'	
		return -1
	end

	--检查是否已装栈板
	if exists(select 1 from ShipPallet where BoxSN=@BoxSN and IsCancel=0)
	begin
		select '' as AffirmBoxSN,'' as SplitCommand,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:外箱 ['+@BoxSN+'] 已装栈板，请先执行【外箱移出】操作!'
		set @I_ExceptionFieldName='SplitCommand'
		return -1
	end

	if ISNULL(@SplitCommand,'')<>'CMDSPLIT'
	begin
		select '' as SplitCommand,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:拆箱指令不符!'
		set @I_ExceptionFieldName='SplitCommand'
		return -1
	end

	--检查是否存在已出库的成品
	declare cursor1 cursor for 
	select LotId from ShipBox where BoxSN=@BoxSN and IsCancel=0
	open cursor1
	fetch next from cursor1 
	into @LotId
	while @@fetch_status=0     
	begin	
		if exists(select 1 from WW_FGInventory where LotId=@LotId and StorageStatus='2' and IsCancel=0)
		begin
			select '' as PalletSN,'' as AffirmPalletSN,'' as SplitCommand,'error.png' as WarnImage
			set @I_ReturnMessage='ServerMessage:外箱 ['+@BoxSN+'] 成品 ['+@LotSN+'] 已出库，不允许执行拆箱操作!'
			return -1
		end
		
		fetch next from cursor1 
		into @LotId
	end 
	close cursor1
	deallocate cursor1

	--游标更新外箱数据
	declare cursor2 cursor for 
	select ShipBoxId from ShipBox where BoxSN=@BoxSN and IsCancel=0
	open cursor2
	fetch next from cursor2 
	into @ShipBoxId
	while @@fetch_status=0     
	begin	
		--更新栈板信息为失效
		update ShipBox set 
			IsCancel=1,
			BoxSN=BoxSN+'_BK',
			LotSN=LotSN+'_BK' 
		where ShipBoxId=@ShipBoxId

		fetch next from cursor2 
		into @ShipBoxId
	end 
	close cursor2
	deallocate cursor2

	select '' as BoxSN,'' as AffirmBoxSN,'' as SplitCommand,'ok.png' as WarnImage
	set @I_ReturnMessage='ServerMessage:箱号 ['+@BoxSN+'] 拆箱成功!'

	return 0

END
