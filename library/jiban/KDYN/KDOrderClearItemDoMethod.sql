
-- =============================================
-- Author:		<OrBit benson>
-- Create date: <2016.10.18>
-- Description:	清除组件数据
-- =============================================
CREATE PROCEDURE  [dbo].[KDOrderClearItemDoMethod]
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
@I_Parameter nvarchar(100)=''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.

AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
		
	declare @return_value int
	set @return_value=-1

	--检查元对象方法用户授权
	exec @return_value=[dbo].[MetadataPermissionCheckDoMethod]
		@I_ReturnMessage=@I_ReturnMessage output,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_Sender=@I_Sender

	if @return_value=-1
	begin
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end

	if ISNULL(@I_ParentPKId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请选择有效行项!'
		return -1
	end

	--删除订单明细
	if not exists(select 1 from KDOrderInfo where KDOrderInfoId=@I_ParentPKId)
	begin
		set @I_ReturnMessage='ServerMessage:未找到任何订单明细!'
		return -1
	end

	delete KDOrderItem where KDOrderInfoId=@I_ParentPKId
	
	set @I_ReturnMessage='ServerMessage:订单明细清除成功!'

	return 0
END







