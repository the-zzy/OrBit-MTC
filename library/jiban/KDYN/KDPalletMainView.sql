
-- =============================================
-- Author:		<benson>
-- Create date: <07  6 2016  5:59PM>
-- Description:	为KDPalletInfo创建主视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDPalletMainView]
@I_PKId char(12) =''				--主键
--以上变量为系统服务固定接口参.
AS
BEGIN
	-- This Stored Procedure is created by OrBit-MetaObject engine
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	--执行MainView,注意：以下过程必须根据业务的需求进行调整
	--如果您不了解MainView过程如何编写，请参考我们提供的示例_SampleProjectMainView


	SELECT PalletSN, CountQty, L, W, H, PNETWEIGHT, PGROSSWEIGHT, PrintCount		
	FROM  KDPalletInfo
	where KDPalletInfoId=@I_PKId
	return 0

END