

-- =============================================

-- Author:		<yf1002>

-- Create date: <08 31 2018  2:56PM>

-- Description:	为AssetCheck创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

create PROCEDURE [dbo].[AssetCheckMainView]

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

                D22,

                AssetDetailid,

                D03,

                D08,

                D28,

                D19,

                CheckYYMM,

                D31,

                D11,

                D25,

                D20,

                D14,

                D01,

                Operator,

                D26,

                D17,

                Assetheadid,

                D23,

                D18,

                CreateUserid,

                D12,

                AssetTypeObjectId,

                D21,

                D15,

                D06,

                D09,

                D29,

                D16,

                AssetNum,

                D10,

                D24,

                D30,

                D02,

                D07,

                D13,

                D27

			FROM        AssetCheck

			where AssetCheckId=@I_PKId

			return 0



END