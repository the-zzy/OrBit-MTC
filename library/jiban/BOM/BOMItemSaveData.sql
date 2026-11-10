

-- =============================================

-- Author:		<OrBit Team >

-- Create date: <2008.8.8>

-- Description:	保存BOMItem，支持Insert以

-- 及Update以及规则检查

-- =============================================

CREATE PROCEDURE [dbo].[BOMItemSaveData] 

@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言

@I_IsNewRow bit = 0 output,				--向客户端报告是否是新行

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

--以上变量为服务固定接口参数，必须在每一个Save过程中实现。



--以下参与必须与该元对象数据在MetadataField表中提供的字段一一对应。

--警告:	以下变量请一定要赋以默认值，否则前台程序会报错

--提示：元数据在MetadataField表中提供的所有字段必须全部包含在Save过程中

--      否则会导致因在更新时为参数不找到出前台程序报错。>



@ProductId	char(12)='',

@ProductName  nvarchar(100)='',

@SpecificationId	char(12)='',

@SpecificationName nvarchar(100)='',

@IsAllowReplace	bit=null,

@TestValueRange	int=null,

@UOMName	nvarchar(100)='',

@IsMESTxn		bit=null,

@IsExpandItem		bit=null,

@ProductDescription nvarchar(1000)='',

@QtyRequired	float=0,

@SingleWeight float=0,

@CustomerNumber nvarchar(50)='',

@ModuleName nvarchar(50)='',

@EnglishDescription nvarchar(500)='',

@FieldsA nvarchar(500)='',

@FieldsB nvarchar(500)='',

@ReplaceGroup nvarchar(50)=''





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

	set @ModifyObject='BOMItem'

	set @ModifyType =''

	

	--没有申请到主键就退出

	if ltrim(@I_PKId)=''

	begin

		set @I_ReturnMessage='No PKId applied'

		return -1

	end



	--各种规则检查段开始

	--判断是否有命名冲突

	if exists(select BOMItemId from BOMItem where SpecificationId=@SpecificationId and ProductId =@ProductId 

		and BOMItemId != @I_PKId and BOMId=@I_ParentPKId)

	begin

		set @I_ReturnMessage='NamingConflicts'

		set @I_ExceptionFieldName='ProductName'

		return -1

	end



	--判断是否是新增的记录

	if not exists(select BOMItemId from BOMItem where BOMItemId = @I_PKId)

	begin		

		set @I_ReturnMessage='ServerMessage:不允许新建!'

		return -1



		--没有在元对象下新增也退出

		if ltrim(@I_ParentPKId)=''

		begin

			set @I_ReturnMessage='Need SampleProject PKId'

			return -1

		end



		--新增

		--执行主表的Insert

		Insert into BOMItem (

				BOMItemId,

				BOMId,

				ProductId,

				SpecificationId,

				IsAllowReplace,

				IsMESTxn,

				IsExpandItem,

				QtyRequired,

				SingleWeight

				) 

			values(

				@I_PKId,

				@I_ParentPKId,

				@ProductId,

				@SpecificationId,

				@IsAllowReplace,

				@IsMESTxn,

				@IsExpandItem,

				@QtyRequired,

				@SingleWeight

				)



		set @I_IsNewRow=1		

		set @ModifyType='Insert'



		--获取刚刚插入的记录

		EXEC	SysGetTableFieldsCombine @ModifyObject,@I_PKId,@FieldsChanged output





		if @I_SourcePKId<>''

		begin

		EXEC	@return_value = [dbo].[BOMItemCopyData]

			@I_ReturnMessage = @I_ReturnMessage OUTPUT,

			@I_PKId = @I_PKId,

			@I_SourcePKId = @I_SourcePKId



			set @ModifyType='Copy'

		end

	end

    else

	begin	

		set @I_ReturnMessage='ServerMessage:不允许编辑!'

		return -1



		--获更新前的记录

		EXEC	SysGetTableFieldsCombine @ModifyObject,@I_PKId,@FieldsValueOld output



		--更新

		update BOMItem set

			--ProductId=@ProductId,

			--SpecificationId=@SpecificationId,

			--IsAllowReplace=@IsAllowReplace,

			--IsMESTxn=@IsMESTxn,

			--IsExpandItem=@IsExpandItem,

			--QtyRequired=@QtyRequired

			CustomerNumber=@CustomerNumber,

			ModuleName=@ModuleName,

			EnglishDescription=@EnglishDescription

		where BOMItemId = @I_PKId 



		set @ModifyType='Update'



		--获更新后的记录,并进行比较

		EXEC	SysGetTableFieldsCombine @ModifyObject,@I_PKId,@FieldsValueNew output

		EXEC	SysGetTableFieldsCompare @FieldsValueOld,@FieldsValueNew,@FieldsChanged OUTPUT





	end



	--最后将所做的修改写入修改历史中

	if @FieldsChanged<>''	

	EXEC	[dbo].[SysWriteInModifyHistory]

			@ObjectName = @ModifyObject,

			@TablePKId = @I_PKId ,

			@ModifyType = @ModifyType,

			@UserName = @I_OrBitUserName,

			@ModifyHistory =  @FieldsChanged



	return 0

END

















