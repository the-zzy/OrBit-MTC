
-- =============================================
-- Author:		<Wang AL>
-- Create date: <2019.07.03>
-- Description:	设备点检查询
-- =============================================

/*


*/
CREATE PROCEDURE [dbo].[EquCheckQueryDoMethod]
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
    @I_Parameter NVARCHAR(100) = '' ,		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
--YYMM,Operator,ObjectType,AssetTypeName,Assetheadid,typecode
    @yymm VARCHAR(6) ,
    @Operator CHAR(20) = '' ,
    @ObjectType NVARCHAR(20) = '' ,
    @AssetTypeName NVARCHAR(30) = '' ,
    @Assetheadid VARCHAR(12) = '' ,
    @typecode VARCHAR(1) = '' ,
    @workcenterid VARCHAR(12) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--写入查看日志

    DECLARE @SDate INT;
    DECLARE @EDate INT;
    DECLARE @CurrMonth DATETIME= '';
    DECLARE @NextMonth DATETIME= '';
    DECLARE @StrSql NVARCHAR(4000)= '';
    DECLARE @StrDay VARCHAR(20)= '';
	DECLARE @StrWhere VARCHAR(4000)=''
    DECLARE @DaySeq INT= 0;
	DECLARE @divisionid VARCHAR(12)=''
	--SELECT @divisionid = DivisionId FROM sysuser WITH(NOLOCK) where userid = @I_OrBitUserId

	SELECT @divisionid = b.ServiceDivisionid FROM dbo.SysUser a WITH(NOLOCK)
	INNER JOIN dbo.Division b  WITH(NOLOCK) ON b.DivisionId = a.DivisionId WHERE UserId = @I_OrBitUserId
	DECLARE @divison TABLE (divisionid VARCHAR(12))
	
	INSERT INTO  @divison
	SELECT DivisionId  FROM dbo.Division WHERE ServiceDivisionid = @divisionid
	

    SET @SDate = '';
    SET @EDate = '';
	
    IF ISNULL(@yymm, '') = '' AND ISNULL(@Assetheadid, '') = '' AND ISNULL(@Operator, '') = '' AND ISNULL(@typecode, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:必须输入一项查询!';
        RETURN -1;

    END;	

    IF ISNULL(@I_Sender, '') = 'DayCheck'
    BEGIN 

	IF @workcenterid='WKC1000001UC' -- 钢网房
	BEGIN
    
		
        SELECT DISTINCT
                a.AssetNum, CASE 
				WHEN a.AssetNum IN('2002455','3006637','2003980','2002331','2003699','3006452')  THEN b.TypeName
				ELSE b.Descriptionx END AS Descriptionx, '钢网房' AS  WorkcenterName, a.CheckYYMM,c.objectType, D01, D02, D03, D04, D05, D06, D07, D08, D09,
                D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26, D27, D28, D29, D30,
                D31, a.Operator, e.PersonName
        FROM    dbo.AssetCheck a
        INNER JOIN dbo.AssetDetail b ON b.AssetDetailid = a.AssetDetailid --AND b.Divisionid = @divisionid
        INNER JOIN dbo.AssetHead q ON q.AssetHeadid = a.Assetheadid
        INNER JOIN dbo.AssetTypeObject c ON c.AssetTypeObjectid = a.AssetTypeObjectId AND c.AssetHeadid = a.Assetheadid
        LEFT JOIN dbo.PersonInfo e ON e.PersonNumber = a.Operator
        LEFT JOIN dbo.Workcenter f ON f.WorkcenterId = a.WorkCenterId
		--INNER JOIN @divison k ON k.divisionid = b.Divisionid
        WHERE   LEFT(c.Value, 1) = 'D'  AND  a.AssetNum IN('2002455','3006637','2003980','2002331','2003699','3006452') AND (
                                             a.CheckYYMM = @yymm OR ISNULL(@yymm, '') = ''
                                           ) AND (
                                                   a.Operator = @Operator OR ISNULL(@Operator, '') = ''
                                                 ) AND (
                                                         b.AssetHeadid = @Assetheadid OR ISNULL(@Assetheadid, '') = ''
                                                       
                                                             ) AND ISNULL(a.AssetTypeObjectId, '') <> '';

   
   

	END
    ELSE
    BEGIN
    

        SELECT DISTINCT
                a.AssetNum, CASE 
				WHEN a.AssetNum IN('2002455','3006637','2003980','2002331','2003699','3006452')  THEN b.TypeName
				ELSE b.Descriptionx END AS Descriptionx, f.WorkcenterName, a.CheckYYMM,c.objectType, D01, D02, D03, D04, D05, D06, D07, D08, D09,
                D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26, D27, D28, D29, D30,
                D31, a.Operator, e.PersonName
        FROM    dbo.AssetCheck a
        INNER JOIN dbo.AssetDetail b ON b.AssetDetailid = a.AssetDetailid --AND b.Divisionid = @divisionid
        INNER JOIN dbo.AssetHead q ON q.AssetHeadid = a.Assetheadid
        INNER JOIN dbo.AssetTypeObject c ON c.AssetTypeObjectid = a.AssetTypeObjectId AND c.AssetHeadid = a.Assetheadid
        LEFT JOIN dbo.PersonInfo e ON e.PersonNumber = a.Operator
        LEFT JOIN dbo.Workcenter f ON f.WorkcenterId = a.WorkCenterId
		--INNER JOIN @divison k ON k.divisionid = b.Divisionid
        WHERE   LEFT(c.Value, 1) = 'D'  AND (LEFT(f.WorkcenterName,1) IN( 'S','A') OR a.AssetNum IN('2002455','3006637','2003980','2002331','2003699','3006452')
		) AND (
                                             a.CheckYYMM = @yymm OR ISNULL(@yymm, '') = ''
                                           ) AND (
                                                   a.Operator = @Operator OR ISNULL(@Operator, '') = ''
                                                 ) AND (
                                                         b.AssetHeadid = @Assetheadid OR ISNULL(@Assetheadid, '') = ''
                                                       ) AND (
                                                               f.WorkcenterId = @workcenterid OR ISNULL(@workcenterid,
                                                                                                        '') = ''
                                                             ) AND ISNULL(a.AssetTypeObjectId, '') <> '';

   
   
   
   
	END
    
   
   
    END; 


    IF ISNULL(@I_Sender, '') = 'WeekCheck'
    BEGIN 
        SET @DaySeq = 1;
        SET @CurrMonth = LEFT(@yymm, 4) + '-' + RIGHT(@yymm, 2) + '-01';
        SET @NextMonth = DATEADD(MONTH, 1, @CurrMonth);

        WHILE @CurrMonth < @NextMonth
        BEGIN 
            SET LANGUAGE N'English';
            IF DATENAME(WEEKDAY, @CurrMonth) = 'Monday'
            BEGIN 
                SET @StrDay = ISNULL(@StrDay, '') + 'D' + RIGHT('00' + CAST(@DaySeq AS VARCHAR(30)), 2) + ',';
            END; 
            SELECT  @CurrMonth = DATEADD(DAY, 1, @CurrMonth), @DaySeq = @DaySeq + 1;			
        END; 


		SET @StrSql='SELECT DISTINCT a.AssetNum, b.Descriptionx, f.WorkcenterName, a.CheckYYMM,c.objectType, /*  c.ObjectTypeName,*/ ' + @StrDay 
		SET @StrSql = @StrSql + 'a.Operator, e.PersonName
							FROM    dbo.AssetCheck a
							INNER JOIN dbo.AssetDetail b ON b.AssetDetailid = a.AssetDetailid 
							INNER JOIN dbo.AssetHead q ON q.AssetHeadid = a.Assetheadid
							INNER JOIN dbo.AssetTypeObject c ON c.AssetTypeObjectid = a.AssetTypeObjectId AND c.AssetHeadid = a.Assetheadid
							LEFT JOIN dbo.PersonInfo e ON e.PersonNumber = a.Operator
							LEFT JOIN dbo.Workcenter f ON f.WorkcenterId = a.WorkCenterId
							WHERE   LEFT(c.Value, 1) = ''W''  AND LEFT(f.WorkcenterName,1) IN( ''S'',''A'')  AND ISNULL(a.AssetTypeObjectId, '''') <> ''''  '

		IF ISNULL(@yymm,'')<>''
			SET @StrSql=@StrSql + 'AND a.CheckYYMM = ' + QUOTENAME(@yymm,'''')
		IF ISNULL(@Operator,'')<>''
			SET @StrSql=@StrSql + 'AND a.Operator = ' + QUOTENAME(@Operator,'''')
		IF ISNULL(@Assetheadid,'')<>''
			SET @StrSql=@StrSql + 'AND b.AssetHeadid = ' + QUOTENAME(@Assetheadid,'''')
		IF ISNULL(@workcenterid,'')<>''
			SET @StrSql=@StrSql + 'AND f.WorkcenterId = ' + QUOTENAME(@workcenterid,'''')

		PRINT(@StrSql)
		EXEC (@StrSql)


        --SELECT  a.AssetNum, b.Descriptionx, f.WorkcenterName, a.CheckYYMM, c.objectType, c.ObjectTypeName, D01, D02, D03,
        --        D04, D05, D06, D07, D08, D09, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24,
        --        D25, D26, D27, D28, D29, D30, D31, a.Operator, e.PersonName
        --FROM    dbo.AssetCheck a
        --INNER JOIN dbo.AssetDetail b ON b.AssetDetailid = a.AssetDetailid
        --INNER JOIN dbo.AssetHead q ON q.AssetHeadid = a.Assetheadid
        --INNER JOIN dbo.AssetTypeObject c ON c.AssetTypeObjectid = a.AssetTypeObjectId AND c.AssetHeadid = a.Assetheadid
        --LEFT JOIN dbo.PersonInfo e ON e.PersonNumber = a.Operator
        --LEFT JOIN dbo.Workcenter f ON f.WorkcenterId = a.WorkCenterId
        --WHERE   LEFT(c.Value, 1) = 'W' AND (
        --                                     a.CheckYYMM = @yymm OR ISNULL(@yymm, '') = ''
        --                                   ) AND (
        --                                           a.Operator = @Operator OR ISNULL(@Operator, '') = ''
        --                                         ) AND (
        --                                                 b.AssetHeadid = @Assetheadid OR ISNULL(@Assetheadid, '') = ''
        --                                               ) AND (
        --                                                       f.WorkcenterId = @workcenterid OR ISNULL(@workcenterid,
        --                                                                                                '') = ''
        --                                                     ) AND ISNULL(a.AssetTypeObjectId, '') <> '';

    END; 
	

    IF ISNULL(@I_Sender, '') = 'MonthCheck'
    BEGIN 

        SELECT DISTINCT  a.AssetNum, b.Descriptionx, f.WorkcenterName, a.CheckYYMM,  c.objectType, /* c.ObjectTypeName,*/ D27, D28, D29, D30, D31,
                a.Operator, e.PersonName
        FROM    dbo.AssetCheck a
        INNER JOIN dbo.AssetDetail b ON b.AssetDetailid = a.AssetDetailid --and b.Divisionid = @divisionid
        INNER JOIN dbo.AssetHead q ON q.AssetHeadid = a.Assetheadid
        INNER JOIN dbo.AssetTypeObject c ON c.AssetTypeObjectid = a.AssetTypeObjectId AND c.AssetHeadid = a.Assetheadid
        LEFT JOIN dbo.PersonInfo e ON e.PersonNumber = a.Operator
        LEFT JOIN dbo.Workcenter f ON f.WorkcenterId = a.WorkCenterId
		--INNER JOIN @divison k ON k.divisionid = b.Divisionid
        WHERE   LEFT(c.Value, 1) = 'M' AND LEFT(f.WorkcenterName,1) IN( 'S','A') AND (
                                             a.CheckYYMM = @yymm OR ISNULL(@yymm, '') = ''
                                           ) AND (
                                                   a.Operator = @Operator OR ISNULL(@Operator, '') = ''
                                                 ) AND (
                                                         b.AssetHeadid = @Assetheadid OR ISNULL(@Assetheadid, '') = ''
                                                       ) AND (
                                                               f.WorkcenterId = @workcenterid OR ISNULL(@workcenterid,
                                                                                                        '') = ''
                                                             ) AND ISNULL(a.AssetTypeObjectId, '') <> '';

    END; 
		



    RETURN 0;

END;





