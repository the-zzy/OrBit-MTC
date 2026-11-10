

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016 12:03PM>

-- Description:	为KDOrderInfo创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDOrderInfoMainView] @I_PKId CHAR(12) = ''				--主键

--以上变量为系统服务固定接口参数，必须在每一个MainView过程中实现.

AS

BEGIN



    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



    SELECT  a.OrderName, a.SOName, a.ProductId, a.ProductCode AS ProductName, a.IsSplitBatch,

            f.ProductDescription AS OrderDescription, a.OrderQty, a.CustomerName, a.CustomerModel, a.HSCode,

            a.ModuleBinningQty, a.RollingPlan, a.OrderDate, a.Brand, a.Panel, a.SKD, a.SupplierCode, a.ProjectNo, a.PONO,

            a.LotNo, a.MadeCountry, a.Country, a.KDLabelTypeId AS LabelTypeId, c.LabelType, b.UserName AS CreateUserName,

            a.CreateDate, a.CustomerAddress, a.LMNYPCustomerModel, a.LMNYPPINO, a.LMNYSCustomerModel, a.LMNYSPINO

    FROM    KDOrderInfo a WITH ( NOLOCK )

    LEFT JOIN SysUser b WITH ( NOLOCK ) ON b.UserId = a.CreateUserId

    LEFT JOIN KDLabelType c WITH ( NOLOCK ) ON c.KDLabelTypeId = a.KDLabelTypeId

    LEFT JOIN Product f WITH ( NOLOCK ) ON f.ProductId = a.ProductId

    WHERE   a.KDOrderInfoId = @I_PKId;



    RETURN 0;



END;













