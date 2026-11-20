
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016  1:55PM>
-- Description:	为KDBoxInfo创建保存过程
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDBoxInfoSaveData]
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_IsNewRow BIT = 0 OUTPUT ,				--向客户端报告是否是新行
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKId CHAR(12) = '' ,				--主键
    @I_SourcePKId CHAR(12) = '' ,			--执行拷贝时传入的源主键  
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' ,		--插件参数
--以上变量为服务固定接口参数，必须在每一个Save过程中实现。

--以下参与必须与该元对象数据在MetadataField表中提供的字段一一对应。

--警告:	以下变量请一定要赋以默认值，否则前台程序会报错
--提示：元数据在MetadataField表中提供的所有字段必须全部包含在Save过程中
--      否则会导致因在更新时为参数不找到出前台程序报错。>
--提示：以下是用户变量定义段，如有用户变量定义段，请将上面@I_Parameter nvarchar(100)=''后面加上,号！
    @BoxNumber NVARCHAR(50) = '' ,
    @BoxSN NVARCHAR(50) = '' ,
    @BoxLevel NVARCHAR(20) = '' ,
    @BoxType NVARCHAR(20) = '' ,
    @BoxLength DECIMAL(18, 2) = 0 ,
    @BoxWidth DECIMAL(18, 2) = 0 ,
    @BoxHeight DECIMAL(18, 2) = 0 ,
    @NetWeight DECIMAL(18, 2) = 0 ,
    @GrossWeight DECIMAL(18, 2) = 0
--用户变量结束
AS
BEGIN
	-- This Stored Procedure is created by OrBit-MetaObject engine
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	--执行SaveData,注意：以下过程必须根据业务的需求进行调整
	--如果您不了解SaveData过程如何编写，请参考我们提供的示例_SampleProjectSaveData

    DECLARE @ModifyObject NVARCHAR(50);
    DECLARE @ModifyType NVARCHAR(20);
    DECLARE @return_value INT;
    DECLARE @S_ReturnMessage NVARCHAR(100);

    DECLARE @FieldsValueOld NVARCHAR(MAX);
    DECLARE @FieldsValueNew NVARCHAR(MAX);
    DECLARE @FieldsChanged NVARCHAR(MAX);

    SET @I_ReturnMessage = '';
    SET @I_IsNewRow = 0;
    SET @I_ExceptionFieldName = '';
    SET @ModifyObject = 'KDBoxInfo';   --这里必须要是当前操作的表名
    SET @ModifyType = '';
	
    IF NOT EXISTS ( SELECT  1
                    FROM    KDBoxInfo
                    WHERE   KDBoxInfoId = @I_PKId )
    BEGIN
        SET @I_ReturnMessage = 'ServeMessage: 箱号不存在，请检查!';
        RETURN -1;
    END;
	
    IF NOT EXISTS ( SELECT  1
                    FROM    KDBoxType
                    WHERE   BoxType = @BoxType )
    BEGIN
        SET @I_ReturnMessage = 'ServeMessage: 箱子类别不存在，请检查!';
        RETURN -1;
    END;
	
    SELECT  @BoxLength = b.BoxLength, @BoxWidth = b.BoxWidth, @BoxHeight = b.BoxHeight
    FROM    KDBoxType a
    LEFT JOIN KDBoxTypeItem b ON a.KDBoxTypeId = b.KDBoxTypeId
    WHERE   a.BoxType = @BoxType;

    IF ISNULL(@BoxLength, 0) <= 0 OR ISNULL(@BoxWidth, 0) <= 0 OR ISNULL(@BoxHeight, 0) <= 0
    BEGIN
        SET @I_ReturnMessage = 'ServeMessage: 箱子类别的[长/宽/高]没有维护，请检查!';
        RETURN -1;
    END;
	
    IF ISNULL(@GrossWeight, 0) < ISNULL(@NetWeight, 0)
    BEGIN
        SET @I_ReturnMessage = 'ServeMessage: 毛重必须大于净重，请检查!';
        RETURN -1;
    END;
	

	--获更新前的记录
    EXEC SysGetTableFieldsCombine
        @ModifyObject ,
        @I_PKId ,
        @FieldsValueOld OUTPUT;

    UPDATE  KDBoxInfo
    SET     BoxLength = @BoxLength, BoxWidth = @BoxWidth, BoxHeight = @BoxHeight, GrossWeight = @GrossWeight,
            NetWeight = @NetWeight, BoxType = @BoxType
    WHERE   KDBoxInfoId = @I_PKId;

    SET @ModifyType = 'Update';
	--获更新后的记录,并进行比较
    EXEC SysGetTableFieldsCombine
        @ModifyObject ,
        @I_PKId ,
        @FieldsValueNew OUTPUT;
    EXEC SysGetTableFieldsCompare
        @FieldsValueOld ,
        @FieldsValueNew ,
        @FieldsChanged OUTPUT;



    	--最后将所做的修改入修改历史中
    IF @FieldsChanged <> ''
        EXEC [dbo].[SysWriteInModifyHistory]
            @ObjectName = @ModifyObject ,
            @TablePKId = @I_PKId ,
            @ModifyType = @ModifyType ,
            @UserName = @I_OrBitUserName ,
            @ModifyHistory = @FieldsChanged;

    RETURN 0;

END;

