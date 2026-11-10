

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016  1:55PM>

-- Description:	为KDBoxInfo创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDBoxInfoItemMainView] @I_PKId CHAR(12) = ''				--主键

--以上变量为系统服务固定接口参数，必须在每一个MainView过程中实现.

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine

    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--执行MainView,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解MainView过程如何编写，请参考我们提供的示例_SampleProjectMainView

    DECLARE @KDOrderInfoId CHAR(12)= '' ,

        @LabelName NVARCHAR(100)= '' ,

        @LabelId CHAR(12)= '';



	DECLARE @NewStartBoxSN NVARCHAR(50) = '';

	DECLARE @NewEndBoxSN NVARCHAR(50) = '';



    SELECT  @KDOrderInfoId = KDOrderInfoId

    FROM    KDBoxInfo

    WHERE   KDBoxInfoId = @I_PKId;



	SELECT @NewStartBoxSN = MIN(BoxSN), @NewEndBoxSN = MAX(BoxSN)

	FROM dbo.KDBoxInfo

	WHERE KDOrderInfoId = @KDOrderInfoId



    SELECT  @LabelId = b.LabelId, @LabelName = b.LabelName

    FROM    KDOrderInfo a

    LEFT JOIN Label b ON b.LabelId = a.LabelId

    WHERE   a.KDOrderInfoId = @KDOrderInfoId;



    SELECT  KDBoxInfoId, BoxNumber AS StartBoxSN, BoxNumber AS EndBoxSN, KDOrderInfo.OrderName, @LabelId AS LabelId,

            @LabelName AS LabelName, @NewStartBoxSN AS NewStartBoxSN, @NewEndBoxSN AS NewEndBoxSN

    FROM    KDBoxInfo

    INNER JOIN KDOrderInfo ON KDOrderInfo.KDOrderInfoId = KDBoxInfo.KDOrderInfoId

    WHERE   KDBoxInfoId = @I_PKId;



    RETURN 0;



END;





