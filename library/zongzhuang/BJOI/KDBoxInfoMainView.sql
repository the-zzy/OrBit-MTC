

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016  1:55PM>

-- Description:	为KDBoxInfo创建主视图

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDBoxInfoMainView]

@I_PKId char(12) =''				--主键

--以上变量为系统服务固定接口参数，必须在每一个MainView过程中实现.

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--执行MainView,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解MainView过程如何编写，请参考我们提供的示例_SampleProjectMainView



	declare @KDOrderInfoId char(12)='',@LabelType nvarchar(50)='',@LabelTypeId char(12)=''

	select @KDOrderInfoId=KDOrderInfoId from KDBoxInfo where KDBoxInfoId=@I_PKId

	

	select @LabelType=b.LabelType, @LabelTypeId=a.KdLabelTypeId  from KDOrderInfo a 

	left join KDLabelType b on b.KDLabelTypeId=a.KDLabelTypeId	

	where a.KDOrderInfoId=@KDOrderInfoId

	

	select BoxLevel,BoxType,@LabelTypeId as LabelTypeId,@LabelType as LabelType from KDBoxInfo where KDBoxInfoId=@I_PKId



	return 0



END



