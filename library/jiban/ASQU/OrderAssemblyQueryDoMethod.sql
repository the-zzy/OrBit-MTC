
-- =============================================
-- Author:		<AMTC CHAY>
-- Create date: <2017.09.02>
-- Description:	订单采集数据查询
-- =============================================
CREATE PROCEDURE  [dbo].[OrderAssemblyQueryDoMethod]
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

@OrderName nvarchar(50)=''          --订单号

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
		
	declare @LotSN nvarchar(50)
    declare @sql nvarchar(max)
	declare @ProductName nvarchar(50)
	declare @SOName nvarchar(50)
	declare @OrderFieldSettingId char(12)

	set @LotSN=''
	set @sql=''
	set @ProductName=''
	set @SOName=''
	set @OrderFieldSettingId=''

	
	--预置表
	declare  @OrderSetTemp table(
		LotSN nvarchar(50),
		CollectItemName nvarchar(50),
		CollectSN nvarchar(50)
	)
	declare @LotInfo table(
		lotId char(12),
		LotSN nvarchar(50)
	)

	        -- 读写数据库分开提示
	if CAST(SERVERPROPERTY('MachineName') as varchar)<>(select top 1 ParameterValue from SysParameter where ParameterName='[Report Server]')
	begin
		set @I_ReturnMessage='ServerMessage:当前为生产服务器，查询报表请转到报表服务器.'
		return -1
	end
	

	if ISNULL(@OrderName,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入订单号'
		return -1
	end

	if ISNULL(@OrderName,'')<>''
	begin
		if LEN(@OrderName)<>12
		begin
			set @I_ReturnMessage='ServerMessage:订单号 ['+@OrderName+'] 长度必须为 12 位，请检查!'
			return -1
		end

		if not exists(select 1 from OrderFieldSetting where OrderName=@OrderName)
		begin
			set @I_ReturnMessage='ServerMessage:订单号 ['+@OrderName+'] 无效，请检查!'
			return -1
		end		
	end

	--获取品号、销售订单号、id
	select @OrderFieldSettingId=OrderFieldSettingid,@ProductName=ProductName,@SOName=SOName from OrderFieldSetting where OrderName=@OrderName

	--获取预置表的主批号
	select @LotSN=e.FieldName 
	from OrderFieldSetting a
	inner join ModelSetting c on a.ModelSettingId=c.ModelSettingId
	inner join ModelFieldSetting d on c.ModelSettingId=d.ModelSettingId
	inner join FieldSetting e on d.FieldSettingId=e.FieldSettingId
	where a.OrderName=@OrderName and d.IsMainSN=1

	if @LotSN <> ''
	begin
		set @sql='select a.'+@LotSN+' as LotSN,''MAC地址'' as MAC,a.MAC from OrderSetItem a
		where  a.MAC<>'''' and a.OrderFieldSettingId='''+@OrderFieldSettingId+''''
		insert into @OrderSetTemp exec(@sql)
	end

	--获取Lot表的信息
	insert into @LotInfo(LotId,LotSN)
	select LotId,LotSN from Lot where OrderName=@OrderName and Lot.LotStatus='1'

	--得到输出数据

	--insert into @OutTemp

	SELECT SOName as SOName,
		[dbo].[RemoveZero](MO.MOName) AS MOName,
		@ProductName AS ProductName,
		Lot.LotSN,
		WorkflowStep.WorkflowStepName,
		TA.ItemName AS CollectItemName,
		TA.CollectSN,TA.Operator,PersonInfo.PersonName,Workcenter.WorkcenterName,TA.AssemblyTime
	FROM @LotInfo Lot
	inner join DataChainAssembly TA on Lot.lotId=TA.LotId 
	LEFT JOIN MO MO ON MO.MOId=TA.MOId
	LEFT JOIN WorkflowStep ON WorkflowStep.WorkflowStepId=TA.WorkflowStepId 
	LEFT JOIN PersonInfo ON TA.Operator=PersonInfo.PersonNumber
	LEFT JOIN Workcenter ON TA.WorkcenterId=Workcenter.WorkcenterId
	where TA.IsCancel=0

	union all 
	select distinct @SOName,[dbo].[RemoveZero](d.MOName)AS MOName,@ProductName as ProductName,c.LotSN,'写号' as WorkflowStepName,c.CollectItemName,c.CollectSN ,'','','',null
	from @OrderSetTemp c
	inner join DataChainTEST a on c.LotSN=a.LotSN
	left join MO d on a.MOId=d.MOId
	where   a.IsCancel=0
	order by LotSN,AssemblyTime
		
		--select SOName,MOName,ProductName,LotSN,WorkflowStepName,CollectItemName,CollectSN,Operator,PersonName,WorkcenterName,AssemblyTime
		--from @OutTemp a ORDER BY LotSN,AssemblyTime 

	
	set @EndTime=GETDATE()
			
	set @I_ReturnMessage='ServerMessage:查询完成，耗时 '+CAST(DATEDIFF(SECOND,@StartTime,@EndTime) as varchar)+' 秒.'
	--insert into QueryLog(MethodName,ResourceId,UserId,StartDate,EndDate)values('OrderAssemblyQueryDoMethod',@I_ResourceId,@I_OrBitUserId,@StartTime,@EndTime)
	return 0

END