
-- =============================================
-- Author:		<Wang RT>
-- Create date: <2020.4.18>
-- Description:	<手贴物料信息查询>
-- Rev:1.00 
-- =============================================
CREATE PROCEDURE [dbo].[HandPasteQueryDoMethod]
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
    @I_Parameter NVARCHAR(MAX) = '' ,                 --插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @CreateDate DATETIME = NULL ,                 --日期 
    @MOName NVARCHAR(50) = '' ,                       --工单号
    @Side NVARCHAR(10) = '' ,                         --A/B面
    @ScanProductName NVARCHAR(50) = ''                   --扫描料号
AS
BEGIN
	
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @sql NVARCHAR(MAX) = '';
    DECLARE @where NVARCHAR(MAX) = '';
    DECLARE @DateFrom VARCHAR(10) = CONVERT(VARCHAR(10), @CreateDate, 120);
    DECLARE @DateTo VARCHAR(10) = CONVERT(VARCHAR(10), @CreateDate + 1, 120);

    SET @CreateDate = CONVERT(VARCHAR(10), @CreateDate, 120);

    IF ISNULL(@CreateDate, '') = '' AND ISNULL(@MOName, '') = '' AND ISNULL(@ScanProductName, '') = ''
    BEGIN
        SET @I_ReturnMessage = '查询条件必须输入一个，请重新输入！';
        RETURN -1;
    END; 

	--IF ISNULL(@CreateDate,'') <> ''
	--BEGIN
	--	SET @where = @where + 'AND CreateDate >= ''' + @DateFrom + ''' AND CreateDate < ''' + @DateTo + ''' '
	--END 

	--IF ISNULL(@MOName,'') <> ''
	--BEGIN
	--	SET @where = @where + 'AND MONAME = ''' + @MOName + ''' '
	--END 

	--IF ISNULL(@ScanProductName,'') <> ''
	--BEGIN
	--	SET @where = @where + 'AND ProductName = ''' + @ScanProductName + ''' '
	--END 

	--SET @sql = 'SELECT MOName,ProductName,Side,Dosage as ''单板用量'',PlannerQty as ''手贴数量'',LotSN,Operator,CONVERT(VARCHAR(10),CreateDate,120) as CreateDate FROM HandPaste WHERE 1 = 1 '

	--SET @sql = @sql + @where

	--PRINT(@sql)

	
	--EXEC(@sql)
    IF ISNULL(@ScanProductName, '') <> ''
    BEGIN
		
        SELECT  LotSN
        INTO    #TempZ
        FROM    dbo.HandPaste
        WHERE   ProductName LIKE '%' + @ScanProductName + '%';

        SELECT  DISTINCT
                MOName, ProductName, Side, Dosage AS 单板用量, PlannerQty AS 手贴数量, LotSN, Operator,
                CONVERT(VARCHAR(10), CreateDate, 120) AS CreateDate,
                ROW_NUMBER() OVER ( PARTITION BY LotSN ORDER BY ProductName DESC ) AS NGSeq
        INTO    #TempX
        FROM    dbo.HandPaste
        WHERE   LotSN IN ( SELECT DISTINCT
                                    LotSN
                           FROM     #TempZ ) AND (
                                                   MOName = @MOName OR @MOName = ''
                                                 ) 

        SELECT  DISTINCT
                b.CreateDate, b.MOName, b.Side, LEFT(NGDesc, LEN(b.NGDesc) - 1) AS ProductName, b.LotSN, b.单板用量, b.手贴数量,
                b.Operator
        FROM    (
                  SELECT    DISTINCT
                            b.CreateDate, b.MOName, b.Side, b.单板用量, b.手贴数量,
                            (
                              SELECT    a.ProductName + ','
                              FROM      #TempX a
                              WHERE     b.LotSN = a.LotSN AND a.NGSeq <= 50
                            FOR
                              XML PATH('')
                            ) AS NGDesc, b.LotSN, b.Operator
                  FROM      #TempX b
                  WHERE     b.NGSeq <= 50
                  GROUP BY  b.CreateDate, b.MOName, b.Side, b.单板用量, b.手贴数量, b.LotSN, b.Operator
                ) b;
        RETURN 0;

    END; 

    SELECT  MOName, ProductName, Side, Dosage AS 单板用量, PlannerQty AS 手贴数量, LotSN, Operator,
            CreateDate,
            ROW_NUMBER() OVER ( PARTITION BY LotSN ORDER BY ProductName DESC ) AS NGSeq
    INTO    #TempA
    FROM    HandPaste
    WHERE   (
              MOName = @MOName OR @MOName = ''
            ) AND (
                    ProductName = @ScanProductName OR @ScanProductName = ''
                  ) 
	
	
    SELECT  b.CreateDate, b.MOName, b.Side, LEFT(NGDesc, LEN(b.NGDesc) - 1) AS ProductName, b.LotSN, b.单板用量, b.手贴数量,
            b.Operator
    FROM    (
              SELECT    b.CreateDate, b.MOName, b.Side, b.单板用量, b.手贴数量, (
                                                                          SELECT    a.ProductName + ','
                                                                          FROM      #TempA a
                                                                          WHERE     b.LotSN = a.LotSN AND a.NGSeq <= 50
                                                                        FOR
                                                                          XML PATH('')
                                                                        ) AS NGDesc, b.LotSN, b.Operator
              FROM      #TempA b
              WHERE     b.NGSeq <= 50
              GROUP BY  b.CreateDate, b.MOName, b.Side, b.单板用量, b.手贴数量, b.LotSN, b.Operator
            ) b;

    RETURN 0;

END;




