

-- =============================================
-- Author:		<OBit Team phoenix>
-- Create date: <2016.04.26>
-- Description:	<SMT炉后目检采集>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[MOStoveStationScan_ViewListEx]
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @QueryParameter NVARCHAR(100) = ''	--值列表级联时使用
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @WorkcenterName NVARCHAR(50);

    SET @WorkcenterName = '';

    SELECT  @WorkcenterName = Workcenter.WorkcenterName
    FROM    SysUser(NOLOCK)
    INNER JOIN Workcenter(NOLOCK) ON Workcenter.WorkcenterId = SysUser.WorkcenterId
    WHERE   UserId = @I_OrBitUserId;
	
	--为工单只显示出自制件以及外协件
    SELECT  MO.MOId, RIGHT(MO.MOName, 10) AS MOName, RIGHT(MO.SOName, 10) AS SOName,
            product.prdname AS ProductName, Product.ProductDescription, Product.MakeupNumber,
            Product.MakeupNumber AS STDMakeupNumber, MO.MOQtyRequired, @WorkcenterName AS WorkcenterName,
            '\\172.16.20.201\1' AS FilePath
    FROM    MO (NOLOCK)
    LEFT JOIN Product (NOLOCK) ON Product.ProductId = MO.ProductId
--    LEFT  JOIN ProductRoot(NOLOCK) ON ProductRoot.ProductRootId = Product.ProductRootId
    WHERE   MO.ModifyDate >= DATEADD(DAY, -100, GETDATE()) AND MO.MOQtyRequired>MO.MOQtyDone
	    AND prdname LIKE '5%'
	UNION
	--为工单只显示出自制件以及外协件
    SELECT  MO.MOId, RIGHT(MO.MOName, 10) AS MOName, RIGHT(MO.SOName, 10) AS SOName,
            product.prdname AS ProductName, Product.ProductDescription, Product.MakeupNumber,
            Product.MakeupNumber AS STDMakeupNumber, MO.MOQtyRequired, @WorkcenterName AS WorkcenterName,
            '\\172.16.20.201\1' AS FilePath
    FROM    MO (NOLOCK)
    LEFT JOIN Product (NOLOCK) ON Product.ProductId = MO.ProductId
   -- LEFT  JOIN ProductRoot(NOLOCK) ON ProductRoot.ProductRootId = Product.ProductRootId
    WHERE   MO.MOName = '001011246709'

    RETURN 0;
 
END;













