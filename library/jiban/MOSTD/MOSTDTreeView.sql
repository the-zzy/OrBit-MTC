
-- =============================================
-- Author:		<administrator>
-- Create date: <09  1 2009  8:04AM>
-- Description:	为MO创建导航树视图
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[MOSTDTreeView]
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_LanguageId CHAR(1) = '1' ,			--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_FiltCondition NVARCHAR(MAX) = '' ,	--过滤条件表达式
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKId CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = ''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF @I_PKId <> ''
    BEGIN
        SELECT  MOId, RIGHT(MOName, 10) AS MOName, MOTypeId, MOType.UserCodeDescription AS MOType,
                prdname AS ProductName, SOName, MO.MOERPStatus, MO.OrganID AS 'CustmerPo', MO.BatchNum
        FROM    MO
        LEFT JOIN Product ON Product.ProductId = MO.ProductId
        LEFT JOIN UserCode MOType ON MOType.UserCodeId = MO.MOTypeId AND MOType.ParentUserCodeId = 'URC1000000DR'
        LEFT JOIN Factory ON Factory.FactoryId = MO.FactoryId
        LEFT OUTER JOIN (
                          SELECT    dbo.BillStates.BillStates, dbo.BillStates.BillStatesDescription
                          FROM      dbo.Bill
                          LEFT OUTER JOIN dbo.BillStates ON dbo.Bill.BillId = dbo.BillStates.BillId
                          WHERE     ( dbo.Bill.BillName = N'MO' )
                        ) AS MOStatusTable ON MO.MOStatus = MOStatusTable.BillStates
        WHERE   MOId = @I_PKId;
        RETURN 0;
    END;

    IF @I_ParentPKId <> ''
    BEGIN
        SELECT  MOId, RIGHT(MOName, 10) AS MOName, MOTypeId, MOType.UserCodeDescription AS MOType,
                prdname AS ProductName, SOName, MO.OrganID AS 'CustmerPo', MO.BatchNum
        FROM    MO
        LEFT JOIN Product ON Product.ProductId = MO.ProductId
        LEFT JOIN UserCode MOType ON MOType.UserCodeId = MO.MOTypeId AND MOType.ParentUserCodeId = 'URC1000000DR'
        LEFT JOIN Factory ON Factory.FactoryId = MO.FactoryId
        LEFT OUTER JOIN (
                          SELECT    dbo.BillStates.BillStates, dbo.BillStates.BillStatesDescription
                          FROM      dbo.Bill
                          LEFT OUTER JOIN dbo.BillStates ON dbo.Bill.BillId = dbo.BillStates.BillId
                          WHERE     ( dbo.Bill.BillName = N'MO' )
                        ) AS MOStatusTable ON MO.MOStatus = MOStatusTable.BillStates
        WHERE   MOId = @I_ParentPKId;
        RETURN 0;
    END;
    
    IF @I_PlugInCommand = 'MOSTL'
    BEGIN
        SELECT  MOId, RIGHT(MOName, 10) AS MOName, MOTypeId, MO.MOQtyRequired, Product.prdname AS ProductName, MO.SOName,
                Product.ProductDescription
        FROM    MO
        INNER JOIN Product ON Product.ProductId = MO.ProductId AND LEFT(Product.prdname, 3) = '531'
        LEFT JOIN UserCode MOType ON MOType.UserCodeId = MO.MOTypeId AND MOType.ParentUserCodeId IN ( 'URC1000000DR',
                                                                                                      'URC1000000Q6' )
        INNER JOIN SysUser_Factory ON SysUser_Factory.FactoryId = MO.FactoryId
        WHERE   SysUser_Factory.UserId = @I_OrBitUserId AND MO.CreateDate >= GETDATE() - 90 AND MO.MOERPStatus <> '技术实现'
        ORDER BY MOName;
        RETURN 0;
    END;

    IF @I_PlugInCommand = 'MOLOG'
    BEGIN
        SELECT  MOId, RIGHT(MOName, 10) AS MOName, MOTypeId, MO.MOQtyRequired, Product.prdname AS ProductName, MO.SOName,
                Product.ProductDescription
        FROM    MO
        INNER JOIN Product ON Product.ProductId = MO.ProductId AND LEFT(Product.prdname, 3) IN ( '514', '515' )
        LEFT JOIN UserCode MOType ON MOType.UserCodeId = MO.MOTypeId AND MOType.ParentUserCodeId IN ( 'URC1000000DR',
                                                                                                      'URC1000000Q6' )
        INNER JOIN SysUser_Factory ON SysUser_Factory.FactoryId = MO.FactoryId
        WHERE   SysUser_Factory.UserId = @I_OrBitUserId AND MO.CreateDate >= GETDATE() - 90 AND MO.MOERPStatus <> '技术实现'
        ORDER BY MOName;
        RETURN 0;

	
    END;
    ELSE
    BEGIN
	
        SELECT  MOId, RIGHT(MOName, 10) AS MOName, MOTypeId, MOType.UserCodeDescription AS MOType,
                Product.prdname AS ProductName, SOName, MO.MOERPStatus, MO.OrganID AS 'CustmerPo', MO.BatchNum,
                MO.CreateDate
        FROM    MO
        LEFT JOIN Product ON Product.ProductId = MO.ProductId
        LEFT JOIN UserCode MOType ON MOType.UserCodeId = MO.MOTypeId AND MOType.ParentUserCodeId IN ( 'URC1000000DR',
                                                                                                      'URC1000000Q6' )
        WHERE   MO.FactoryId IN ( 'FAC10000001A', 'FAC10000000L', 'FAC1000000TK', 'FAC1000000TK', 'FAC1000000U0',
                                  'FAC1000000U3' ) AND (
                                                         MO.ModifyDate >= GETDATE() - 90 OR prdname IN ( '515T5143FM05' ) OR MOId IN
														(
														'MOD10000GVOZ',
														'MOD10000GVP0',
														'MOD10000GVQ7',
														'MOD10000GVQ6',
														'MOD10000GVP3',
														'MOD10000GVP4',
														'MOD10000GVP5',
														'MOD10000GVP6',
														'MOD10000GVP1',
														'MOD10000GVP2',
														'MOD10000H11P'
														)

                                                       )
        ORDER BY MO.CreateDate DESC;
    END;
    RETURN 0;
END;





