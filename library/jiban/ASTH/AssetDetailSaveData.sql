

-- =============================================

-- Author:		<yf1002>

-- Create date: <08 29 2018  7:24PM>

-- Description:	为AssetDetail创建保存过程

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[AssetDetailSaveData]

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

--   a.AssetDetailid,a.AssetHeadid,b.AssetTypeName,a.AssetNum,a.Company,a.CostCenter,a.Roomer,

			--   a.Descriptionx,a.ExtDescription





@AssetDetailid  VARCHAR(12)='',

@AssetHeadid  varchar(12)='',

@AssetTypeName  varchar(30)='',

@AssetNum  varchar(30)='',

@Company  varchar(10)='',

@CostCenter  varchar(10)='',

@Roomer   nvarchar(50)='',

@Descriptionx NVARCHAR(100)='',

@ExtDescription NVARCHAR(100)='',

@divisionid     VARCHAR(12)='',

@DivisionName   NVARCHAR(50)='',

@location       NVARCHAR(100)='',

@Workcenterid   VARCHAR(12)='',

@Original_assets varchar(12)='',

@SubCountNum   NVARCHAR(50)='',

@AgingLoadQty INT =0



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

	DECLARE @factoryid    varchar(12)=''

	set @I_ReturnMessage=''

	set @I_IsNewRow = 0

	set @I_ExceptionFieldName=''

	set @ModifyObject='AssetDetail'   --这里必须要是当前操作的表名

	set @ModifyType =''

	

	--没有申请到主键就退出

	if ltrim(@I_PKId)=''

	begin

		set @I_ReturnMessage='No PKId applied'

		return -1

	end

	

	--IF ISNULL(@divisionid,'') =''

	--   SELECT @divisionid = divisionid,@factoryid = FactoryId FROM dbo.SysUser WHERE UserId = @I_OrBitUserId

	IF ISNULL(@factoryid,'') ='' AND ISNULL(@divisionid,'') <> ''

	  SELECT @factoryid = FactoryId FROM dbo.Division  WHERE DivisionId = @divisionid

    IF ISNULL(@factoryid,'') <> ''

	SELECT @Company = FactoryName  FROM factory  WHERE factoryid = @factoryid



	IF ISNULL(@AssetTypeName,'') =''

	SELECT @AssetTypeName = AssetTypeName  FROM dbo.AssetHead WHERE AssetHeadid = @I_ParentPKId

	



	--SELECT @factoryid = FactoryId FROM dbo.Factory WHERE FactoryName = @Company



    if not exists(SELECT AssetDetailId FROM AssetDetail WHERE AssetDetailId=@I_PKId)

		begin

		  INSERT INTO dbo.AssetDetail (AssetDetailid,AssetHeadid,Factoryid,AssetNum,Company,Activer,

		            CostCenter,roomer,TypeName, Descriptionx, ExtDescription,divisionid,workcenterid,Original_assets,SubCountNum)

		  VALUES   (@i_pkid,@I_ParentPKId,@Factoryid,@AssetNum,@Company,1,@CostCenter,@roomer,@AssetTypeName,

		            @Descriptionx,@ExtDescription,@divisionid,@workcenterid,@Original_assets,@SubCountNum)

					 

					

		-- 1003153 2026.10.26 [负载主数据] 老化柜保存后首次生成负载编码  

		DECLARE @GenRet INT; 

		IF @AssetTypeName = N'老化柜'

		BEGIN 

			SET @AgingLoadQty = CASE WHEN ISNULL(@AgingLoadQty, 0) <= 0 THEN 56 ELSE @AgingLoadQty END;



			EXEC @GenRet = dbo.AgingCabinetLoad_GenerateForAssetDetail

				@AssetDetailId = @I_PKId,

				@AssetNum = @AssetNum,

				@AgingLoadQty = @AgingLoadQty,

				@I_OrBitUserId = @I_OrBitUserId,

				@I_ReturnMessage = @I_ReturnMessage OUTPUT;



			IF @GenRet <> 0 AND @I_ReturnMessage NOT LIKE N'%跳过生成%'

			BEGIN

				SET @I_ReturnMessage = @I_ReturnMessage;

				RETURN -1;

			END

		END



       	end

        else

		begin

			--获更新前的记录

			--EXEC	SysGetTableFieldsCombine @ModifyObject,@I_PKId,@FieldsValueOld output



				Update AssetDetail

				   set AssetHeadid = @AssetHeadid,TypeName = @AssetTypeName,

				       Roomer = @roomer,AssetNum = @AssetNum,divisionid = @divisionid,

					   CostCenter = @CostCenter,company = @Company,SubCountNum = @SubCountNum,

					   Descriptionx = @Descriptionx,workcenterid = @Workcenterid,Location = @location,

					   ExtDescription = @ExtDescription,Original_assets=@Original_assets

			    WHERE AssetDetailId=@I_PKId



		end



  

		return 0



END

