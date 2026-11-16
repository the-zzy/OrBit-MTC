-- =============================================
-- Author:		<AMTC MHY>
-- Create date: <2017.03.31>
-- Description:	TV客检报表查询
-- =============================================
CREATE PROCEDURE dbo.Query_AssetKupQueryDoMethod
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKid char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='',		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
--YYMM,Operator,ObjectType,AssetTypeName,Assetheadid,typecode
@yymm     VARCHAR(10),
@Operator char(20)='',
@ObjectType nvarchar(20)='',          --场地
@AssetTypeName nVARCHAR(30)='',
@Assetheadid  VARCHAR(12)='',
@typecode  VARCHAR(1)='',
@workcenterid VARCHAR(12)='',
@Workcentername VARCHAR(20) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--写入查看日志

	IF CAST(SERVERPROPERTY('MachineName') AS VARCHAR) <> (
                                                           SELECT TOP 1
                                                                    ParameterValue
                                                           FROM     SysParameter
                                                           WHERE    ParameterName = '[Report Server]'
                                                         ) AND @I_OrBitUserName NOT IN ('1001942', '1002873','2061399','1003076','1003153')  --raoym 20240327
	BEGIN
			SET @I_ReturnMessage = 'ServerMessage:当前为生产服务器，查询报表请转到报表服务器.当前 ' + CAST(SERVERPROPERTY('MachineName') AS VARCHAR);
			RETURN -1;
	END;

	declare @SDate int
	declare @EDate INT
    DECLARE @divisionid VARCHAR(12)=''
	DECLARE @yymm2 VARCHAR(10) = ''

	set @SDate=''
	set @EDate=''
	
	SELECT @divisionid = b.ServiceDivisionid FROM dbo.SysUser a
	INNER JOIN dbo.Division b ON b.DivisionId = a.DivisionId WHERE UserId = @I_OrBitUserId
	DECLARE @divison TABLE (divisionid VARCHAR(12))
	IF @I_OrBitUserName IN('YF1002')
	BEGIN
	    INSERT INTO @divison
	            ( divisionid )
	    SELECT DISTINCT Divisionid   FROM  AssetDetail
	END
	ELSE
	BEGIN
	  INSERT INTO  @divison
	   SELECT DivisionId  FROM dbo.Division WHERE ServiceDivisionid = @divisionid
	   INSERT INTO  @divison
	   VALUES(@divisionid)
	END
	
	PRINT '222'

	IF ISNULL(@yymm,'')<>''
	BEGIN
		IF LEN(@yymm) <> 6
		BEGIN
			SET @I_ReturnMessage = 'ServerMessage: 点检年月只能是6位数';
			RETURN -1;
		END
        

	END
    

	--if ISNULL(@yymm,'')=''
	--begin
		--set @I_ReturnMessage='ServerMessage:请输入点检的年月!'+@Assetheadid
		--return -1
	--end

	--if ISNULL(@EndDate,'')=''
	--begin
	--	set @I_ReturnMessage='ServerMessage:请输入截止日期!'
	--	return -1
	--end

	IF ISNULL(@yymm,'') ='' AND ISNULL(@Assetheadid,'') ='' AND ISNULL(@Operator,'') ='' AND ISNULL(@typecode,'') =''
	BEGIN
       set @I_ReturnMessage='ServerMessage:必须输入一项查询!'
	   RETURN -1

	end	
		PRINT '222'

        SELECT  a.AssetNum, b.Descriptionx, f.WorkcenterName, a.CheckYYMM, c.objectType, c.ObjectTypeName, D01, D02, D03,
                D04, D05, D06, D07, D08, D09, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24,
                D25, D26, D27, D28, D29, D30, D31, a.Operator, e.PersonName, CASE D01
                                                                               WHEN '/' THEN '[PReStates:XAY0Z]'
                                                                               ELSE '[PReStates:X4Y0Z]'
                                                                             END AS ColorControlId
		INTO #Temp1
        FROM    dbo.AssetCheck a
        INNER JOIN dbo.AssetDetail b ON ( b.AssetDetailid = a.AssetDetailid )
        INNER JOIN dbo.AssetHead q ON ( q.AssetHeadid = a.Assetheadid )
        INNER JOIN dbo.AssetTypeObject c ON (
             c.AssetTypeObjectid = a.AssetTypeObjectId AND c.AssetHeadid = a.Assetheadid
                                            )
        LEFT JOIN dbo.PersonInfo e ON ( e.PersonNumber = a.Operator )
        LEFT JOIN dbo.Workcenter f ON ( f.WorkcenterId = a.WorkCenterId )
        LEFT JOIN @divison k ON k.divisionid = b.Divisionid  
        WHERE   (
                  a.CheckYYMM = @yymm OR ISNULL(@yymm, '') = ''
                ) AND (
                        a.Operator = @Operator OR ISNULL(@Operator, '') = ''
                      ) AND (
                              b.AssetHeadid = @Assetheadid OR ISNULL(@Assetheadid, '') = ''
                            ) AND (
                                    LEFT(c.Value, 1) = @typecode OR ISNULL(@typecode, '') = ''
                                  ) AND (
                                          f.WorkcenterId = @workcenterid OR ISNULL(@workcenterid, '') = ''
                                        ) AND ISNULL(a.AssetTypeObjectId, '') <> ''; --and b.divisionid = @divisionid

		SET @yymm2 = LEFT(@yymm,4) + '-' + RIGHT(@yymm,2) + '-01'
		
	
		
		IF @I_Sender = 'AssetKeepDayQuery'
		BEGIN
			SELECT a.EquipmentNum, b.Descriptionx, a.WorkcenterName, a.CheckDate, a.DealType, a.CheckItem, a.CheckItemResult, a.Operator, d.PersonName, c.PersonName AS AuditUser, a.CreateDate
			FROM EquipmentUpkeep a
        	INNER JOIN dbo.AssetDetail b ON a.EquipmentNum = b.AssetNum			
			LEFT JOIN personinfo e ON b.Operator = e.PersonNumber
			LEFT JOIN PersonInfo d ON a.Operator = d.PersonNumber
			LEFT JOIN PersonInfo c ON a.AuditUser = c.PersonNumber
			WHERE a.CreateDate >= @yymm2 AND a.CreateDate < DATEADD(MONTH,1,@yymm2)
			AND ( b.Operator = @Operator OR ISNULL(@Operator, '') = '') 
			AND ( b.AssetHeadid = @Assetheadid OR ISNULL(@Assetheadid, '') = '')
			AND ( a.WorkcenterName = @Workcentername OR ISNULL(@Workcentername, '') = '')
			GROUP BY a.EquipmentNum, b.Descriptionx, a.WorkcenterName, a.CheckDate, a.DealType, a.CheckItem, a.CheckItemResult, a.Operator, d.PersonName, c.PersonName, a.CreateDate
			ORDER BY a.DealType asc ,a.CheckDate DESC, a.EquipmentNum asc
			
			DROP TABLE #Temp1;
			
			RETURN 0;
		END 

			PRINT '222'



		SELECT DISTINCT
		AssetNum, Descriptionx, a.WorkcenterName, CheckYYMM, objectType, ObjectTypeName,
		D01, CASE WHEN DATEPART(DAY,b.CreateDate) = 1 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T01,
		D02, CASE WHEN DATEPART(DAY,b.CreateDate) = 2 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T02,
		D03, CASE WHEN DATEPART(DAY,b.CreateDate) = 3 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T03,
		D04, CASE WHEN DATEPART(DAY,b.CreateDate) = 4 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T04,
		D05, CASE WHEN DATEPART(DAY,b.CreateDate) = 5 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T05,
		D06, CASE WHEN DATEPART(DAY,b.CreateDate) = 6 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T06,
		D07, CASE WHEN DATEPART(DAY,b.CreateDate) = 7 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T07,
		D08, CASE WHEN DATEPART(DAY,b.CreateDate) = 8 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T08,
		D09, CASE WHEN DATEPART(DAY,b.CreateDate) = 9 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T09,
		D10, CASE WHEN DATEPART(DAY,b.CreateDate) = 10 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T10,
		D11, CASE WHEN DATEPART(DAY,b.CreateDate) = 11 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T11,
		D12, CASE WHEN DATEPART(DAY,b.CreateDate) = 12 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T12,
		D13, CASE WHEN DATEPART(DAY,b.CreateDate) = 13 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T13,
		D14, CASE WHEN DATEPART(DAY,b.CreateDate) = 14 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T14,
		D15, CASE WHEN DATEPART(DAY,b.CreateDate) = 15 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T15,
		D16, CASE WHEN DATEPART(DAY,b.CreateDate) = 16 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T16,
		D17, CASE WHEN DATEPART(DAY,b.CreateDate) = 17 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T17,
		D18, CASE WHEN DATEPART(DAY,b.CreateDate) = 18 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T18,
		D19, CASE WHEN DATEPART(DAY,b.CreateDate) = 19 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T19,
		D20, CASE WHEN DATEPART(DAY,b.CreateDate) = 20 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T20,
		D21, CASE WHEN DATEPART(DAY,b.CreateDate) = 21 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T21,
		D22, CASE WHEN DATEPART(DAY,b.CreateDate) = 22 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T22,
		D23, CASE WHEN DATEPART(DAY,b.CreateDate) = 23 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T23,
		D24, CASE WHEN DATEPART(DAY,b.CreateDate) = 24 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T24,
		D25, CASE WHEN DATEPART(DAY,b.CreateDate) = 25 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T25,
		D26, CASE WHEN DATEPART(DAY,b.CreateDate) = 26 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T26,
		D27, CASE WHEN DATEPART(DAY,b.CreateDate) = 27 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T27,
		D28, CASE WHEN DATEPART(DAY,b.CreateDate) = 28 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T28,
		D29, CASE WHEN DATEPART(DAY,b.CreateDate) = 29 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T29,
		D30, CASE WHEN DATEPART(DAY,b.CreateDate) = 30 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T30,
		D31, CASE WHEN DATEPART(DAY,b.CreateDate) = 31 THEN CONVERT(VARCHAR(20),b.CreateDate,120) ELSE '' END AS T31,
		a.Operator, a.PersonName
		INTO #Temp2
		FROM #Temp1 a
		INNER JOIN EquipmentUpkeep b ON a.AssetNum = b.EquipmentNum		
		WHERE b.CreateDate >= @yymm2 AND b.CreateDate < DATEADD(MONTH,1,@yymm2)

		

			PRINT '222'

		SELECT AssetNum,Descriptionx,WorkcenterName,CheckYYMM,objectType,ObjectTypeName,D01,MAX(T01) AS T01,
		D02,MAX(T02) AS T02,D03,MAX(T03) AS T03,D04,MAX(T04) AS T04,D05,MAX(T05) AS T05,D06,MAX(T06) AS T06,
		D07,MAX(T07) AS T07,D08,MAX(T08) AS T08,D09,MAX(T09) AS T09,D10,MAX(T10) AS T10,D11,MAX(T11) AS T11,
		D12,MAX(T12) AS T12,D13,MAX(T13) AS T13,D14,MAX(T14) AS T14,D15,MAX(T15) AS T15,D16,MAX(T16) AS T16,
		D17,MAX(T17) AS T17,D18,MAX(T18) AS T18,D19,MAX(T19) AS T19,D20,MAX(T20) AS T20,D21,MAX(T21) AS T21,
		D22,MAX(T22) AS T22,D23,MAX(T23) AS T23,D24,MAX(T24) AS T24,D25,MAX(T25) AS T25,D26,MAX(T26) AS T26,
		D27,MAX(T27) AS T27,D28,MAX(T28) AS T28,D29,MAX(T29) AS T29,D30,MAX(T30) AS T30,D31,MAX(T31) AS T31,
		Operator,PersonName
		FROM #Temp2
		GROUP BY AssetNum, Descriptionx, WorkcenterName, CheckYYMM, objectType, ObjectTypeName,D01, D02, D03, 
		D04, D05, D06, D07, D08, D09, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, 
		D24, D25, D26, D27, D28, D29, D30, D31,	Operator, PersonName
		
		DROP TABLE #Temp1;
		DROP TABLE #Temp2


	return 0

END





