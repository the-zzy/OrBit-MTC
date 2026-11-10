

-- =============================================

-- Author:		<yf1002>

-- Create date: <08 29 2018  7:24PM>

-- Description:	为AssetDetail创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[AssetDetailMainView]

@I_PKId char(12) =''				--主键

--以上变量为系统服务固定接口参数，必须在每一个MainView过程中实现.

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--执行MainView,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解MainView过程如何编写，请参考我们提供的示例_SampleProjectMainView



			SELECT     

               a.AssetDetailid,a.AssetHeadid,a.divisionid,c.DivisionName,a.Original_assets,b.AssetTypeName,a.AssetNum,a.Company,a.CostCenter,a.Roomer,

			   a.Location,a.workcenterid,SubCountNum, a.Descriptionx,a.ExtDescription

			FROM        AssetDetail a

			    LEFT JOIN dbo.AssetHead b ON(b.AssetHeadid = a.AssetHeadid)

				LEFT JOIN dbo.Division c ON c.DivisionId = a.divisionid

			where a.AssetDetailId=@I_PKId

			return 0



END