
-- =============================================
-- Author:		<OrBit benson>
-- Create Date: <2017.01.04>
-- Description:	散件取消外箱箱号
-- =============================================
CREATE PROCEDURE [dbo].[KDCancelBoxSNDoMethod]
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
    @StartBoxSN NVARCHAR(50) = '' ,
    @EndBoxSN NVARCHAR(50) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	--declare @return_value int
	--set @return_value=-1

	----检查元对象方法用户授权
	--exec @return_value=[dbo].[MetadataPermissionCheckDoMethod]
	--	@I_ReturnMessage=@I_ReturnMessage output,
	--	@I_OrBitUserId=@I_OrBitUserId,
	--	@I_OrBitUserName=@I_OrBitUserName,
	--	@I_Sender=@I_Sender

	--if @return_value=-1
	--begin
	--	set @I_ReturnMessage=@I_ReturnMessage
	--	return -1
	--end

    DECLARE @KDBoxInfoId CHAR(12);
    DECLARE @KDOrderInfoId CHAR(12);
    DECLARE @BoxType VARCHAR(20);
    DECLARE @BoxLevel VARCHAR(20);
    DECLARE @OrderName NVARCHAR(50);
    DECLARE @StartKDBoxInfoId CHAR(12);
    DECLARE @EndKDBoxInfoId CHAR(12);
    DECLARE @BoxSN NVARCHAR(50);

    SET @KDBoxInfoId = '';
    SET @KDOrderInfoId = '';
    SET @BoxType = '';
    SET @BoxLevel = '';
    SET @OrderName = '';
    SET @StartKDBoxInfoId = '';
    SET @EndKDBoxInfoId = '';
    SET @BoxSN = '';

    DECLARE @RepealCount INT = 0;
    DECLARE @CounterType VARCHAR(50) = '';
    DECLARE @True BIT = 0;

    DECLARE @Temp TABLE
        (
          KDBoxInfoId CHAR(12) ,
          BoxSN NVARCHAR(50)
        );
	
    IF ISNULL(@I_ParentPKId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择有效行项!';
        RETURN -1;
    END;

    IF ISNULL(@StartBoxSN, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入起始箱号!';
        RETURN -1;
    END;

    IF ISNULL(@EndBoxSN, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入截止箱号!';
        RETURN -1;
    END;

	--获取外箱信息
    SELECT TOP 1
            @KDBoxInfoId = KDBoxInfoId, @KDOrderInfoId = KDOrderInfoId, @BoxType = BoxType, @BoxLevel = BoxLevel
    FROM    KDBoxInfo
    WHERE   KDBoxInfoId = @I_ParentPKId;

	--获取订单信息
    SELECT  @OrderName = OrderName
    FROM    KDOrderInfo
    WHERE   KDOrderInfoId = @KDOrderInfoId;

    IF NOT EXISTS ( SELECT  1
                    FROM    KDBoxInfo
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxSN = @StartBoxSN AND IsCancel = 0 )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:起始箱 [' + @StartBoxSN + '] 无效，请检查!';
        RETURN -1;
    END;

    IF NOT EXISTS ( SELECT  1
                    FROM    KDBoxInfo
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxSN = @EndBoxSN AND IsCancel = 0 )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:截止箱 [' + @EndBoxSN + '] 无效，请检查!';
        RETURN -1;
    END;
    

    IF CHARINDEX('XHZZ', (
                           SELECT   BoxSN
                           FROM     dbo.KDBoxInfo
                           WHERE    KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @EndBoxSN AND IsCancel = 0
                         )) > 0
        SET @True = 1;

    SELECT  @CounterType = REPLACE(LEFT(BoxSN, LEN(BoxSN) - 5), '#', '-')
    FROM    dbo.KDBoxInfo
    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @EndBoxSN AND IsCancel = 0; 


		--外箱层级是否一致
    IF (
         SELECT BoxLevel
         FROM   KDBoxInfo
         WHERE  KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @StartBoxSN AND IsCancel = 0
       ) != (
              SELECT    BoxLevel
              FROM      KDBoxInfo
              WHERE     KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @EndBoxSN AND IsCancel = 0
            )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:不允许同时失效非同一层级的外箱标签，操作失败!';
        RETURN -1;
    END;

	--外箱类别是否一致
    IF (
         SELECT BoxType
         FROM   KDBoxInfo
         WHERE  KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @StartBoxSN AND IsCancel = 0
       ) != (
              SELECT    BoxType
              FROM      KDBoxInfo
              WHERE     KDOrderInfoId = @KDOrderInfoId AND BoxNumber = @EndBoxSN AND IsCancel = 0
            )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:不允许同时失效非同一类别的外箱标签，操作失败!';
        RETURN -1;
    END;
   
    SELECT  @StartKDBoxInfoId = KDBoxInfoId
    FROM    KDBoxInfo
    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxSN = @StartBoxSN AND IsCancel = 0;
   
    SELECT  @EndKDBoxInfoId = KDBoxInfoId
    FROM    KDBoxInfo
    WHERE   KDOrderInfoId = @KDOrderInfoId AND BoxSN = @EndBoxSN AND IsCancel = 0;

    IF ISNULL(@StartKDBoxInfoId, '') > ISNULL(@EndKDBoxInfoId, '')
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:起始箱 [' + @StartBoxSN + '] 不允许大于截止箱 [' + @EndBoxSN + ']，请检查!';
        RETURN -1;
    END;

	--写入临时表
    INSERT  INTO @Temp ( KDBoxInfoId, BoxSN )
    SELECT DISTINCT
            KDBoxInfoId, BoxSN
    FROM    KDBoxInfo
    WHERE   KDOrderInfoId = @KDOrderInfoId 
    AND BoxLevel = @BoxLevel 
    AND BoxType = @BoxType 
    AND IsCancel = 0 
    AND KDBoxInfoId >= @StartKDBoxInfoId 
    AND KDBoxInfoId <= @EndKDBoxInfoId;
   

	--检查数据
    DECLARE cursor1 CURSOR
    FOR
    SELECT  KDBoxInfoId, BoxSN
    FROM    @Temp
    ORDER BY KDBoxInfoId;
    OPEN cursor1;
    FETCH NEXT FROM cursor1 
	INTO @KDBoxInfoId, @BoxSN;
    WHILE @@FETCH_STATUS = 0
    BEGIN	
        IF EXISTS ( SELECT  1
                    FROM    ShipBox
                    WHERE   BoxSN = @BoxSN AND IsCancel = 0 )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:外箱 [' + @BoxSN + '] 已执行装箱，不允许失效，如果要失效，请先清空外箱!';
            RETURN -1;
        END;

        FETCH NEXT FROM cursor1 
		INTO @KDBoxInfoId, @BoxSN;
    END;
    CLOSE cursor1;
    DEALLOCATE cursor1; 

	--失效数据
    DECLARE cursor2 CURSOR
    FOR
    SELECT  KDBoxInfoId, BoxSN
    FROM    @Temp
    ORDER BY KDBoxInfoId;
    OPEN cursor2;
    FETCH NEXT FROM cursor2 
	INTO @KDBoxInfoId, @BoxSN;
    WHILE @@FETCH_STATUS = 0
    BEGIN	
        DELETE  KDBoxInfo
        WHERE   KDBoxInfoId = @KDBoxInfoId;

        DELETE  KDBoxItem
        WHERE   KDBoxInfoId = @KDBoxInfoId;

        DELETE  KDLoadBox
        WHERE   ParentBoxInfoId = @KDBoxInfoId;

        FETCH NEXT FROM cursor2 
		INTO @KDBoxInfoId, @BoxSN;
    END;
    CLOSE cursor2;
    DEALLOCATE cursor2; 
   
    IF @True = 1
    BEGIN
        SELECT  @RepealCount = COUNT(1)
        FROM    @Temp;

        UPDATE  dbo.SNCounter
        SET     SNCounter = SNCounter - @RepealCount
        WHERE   SNCounterName = 'KDOI自动生成箱号' AND CounterType = @CounterType;
    END; 


    SET @I_ReturnMessage = 'ServerMessage:取消箱号成功! 起始箱 [' + @StartBoxSN + '] 截止箱 [' + @EndBoxSN + '].';
    RETURN 0;
END;
 












