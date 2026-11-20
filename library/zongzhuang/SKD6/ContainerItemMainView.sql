
-- =============================================
-- Author:		<chensengang>
-- Create date: <10 31 2021  5:05PM>
-- Description:	为ContainerItem创建主视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[ContainerItemMainView] @I_PKId CHAR(12) = ''				--主键
--以上变量为系统服务固定接口参数，必须在每一个MainView过程中实现.
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StowageType NVARCHAR(10) = '';

    SELECT  @StowageType = b.StowageType
    FROM    dbo.ContainerItem a
    INNER JOIN dbo.ContainerInfo b ON b.ContainerInfoId = a.ContainerInfoId
    WHERE   ContainerItemId = @I_PKId;

    IF @StowageType = '整机'
    BEGIN
        SELECT  c.OrderName, d.prdname AS ProductName, a.RealQty, b.ContainerPreSN, b.ContainerSN, a.CreateDate,
                a.ModifyDate
        FROM    dbo.ContainerItem a
        LEFT JOIN dbo.ContainerInfo b ON b.ContainerInfoId = a.ContainerInfoId
        LEFT JOIN dbo.OrderFieldSetting c ON c.OrderFieldSettingId = a.KDOrderInfoId
        LEFT JOIN dbo.Product d ON d.ProductId = a.ProductId
        WHERE   a.ContainerItemId = @I_PKId;
    END;
    ELSE
    BEGIN
        SELECT  c.OrderName, d.prdname AS ProductName, a.RealQty, b.ContainerPreSN, b.ContainerSN, a.CreateDate,
                a.ModifyDate
        FROM    dbo.ContainerItem a
        LEFT JOIN dbo.ContainerInfo b ON b.ContainerInfoId = a.ContainerInfoId
        LEFT JOIN dbo.KDOrderInfo c ON c.KDOrderInfoId = a.KDOrderInfoId
        LEFT JOIN dbo.Product d ON d.ProductId = a.ProductId
        WHERE   a.ContainerItemId = @I_PKId;
    END;

    RETURN 0;

END;

