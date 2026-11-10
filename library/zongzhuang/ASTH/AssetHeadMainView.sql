-- =============================================

-- Author:		<yf1002>

-- Create date: <08 20 2018  2:38PM>

-- Description:	为AssetHead创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[AssetHeadMainView] @I_PKId CHAR(12) = ''				--主键

--以上变量为系统服务固定接口参数，必须在每一个MainView过程中实现.

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine

    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--执行MainView,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解MainView过程如何编写，请参考我们提供的示例_SampleProjectMainView



    SELECT  b.DivisionName, a.iscancel, a.AssetTypeName, a.Divisionid, a.AssetCode, a.AssetTypeid, a.WeixinChart

    FROM    AssetHead a

    INNER JOIN dbo.Division b ON ( b.DivisionId = a.Divisionid )

    WHERE   a.AssetHeadid = @I_PKId;

    RETURN 0;



END;

