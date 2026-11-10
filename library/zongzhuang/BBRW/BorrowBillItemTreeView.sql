

-- =============================================

-- Author:		<yf1002>

-- Create date: <03  7 2018  3:37PM>

-- Description:	为BorrowBillItem创建导航树视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[BorrowBillItemTreeView]

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

    if @I_PKId<>''  --当SaveData执行完成后刷新单行时执行

	begin

			SELECT    BorrowBillItemId,soName,productname,Qnty as '申请数量',gqnty as '借出扫描数量',wareHouseid as WareHouse,ReturnQty as '归还数量'  

			FROM        BorrowBillItem

			where BorrowBillItemId=@I_PKId 

			return 0

	end

    

	if @I_ParentPKId <> ''

	begin

	   SELECT   BorrowBillItemId,soName,productname,Qnty as '申请数量',gqnty as '借出扫描数量',b.WorkcenterName as WareHouse,ReturnQty as '归还数量'  

			FROM        BorrowBillItem a

			INNER JOIN dbo.Workcenter b ON a.WarehouseId = b.WorkcenterId

			where a.BorrowBillId=@I_ParentPKId 

			return 0

	  

	END

	

	RETURN 0

END