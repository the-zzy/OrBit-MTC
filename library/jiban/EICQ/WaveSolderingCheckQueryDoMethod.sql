
--=======================================
-- Author:		<Wang RT>
-- Create date: <2021.01.15>
-- Description:	波峰焊参数点检查询
-- =============================================
CREATE PROCEDURE  [dbo].[WaveSolderingCheckQueryDoMethod]
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
		
	SELECT	CONVERT(VARCHAR(10),a.CreateDate,120) AS 日期, b.WorkcenterName, a.WaveSolderingSN, a.Model, a.WorkingGroup, a.Operator, c.PersonName, 
			a.SideCount, a.StoveTemperature, a.PreheatOne, a.PreheatTwo, a.PreheatThree, a.AdmissionPressure, a.NozzlePressure, a.SpraySpeed,
			a.ChainSpeed, a.Angle, a.FluxFlow, a.CreateDate, a.ReturnMessage
	FROM dbo.WaveSolderingCheck a
	LEFT JOIN dbo.Workcenter b ON b.WorkcenterId = a.WorkcenterId
	LEFT JOIN dbo.PersonInfo c ON a.Operator = c.PersonNumber
	WHERE ( a.CreateDate > @DateFrom OR ISNULL(@DateFrom,'') = '' )
	AND ( a.CreateDate < @DateTo + 1 OR ISNULL(@DateTo,'') = '' )
	AND ( a.WorkcenterId = @WorkcenterId OR ISNULL(@WorkcenterId,'') = '' )

	RETURN 0

END















