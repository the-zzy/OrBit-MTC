-- =============================================

-- Author:		<OrBit Team >

-- Create date: <2008.8.8>

-- Description:	保存UserCode，支持Insert以

-- 及Update以及规则检查

-- =============================================

CREATE PROCEDURE [dbo].[UserCodeSaveData]

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

    @I_Parameter NVARCHAR(100) = '' ,			--插件参数

--以上变量为服务固定接口参数，必须在每一个Save过程中实现。



--以下参与必须与该元对象数据在MetadataField表中提供的字段一一对应。

--警告:	以下变量请一定要赋以默认值，否则前台程序会报错

--提示：元数据在MetadataField表中提供的所有字段必须全部包含在Save过程中

--      否则会导致因在更新时为参数不找到出前台程序报错。>

    @UserCodeName NVARCHAR(100) = '' ,

    @UserCodeDescription NVARCHAR(200) = '' ,

    @ParentUserCodeId CHAR(12) = '' ,

    @Parameter1 NVARCHAR(100) = '' ,

    @Parameter2 NVARCHAR(100) = '' ,

    @Parameter3 NVARCHAR(100) = ''

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



	--初始化一些变量

    DECLARE @ModifyObject NVARCHAR(50);

    DECLARE @ModifyType NVARCHAR(20);

    DECLARE @return_value INT;

    DECLARE @S_ReturnMessage NVARCHAR(100);



    DECLARE @FieldsValueOld NVARCHAR(MAX);

    DECLARE @FieldsValueNew NVARCHAR(MAX);

    DECLARE @FieldsChanged NVARCHAR(MAX);

    DECLARE @Divisionid VARCHAR(12)= '';

    SELECT  @Divisionid = DivisionId

    FROM    SysUser WITH ( NOLOCK )

    WHERE   UserId = @I_OrBitUserId;



    SET @I_ReturnMessage = '';

    SET @I_IsNewRow = 0;

    SET @I_ExceptionFieldName = '';

    SET @ModifyObject = 'UserCode';   --这里必须要是当前操作的表名

    SET @ModifyType = '';

	

	--没有申请到主键就退出

    IF LTRIM(@I_PKId) = ''

    BEGIN

        SET @I_ReturnMessage = 'No PKId applied';

        RETURN -1;

    END;



	--各种规则检查段开始

	--判断是否有命名冲突

    IF EXISTS ( SELECT  UserCodeId

                FROM    dbo.UserCode

                WHERE   UserCodeName = @UserCodeName AND UserCodeId != @I_PKId AND ParentUserCodeId = @I_ParentPKId )

    BEGIN

        SET @I_ReturnMessage = 'NamingConflicts';

        SET @I_ExceptionFieldName = 'UserCodeName';

        RETURN -1;

    END;

	

	--判断是否是新增的记录

    IF NOT EXISTS ( SELECT  UserCodeId

                    FROM    dbo.UserCode

                    WHERE   UserCodeId = @I_PKId )

    BEGIN		



		--新增

		--执行主表的Insert

        INSERT  INTO dbo.UserCode ( UserCodeId, UserCodeName, UserCodeDescription, ParentUserCodeId, Divisionid,

                                    Parameter1, Parameter2, Parameter3 )

        VALUES  ( @I_PKId, @UserCodeName, @UserCodeDescription, @I_ParentPKId, @Divisionid, @Parameter1, @Parameter2,

                  @Parameter3 );



        SET @I_IsNewRow = 1;		

        SET @ModifyType = 'Insert';



        IF @I_ParentPKId = 'URC1000000UH'

        BEGIN

            SET @I_ReturnMessage = 'Mes:请检查料号的解冻时间！时否增加！';

        END;



		--获取刚刚插入的记录

        EXEC SysGetTableFieldsCombine

            @ModifyObject ,

            @I_PKId ,

            @FieldsChanged OUTPUT;



    END;

    ELSE

    BEGIN



		--检查记录是否受到保护

        DECLARE @Protected BIT;	



        SELECT  @Protected = Protected

        FROM    dbo.UserCode

        WHERE   UserCodeId = @I_PKId; 



		--获更新前的记录

        EXEC SysGetTableFieldsCombine

            @ModifyObject ,

            @I_PKId ,

            @FieldsValueOld OUTPUT;



        UPDATE  dbo.UserCode

        SET     UserCodeName = @UserCodeName, UserCodeDescription = @UserCodeDescription,

                ParentUserCodeId = @I_ParentPKId, Divisionid = @Divisionid, Parameter1 = @Parameter1,

                Parameter2 = @Parameter2, Parameter3 = @Parameter3

        WHERE   UserCodeId = @I_PKId; 



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

    END;



	--最后将所做的修改写入修改历史中

    IF @FieldsChanged <> ''

        EXEC [dbo].[SysWriteInModifyHistory]

            @ObjectName = @ModifyObject ,

            @TablePKId = @I_PKId ,

            @ModifyType = @ModifyType ,

            @UserName = @I_OrBitUserName ,

            @ModifyHistory = @FieldsChanged;



    RETURN 0;



END;



