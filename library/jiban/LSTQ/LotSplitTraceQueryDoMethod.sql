/*


EXEC dbo.LotSplitTraceQueryDoMethod
    @I_Sender = N'' , -- nvarchar(200)
    @I_ReturnMessage = N'' , -- nvarchar(max)
    @I_ExceptionFieldName = N'' , -- nvarchar(100)
    @I_LanguageId = '' , -- char(1)
    @I_PlugInCommand = '' , -- varchar(5)
    @I_OrBitUserId = 'SUR1000004LJ' , -- char(12)
    @I_OrBitUserName = N'' , -- nvarchar(100)
    @I_ResourceId = '' , -- char(12)
    @I_ResourceName = N'' , -- nvarchar(100)
    @I_PKid = '' , -- char(12)
    @I_ParentPKId = '' , -- char(12)
    @I_Parameter = N'' , -- nvarchar(100)
    @LotSN = 'RJHZ010000005348'  -- varchar(20)
 


*/

-- =============================================
-- Author:		<Wang AnLiang>
-- Create date: <2018.09.17>
-- Description:	<拆分批号来源追踪>
-- =============================================

CREATE  PROCEDURE [dbo].[LotSplitTraceQueryDoMethod]
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
    @I_Parameter NVARCHAR(100) = '' ,       --插件参数

--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @LotSN VARCHAR(30) = '' ,
    @Fromdate DATETIME = NULL ,
    @EndDate DATETIME = NULL,
    @prdname NVARCHAR(50)=''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @RootSN VARCHAR(30)= '';
	DECLARE @Orgiallotsn VARCHAR(50)=''



    IF @I_Sender = 'btnLotMeragTraceQuery'
    BEGIN
        IF ISNULL(@LotSN, '') = '' AND @Fromdate IS NULL AND @EndDate IS NULL
        BEGIN
            SET @I_ReturnMessage = 'Servermessage批号，开始日期，结束日期不能同时为空!';
            RETURN -1;
        END;
        IF @EndDate - @Fromdate > 365
        BEGIN
            SET @I_ReturnMessage = 'Servermessage:不能查询超过一年的时间!';
            RETURN -1;
        END; 

        SELECT  a.ParentenSn AS '合并主批', c.LotQty AS '主批数量', a.Lotsn AS '子批号', a.Lotqty, a.MergeDate, b.prdname,
                b.ProductDescription
        FROM    dbo.MergeRmSn a WITH ( NOLOCK )
        INNER JOIN Product b WITH ( NOLOCK ) ON b.ProductId = a.productid
        INNER JOIN dbo.WW_RMInventory c ON c.LotSN = a.ParentenSn
        WHERE   (
                  --a.Lotsn = ISNULL(@LotSN, '') OR ISNULL(@LotSN, '') = ''
        			a.ParentenSn = ISNULL(@LotSN, '') OR ISNULL(@LotSN, '') = ''
                ) AND (
                        a.CreateDate >= CONVERT(CHAR, @Fromdate, 23) OR @Fromdate IS NULL
                      ) AND (
                              a.CreateDate <= CONVERT(CHAR, @EndDate + 1, 23) OR @EndDate IS NULL
                            )
        ORDER BY a.ParentenSn;
			   
        RETURN 0;

    END;


	--检查判断当前是否报表服务器，如果否，则提示
    --IF CAST(SERVERPROPERTY('MachineName') AS VARCHAR) <> (
    --                                                       SELECT TOP 1
    --                                                                ParameterValue
    --                                                       FROM     SysParameter
    --                                                       WHERE    ParameterName = '[Report Server]'
    --                                                     ) AND @I_OrBitUserId <> 'SUR1000004LJ' 
				--										 AND @I_OrBitUserId NOT IN (
    --    'SUR10000035R', 'SUR1000004TG','' )
    --BEGIN
    --    SET @I_ReturnMessage = 'ServerMessage:当前为生产服务器，查询报表请转到报表服务器.';
    --    RETURN -1;
    --END;

    IF @I_Sender = 'btnLotSplitTraceQuery'
    BEGIN


	       -- 如果提供了 LotSN，但该批号不存在于系统中，报错
		IF  ISNULL(@LotSN,'')<>''
		BEGIN
			 IF NOT EXISTS ( SELECT  1
							FROM    dbo.WW_RMInventory(NOLOCK)
							WHERE   LotSN = @LotSN )
			BEGIN
				SET @I_ReturnMessage = '物料批号在系统中不存在!';
				RETURN -1;
			END;	

		END;
	   

	     IF ISNULL(@LotSN,'')<>''
    BEGIN
	   SET @Orgiallotsn= @lotsn

      IF EXISTS(SELECT TOP 1 1  FROM dbo.MLotSplitRecord WHERE lotsn = @LotSN)
            SELECT @Orgiallotsn = Orgiallotsn FROM dbo.MLotSplitRecord WHERE lotsn = @lotsn
		

