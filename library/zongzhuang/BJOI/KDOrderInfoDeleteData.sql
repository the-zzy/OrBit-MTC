

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016 12:03PM>

-- Description:	删除KDOrderInfo表的数据

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDOrderInfoDeleteData]

    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言

    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID

    @I_PlugInCommand VARCHAR(5) = '' ,			--插件命令

    @I_OrBitUserId CHAR(12) = '' ,				--用户ID

    @I_OrBitUserName NVARCHAR(100) = '' ,		--用户名

    @I_ResourceId CHAR(12) = '' ,			--资源ID(如果资源不在资源清单中，那么它将是空的)

    @I_ResourceName NVARCHAR(100) = '' ,		--资源名

    @I_FiltCondition NVARCHAR(MAX) = '' ,	--过滤条件表达式

    @I_PKId CHAR(12) = '' ,					--主键

    @I_ParentPKId CHAR(12) = '' ,				--用于过滤的上级主键

    @I_Parameter NVARCHAR(100) = ''			--插件参数

--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine	

    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



	--set @I_ReturnMessage='ServerMessage:不允许删除!'

	--return -1



	--SELECT * FROM dbo.KDOrderInfo WHERE OrderName ='ZZ2130003042-2'

	--SELECT * FROM dbo.KDBoxInfo WHERE KDOrderInfoId ='KDOI00000C2M'

--DELETE  from dbo.KDPalletInfo where KDOrderInfoId='KDOI00000C2M'



    IF EXISTS ( SELECT  1

                FROM    KDBoxInfo

                WHERE   KDOrderInfoId = @I_PKId AND IsCancel = 0 )

    BEGIN

        SET @I_ReturnMessage = 'ServerMessage:该订单已产生外箱，不允许删除!' + @I_PKId;

        RETURN -1;

    END;

    

    IF EXISTS ( SELECT  1

                FROM    dbo.KDPalletInfo

                WHERE   KDOrderInfoId = @I_PKId AND IsCancel = 0 )

    BEGIN

        SET @I_ReturnMessage = 'ServerMessage:该订单已产生栈板，不允许删除!' + @I_PKId;

        RETURN -1;

    END;



	--执行Delete

	--如果您不了解Delete过程如何编写，请参考我们提供的示例_SampleProjectDeleteData

	--获取删除前的记录	

    DECLARE @FieldsChanged NVARCHAR(MAX);

    EXEC SysGetTableFieldsCombine

        'KDOrderInfo' ,

        @I_PKId ,

        @FieldsChanged OUTPUT;



    DELETE  KDOrderInfo

    WHERE   KDOrderInfoId = @I_PKId; 



	--将所做的删除写入修改历史中

    EXEC [dbo].[SysWriteInModifyHistory]

        @ObjectName = 'KDOrderInfo' ,

        @TablePKId = @I_PKId ,

        @ModifyType = 'Delete' ,

        @UserName = @I_OrBitUserName ,

        @ModifyHistory = @FieldsChanged;



END;







