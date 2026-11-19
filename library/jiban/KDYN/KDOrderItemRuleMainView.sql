
-- =============================================
-- Author:		<benson>
-- Create date: <11 28 2016  6:38PM>
-- Description:	为KDOrderItemRule创建主视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
create PROCEDURE [dbo].[KDOrderItemRuleMainView]
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
                FewHex,
                AllBits,
                PrefixBits,
                StartBits,
                EndBits,
                MinValue,
                MaxValue,
                IsSole,
                ContainsChar
			FROM        KDOrderItemRule
			where KDOrderItemRuleId=@I_PKId
			return 0

END