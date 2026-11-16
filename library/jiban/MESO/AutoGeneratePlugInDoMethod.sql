
-- =============================================
-- Author:		<OrBit Team  Aaron>
-- Create date: <2015.09.28>
-- Description:	保存插件表的数据，支持Insert以
-- 及Update以及规则检查
-- =============================================
CREATE PROCEDURE [dbo].[AutoGeneratePlugInDoMethod]  
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_IsNewRow bit = 0 output,				--向客户端报告是否是新行
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12) = '',				--主键事务
@I_SourcePKId char(12)='',			--执行拷贝时传入的源主键  
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='',			--插件参数
--以上变量为服务固定接口参数，必须在每一个Save过程中实现。

--以下参与必须与该元对象数据在MetadataField表中提供的字段一一对应。
--警告:	以下变量请一定要赋以默认值，否则前台程序会报错
--提示：元数据在MetadataField表中提供的所有字段必须全部包含在Save过程中
--      否则会导致因在更新时为参数不找到出前台程序报错。
@PluginCmd	char(5)='',
@PluginNaming nvarchar(100)='',
@PluginType	char(1)='1',
@PluginTypeName	nvarchar(100)='',
@PluginFileName	nvarchar(100)='PluginMESStaticTxn.dll',
@PluginPhysicsFile nvarchar(100)='',
@PluginImageURL	nvarchar(100)='',
@PluginParameter	nvarchar(100)='',
@MetadataId	char(12)='',
@MetadataName	nvarchar(100)='',
@IsActivity	bit=1,
@Text1 nvarchar(100)='',
@Text2 nvarchar(100)='',
@Text3 nvarchar(100)='',
@Text4 nvarchar(100)='',
@Text5 nvarchar(100)='',
@Text6 nvarchar(100)='',
@Text7 nvarchar(100)='',
@Text8 nvarchar(100)='',
@SOPId char(12)='',
@SOPName nvarchar(100)='',
@IsUseWorkflow bit=0,
@WorkflowId char(12)='',
@WorkflowName nvarchar(100)='',
@PluginIcon nvarchar(50) = '',
@PluginPNG nvarchar(50) = '',
@ParameterId char(12)='' ,
@ParameterName  nvarchar(100)='' ,
@PK_Id  char(12)='' , -- 插件ID
@ParameterNameTemp  nvarchar(100)='',  -- 临时参数组成部分
@NoToolBar  bit=1,
@NoLotScan  bit=1,
@NoSpecCheck bit=1,
@CombineTemp  nvarchar(50) = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

   	--初始化一些变量

	declare @ModifyObject nvarchar(50)
	declare @ModifyType nvarchar(20)
	declare	@return_value int
	declare @S_ReturnMessage nvarchar(100)

	declare @FieldsValueOld nvarchar(max)
	declare @FieldsValueNew nvarchar(max)
	declare @FieldsChanged nvarchar(max)

	set @I_ReturnMessage=''
	set @I_IsNewRow = 0
	set @I_ExceptionFieldName=''
	set @ModifyObject='SysPlugin'
	set @ModifyType =''
	set @Text1 = @PluginNaming
	
		---============申请[SysPlugin]主键=========-----------
		EXEC	[dbo].[SysGetObjectPKId]
		@ObjectName = 'SysPlugin',
		@PKID=@PK_Id OUTPUT

	--没有申请到主键就退出
	if ltrim(@I_PKId)=''
	begin
		set @I_ReturnMessage='No PKId applied'
		return -1
	end
	if  rtrim(ltrim(@PluginCmd))=''
		begin
		set @I_ReturnMessage='请输入插件命令'
		return -1
	end

	if  rtrim(ltrim(@PluginNaming))=''
		begin
		set @I_ReturnMessage='请输入插件名称'
		return -1
	end

    --各种规则检查段开始
	--判断是否有命名冲突
	if exists(select PluginId from SysPlugin 
		where PluginCommand=@PluginCmd and PluginId != @PK_Id)
		begin
			set @I_ReturnMessage='NamingConflicts'
			set @I_ExceptionFieldName='PluginCommand'
			return -1
		end

	if exists(select PluginId from SysPlugin 
		where PluginName=@PluginNaming and PluginId != @PK_Id)
		begin
			set @I_ReturnMessage='NamingConflicts'
			set @I_ExceptionFieldName='PluginName'
			return -1
		end
 
     if  @NoToolBar = 1 
	     set   @CombineTemp = @CombineTemp +  '[NoToolBar]'
     if  @NoLotScan = 1
	     set  @CombineTemp  = @CombineTemp + '[NoLotScan]'
	 if  @NoSpecCheck = 1
         set  @CombineTemp = @CombineTemp + '[NoSpecCheck]'
	 

    SET  @PluginNaming = rtrim(ltrim(@PluginNaming))
    set  @ParameterName='[MESTXN:'+ @PluginNaming +']'+ @CombineTemp +'[N]'
	set  @PluginParameter = @ParameterName
	-- 获取前端事务ID列表
	declare   @tempMesTxnObjectId   char(12)
	declare   @mesTxnObjectDesc   varchar(50)
	declare curMesTxnObjectId cursor   --定义一个游标
	   read_only
	   for  select * from  ConvertParameterToTable(@I_Parameter,';')
	   open curMesTxnObjectId   --打开游标
	   fetch next from curMesTxnObjectId  into @tempMesTxnObjectId  --把提取操作的列数据放到局部变量中
	   while(@@fetch_status=0)   --返回被 FETCH 语句执行的最后游标的状态，而不是任何当前被连接打开的游标的状态。
	   begin
	        --SELECT  @ParameterNameTemp=MESTxnObjectName  FROM   MESTxnObject    
	    	--WHERE  MESTxnObjectId = @I_PKId
			 SELECT  @ParameterNameTemp=MESTxnObjectName ,@mesTxnObjectDesc =MESTxnObjectDesc FROM   MESTxnObject    
	    	 WHERE  MESTxnObjectId = @tempMesTxnObjectId
		    
		    if exists 
	           ( SELECT ParameterName  FROM   SysParameter   
		        where ParameterName =@ParameterName)
		        begin
		            SELECT @PluginParameter= ParameterName  FROM   SysParameter   
		            WHERE ParameterName =@PluginNaming
                
					 ---============申请SysParameter主键=========-----------
		             EXEC	[dbo].[SysGetObjectPKId]
		                 @ObjectName = 'SysParameter',
		                 @PKID=@ParameterId OUTPUT

			          --	 MESTxnObjectName
			         set  @ParameterNameTemp =  rtrim(ltrim(@ParameterNameTemp))
			       
			 	     INSERT INTO  SysParameter (ParameterId,ParameterName,ParameterDescription , ParameterValue ,CreateDate)
				     VALUES (@ParameterId,@ParameterName,@mesTxnObjectDesc,@ParameterNameTemp,GETDATE())
		        end
	        else
	            begin
		              ---============申请SysParameter主键=========-----------
		             EXEC	[dbo].[SysGetObjectPKId]
		                 @ObjectName = 'SysParameter',
		                 @PKID=@ParameterId OUTPUT

			          --	 MESTxnObjectName
			        set  @ParameterNameTemp =  rtrim(ltrim(@ParameterNameTemp))
			       
			 	     INSERT INTO  SysParameter (ParameterId,ParameterName,ParameterDescription , ParameterValue ,CreateDate)
				     VALUES (@ParameterId,@ParameterName,@mesTxnObjectDesc,@ParameterNameTemp,GETDATE())
				 
		        end

            --提前下一位信息
            fetch next from curMesTxnObjectId into @tempMesTxnObjectId
       end
       close curMesTxnObjectId   --关闭游标
       deallocate curMesTxnObjectId   --删除游标


	--判断是否是新增的记录
	if not exists(select PluginId from SysPlugin 
		 where PluginId = @PK_Id)
	begin		


		--新增
		--执行主表的Insert
		Insert into SysPlugin (
				PluginId,
				PluginCommand,
				PluginName,
				PluginDescription,
				PluginType,
				PluginFileName,
				PluginImageURL,
				PluginParameter,
				MetadataId,
				IsActivity,
				SOPId,
				IsUseWorkflow,
				WorkflowId
				) 
				values(
				@PK_Id,
				UPPER(@PluginCmd),
				@PluginNaming,
				@Text1,
				@PluginType,
				@PluginFileName,
				@PluginImageURL,
				@PluginParameter,
				@MetadataId,
				@IsActivity,
				@SOPId,
				@IsUseWorkflow,
				@WorkflowId
				)
		set @I_IsNewRow=1		
		set @ModifyType='Insert'

		--获取刚刚插入的记录
		EXEC	SysGetTableFieldsCombine @ModifyObject,@PK_Id,@FieldsChanged output

	end
    else
	begin
	--检查记录是否受到保护
		declare @Protected bit	
		select @Protected=Protected from SysPlugin 
			where PluginId = @PK_Id 
		if @Protected=1
		begin
			set @I_ReturnMessage='Data has been protected'			
			return -1
		end


		--获更新前的记录
		EXEC	SysGetTableFieldsCombine @ModifyObject,@PK_Id,@FieldsValueOld output

		--更新
		begin tran
			update  SysPlugin set
				PluginCommand=UPPER(@PluginCmd),
				PluginName=@PluginNaming,
				PluginDescription=@Text1,
				PluginType=@PluginType,
				PluginFileName=@PluginFileName,
				PluginImageURL=@PluginImageURL,
				PluginParameter=@PluginParameter,
				MetadataId=@MetadataId,
				IsActivity=@IsActivity,
				SOPId=@SOPId,
				IsUseWorkflow=@IsUseWorkflow,
				WorkflowId=@WorkflowId
				where
				PluginId = @PK_Id 
		 commit tran 

		 set @ModifyType='Update'

		--获更新后的记录,并进行比较
		EXEC	SysGetTableFieldsCombine @ModifyObject,@PK_Id,@FieldsValueNew output
		EXEC	SysGetTableFieldsCompare @FieldsValueOld,@FieldsValueNew,@FieldsChanged OUTPUT



	end

     --将Text1-Text8插入到SysText表中
		 EXEC	[dbo].[SysTextSaveModuleValue]
				@TextModule = @PK_Id,
				@Text1 = @Text1,
				@Text2 = @Text2,
				@Text3 = @Text3,
				@Text4 = @Text4,
				@Text5 = @Text5,
				@Text6 = @Text6,
				@Text7 = @Text7,
				@Text8 = @Text8

		--最后将所做的修改写入修改历史中
		if @FieldsChanged<>''	
		EXEC	[dbo].[SysWriteInModifyHistory]
				@ObjectName = @ModifyObject,
				@TablePKId = @PK_Id ,
				@ModifyType = @ModifyType,
				@UserName = @I_OrBitUserName,
				@ModifyHistory =  @FieldsChanged

         set @I_ReturnMessage=@I_ReturnMessage+'插件配置成功...'
         
	return 0
END
