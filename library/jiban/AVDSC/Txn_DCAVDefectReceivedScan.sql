

-- =============================================
-- Author:		<MTC.IT   MHY>
-- Create date: <2016.09.29>
-- Description:	<AV批号离线维修删除维修记录>
-- Rev: 10.00
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_DCAVDefectReceivedScan]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12) = '',				--主键
@I_SourcePKId char(12)='',			--执行拷贝时传入的源主键  
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='',		--插件参数	

@LotSN nvarchar(50)='',
@Operator nvarchar(50)=''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @LotId char(12)
	declare @DCRepairOffLineId char(12)
	declare @WorkflowDefectId char(12)
	declare @ParentLotId char(12)

	set @LotId=''
	set @DCRepairOffLineId=''
	set @WorkflowDefectId=''	
	set @ParentLotId=''
	
	--检查不能为空
	if ISNULL(@Operator,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请选中有效项!'
		return -1
	end

	if NOT EXISTS(SELECT TOP 1 1 FROM dbo.PersonInfo WHERE PersonNumber = @Operator AND IsActivity = 1)
	begin
		set @I_ReturnMessage='ServerMessage:请输入有效的工号!'+  @Operator
		return -1
	end

	--检查是否有此维修记录
	if not exists(select WorkflowDefectid from WorkflowDefect where lotsn LIKE RTRIM(@LotSN) + '%' AND IsExe = 0 ) 
	begin
		set @I_ReturnMessage='ServerMessage:LotSN ['+@LotSN+'] 不存在不良采集的记录!'
		return -1
	END
   

	--if exists(select WorkflowDefectid from WorkflowDefect where lotsn=@LotSN AND IsExe = 0)
	--begin
	--	--获取维修记录信息
	--	begin tran 
			update WorkflowDefect set receivedate =GETDATE(),ReceiveOperator = @Operator where lotsn LIKE RTRIM(@lotsn) + '%' AND IsExe =0
	--	commit tran
	--end

	
	set @I_ReturnMessage='ServerMessage:Say{不良接收扫描成功}不良接收扫描成功!'
	set @I_ExceptionFieldName='DefectLocation'

	return 0
END




















