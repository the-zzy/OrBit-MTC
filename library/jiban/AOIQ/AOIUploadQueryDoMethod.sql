
/*


EXEC dbo.AOIUploadQueryDoMethod
    @I_Sender = N'' , -- nvarchar(200)
    @I_ReturnMessage = N'' , -- nvarchar(max)
    @I_ExceptionFieldName = N'' , -- nvarchar(100)
    @I_LanguageId = '' , -- char(1)
    @I_PlugInCommand = '' , -- varchar(5)
    @I_OrBitUserId = '' , -- char(12)
    @I_OrBitUserName = N'' , -- nvarchar(100)
    @I_ResourceId = '' , -- char(12)
    @I_ResourceName = N'' , -- nvarchar(100)
    @I_PKid = '' , -- char(12)
    @I_ParentPKId = '' , -- char(12)
    @I_Parameter = N'' , -- nvarchar(100)
    @LineNum = 'S28' , -- varchar(20)
    @MOName = '' , -- varchar(20)
    @FromDate = '2018-04-24 17:56:16' , -- datetime
    @ToDate = NULL-- datetime


*/
CREATE  PROCEDURE [dbo].[AOIUploadQueryDoMethod]
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKid CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' ,       --插件参数

--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @LineNum VARCHAR(20) = NULL ,
    @MOName VARCHAR(20) = NULL ,
    @FromDate DATETIME = NULL ,
    @ToDate DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @sql VARCHAR(4000)= '' ,
        @EnterChar VARCHAR(5)= CHAR(10) + CHAR(13);

    SET @sql = @sql + '	SELECT AOIUploadDataId, PCB_SN, PCBA_SN, PathWay, MOName, PCB_Type, LineNum, CheckStatus, CheckDesc,
									CheckDate, CreateDate, Remark
							 FROM  dbo.AOIUploadData (NOLOCK)	WHERE 1=1 ';

    IF ISNULL(@LineNum, '') <> ''
        SET @sql = @sql + ' AND LineNum= ' + QUOTENAME(@LineNum, '''') + @EnterChar;

    IF ISNULL(@MOName, '') <> ''
        SET @sql = @sql + ' AND MOName= ' + QUOTENAME(@MOName, '''') + @EnterChar;

    IF ISNULL(@FromDate, '') <> ''
        SET @sql = @sql + ' AND CheckDate>= ''' + CONVERT(VARCHAR(10), @FromDate, 120) + '''' + @EnterChar;

    IF ISNULL(@ToDate, '') <> ''
        SET @sql = @sql + ' AND CheckDate< ''' + CONVERT(VARCHAR(10), DATEADD(DAY, 1, @ToDate), 120) + '''' + @EnterChar;
	

    PRINT ( @sql );
    EXEC (@sql);

    RETURN 0;

END;





