

-- =============================================

-- Author:		<yf1002>

-- Create date: <03  7 2018  3:03PM>

-- Description:	为BorrowBill创建导航树视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[BorrowBillTreeView]

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

			SELECT   e.BorrowBillId,  e.OAID AS OANAME,e.FactoryName,e.DepartName,f.qnty as '申请数量1',f.gqnty as '借出数量'

			FROM        BorrowBill e

			       left join (select borrowbillid,sum(qnty) as qnty,sum(gqnty) as gqnty from BorrowBillItem where borrowbillid = @I_ParentPKId group by BorrowBillId ) f

				   on (f.BorrowBillId = e.BorrowBillId )

			where e.BorrowBillId=@I_ParentPKId 

			return 0

	end

	if @I_PKId<>''  --当SaveData执行完成后刷新单行时执行

	begin

			SELECT   e.BorrowBillId,  e.OAID AS OANAME,e.FactoryName,e.DepartName as '借出部门',

			         case when isnull(g.gqnty,0) = 0 then '未借机' 

					      when isnull(g.qnty,0) > isnull(g.gqnty ,0) then '部分借出'

						  when isnull(g.qnty,0) = isnull(g.gqnty,0)  then '借出完' 

						  end

						  as '借机状态',

					 case when isnull(f.rqty,0) = 0 then '未还机' 

					      when isnull(f.rqty,0) >0 and  isnull(f.rqty,0) < isnull(g.qnty,0) then '部分归还'

						  when isnull(g.qnty,0) = isnull(f.rqty,0) then '已结单' end

						  as '归还状态'

			FROM        BorrowBill e

			       left join (select Borrowbillid,

                               sum(case  when borrowtype = '0'  then borrowbillqty else 0 end) as bqty,

	                            sum(case  when borrowtype = '1'  then borrowbillqty else 0 end) as rqty     from BorrowBillSubmit where borrowbillid = @I_PKId group by BorrowBillId ) f

				   on (f.BorrowBillId = e.BorrowBillId )

				   left join (select borrowbillid,sum(qnty) as qnty,sum(gqnty) as gqnty from BorrowBillItem where borrowbillid = @I_PKId   group by BorrowBillId ) g

				   on (g.BorrowBillId = e.BorrowBillId )

			return 0

	end

			

	--向前台返回所有的数据时执行

	SELECT   e.BorrowBillId,  e.OAID AS OANAME,e.FactoryName,e.DepartName as '借出部门',

	         CASE when isnull(g.gqnty,0) = 0 AND DATEADD(DAY, -7, GETDATE()) > e.CreaDate then '已过期'  

		          when isnull(g.gqnty,0) = 0 then '未借机' 

			      when isnull(g.qnty,0) > isnull(g.gqnty ,0) then '部分借出'

				  when isnull(g.qnty,0) = isnull(g.gqnty,0)  then '借出完' 

				  end

				  as '借机状态',

			 case when isnull(f.rqty,0) = 0 then '未还机' 

			      when isnull(f.rqty,0) >0 and  isnull(f.rqty,0) < isnull(g.qnty,0) then '部分归还'

				  when isnull(g.qnty,0) = isnull(f.rqty,0) then '已结单' end

				  as '归还状态',





			case when  isnull(g.gqnty,0) = 0  then  '[RowColor:Y4A]' 

			        when  isnull(g.qnty,0) > isnull(g.gqnty ,0) then '[RowColor:Y4Z]'

					when  isnull(g.qnty,0) = isnull(g.gqnty,0) then '[RowColor:YDZ]'  

			        when  isnull(f.rqty,0) = 0  then '[RowColor:YAZ]' 

					when  isnull(f.rqty,0) >0 and  isnull(f.rqty,0) < isnull(g.qnty,0) then '[RowColor:A2Z]' 

					when  isnull(g.qnty,0) = isnull(f.rqty,0) then '[RowColor:YDZ]' 

					end

		            ColorControlId  	     



	FROM        BorrowBill e

	       left join (select Borrowbillid,

                       sum(case  when borrowtype = '5'  then borrowbillqty else 0 end) as bqty,

                        sum(case  when borrowtype = '6'  then borrowbillqty else 0 end) as rqty     from BorrowBillSubmit  group by BorrowBillId ) f

		   on (f.BorrowBillId = e.BorrowBillId )

		   left join (select borrowbillid,sum(qnty) as qnty,sum(gqnty) as gqnty from BorrowBillItem  group by BorrowBillId ) g

		   on (g.BorrowBillId = e.BorrowBillId )

	  WHERE e.CreaDate > DATEADD(DAY, -180, GETDATE())

			

	  return 0

END



-- select * from BorrowBillsubmit