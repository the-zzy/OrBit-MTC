

-- =============================================

-- Author:		<1002873>

-- Create date: <01 13 2025  3:20PM>

-- Description:	为BOMBindRalation创建保存过程

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[BOMBindRalationSaveData]

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

--提示：以下是用户变量定义段，如有用户变量定义段，请将上面@I_Parameter nvarchar(100)=''后面加上,号！

@ProductId  char(12)='',

@BindType  int=0,

@ProductDescription NVARCHAR(500) = '',

@ProductName VARCHAR(50) = ''



--用户变量结束

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--执行SaveData,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解SaveData过程如何编写，请参考我们提供的示例_SampleProjectSaveData



	declare @ModifyObject nvarchar(50)

	declare @ModifyType nvarchar(20)

	declare	@return_value int

	declare @S_ReturnMessage nvarchar(100)



	declare @FieldsValueOld nvarchar(max)

	declare @FieldsValueNew nvarchar(max)

	declare @FieldsChanged nvarchar(max)

	

	DECLARE @BOMId CHAR(12);



	set @I_ReturnMessage=''

	set @I_IsNewRow = 0

	set @I_ExceptionFieldName=''

	set @ModifyObject='BOMBindRalation'   --这里必须要是当前操作的表名

	set @ModifyType =''

	

	--没有申请到主键就退出

	if ltrim(@I_PKId)=''

	begin

		set @I_ReturnMessage='No PKId applied'

		return -1

	END

	

	SET @BindType = 1;

	SELECT @ProductId = ProductId FROM Product WHERE prdname = @ProductName;



	--各种规则检查段开始

	--判断是否有命名冲突

	-- if exists(select XXXXId from XXXX 

	--	where XXXXName=@XXXXName and XXXId  != @I_PKId)		

	--	begin

	--		set @I_ReturnMessage='NamingConflicts'

	--		set @I_ExceptionFieldName='XXXName'

	--		return -1

	--	end

	

	IF ISNULL(@ProductId, '') = ''

	BEGIN

		SET @I_ReturnMessage = 'ServerMessage: 料号不能为空，请检查!';

		RETURN -1;

	END

	

	SELECT @BOMId = BOMId FROM BOMItem WHERE BOMItemId = @I_ParentPKId

	

	IF NOT EXISTS (

		SELECT 1

		FROM BOMItem

		WHERE BOMId = @BOMId

		AND ProductId = @ProductId

	)

	BEGIN

		SET @I_ReturnMessage = 'ServerMessage: 该料号非此BOM下的物料，请检查!';

		RETURN -1;

	END

	

	IF EXISTS (

		SELECT 1

		FROM BOMBindRalation

		WHERE BOMItemId = @I_ParentPKId

		AND ProductId = @ProductId

		AND BOMBindRalationId <> @I_PKId

	)

	BEGIN

		SET @I_ReturnMessage = 'ServerMessage: 料号重复，请检查!';

		RETURN -1;

	END

	

	

	



    if not exists(SELECT BOMBindRalationId FROM BOMBindRalation WHERE BOMBindRalationId=@I_PKId)

		begin

		Insert into BOMBindRalation(

				 BOMBindRalationId,

				 BOMItemId,

				 ProductId,

				 BindType,

				 CreateUser

      )Values(

				 @I_PKId,

				 @I_ParentPKId,

				 @ProductId,

				 @BindType,

				 @I_OrBitUserId)



			set @I_IsNewRow=1		

			set @ModifyType='Insert'

			--获取刚刚插入的记录

			EXEC	SysGetTableFieldsCombine @ModifyObject,@I_PKId,@FieldsChanged output



		end

        else

		begin

			--获更新前的记录

			EXEC	SysGetTableFieldsCombine @ModifyObject,@I_PKId,@FieldsValueOld output



				Update BOMBindRalation set 

			    ProductId=@ProductId,

			    BindType=@BindType

			    WHERE BOMBindRalationId=@I_PKId



			 set @ModifyType='Update'

			--获更新后的记录,并进行比较

			EXEC	SysGetTableFieldsCombine @ModifyObject,@I_PKId,@FieldsValueNew output

			EXEC	SysGetTableFieldsCompare @FieldsValueOld,@FieldsValueNew,@FieldsChanged OUTPUT



		end



    	--最后将所做的修改入修改历史中

		if @FieldsChanged<>''

		EXEC	[dbo].[SysWriteInModifyHistory]

				@ObjectName = @ModifyObject,

				@TablePKId = @I_PKId ,

				@ModifyType = @ModifyType,

				@UserName = @I_OrBitUserName,

				@ModifyHistory =  @FieldsChanged



		return 0



END