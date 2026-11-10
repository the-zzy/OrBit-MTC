

-- =============================================

-- Author:		<yf1002>

-- Create date: <08 31 2018  2:56PM>

-- Description:	为AssetCheck创建导航树视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[AssetCheckTreeView]

@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言

@I_LanguageId char(1)='1',				--客户端传入的语言ID

@I_PlugInCommand varchar(5)='',		--插件命令

@I_FiltCondition	nvarchar(max)='',	--过滤条件表达式

@I_OrBitUserId char(12)='',			--用户ID

@I_OrBitUserName nvarchar(100)='',	--用户名

@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)

@I_ResourceName nvarchar(100)='',	--资源名

@I_PKId char(12) ='',				--主键

@I_ParentPKId char(12)='',			--父级主键

@I_Parameter nvarchar(100)=''		--插件参数

--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine	

	SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--执行TreeView,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解TreeView过程如何编写，请参考我们提供的示例_SampleProjectTreeView

	if @I_ParentPKId<>''  --当SaveData执行完成后刷新单行时执行

	begin

			SELECT     a.AssetCheckID,a.AssetNum,a.CheckYYMM,b.ObjectTypeName,a.d01,a.d02,a.d03,a.d04,a.d05,a.d06,a.d07,a.d08,a.d09,

			        a.d10,a.d11,a.d12,a.d13,a.d14,a.d15,a.d16,a.d17,a.d18,a.d19,a.d20,a.d21,a.d22,a.d23,a.d24,a.d25,

					a.d26,a.d27,a.d28,a.d29,a.d30,a.d31,a.Operator

			FROM        AssetCheck a

			 INNER JOIN dbo.AssetTypeObject b ON(b.AssetTypeObjectid = a.AssetTypeObjectId)

			where a.AssetDetailid=@I_ParentPKId 

			return 0

	end







	if @I_PKId<>''  --当SaveData执行完成后刷新单行时执行

	begin

			SELECT    a.AssetCheckID, a.AssetNum,a.CheckYYMM,b.ObjectTypeName,a.d01,a.d02,a.d03,a.d04,a.d05,a.d06,a.d07,a.d08,a.d09,

			        a.d10,a.d11,a.d12,a.d13,a.d14,a.d15,a.d16,a.d17,a.d18,a.d19,a.d20,a.d21,a.d22,a.d23,a.d24,a.d25,

					a.d26,a.d27,a.d28,a.d29,a.d30,a.d31,a.Operator

			FROM        AssetCheck a

			 INNER JOIN dbo.AssetTypeObject b ON(b.AssetTypeObjectid = a.AssetTypeObjectId)

			where a.AssetCheckId=@I_PKId 

			return 0

	end

			----以下被注释的段落是启用协同工作流后的代码,如果需要运行协同工作流请将它取消注释即可

			--if   charindex('[',@I_Parameter)>0 --向前台传送数据行统计信息

			--begin

			--	set @I_Parameter=REPLACE(REPLACE(@I_Parameter,'[',''),']','')

			--	SELECT   COUNT(*) AS CountId

			--			FROM      dbo.AssetCheck INNER JOIN

			--			dbo.WorkflowStep ON dbo.AssetCheck.WorkflowStepId = dbo.WorkflowStep.WorkflowStepId INNER JOIN

			--			dbo.Spec_User ON dbo.WorkflowStep.SpecificationId = dbo.Spec_User.SpecificationId

			--			WHERE     dbo.Spec_User.UserId = @I_OrBitUserId and dbo.AssetCheck.WorkflowStepId =@I_Parameter 

			--	return 0

			--end

			

			--if ltrim(@I_Parameter)<>''

			--begin

			--	SELECT  * 

			--			FROM         dbo.AssetCheck INNER JOIN

			--			  dbo.WorkflowStep ON dbo.AssetCheck.WorkflowStepId = dbo.WorkflowStep.WorkflowStepId INNER JOIN

			--			  dbo.Spec_User ON dbo.WorkflowStep.SpecificationId = dbo.Spec_User.SpecificationId

			--			WHERE     dbo.Spec_User.UserId = @I_OrBitUserId and dbo.AssetCheck.WorkflowStepId =@I_Parameter			

			--	return 0

			--end 

			

			--向前台返回所有的数据时执行

			SELECT     *

			FROM        AssetCheck

			return 0

END

