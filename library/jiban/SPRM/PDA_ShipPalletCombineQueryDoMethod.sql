
-- =============================================
-- Author:		<OrBit Team Andraw>
-- Create date: <2016.8.29>
-- Update date:
-- Description:	<获取工单基本信息>
-- Rev:1.00 
-- =============================================
CREATE PROCEDURE  [dbo].[PDA_ShipPalletCombineQueryDoMethod]
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


	
	if ISNULL(@ScanPalletSN,'') =''
	begin
	    set @I_ReturnMessage='ServerMessage:请扫描栈板号!'
	    set @I_ExceptionFieldName = 'ScanPalletSN'
		return -1
	end	
	
		
    select PalletSN,BoxSN from ShipPalletCombineHistory where PalletSN=@ScanPalletSN and  IsCancel=0
	    
			
	
	return 0

END