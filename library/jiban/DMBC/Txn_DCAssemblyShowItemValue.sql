
-- =============================================
-- Author:		<OrBit andraw>
-- Create date: <2016.10.10>
-- Description:	<总装上线扫描-显示采集项>
-- =============================================
CREATE PROCEDURE [dbo].[Txn_DCAssemblyShowItemValue]  
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
----
--@OrderName nvarchar(100)=''
@OrderName nvarchar(100)='',	
@MOId char(12)=''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @ProductId char(12)
	declare @PluginParameter nvarchar(100)

	if ISNULL(@OrderName,'')=''
	begin
	   		set @I_ExceptionFieldName='OrderName'
			return -1
	end


	if ISNULL(@MOId,'')<>''
	begin
	     select @ProductId=ProductId from  MO where MOId=@MOId
	end

	if ISNULL(@OrderName,'')<>''
	begin
	     select @ProductId=MO.ProductId from  MO 
		                           inner join OrderFieldSetting on OrderFieldSetting.MOId=MO.MOId
						                   where OrderFieldSetting.OrderName=@OrderName
	end



	select @PluginParameter=PluginParameter from SysPlugIn where PluginCommand=@I_PlugInCommand

	if   CHARINDEX('DC AssemblyScan',@PluginParameter)>0
	begin
	  
	      select Product_CollectSetting.Sequence,CollectItem.CollectItemName ,'' as CollectSN
		       from Product_CollectSetting
	                inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
				            where ProductId=@ProductId  and Product_CollectSetting.SpecificationId='SPE10000018S'
		  return 0
	

	end 
	if   CHARINDEX('多码合一采集',@PluginParameter)>0
	begin
	
	      select Product_CollectSetting.Sequence,CollectItem.CollectItemName ,'' as CollectSN
		       from Product_CollectSetting
	                inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
				            where ProductId=@ProductId  and Product_CollectSetting.SpecificationId='SPE1000001BH'
		  return 0
	

	end 

	if   CHARINDEX('DC CollectPrint',@PluginParameter)>0
	begin
	
	      select Product_CollectSetting.Sequence,CollectItem.CollectItemName ,'' as CollectSN
		       from Product_CollectSetting
	                inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
				            where ProductId=@ProductId  and Product_CollectSetting.SpecificationId='SPE1000001AZ'
	    	set @I_ExceptionFieldName='OrderName'
		  return 0
	

	end 
	if   CHARINDEX('成品包装',@PluginParameter)>0
	begin
	
	      select Product_CollectSetting.Sequence,CollectItem.CollectItemName ,'' as CollectSN
		       from Product_CollectSetting
	                inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
				            where ProductId=@ProductId  and Product_CollectSetting.SpecificationId='SPE100000192'

		  set @I_ExceptionFieldName='OrderName'
		  return 0
	

	end 
	if   CHARINDEX('包装打印',@PluginParameter)>0
	begin
	
	      select Product_CollectSetting.Sequence,CollectItem.CollectItemName ,'' as CollectSN
		       from Product_CollectSetting
	                inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
				            where ProductId=@ProductId  and Product_CollectSetting.SpecificationId='SPE100000192'

		  set @I_ExceptionFieldName='OrderName'
		  return 0

	end 
			            
	return 0
	
END