--SELECT * FROM dbo.MLotSplitRecord WHERE lotsn ='R8C4640000000022'
      
        ;WITH  FindRoot
                  AS (
				      
                       SELECT  CAST('原始批号' AS VARCHAR(50)) AS Orgiallotsn,
					    a.LotSN,a.OriginalQty AS  PreSplitqty,  CAST(0 AS DECIMAL(18,4)) AS SplitQty,a.OriginalQty ,
						CAST('' AS nvarchar(50)) AS Operator,a.CreateDate,a.Remainhours 
                       FROM     dbo.WW_RMInventory a ( NOLOCK )				   
                       WHERE    a.lotsn =@Orgiallotsn
                       UNION ALL
                       SELECT  c.SplitLotSN AS Orgiallotsn, C.LotSN,c.PreSplitqty ,C.SplitQty, 
					   CAST(c.PreSplitqty - C.SplitQty AS DECIMAL(18,4)) AS OriginalQty,c.Operator, c.CreateDate,P.Remainhours
                       FROM     FindRoot AS P
                       INNER JOIN dbo.MLotSplitRecord AS C ( NOLOCK ) ON C.SplitLotSN = P.LotSN AND ISNULL(C.LotSN, '') <> ''
                     )
            SELECT   FindRoot.Orgiallotsn,LOTSN,FindRoot.PreSplitqty AS '拆分前数量',FindRoot.SplitQty,
			         FindRoot.OriginalQty,FindRoot.Operator,FindRoot.CreateDate ,FindRoot.Remainhours AS '剩余时间'
            FROM    FindRoot ORDER BY FindRoot.CreateDate ;
           
      
	   RETURN 0
    END

	
	ELSE
    
	 BEGIN

	  DECLARE @productid CHAR(12)='';
	  SELECT @productid=ProductId FROM product WHERE prdname=@prdname

	   IF ISNULL(@productid,'')='' AND  ISNULL(@Fromdate,'')='' 
	   BEGIN
		SET @I_ReturnMessage='ServerMessage: 日期和料号必须选一个'
		RETURN -1

	   END

      IF ISNULL(@Fromdate,'')<>'' AND ISNULL(@EndDate,'')=''
		SET @EndDate = @Fromdate


   IF ISNULL(@EndDate,'')<>'' AND ISNULL(@Fromdate,'')=''
		SET @Fromdate = @EndDate




	  IF ISNULL(@productid,'')<>'' AND ISNULL(@Fromdate,'')<>''

	  BEGIN
		      -- 模式 B：未提供 LotSN → 按条件筛选拆分记录
        SELECT  
            m.SplitLotSN AS '父批号',
            m.LotSN AS '当前批号',
            m.PreSplitqty AS '拆分前数量',
            m.SplitQty AS '拆分数量',
            CAST(w.LotQty AS DECIMAL(18,4)) AS '当前数量',
            m.Operator AS '操作员',
            m.CreateDate AS '拆分时间',
           ISNULL( w.Remainhours,0) AS '剩余时间(小时)',
            c.prdname AS '料号'
        FROM dbo.MLotSplitRecord m (NOLOCK)
        INNER JOIN dbo.WW_RMInventory w (NOLOCK) 
            ON w.LotSN = m.LotSN
			INNER JOIN product c (NOLOCK) ON c.ProductId = w.ProductId
        WHERE 
            -- 日期范围过滤
         m.CreateDate >= @Fromdate
            AND  m.CreateDate < DATEADD(DAY, 1, @EndDate)
            -- 料号过滤
            AND  w.ProductId = @ProductId
        ORDER BY m.CreateDate DESC;

	  END


	    IF  ISNULL(@Fromdate,'')<>''
        -- 模式 B：未提供 LotSN → 按条件筛选拆分记录
        SELECT  
            m.SplitLotSN AS '父批号',
            m.LotSN AS '当前批号',
            m.PreSplitqty AS '拆分前数量',
            m.SplitQty AS '拆分数量',
            CAST(w.LotQty AS DECIMAL(18,4)) AS '当前数量',
            m.Operator AS '操作员',
            m.CreateDate AS '拆分时间',
           ISNULL( w.Remainhours,0) AS '剩余时间(小时)',
           c.prdname AS '料号'
        FROM dbo.MLotSplitRecord m (NOLOCK)
        INNER JOIN dbo.WW_RMInventory w (NOLOCK) 
            ON w.LotSN = m.LotSN
			INNER JOIN product c (NOLOCK) ON c.ProductId = w.ProductId
        WHERE 
            -- 日期范围过滤
            ( m.CreateDate >= @Fromdate)
            AND m.CreateDate < DATEADD(DAY, 1, @EndDate)-- 包含整天

        ORDER BY m.CreateDate DESC;

		  IF ISNULL(@productid,'')<>'' 
		     SELECT  
            m.SplitLotSN AS '父批号',
            m.LotSN AS '当前批号',
            m.PreSplitqty AS '拆分前数量',
            m.SplitQty AS '拆分数量',
            CAST(w.LotQty AS DECIMAL(18,4)) AS '当前数量',
            m.Operator AS '操作员',
            m.CreateDate AS '拆分时间',
           ISNULL( w.Remainhours,0) AS '剩余时间(小时)',
            c.prdname AS '料号'
        FROM dbo.MLotSplitRecord m (NOLOCK)
        INNER JOIN dbo.WW_RMInventory w (NOLOCK) 
            ON w.LotSN = m.LotSN
			INNER JOIN product c (NOLOCK) ON c.ProductId = w.ProductId
        WHERE 
          w.ProductId=@productid

        ORDER BY m.CreateDate DESC;

    END;

    RETURN 0;
