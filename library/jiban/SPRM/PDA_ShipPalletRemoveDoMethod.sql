
-- =============================================
-- Author:		<OrBit Team Andraw>
-- Create date: <2016.8.29>
-- Update date:
-- Description:	<获取工单基本信息>
-- Rev:1.00 
-- =============================================
CREATE PROCEDURE  [dbo].[PDA_ShipPalletRemoveDoMethod]
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
@I_Parameter nvarchar(max)='',  		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.

@Operator nvarchar(50) = '',    --扫描人员 
@ScanPalletSN nvarchar(50) = '',--栈板号
@BoxSN nvarchar(50) = ''        --箱号


AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @PalletSN nvarchar(100)
	declare @ShipPalletCombineHistoryId char(12)
	declare @ProductId char(12)
	declare @Query int
	--处理键盘大小写问题（统一为大写）
	set @ScanPalletSN=UPPER(RTRIM(LTRIM(@ScanPalletSN)))
	set @BoxSN=UPPER(RTRIM(LTRIM(@BoxSN)))
	set @Query=0


	if ISNULL(@Operator,'') =''
	begin
	    set @I_ReturnMessage='ServerMessage:请扫描员工工号!'
	    set @I_ExceptionFieldName = 'Operator'
		return -1
	end	
	if ISNULL(@ScanPalletSN,'') =''
	begin
	    set @I_ReturnMessage='ServerMessage:请扫描栈板号!'
	    set @I_ExceptionFieldName = 'ScanPalletSN'
		return -1
	end	
	if ISNULL(@BoxSN,'') =''
	begin
	    set @I_ReturnMessage='ServerMessage:请扫描箱号!'
	    set @I_ExceptionFieldName = 'BoxSN'
		return -1
	end	
	 --:员工工号是否有效
	if not exists(select 1 from PersonInfo where PersonNumber=@Operator and IsActivity=1)
	begin
		select '' as Operator,'' as ScanPalletSN,'' as BoxSN
		set @I_ReturnMessage='ServerMessage:员工工号 ['+@Operator+'] 不存在!'
		set @I_ExceptionFieldName='Operator'
		return -1
	end

	if not exists (select 1 from ShipPallet where PalletSN= @ScanPalletSN  and IsCancel=0  )
	begin
		        set @I_ReturnMessage='ServerMessage:您扫描的栈板号：'+@ScanPalletSN+' 没有栈板扫描,不需要判断是否属于此栈板号 【 '+@ScanPalletSN+' 】!'
					select '' as ScanPalletSN,'' as BoxSN
				set @I_ExceptionFieldName = 'ScanPalletSN'
				return -1
    end

	--处理扫描箱号（同一个栈板下）
	if not exists (select 1 from ShipPallet where BoxSN= @BoxSN and IsCancel=0)
	begin
		set @I_ReturnMessage='ServerMessage:您扫描的箱号：'+@BoxSN +' 非法不存在没有栈板下线或者!'
		select '' as BoxSN
		set @I_ExceptionFieldName = 'BoxSN'
		return -1
    end

	select @PalletSN=PalletSN ,@ProductId =ProductId from ShipPallet where  BoxSN= @BoxSN and IsCancel=0

	if @ScanPalletSN<>@PalletSN
	begin
	    set @I_ReturnMessage='ServerMessage:您扫描的箱号：【 '+@BoxSN+' 】'+'不属于栈板号：【 '+@PalletSN+' 】'
		select '' as BoxSN
		set @I_ExceptionFieldName = 'BoxSN'
		return -1
	end
	else
	begin
	        
			if  exists (select 1 from ShipPalletCombineHistory where BoxSN= @BoxSN and IsCancel=0)
			begin
				set @I_ReturnMessage='ServerMessage:移除成功,您扫描的箱号：【 '+@BoxSN+' 】'+'属于栈板号：【 '+@PalletSN+' 】'
				select @Query=COUNT(1) from ShipPalletCombineHistory where PalletSN=@ScanPalletSN and  IsCancel=0
				select CAST(@Query as nvarchar(10)) as ScanQty,'' as BoxSN
				set @I_ExceptionFieldName = 'BoxSN'
				
				return 0
			end
			else
			begin
			     exec SysGetObjectPKId '','ShipPalletCombineHistory',@ShipPalletCombineHistoryId output

				 insert into ShipPalletCombineHistory(ShipPalletCombineHistoryId,PalletSN,BoxSN,ProductId,ResourceId,Operator)
				 values(@ShipPalletCombineHistoryId,@PalletSN,@BoxSN,@ProductId,@I_ResourceId,@Operator)

				set @I_ReturnMessage='ServerMessage:移除成功,您扫描的箱号：【 '+@BoxSN+' 】'+'属于栈板号：【 '+@PalletSN+' 】'
				select @Query=COUNT(1) from ShipPalletCombineHistory where PalletSN=@ScanPalletSN and  IsCancel=0
				select CAST(@Query as nvarchar(10)) as ScanQty,'' as BoxSN
				set @I_ExceptionFieldName = 'BoxSN'
				return 0
				                
			end



	end
	
		
			
			
	
	return 0

END