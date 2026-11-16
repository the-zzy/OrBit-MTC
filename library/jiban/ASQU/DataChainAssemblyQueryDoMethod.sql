
-- =============================================
-- Author:		<OrBit benson>
-- Create date: <2016.06.20>
-- Description:	组装、包装采集项查询
-- =============================================
CREATE PROCEDURE  [dbo].[DataChainAssemblyQueryDoMethod]
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

@LotSN nvarchar(50)='',             --产品批号
@CollectSN nvarchar(50)=''          --采集项SN

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @StartTime datetime
	declare @EndTime datetime

	set @StartTime=GETDATE()
	set @EndTime=GETDATE()

	declare @where nvarchar(500)
	declare @sqlCollectSN nvarchar(max)
	declare @MACLotSN nvarchar(50)
	declare @sqlMAC nvarchar(max)
	declare @LotLotSN nvarchar(50)
	declare @sqlLotSN nvarchar(max)
	declare @SN nvarchar(100)
	declare @OrderName nvarchar(50)

	set @where=''
	set @sqlCollectSN=''
	set @MACLotSN=''
	set @sqlMAC=''
	set @LotLotSN=''
	set @sqlLotSN=''
	set @OrderName=''
	set @LotSN=LTrim(RTrim(@LotSN))
	set @CollectSN=LTrim(RTrim(@CollectSN))

	        -- 读写数据库分开提示
	if CAST(SERVERPROPERTY('MachineName') as varchar)<>(select top 1 ParameterValue from SysParameter where ParameterName='[Report Server]')
	begin
		set @I_ReturnMessage='ServerMessage:当前为生产服务器，查询报表请转到报表服务器.'
		return -1
	end
		--预置表
	declare  @OrderSetTemp table(
		SOName nvarchar(50),
		ProductName nvarchar(50),
		LotSN nvarchar(50),
		CollectItemName nvarchar(50),
		CollectSN nvarchar(50)
	)
	--输出表
	declare  @OutTemp table(
		SOName nvarchar(50),
		MOName nvarchar(50),
		ProductName nvarchar(50),
		LotSN nvarchar(50),
		WorkflowStepName nvarchar(100),
		CollectItemName nvarchar(50),
		CollectSN nvarchar(50),
		Operator nvarchar(50),
		PersonName nvarchar(30),
		WorkcenterName nvarchar(50),
		AssemblyTime datetime

	)

	set @where=' WHERE 1=1 '

	if @LotSN='' and @CollectSN=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入产品批号或者采集项SN!'
		return -1
	end

	if @LotSN<>'' and  @CollectSN<>''
	begin
		set @I_ReturnMessage='ServerMessage:对不起! 批号和采集项值只能输入一个,请输入批号 或 采集项值!'
		return -1
	end

	if @LotSN<>''
	begin
		select @OrderName=OrderName from lot with(nolock) where LotSN=@LotSN and LotStatus='1'
		select @LotLotSN=e.FieldName from OrderFieldSetting a with(nolock)
		inner join ModelSetting c with(nolock) on a.ModelSettingId=c.ModelSettingId
		inner join ModelFieldSetting d with(nolock) on c.ModelSettingId=d.ModelSettingId
		inner join FieldSetting e with(nolock) on  d.FieldSettingId=e.FieldSettingId
		where  d.IsMainSN=1 and a.OrderName=@OrderName

		if @LotLotSN <> ''
		begin
			set @SN='a.'+@LotLotSN
			set @sqlLotSN='select b.SOName,b.ProductName,'+@LotLotSN+' as LotSN,''MAC地址'' as MAC,a.MAC from OrderSetItem a with(nolock)
			inner join OrderFieldSetting b with(nolock) on a.OrderFieldSettingId=b.OrderFieldSettingId
			where '+  @SN+'='''+@LotSN+''''
			---SUBSTRING(LTrim(RTrim(a.MAC)),3,1)='':'' and 
		end

		insert into @OrderSetTemp exec(@sqlLotSN)

		insert into @OutTemp
		SELECT distinct MO.SOName as SOName,
			[dbo].[RemoveZero](MO.MOName) AS MOName,
			ProductRoot.ProductName AS ProductName,
			Lot.LotSN,
			WorkflowStep.WorkflowStepName,
			TA.ItemName AS CollectItemName,
			TA.CollectSN,TA.Operator,PersonInfo.PersonName,Workcenter.WorkcenterName,TA.AssemblyTime
		FROM DataChainAssembly TA with(nolock)
		LEFT JOIN Lot with(nolock) ON Lot.LotId=TA.LotId
		LEFT JOIN MO with(nolock) ON MO.MOId=TA.MOId
		LEFT JOIN Product with(nolock) ON Product.ProductId=TA.ProductId
		LEFT JOIN ProductRoot with(nolock) ON ProductRoot.ProductRootId=Product.ProductRootId
		LEFT JOIN WorkflowStep with(nolock) ON WorkflowStep.WorkflowStepId=TA.WorkflowStepId 
		LEFT JOIN PersonInfo with(nolock) ON TA.Operator=PersonInfo.PersonNumber
		LEFT JOIN Workcenter with(nolock) ON TA.WorkcenterId=Workcenter.WorkcenterId
		where TA.IsCancel=0 and  lot.LotSN=@LotSN and Lot.LotStatus='1'

		union all 
		select distinct c.SOName,[dbo].[RemoveZero](d.MOName)AS MOName,c.ProductName as ProductName,c.LotSN,'写号' as WorkflowStepName,
		c.CollectItemName,c.CollectSN ,'' as Operator,'' as PersonName,'' as WorkcenterName,null as AssemblyTime
		from @OrderSetTemp c
		LEFT join DataChainTEST a with(nolock) on c.LotSN=a.LotSN
		left join MO d with(nolock) on a.MOId=d.MOId
		--where a.IsCancel=0

		select SOName,MOName,ProductName,LotSN,WorkflowStepName,CollectItemName,CollectSN,Operator,PersonName,WorkcenterName,AssemblyTime
		from @OutTemp a ORDER BY LotSN,AssemblyTime 

		set @EndTime=GETDATE()

		--写入查看日志
		--insert into QueryLog(MethodName,ResourceId,UserId,StartDate,EndDate)values('DataChainAssemblyQueryDoMethod',@I_ResourceId,@I_OrBitUserId,@StartTime,@EndTime)
		
		set @I_ReturnMessage='ServerMessage:查询完成，耗时 '+CAST(DATEDIFF(SECOND,@StartTime,@EndTime) as varchar)+' 秒.'

		return 0
	end

	if @CollectSN<>''
	begin
		select @MACLotSN=e.FieldName from OrderFieldSetting a with(nolock)
		inner join OrderSetItem b with(nolock) on a.OrderFieldSettingId=b.OrderFieldSettingId
		inner join ModelSetting c with(nolock) on a.ModelSettingId=c.ModelSettingId
		inner join ModelFieldSetting d with(nolock) on c.ModelSettingId=d.ModelSettingId
		inner join FieldSetting e with(nolock) on d.FieldSettingId=e.FieldSettingId
		where  b.MAC=@CollectSN and d.IsMainSN=1

		if @MACLotSN <> ''
			begin
				set @sqlMAC='select distinct b.SOName,b.ProductName,'+@MACLotSN+' as LotSN,''写号'' as WorkflowStepName,''MAC地址'' as CollectItemName,a.MAC as CollectSN from OrderSetItem a
				inner join OrderFieldSetting b on a.OrderFieldSettingId=b.OrderFieldSettingId
				where a.MAC='''+@CollectSN+''''
				exec(@sqlMAC)
				return 0
			end
		set @where=@where+' AND TA.CollectSN='''+@CollectSN+''' and TA.iscancel=0'
	end



	set @sqlCollectSN='
		SELECT MO.SOName,[dbo].[RemoveZero](MO.MOName)AS MOName,ProductRoot.ProductName,Lot.LotSN,WorkflowStep.WorkflowStepName,TA.ItemName as CollectItemName,TA.CollectSN,TA.Operator,PersonInfo.PersonName,Workcenter.WorkcenterName,TA.AssemblyTime
		FROM DataChainAssembly TA with(nolock)
		LEFT JOIN Lot with(nolock) ON Lot.LotId=TA.LotId and Lot.LotStatus=''1''
		LEFT JOIN MO with(nolock) ON MO.MOId=TA.MOId
		LEFT JOIN Product with(nolock) ON Product.ProductId=TA.ProductId
		LEFT JOIN ProductRoot with(nolock) ON ProductRoot.ProductRootId=Product.ProductRootId
		LEFT JOIN WorkflowStep with(nolock) ON WorkflowStep.WorkflowStepId=TA.WorkflowStepId 
		LEFT JOIN Workcenter with(nolock) ON Workcenter.WorkcenterId=TA.WorkcenterId
		LEFT JOIN PersonInfo with(nolock) ON PersonInfo.PersonNumber=TA.Operator'

	if @where<>''
		set @sqlCollectSN=@sqlCollectSN+@where

	set @sqlCollectSN=@sqlCollectSN+' ORDER BY Lot.LotSN,TA.AssemblyTime'

	exec(@sqlCollectSN)

	set @EndTime=GETDATE()

	--写入查看日志
	--insert into QueryLog(MethodName,ResourceId,UserId,StartDate,EndDate)values('DataChainAssemblyQueryDoMethod',@I_ResourceId,@I_OrBitUserId,@StartTime,@EndTime)
		
	set @I_ReturnMessage='ServerMessage:查询完成，耗时 '+CAST(DATEDIFF(SECOND,@StartTime,@EndTime) as varchar)+' 秒.'

	return 0

END