END;


    --IF @I_Sender = 'btnLotMeragTraceQuery'
    --BEGIN
    --    IF ISNULL(@LotSN, '') = '' AND @Fromdate IS NULL AND @EndDate IS NULL
    --    BEGIN
    --        SET @I_ReturnMessage = 'Servermessage批号，开始日期，结束日期不能同时为空!';
    --        RETURN -1;
    --    END;
    --    IF @EndDate - @Fromdate > 365
    --    BEGIN
    --        SET @I_ReturnMessage = 'Servermessage:不能查询超过一年的时间!';
    --        RETURN -1;
    --    END; 
    --    SELECT  a.ParentenSn AS '主批号', a.Lotsn AS '子批号', a.Lotqty, a.MergeDate, b.prdname, b.ProductDescription
    --    FROM    dbo.MergeRmSn a
    --    INNER JOIN Product b ON b.ProductId = a.productid
    --    WHERE   (
    --              Lotsn = ISNULL(@LotSN, '') OR ISNULL(@LotSN, '') = ''
    --            ) AND (
    --                    a.CreateDate >= @Fromdate OR @Fromdate IS NULL
    --                  ) AND (
    --                          a.CreateDate <= @EndDate OR @EndDate IS NULL
    --                        );
			   
    --    RETURN 0;

    --END;

    RETURN 0

END
