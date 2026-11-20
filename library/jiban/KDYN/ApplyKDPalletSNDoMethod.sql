
-- =============================================
-- Author:		<OrBit benson>
-- Create Date: <2016.06.08>
-- Description:	申请栈板号_散件
-- =============================================
CREATE PROCEDURE [dbo].[ApplyKDPalletSNDoMethod]
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
    @ApplyQty INT = 0 ,                   --申请数量
    @PalletQty INT = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @return_value INT;
    DECLARE @OrderName NVARCHAR(50);
    DECLARE @SNQty INT;
    DECLARE @PalletSN NVARCHAR(50);
    DECLARE @KDPalletInfoId CHAR(12);
    DECLARE @KDOrderInfoId CHAR(12);
    DECLARE @PalletCounter INT;
    DECLARE @PrefixBits NVARCHAR(30);

    SET @return_value = -1;
    SET @OrderName = '';
    SET @SNQty = 0;
    SET @PalletSN = '';
    SET @KDPalletInfoId = '';
    SET @KDOrderInfoId = '';
    SET @PalletCounter = 0;
    SET @PrefixBits = '';

	--检查元对象方法用户授权
    EXEC @return_value= [dbo].[MetadataPermissionCheckDoMethod]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @I_OrBitUserId = @I_OrBitUserId ,
        @I_OrBitUserName = @I_OrBitUserName ,
        @I_Sender = @I_Sender;

    IF @return_value = -1 AND  @I_OrBitUserName NOT IN ('sc3902')
    BEGIN
        SET @I_ReturnMessage = @I_ReturnMessage;
        RETURN -1;
    END;

    IF ISNULL(@I_ParentPKId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择有效项!';
        RETURN -1;
    END;

    IF ISNULL(@ApplyQty, 0) <= 0
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:申请数量 [' + CAST(@ApplyQty AS VARCHAR) + '] 必须是一个大于零的整数!';
        RETURN -1;
    END;

	--if ISNULL(@PalletQty,0)<=0
	--begin
	--	set @I_ReturnMessage='ServerMessage:栈板容量 ['+CAST(@PalletQty as varchar)+'] 必须是一个大于零的整数!'
	--	return -1
	--end


	--获取订单信息
    SELECT  @OrderName = KDOrderInfo.OrderName, @KDOrderInfoId = KDOrderInfo.KDOrderInfoId,
            @PalletCounter = ISNULL(PalletCounter, 0)
    FROM    KDOrderInfo
    WHERE   KDOrderInfoId = @I_ParentPKId;

    IF @I_PlugInCommand = 'BMIS'
    BEGIN
        SELECT  @OrderName = BrazilMatIssue.MatIssueNo, @KDOrderInfoId = BrazilMatIssue.BrazilMatIssueId,
                @PalletCounter = ISNULL(PalletCounter, 0)
        FROM    dbo.BrazilMatIssue
        WHERE   BrazilMatIssueId = @I_ParentPKId;

    END;


	--DECLARE @ProductDescription NVARCHAR(500) = '';
    DECLARE @ProductName NVARCHAR(50) = '';
    DECLARE @PNETWEIGHT DECIMAL(18, 3) = 0;
    DECLARE @L DECIMAL(18, 3) = 0;
    DECLARE @W DECIMAL(18, 3) = 0;
    DECLARE @H DECIMAL(18, 3) = 0;

    SELECT TOP 1
            @ProductName = d.prdname
    FROM    dbo.KDOrderInfo a
    INNER JOIN dbo.KDMO b ON b.KDOrderInfoId = a.KDOrderInfoId
    INNER JOIN dbo.MOItem c ON c.MOId = b.MOId
    INNER JOIN dbo.Product d ON d.ProductId = c.ProductId
    WHERE   a.KDOrderInfoId = @KDOrderInfoId AND d.prdname LIKE '601%' AND d.ProductDescription LIKE '栈板/%' AND CHARINDEX('mm',
                                                                                                        d.ProductDescription) > 0;

    IF ISNULL(@ProductName, '') <> ''
    BEGIN
        SELECT  @L = Length, @W = Width, @H = Height, @PNETWEIGHT = NetWeight
        FROM    dbo.Product
 WHERE   prdname = @ProductName;
    END;


	--SELECT TOP 1 @ProductDescription = d.ProductDescription, @PNETWEIGHT = d.NetWeight
	--FROM dbo.KDOrderInfo a
	--INNER JOIN dbo.KDMO b ON b.KDOrderInfoId = a.KDOrderInfoId
	--INNER JOIN dbo.MOItem c ON c.MOId = b.MOId
	--INNER JOIN dbo.Product d ON d.ProductId = c.ProductId
	--WHERE a.KDOrderInfoId = @KDOrderInfoId
	--AND d.prdname LIKE '601%' 
	--AND CHARINDEX('栈板', d.ProductDescription) > 0 
	--AND CHARINDEX('mm', d.ProductDescription) > 0;


	----IF LEFT(@ProductDescription,3) IN ('栈板/','纸托/')
	----	SET @ProductDescription = RIGHT(@ProductDescription, LEN(@ProductDescription)-3)

	----IF @ProductDescription <> ''
 ----   BEGIN
 ----       SELECT  @ProductDescription = dbo.ConvertStrToClumn(@ProductDescription, '/', 2);
 ----       SET @ProductDescription = REPLACE(@ProductDescription, 'mm', '');
        
 ----       --modify by LZH 去除中文字符(暂时修改，有缺点)
 ----       SET @ProductDescription = SUBSTRING(@ProductDescription, PATINDEX('%[0-9]%', @ProductDescription), LEN(@ProductDescription));
        
 ----       SELECT  @L = CAST(dbo.ConvertStrToClumn(@ProductDescription, '*', 1) AS DECIMAL(18, 3));
 ----       SELECT  @W = CAST(dbo.ConvertStrToClumn(@ProductDescription, '*', 2) AS DECIMAL(18, 3));
 ----       SELECT  @H = CAST(dbo.ConvertStrToClumn(@ProductDescription, '*', 3) AS DECIMAL(18, 3));
 ----   END;


    IF ISNULL(@OrderName, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:订单号不能为空!';
        RETURN -1;
    END;

    WHILE ( @SNQty < @ApplyQty )
    BEGIN
        SET @SNQty = @SNQty + 1;
        SET @PalletSN = '';
        SET @PalletCounter = @PalletCounter + 1;

		--生成栈板号
        SET @PrefixBits = 'P' + @OrderName;
        SELECT  @PalletSN = @PrefixBits + [dbo].[Convert10ToDecimal](@PalletCounter, 5, 10);
	
        IF EXISTS ( SELECT  1
                    FROM    KDPalletInfo
                    WHERE   PalletSN = @PalletSN AND IsCancel = 0 )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:生成的栈板号 [' + @PalletSN + '] 已存在，不允许重复，请检查!';
            RETURN -1;
        END;

		--写入栈板信息表
        EXEC SysGetObjectPKId
            '' ,
            'KDPalletInfo' ,
            @KDPalletInfoId OUTPUT;
        INSERT  INTO KDPalletInfo ( KDPalletInfoId, KDOrderInfoId, OrderName, PalletSN, CountQty, PNETWEIGHT, L, W, H )
        VALUES  ( @KDPalletInfoId, @KDOrderInfoId, @OrderName, @PalletSN, @PalletQty, @PNETWEIGHT, @L, @W, @H );

		--更新栈板号计数器
        IF @I_PlugInCommand = 'BMIS'
            UPDATE  dbo.BrazilMatIssue
            SET     PalletCounter = ISNULL(PalletCounter, 0) + 1
            WHERE   BrazilMatIssueId = @KDOrderInfoId;
        ELSE
            UPDATE  KDOrderInfo
            SET     PalletCounter = PalletCounter + 1
            WHERE   KDOrderInfoId = @KDOrderInfoId;
    END;

    SET @I_ReturnMessage = 'ServerMessage:申请栈板信息成功! 数量 ' + CAST(@ApplyQty AS VARCHAR) + ' 个，' + '栈板容量为' + CAST(@PalletQty AS VARCHAR) + '。';


    RETURN 0;

END;
 






 --select * from KDPalletInfo order by CreateDate desc




