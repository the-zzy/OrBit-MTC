
/*

EXEC dbo.SMTCoverQueryDoMethod
    @I_Sender = N'ds' , -- nvarchar(200)
    @I_ReturnMessage = N'dwa' , -- nvarchar(max)
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
    @CreateDate = '' , -- datetime
    @MONames = N'' , -- nvarchar(50)
    @WorkingTime = '' --nvarchar(50)

*/

CREATE PROCEDURE [dbo].[SMTCoverQueryDoMethod]
    @I_Sender NVARCHAR(200) = '' ,                    --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,      --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,                     --客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,                --插件命令
    @I_OrBitUserId CHAR(12) = '' ,                    --用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,             --用户名
    @I_ResourceId CHAR(12) = '' ,                     --资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,              --资源名
    @I_PKid CHAR(12) = '' ,                           --主键
    @I_ParentPKId CHAR(12) = '' ,                     --父级主键
    @I_Parameter NVARCHAR(100) = '' ,                 --插件参数
	                                                  --以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @CreateDate DATETIME = NULL ,                     --日期 
    @MONames NVARCHAR(50) = '' ,                      --工单
    @WorkingTime NVARCHAR(50) = '' ,                 --班别
    @WorkcenterName NVARCHAR(50) = ''                 --线别
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE @Time NVARCHAR(10) = '';
    DECLARE @Time1 VARCHAR(10) = '';
    SET @Time = CONVERT(NVARCHAR(10), @CreateDate, 120);
    SET @Time1 = CONVERT(NVARCHAR(10), @CreateDate + 1, 120);
    IF ISNULL(@MONames, '') <> ''
        SET @MONames = '00' + @MONames;


    IF ( ISNULL(@CreateDate, '') ) = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入日期!';
        RETURN -1;
    END; 
	--select  @Time,@Time1 
	 
    IF NOT EXISTS ( SELECT  1
                    FROM    SMTOnLineVerify
                    WHERE   CreateDate BETWEEN @Time AND @Time1 )
    BEGIN 
        SET @I_ReturnMessage = 'ServerMessage:当前输入日期有误 请输入正确的日期!';
        RETURN -1;
    END; 
 


    SELECT  c.WorkcenterName, RIGHT(m.MOName, 10) AS MOName, a.MOId, a.ProductId, p.prdname AS PCBProductName,
            b.CreateDate, a.LotProductId, q.prdname MatProductName, a.CreateDate AS OnLineDate,
            b.CreateDate AS CheckDate, 1 AS OnLineFlag, CASE WHEN b.LotProductId IS NOT NULL THEN 1
                                                             ELSE 0
                                                        END AS CheckResult
    INTO    #TempVerifyDetail
    FROM    LotOnSMT a ( NOLOCK )
    LEFT JOIN SMTOnLineVerify b ( NOLOCK ) ON b.MOId = a.MOId AND b.WorkcenterId = a.WorkcenterId AND b.LotProductId = a.LotProductId
    LEFT JOIN dbo.Workcenter c ( NOLOCK ) ON c.WorkcenterId = a.WorkcenterId
    LEFT JOIN dbo.MO m ( NOLOCK ) ON m.MOId = a.MOId
    LEFT JOIN dbo.Product p ( NOLOCK ) ON p.ProductId = a.ProductId
    LEFT JOIN dbo.Product q ( NOLOCK ) ON q.ProductId = a.LotProductId
    WHERE   a.CreateDate >= CONVERT(VARCHAR(10), @CreateDate, 120) AND a.CreateDate < CONVERT(VARCHAR(10), DATEADD(DAY,
                                                                                                        1, @CreateDate), 120)
																										AND  (
                                          MOName = @MONames OR @MONames = ''
                                        ) AND (
                                                WorkcenterName = @WorkcenterName OR @WorkcenterName = ''
                                              ) 

    SELECT   CreateDate, WorkcenterName, MOName, PCBProductName, CheckDate,
            SUM(OnLineFlag) OnLineFlag, SUM(CheckResult) CheckFlag, CAST('' AS NVARCHAR(20)) AS CheckResult
    INTO    #TempVerifyGroup
    FROM    #TempVerifyDetail
    --GROUP BY CONVERT(VARCHAR(10), CreateDate, 120), WorkcenterName, MOName, PCBProductName, CheckDate;

	GROUP BY  CreateDate, WorkcenterName, MOName, PCBProductName, CheckDate;

    UPDATE  #TempVerifyGroup
    SET     CheckResult = CASE WHEN OnLineFlag = CheckFlag THEN 'True'
                               ELSE 'false'
                          END; 

    SELECT  CONVERT(VARCHAR(100), CreateDate, 23) AS '日期', CONVERT(VARCHAR(100), CreateDate, 24) AS '详细时间',
            CASE WHEN CreateDate >= (
                                      SELECT    DATEADD(MINUTE, 450, CONVERT(VARCHAR(10), GETDATE(), 120))
                                    ) AND CreateDate < (
                                                         SELECT DATEADD(MINUTE, 1170,
                                                                        CONVERT(VARCHAR(10), GETDATE(), 120))
                                                       ) THEN '白班'
                 ELSE '夜班'
            END AS '班别', WorkcenterName, MOName, PCBProductName as '产品名', CheckResult
    INTO    #TempWorkGroup
    FROM    #TempVerifyGroup;

    SELECT  DISTINCT *
    FROM    #TempWorkGroup
    WHERE   #TempWorkGroup.日期 = @CreateDate  AND ( #TempWorkGroup.班别 = @WorkingTime OR  ISNULL(@WorkingTime,'')='' );


END;

