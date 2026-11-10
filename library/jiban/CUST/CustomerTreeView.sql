



-- =============================================

-- Author:		<OrBit Team>

-- Create date: <2009.4.20>

-- Description:	<获取Customer的导航树>

-- Rev: 10.00

-- =============================================

CREATE PROCEDURE [dbo].[CustomerTreeView]

@I_PlugInCommand varchar(5)='',			--插件命令

@I_OrBitUserId char(12)='',				--用户ID

@I_OrBitUserName nvarchar(100)='',		--用户名

@I_ResourceId	char(12)='',			--资源ID(如果资源不在资源清单中，那么它将是空的)

@I_ResourceName nvarchar(100)='',		--资源名

@I_FiltCondition	nvarchar(max)='',	--过滤条件表达式

@I_PKId char(12)='',					--主键

@I_ParentPKId char(12)='',				--用于过滤的上级主键

@I_Parameter nvarchar(100)=''			--插件参数

--以上变量为服务固定参数，必须在每一个TreeView过程中进行定义。>

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	

	if @I_PKId<>''

	begin

		SELECT     

			CustomerId,

			CustomerName,

			CustomerAbbr,

			CustomerDescription,

			DeleteFlag,

			ERPDate

		FROM         Customer

		WHERE     (CustomerId = @I_PKId)

		ORDER BY CustomerName



		return 0

	end

	        

	SELECT    

		CustomerId,

		CustomerName,

		CustomerAbbr

	FROM         Customer

	ORDER BY CustomerName



	return 0

END









