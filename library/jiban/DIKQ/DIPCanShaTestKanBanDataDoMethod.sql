-- =============================================
-- Author:		<FZP>
-- Create date: <2025.04.2>
-- Description:	DIP掺沙测试看板数据查询 
-- =============================================
CREATE PROCEDURE [dbo].[DIPCanShaTestKanBanDataDoMethod]
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
--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.
    @StartDate DATETIME = NULL ,
    @EndDate DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	IF ISNULL(@StartDate,'')=''OR ISNULL(@EndDate,'')=''
	BEGIN
		SET @I_ReturnMessage='ServerMessage:开始时间和结束时间不能为空，请检查！'
		RETURN -1
	END

	SELECT
		DISTINCT
		ROW_NUMBER() OVER (ORDER BY WorkcenterName) AS '序号',
		CAST(CAST(TestBeginDate AS DATE) AS NVARCHAR(50)) AS '开始时间',
		WorkcenterName AS '线体',
		MO.SOName AS '订单号',
		CanShaTest.LotSN AS '批号',
		TestItemName +WeiHao AS '测试项',
		AOI.PersonName AS AOI操作员,
		TestResult AS '测试结果',
		ZeRenLaZhang AS 责任拉长,
		IPQC.PersonName AS IPQC
		
	FROM dbo.CanShaTest
	LEFT JOIN dbo.MO ON MO.MOId = CanShaTest.MOId
	LEFT JOIN dbo.SO ON SO.SOName = MO.SOName
	left join deliveryorder on replace( mo.soname ,'484','008') =DeliveryOrder.DeliveryOrderName
	left join customer h on h.customerid = DeliveryOrder.CustomerId
	LEFT JOIN dbo.Customer c ON c.CustomerId = SO.CustomerId
	LEFT JOIN dbo.PersonInfo IPQC ON ResultUser = IPQC.PersonNumber
	LEFT JOIN dbo.Workcenter ON Workcenter.WorkcenterId = CanShaTest.WorkcenterId
	LEFT JOIN DCStoveStationScan ON DCStoveStationScan.LotSN = CanShaTest.LotSN
	LEFT JOIN dbo.PersonInfo AOI ON DCStoveStationScan.Operator = AOI.PersonNumber
	 WHERE   (
                  TestBeginDate >=@StartDate
                ) AND (
                        TestBeginDate <= @EndDate )
		AND WorkcenterName LIKE 'D%'
	ORDER BY WorkcenterName ASC 

    RETURN 0;
END;


