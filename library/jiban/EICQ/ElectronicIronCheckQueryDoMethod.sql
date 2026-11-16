
--=======================================
-- Author:		<OrBit Team >
-- Create date: <2008.8.8>
-- Description:	执行_SampleProject元数据的查询示例事件
-- =============================================
CREATE PROCEDURE  [dbo].[ElectronicIronCheckQueryDoMethod]
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
@WorkcenterId CHAR(12) = '',
@DateFrom DATETIME = NULL,
@DateTo DATETIME = NULL

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
		
    IF CAST(SERVERPROPERTY('MachineName') AS VARCHAR) <> (
                                                           SELECT TOP 1
                                                                    ParameterValue
                                                           FROM     SysParameter
                                                           WHERE    ParameterName = '[Report Server]'
                                                         )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:当前为生产服务器，查询报表请转到报表服务器.当前 ' + CAST(SERVERPROPERTY('MachineName') AS VARCHAR);
        RETURN -1;
    END;

	IF ISNULL(@DateFrom,'') = '' AND ISNULL(@DateTo,'') = '' AND ISNULL(@WorkcenterId,'') = ''
	BEGIN
	    SET @I_ReturnMessage = 'ServerMessage: 请输入条件进行查询！';
		RETURN -1;
	END

	IF @I_Sender = 'ElectronicIronVoltageQuery'
	BEGIN
	    
		SELECT '漏电电压' AS 项目,CONVERT(VARCHAR(10),a.CreateDate,120) AS 日期, b.WorkcenterName, a.ElectricitySN, a.TestResult + 'V' AS TestResult, a.SolderTip, a.Operator, c.PersonName, a.CreateDate
		FROM dbo.ElectronicIronCheck a
		LEFT JOIN dbo.Workcenter b ON b.WorkcenterId = a.WorkcenterId
		LEFT JOIN dbo.PersonInfo c ON a.Operator = c.PersonNumber
		WHERE ( a.WorkcenterId = @WorkcenterId OR ISNULL(@WorkcenterId,'') = '' )
		AND ( a.CreateDate > @DateFrom OR ISNULL(@DateFrom,'') = '')
		AND ( a.CreateDate < @DateTo + 1 OR ISNULL(@DateTo,'') = '')
		AND a.TestItem = 'Voltage'
		RETURN 0
	END
	
	IF @I_Sender = 'ElectronicIronTemperatureQuery'
	BEGIN

		DECLARE @TempTable TABLE
		(
			项目 NVARCHAR(50),
			日期 NVARCHAR(50),
			WorkcenterName NVARCHAR(50),
			ElectricitySN NVARCHAR(50),
			TestResult NVARCHAR(50),
			Row NVARCHAR(50)
		)

	    INSERT INTO @TempTable ( 项目, 日期, WorkcenterName, ElectricitySN, TestResult, Row )
		SELECT  '温度' AS 项目, CONVERT(VARCHAR(10), a.CreateDate, 120) AS 日期, b.WorkcenterName, a.ElectricitySN, a.TestResult + '℃' AS TestResult,
            CAST(ROW_NUMBER() OVER ( PARTITION BY CONVERT(VARCHAR(10), a.CreateDate, 120), b.WorkcenterName, a.ElectricitySN ORDER BY a.CreateDate ASC ) AS VARCHAR(10)) + '次'
            AS Row
		FROM    dbo.ElectronicIronCheck a
		LEFT JOIN dbo.Workcenter b ON b.WorkcenterId = a.WorkcenterId
		LEFT JOIN dbo.PersonInfo c ON a.Operator = c.PersonNumber
		WHERE ( a.WorkcenterId = @WorkcenterId OR ISNULL(@WorkcenterId,'') = '' )
		AND ( a.CreateDate > @DateFrom OR ISNULL(@DateFrom,'') = '')
		AND ( a.CreateDate < @DateTo + 1 OR ISNULL(@DateTo,'') = '')
		AND   a.TestItem = 'Temperature';


		SELECT a.项目,a.日期,a.WorkcenterName,a.ElectricitySN,a.[1次],a.[2次],a.[3次],a.[4次],a.[5次],a.[6次]
		FROM @TempTable PIVOT (MAX(TestResult) FOR Row IN ([1次],[2次],[3次],[4次],[5次],[6次]))a  

		RETURN 0
	END
    
	RETURN 0

END

















