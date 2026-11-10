

-- =============================================

-- Author:		<yf1002>

-- Create date: <03 16 2018  5:30PM>

-- Description:	为BorrowBillSubmit创建导航树视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[BorrowBillSubmitTreeView]

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

			SELECT  BorrowBillSubmitID,BorrowBillId,BorrowBillItemid,

			  ProductName,BorrowBillQty,Factory,WareHouseFrom,WareHouseTo,BorrowOperator,

			  CASE WHEN IsSap = '0' THEN '待同步' 

			  	   WHEN IsSap = '1' THEN '同步成功'

			  	   WHEN IsSap = '2' THEN '同步失败' ELSE '' END AS IsSap,

			  TransNumber,SapMesg,SoName,SOItem,BorrowNote,PreTransNumber

			FROM        BorrowBillSubmit

			where BorrowBillId=@I_ParentPKId 

			return 0

	end





		

	if @I_PKId<>''  --当SaveData执行完成后刷新单行时执行

	begin

			SELECT     *

			FROM        BorrowBillSubmit

			where BorrowBillSubmitId=@I_PKId 

			return 0

	end		

			--向前台返回所有的数据时执行

			SELECT     *

			FROM        BorrowBillSubmit

			return 0

END