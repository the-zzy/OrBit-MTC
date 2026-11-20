
-- =============================================
-- Author:		<OrBit Team >
-- Create date: <2011.9.16>
-- Description:	生成事物对象脚本
-- =============================================
CREATE PROCEDURE [dbo].[MESTxnObjectScriptDoMethod]
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
    @I_Parameter NVARCHAR(100) = ''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;

    DECLARE @SERVERNAME NVARCHAR(50);--DB服务器名称
    SELECT  @SERVERNAME = CAST(SERVERPROPERTY('servername') AS VARCHAR(100));--@@SERVERNAME;
    DECLARE @ExportURL NVARCHAR(100);--用于保存文件的服务器目录
    SET @ExportURL = 'C:\OrBitExport\';  
 
    DECLARE @MESTxnObjectId NVARCHAR(12);


    SET @MESTxnObjectId = @I_PKid; 

--获取所以升级的表名称
    IF ( OBJECT_ID('tempdb..#TableTemp') IS NOT NULL )
    BEGIN
        DROP TABLE #TableTemp;
    END; 
    CREATE TABLE #TableTemp
        (
          ObjectName NVARCHAR(50) ,--对象名称
          ObjectType INT--对象类型  0-为表  1-为存错过程 2-viewList
        );

--创建数据对象实体表  
    IF EXISTS ( SELECT  name
                FROM    sysobjects
                WHERE   name = 'MData_Script' AND type = 'u' )
    BEGIN
        DROP TABLE MData_Script;
    END; 
    CREATE TABLE MData_Script ( MDatatext VARCHAR(MAX) );


    INSERT  INTO MData_Script ( MDatatext )
    VALUES  ( '
--**==================================================------
--****************************************************------
--**注意：执行脚本前请先删除 事物对象数据
--****************************************************------
--**==================================================------
' ); 
--创建存储过程实体表  
    IF EXISTS ( SELECT  name
                FROM    sysobjects
                WHERE   name = 'MProcedure_Script' AND type = 'u' )
    BEGIN
        DROP TABLE MProcedure_Script;
    END; 
    CREATE TABLE MProcedure_Script
        (
          MProceduretext VARCHAR(MAX)
        );

    INSERT  INTO MProcedure_Script ( MProceduretext )
    VALUES  ( '
--**==================================================------
--****************************************************------
--**注意：1,执行脚本前请确认事物对应的表存在
--**      2,元对象 Old存储过程将被覆盖，存储过程更新包括 ViewList过程的更新
--****************************************************------
--**==================================================------
' ); 
 -------============读取基本信息========----------
    INSERT  #TableTemp ( ObjectName, ObjectType )----获取事物参数ViewList
            SELECT  ValueList, 2
            FROM    dbo.MESTxnObjectParameter
            WHERE   ValueList <> '' AND MESTxnObjectId = @MESTxnObjectId;
  
    INSERT  #TableTemp ( ObjectName, ObjectType )----获取事物方法DoTxn
            SELECT  SQLDoTxn, 1
            FROM    dbo.MESTxnObjectMethod
            WHERE   SQLDoTxn <> '' AND MESTxnObjectId = @MESTxnObjectId;


--判断过程是否存在
    DECLARE @ProcedureText0 VARCHAR(MAX);
    SET @ProcedureText0 = ''; 
--存储过程
    DECLARE @ProcedureText VARCHAR(MAX);
    SET @ProcedureText = '';

------------游标变量------------
    DECLARE @ObjectType NVARCHAR(5);
    DECLARE @CopyObjectName NVARCHAR(100); 
    SET @CopyObjectName = '';
 
  ----------====开始挖取脚本=---------
    DECLARE CUR_UpgradeTableTemp CURSOR
    FOR
    SELECT  ObjectName, ObjectType
    FROM    #TableTemp
    ORDER BY ObjectType DESC;
    OPEN CUR_UpgradeTableTemp;  
    FETCH NEXT FROM CUR_UpgradeTableTemp
 	INTO @CopyObjectName, @ObjectType;
    WHILE @@FETCH_STATUS = 0
    BEGIN  
		 -----------============生成存储过程更新脚本
		 ----------------print  @CopyObjectName
        SET @ProcedureText0 = '-----=====================[' + @CopyObjectName + '](如果存储过程存在,就删除后重新创建)==================================---
if exists (select * from dbo.sysobjects where id = object_id(''' + @CopyObjectName + ''') and OBJECTPROPERTY(id, N''IsProcedure'') = 1)
   begin
	  DROP PROCEDURE ' + @CopyObjectName + '
   end
GO
';
        SET @ProcedureText = '';
        IF EXISTS ( SELECT  *
                    FROM    dbo.sysobjects
                    WHERE   id = OBJECT_ID('' + @CopyObjectName + '') AND OBJECTPROPERTY(id, 'IsProcedure') = 1 )
        BEGIN ---------判断过程是否存在
            DECLARE CUR_ProcedureText CURSOR
            FOR
            SELECT  [text]
            FROM    dbo.syscomments
            WHERE   id IN ( SELECT  [id]
                            FROM    sysobjects
                            WHERE   type = 'p' AND name = @CopyObjectName ); 
            OPEN CUR_ProcedureText;
            FETCH NEXT FROM CUR_ProcedureText
					INTO @ProcedureText;
            WHILE @@FETCH_STATUS = 0
            BEGIN  
                SET @ProcedureText0 = LTRIM(@ProcedureText0) + @ProcedureText;
                FETCH NEXT FROM CUR_ProcedureText INTO @ProcedureText; 
            END;
            CLOSE CUR_ProcedureText;
            DEALLOCATE CUR_ProcedureText; 
        END;
        IF LEN(@ProcedureText) > 0
        BEGIN
            INSERT  INTO MProcedure_Script ( MProceduretext )
            VALUES  ( LTRIM(@ProcedureText0) + '
GO' ); --------------插入脚本
        END;
        SET @ProcedureText = '';
        SET @ProcedureText0 = '';	---清空数据  
		
		
		
           
        FETCH NEXT FROM CUR_UpgradeTableTemp INTO @CopyObjectName, @ObjectType;
    END;
    CLOSE CUR_UpgradeTableTemp;
    DEALLOCATE CUR_UpgradeTableTemp;  
	
	 
 
    DECLARE @MESTxnObjectText VARCHAR(MAX);
    SET @MESTxnObjectText = '';
    EXEC [dbo].[MESTxnObjectDataText]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @MESTxnObjectText = @MESTxnObjectText OUTPUT ,
        @IsDeclare = 1 ,
        @I_PKId = @MESTxnObjectId;
    INSERT  INTO MData_Script ( MDatatext )
    VALUES  ( LTRIM(@MESTxnObjectText) );
    SET @MESTxnObjectText = '';
 
 


-- 允许配置高级选项
    EXEC sp_configure
        'show advanced options' ,
        1;
-- 重新配置
    RECONFIGURE;
-- 启用xp_cmdshell
    EXEC sp_configure
        'xp_cmdshell' ,
        1;
--重新配置
    RECONFIGURE; 


    DECLARE @dbName NVARCHAR(100);
    SELECT  @dbName = name
    FROM    master..sysdatabases
    WHERE   dbid = (
                     SELECT dbid
                     FROM   master..sysprocesses
                     WHERE  spid = @@spid
                   ); 
    DECLARE @MDataStr NVARCHAR(500);
    DECLARE @MTableStr NVARCHAR(500);
    DECLARE @MProcedureStr NVARCHAR(500);
    SET @MDataStr = 'bcp "select * from [' + ISNULL(@dbName, 'OrBitXIZC') + '].[dbo].[MData_Script]" queryout "' + @ExportURL + '2MESTxn_MData.sql" -S' + @SERVERNAME + ' -T -c -t,';
    SET @MProcedureStr = 'bcp "select * from [' + ISNULL(@dbName, 'OrBitXIZC') + '].[dbo].[MProcedure_Script]" queryout "' + @ExportURL + '1MESTxn_MProcedure.sql" -S' + @SERVERNAME + ' -T -c -t,';

    SET @I_ReturnMessage = 'ServerMessage:' + ISNULL(@I_ReturnMessage, '') + '生成脚本：';
----================生成脚本============--------
    DECLARE @result INT;  

----================生成存储过程脚本============--------
    SET @result = -1;
    EXEC @result = xp_cmdshell
        @MProcedureStr; 
    IF ( @result = 0 )
        SET @I_ReturnMessage = @I_ReturnMessage + '
1MESTxn_MProcedure.sql 成功...';
    ELSE
        SET @I_ReturnMessage = @I_ReturnMessage + '
1MESTxn_MProcedure.sql 失败...';

--================生成元对象数据脚本============--------
    SET @result = -1;
    EXEC @result = xp_cmdshell
        @MDataStr;  
    IF ( @result = 0 )
        SET @I_ReturnMessage = @I_ReturnMessage + '
2MESTxn_MData.sql 成功...';
    ELSE
        SET @I_ReturnMessage = @I_ReturnMessage + '
2MESTxn_MData.sql 失败...'; 
--EXEC xp_cmdshell @MDataStr
--EXEC xp_cmdshell @MTableStr  
--EXEC xp_cmdshell @MProcedureStr
--EXEC xp_cmdshell 'bcp "select ''注意：执行脚本前请先删除本元对象及其相关联的子元对象数据''" queryout "C:\注意.txt" -T -c -t,'
--用完后,要记得将xp_cmdshell禁用(从安全角度安全考虑)
-- 允许配置高级选项
    EXEC sp_configure
        'show advanced options' ,
        1;
-- 重新配置
    RECONFIGURE;
-- 禁用xp_cmdshell
    EXEC sp_configure
        'xp_cmdshell' ,
        1;
--重新配置
    RECONFIGURE;

--删除临时表 
    DROP TABLE #TableTemp;
--删除实体表
    DROP TABLE MData_Script; 
    DROP TABLE MProcedure_Script;

    RETURN 0;

END;



