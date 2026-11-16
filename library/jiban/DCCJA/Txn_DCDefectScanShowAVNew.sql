
-- =============================================
-- Author:		<OBit Team Phoenix>
-- Create date: <2016.05.06>
-- Description:	<不良记录显示>
-- Rev: 10.00
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_DCDefectScanShowAVNew]
@I_Sender nvarchar(200)='',                     --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,       --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output,  --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12) = '',				--主键
@I_SourcePKId char(12)='',			--执行拷贝时传入的源主键  
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='',		--插件参数	

@LotSN nvarchar(50)=''  ,           --单板条码
@Soname VARCHAR(30)='',   ----- soname
@moname VARCHAR(10)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
    DECLARE @return_value INT;
    DECLARE @LotId CHAR(12)= '';
    DECLARE @LotStatus VARCHAR(10)= '';
    DECLARE @LotWorkflowId CHAR(12)= '';
    DECLARE @LotSpecificationId CHAR(12)= '';
    DECLARE @LotWorkflowStepId CHAR(12)= '';
    DECLARE @DefectWorkflowStepId CHAR(12)= '';
    DECLARE @DefectWorkflowStepName NVARCHAR(50)= '';
    DECLARE @DefectCode NVARCHAR(50)= '';
    DECLARE @MOId CHAR(12)= '';
	--declare @MOName nvarchar(50)=''
    DECLARE @LotProductId CHAR(12)= '';
    DECLARE @ProductName NVARCHAR(50)= '';
    DECLARE @WorkflowDefectId CHAR(12)= '';
    DECLARE @StartDate DATETIME= NULL;
    DECLARE @WorkcenterName NVARCHAR(50)= '';
    DECLARE @WorkcenterId CHAR(12)= '';
    DECLARE @ProductDescription NVARCHAR(100)= '';
    DECLARE @Operator NVARCHAR(50)= '';
    DECLARE @MESTxnObjectName NVARCHAR(50)= 'DCDefectScanAV';	
    DECLARE @IsPCBA BIT = 0;
    DECLARE @pcbsn VARCHAR(40)= '';
    DECLARE @WorkflowStepId VARCHAR(12)= '';
    DECLARE @ToWorkflowStepId VARCHAR(12)= '';
    DECLARE @templotsn VARCHAR(40)= '';
    DECLARE @MOWorkflowId VARCHAR(12)= '';
    DECLARE @moProductid VARCHAR(12)= '';
    DECLARE @MoitemLotId VARCHAR(12)= '';
    DECLARE @moitemid VARCHAR(12)= '';
    DECLARE @LotMOId VARCHAR(12)= '';
    DECLARE @TestSpecificationId VARCHAR(12)= '';
    DECLARE @ConvertPcbsn VARCHAR(50)= '';
    DECLARE @OrderFieldSettingId VARCHAR(12);
    DECLARE @iscancel BIT = 0;
    DECLARE @lastworkflowstepid VARCHAR(12)= '';
	DECLARE @tempmoid  VARCHAR(12)=''
	DECLARE @p1  INT=0
	DECLARE @p2  INT = 0
    SET @LotSN = LTRIM(RTRIM(@LotSN));	

	SET @MOWorkflowId = ''
	
    IF ISNULL(@LotSN, '') = ''
      BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请输入产品条码!';
        SET @I_ExceptionFieldName = 'LotSN';
        SELECT  'error.png' AS WarnImage;
        RETURN -1;
      END;

	--获取 Lot 信息
	
    SELECT  @WorkcenterId = WorkcenterId
    FROM    dbo.SysUser
    WHERE   UserName = @I_OrBitUserName;
    SET @WorkflowStepId = '';

		--如果是PCB 板则取对应的 SN 号码
    SET @MOId = '';
    SET @pcbsn = '';
    IF LEFT(@LotSN, 3) IN ( '515', '514', '513', '512' )
      BEGIN
        SET @IsPCBA = 1;
        SET @iscancel = 0;
        SET @pcbsn = @LotSN;
		SET @lotid = ''
        SELECT TOP 1
                @LotId = LotId ,
                @MOId = MOId ,
                @iscancel = IsCancel
        FROM    dbo.DataChainAssembly WITH ( NOLOCK )
        WHERE   CollectSN = @LotSN
        ORDER BY DataChainAssemblyId DESC;
		 IF ISNULL(@iscancel, 0) = 0
          AND ISNULL(@LotId, '') <> ''
          BEGIN
            SET @I_ReturnMessage = 'ServerMessage:PCB 没有解绑，请先解绑!' + @lotid;
            SET @I_ExceptionFieldName = 'LotSN';
            SELECT  'error.png' AS WarnImage;
            RETURN -1;
          END;
		IF ISNULL(@LotId, '') = ''
		BEGIN
          SELECT @lotid = lotid FROM  dbo.OrderSetItem WHERE SNSTB  = @lotsn
		  SELECT @moid = moid FROM lot WHERE lotid = @lotid
		END
        
        IF ISNULL(@LotId, '') <> ''  -- 找到可返工的节点
          BEGIN
            SELECT  @LotSN = LotSN ,
                    @LotSpecificationId = SpecificationId ,
                    @LotWorkflowStepId = WorkflowStepId,@LotWorkflowId = WorkflowId
            FROM    Lot WITH ( NOLOCK )
            WHERE   LotId = @LotId;
          END;
       
		    -- 以上是找到组装上线的相关信息（工作流，节点。

          -- 以上是没有组装时找对应的节点。
        IF ISNULL(@LotId, '') = ''
          BEGIN
            SET @Soname = '';
            SET @ConvertPcbsn = RIGHT(RTRIM(@LotSN), 16);
            SELECT  @Soname = SOName
            FROM    MO WITH ( NOLOCK )
            WHERE   RIGHT(MOName, 10) = LEFT(@ConvertPcbsn, 10);
			-- 找对应的产品
            IF ISNULL(@Soname, '') = ''
              BEGIN
                SELECT  @Soname = b.SOName
                FROM    Lot a
                        LEFT JOIN MO b ON ( b.MOId = a.MOId )
                WHERE   a.LotSN = @LotSN; 
              END;

			IF ISNULL(@Soname,'') =''
			BEGIN
       
              SET @p1 =CHARINDEX('/',@lotsn,0)+1
              SET @p2 = CHARINDEX('-',@lotsn,0)
              SET @moname =  SUBSTRING(@lotsn,@p1,@p2-@p1)
			  SELECT @Soname =SOName  FROM mo WHERE RIGHT(moname,10) = @moname

			end

            SELECT TOP 1
                    @LotProductId = a.ProductId ,
                    @MOId = a.MOId ,
                    @LotWorkflowId = b.WorkflowId
            FROM    MO a
                    INNER JOIN Product b ON ( b.ProductId = a.ProductId )
                    INNER JOIN dbo.ProductType c ON ( c.ProductTypeId = b.ProductTypeId )
            WHERE   a.SOName = @Soname
                    AND c.ProductTypeName >= 'Z101'
                    AND c.ProductTypeName <= 'Z199'
                    AND ISNULL(b.WorkflowId, '') <> '';
          END;
      END;
    ELSE
      BEGIN
        SET @IsPCBA = 0;
        SELECT  @LotId = LotId ,
                @LotStatus = LotStatus ,
                @LotProductId = ProductId ,
                @MOId = MOId ,
                @LotWorkflowId = WorkflowId ,
                @LotWorkflowStepId = WorkflowStepId ,
				@ToWorkflowStepId = NextWorkflowStepId, 
                @LotSpecificationId = SpecificationId
        FROM    Lot WITH ( NOLOCK )
        WHERE   LotSN = @LotSN;
	   -- 找对应的PCBSN
        SELECT TOP 1
                @pcbsn = CollectSN
        FROM    dbo.DataChainAssembly WITH ( NOLOCK )
        WHERE   LotId = @LotId
                AND LEFT(CollectSN, 3) IN ( '515', '514', '513', '512' )
        ORDER BY DataChainAssemblyId DESC;
        IF ISNULL(@pcbsn, '') = ''
          BEGIN
            SELECT  @pcbsn = SnPcba ,
                    @OrderFieldSettingId = OrderFieldSettingId
            FROM    dbo.OrderSetItem WITH ( NOLOCK )
            WHERE   SNSTB = @LotSN;	
            SELECT  @LotProductId = ProductId ,
                    @MOId = MOId
            FROM    dbo.OrderFieldSetting WITH ( NOLOCK )
            WHERE   OrderFieldSettingId = @OrderFieldSettingId;	  			   
          END;
      END;
    --- 以下是找到PCB 或者 SN 的则生成虚的号码
	

	-- 找当前的所在的工作流（由于LOT表中的节点不对，只能找数据链）

    SET @lastworkflowstepid = '';
    SELECT TOP 1
	        @tempmoid = moid,
            @lastworkflowstepid = WorkflowStepId
    FROM    dbo.DataChain WITH ( NOLOCK )
    WHERE   LotId = @LotId
    ORDER BY DataChainId DESC;
    IF ISNULL(@LotWorkflowStepId, '') = ''
      SET @LotWorkflowStepId = @WorkflowStepId;

    -- 找不到工单就重置工单
	IF isnull(@moid,'') = ''
	 SET @moid = @tempmoid

	

    

	 
    IF @lastworkflowstepid <> @LotWorkflowStepId
      AND ISNULL(@lastworkflowstepid, '') <> ''
      BEGIN
        SET @LotWorkflowStepId = @lastworkflowstepid;
      END;

   if isnull(@soname,'') =''
   begin
      SELECT  @Soname = SOName
      FROM    MO
       WHERE   MOId = @MOId
            AND ISNULL(@MOId, '') <> '';
	end
	-- 如果号码中找不到工单，或者没有输入工单号则报错。
    IF ISNULL(@Soname, '') = ''
      BEGIN
        
		  SELECT TOP 1 @LotProductId = a.ProductId ,
                    @MOId = a.MOId,
					@LotWorkflowId = B.WorkflowId
            FROM    MO a
			 INNER JOIN product b ON(b.productid = a.ProductId)
			 INNER JOIN dbo.ProductType c ON(c.ProductTypeid = b.ProductTypeId)
            WHERE    RIGHT(SOName, 10) = RIGHT(RTRIM(@Soname), 10)
                   AND c.ProductTypeName >= 'Z101' AND C.ProductTypeName <= 'Z199' AND ISNULL(b.WorkflowId,'') <>''



        IF ISNULL(@LotProductId, '') = ''
          BEGIN
        --select '' as LotSN,'error.png' as WarnImage
            SET @I_ReturnMessage = 'ServerMessage:Moname [' + ISNULL(@Soname, '') +'/' + ISNULL(@moid, '')+'] 没有定位到订单号请手动输入1!';
            SET @I_ExceptionFieldName = 'Soname';
            RETURN -1;
          END;
      END;

	 -- SET @I_ReturnMessage='ServerMessage:Moname ['+ISNULL(@Moname,'')+'] 没有定位到工单号请手动输入!'+ @LOTSN
		--RETURN -1 
    IF ISNULL(@LotProductId, '') = ''
      BEGIN
        SELECT TOP 1
                @tempmoid = a.MOId ,
                @lotWorkflowId = b.WorkflowId ,
                @LotProductId = a.ProductId
        FROM    MO a
		    INNER JOIN product b ON (b.productid = a.ProductId AND ISNULL(b.WorkflowId,'')<> '')
        WHERE   SOName = @Soname
      END;

	  --如果工单为空，重轩
	  IF ISNULL(@moid,'') =''
	   SET @moid = @tempmoid


    IF ISNULL(@lotWorkflowId, '') = ''
      BEGIN
        SELECT  @lotWorkflowId = WorkflowId ,
                @ProductName = prdname ,
                @ProductDescription = ProductDescription
        FROM    Product WITH ( NOLOCK )
        WHERE   ProductId = @LotProductId;
      END;

    SELECT TOP 1
            @moitemid = MOItemId
    FROM    MOItem
    WHERE   MOId = @MOId; 

	
IF ISNULL(@LotWorkflowId,'') =''
BEGIN
    IF ISNULL(@moname,'') =''
	BEGIN
        SET @I_ExceptionFieldName = 'Moname'
        SET @I_ReturnMessage = 'ServerMessage:LotSN [' + @LotSN + '] 请输入正确的订单号或者工单号！';
        RETURN -1;
	end
	     
    SELECT @Soname = soname FROM mo WHERE RIGHT(moname,10) = @moname AND ISNULL(soname,'') <>''

    SELECT TOP 1 @LOTProductId = a.ProductId ,
                    @tempMOId = a.MOId,
					@LotWorkflowId = B.WorkflowId
            FROM    MO a
			 INNER JOIN product b ON(b.productid = a.ProductId)
			 INNER JOIN dbo.ProductType c ON(c.ProductTypeid = b.ProductTypeId)
            WHERE    RIGHT(SOName, 10) = RIGHT(RTRIM(@Soname), 10)
                   AND c.ProductTypeName >= 'Z101' AND C.ProductTypeName <= 'Z204' AND ISNULL(b.WorkflowId,'') <>''
  
  IF ISNULL(@moid,'')=''
  SET @moid = @tempmoid


   IF ISNULL(@LotWorkflowId,'') =''
   BEGIN
       SET @I_ExceptionFieldName = 'soname'
       SET @I_ReturnMessage = 'ServerMessage:LotSN [' + @LotSN + ']请输入正确的订单号，不是工单号！' + @soname;
        RETURN -1;
   END
end

	-- 如果已经到包装站点则只能记修理记录生成临时号码。
  
    --如果成品号过了包装，就生成临时号码
    IF ISNULL(@IsPCBA, 0) = 0
      BEGIN
        IF ISNULL(@LotSpecificationId, '') IN ( 'SPE100000192', 'SPE100000193', 'SPE100000195', 'SPE100000197',
                                                'SPE100000198', 'SPE10000019X', 'SPE1000001BP' )
          BEGIN
            SET @WorkflowStepId = '';
            SET @LotSN = RTRIM(@LotSN) + 'AVSN';
	   	-- 如果已经到包装站点则只能记修理记录。
            SELECT TOP 1
                    @WorkflowStepId = a.WorkflowStepId ,
                    @ToWorkflowStepId = a.ToWorkflowStepId
            FROM    WorkflowPath a
                    INNER JOIN dbo.WorkflowStep b ON ( a.WorkflowId = b.WorkflowId
                                                       AND a.ToWorkflowStepId = b.WorkflowStepId
                                                     )
            WHERE   a.WorkflowId = @lotWorkflowId
                    AND a.WorkflowStepId = @LotWorkflowStepId
                    AND b.SpecificationId = 'SPE100000191'
                    AND a.SelectCondition = 'CheckIsDefect_PathCondition';

            IF ISNULL(@WorkflowStepId, '') = ''
              BEGIN
   
                SELECT TOP 1
                        @WorkflowStepId = a.WorkflowStepId ,
                        @ToWorkflowStepId = a.ToWorkflowStepId
                FROM    WorkflowPath a
                        INNER JOIN dbo.WorkflowStep b ON ( a.WorkflowId = b.WorkflowId
                                                           AND a.ToWorkflowStepId = b.WorkflowStepId
                                                         )
                WHERE   a.WorkflowId = @lotWorkflowId
                        AND b.SpecificationId = 'SPE100000191'
                        AND a.SelectCondition = 'CheckIsDefect_PathCondition';
              END;

            IF ISNULL(@WorkflowStepId, '') = ''
              BEGIN
                SELECT  @WorkflowStepId = WorkflowStepId ,
                        @ToWorkflowStepId = ToWorkflowStepId
                FROM    WorkflowPath
                WHERE   WorkflowPath.WorkflowId = @lotWorkflowId
                        AND WorkflowPathName = '装箱扫描 1.0 - 整机维修 1.0';
              END;
          END;
      END;
    ELSE
      BEGIN  -- PCBA 扫描了的就是以虚拟号为生成修理。
        SET @LotSN = RTRIM(@LotSN) + 'AVSN';
      END;
   


    IF ISNULL(@LotId, '') = ''  -- 没有找到相应的绑定关系就按PCB 虚批号生成记录
      BEGIN
        IF ISNULL(@pcbsn, '') = ''
          SET @pcbsn = @LotSN; 
        IF RIGHT(RTRIM(@LotSN), 4) <> 'AVSN'
          SET @LotSN = RTRIM(@LotSN) + 'AVSN';
      END;


    IF ISNULL(@WorkflowStepId, '') = ''
      BEGIN
	
        SELECT TOP 1
                @WorkflowStepId = a.WorkflowStepId ,
                @ToWorkflowStepId = a.ToWorkflowStepId
        FROM    WorkflowPath a
                INNER JOIN dbo.WorkflowStep b ON ( a.WorkflowId = b.WorkflowId
                                                   AND a.ToWorkflowStepId = b.WorkflowStepId
                                                 )
        WHERE   a.WorkflowId = @lotWorkflowId
                AND a.WorkflowStepId = @LotWorkflowStepId
                AND b.SpecificationId = 'SPE100000191'
                AND a.SelectCondition = 'CheckIsDefect_PathCondition';


        IF ISNULL(@WorkflowStepId, '') = ''
          BEGIN
            SELECT TOP 1
                    @WorkflowStepId = WorkflowStepId
					--,
                    --@ToWorkflowStepId = ToWorkflowStepId
            FROM    dbo.WorkflowStep
            WHERE   WorkflowId = @lotWorkflowId
                    AND IsStartWorkflowStep = 1;      
            SELECT TOP 1
                    @ToWorkflowStepId = WorkflowStepId
					--@ToWorkflowStepId = ToWorkflowStepId
            FROM    dbo.WorkflowStep
            WHERE   WorkflowId = @lotWorkflowId
                    AND SpecificationId = 'SPE100000191';
          END;
      END;
    


    IF EXISTS ( SELECT WorkflowDefectId
                FROM    dbo.WorkflowDefect
                WHERE   LotSN = @LotSN
                        AND ISNULL(IsExe, 0) = 0 )
      BEGIN
        SELECT  '' AS LotSN ,
                'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:LotSN [' + @LotSN + '] 已存在不良记录，不能再采集';
        RETURN -1;
      END;


	--SELECT * FROM dbo.DCRepairRecord

-- 再次找不良采集点

IF ISNULL(@WorkflowStepId, '') = ''
  BEGIN

    SELECT  @WorkflowStepId = WorkflowStepId
    FROM    dbo.WorkflowStep
    WHERE   WorkflowId = @LotWorkflowId
            AND IsStartWorkflowStep = 1;
    IF NOT EXISTS ( SELECT TOP 1
                            1
                    FROM    WorkflowPath a
                            INNER JOIN dbo.WorkflowStep b ON ( a.WorkflowId = b.WorkflowId
                                                               AND a.ToWorkflowStepId = b.WorkflowStepId
                                                             )
                    WHERE   a.WorkflowId = @LotWorkflowId
                            AND a.WorkflowStepId = @WorkflowStepId
                            AND b.SpecificationId = 'SPE100000191' )  --AND a.SelectCondition = 'CheckIsDefect_PathCondition'
      BEGIN
        SELECT  @WorkflowStepId = WorkflowStepId,
		        @ToWorkflowStepId = ToWorkflowStepId 
        FROM    WorkflowPath WITH ( NOLOCK )
        WHERE   WorkflowId = @LotWorkflowId
                AND IsDefaultWorkflowPath = 1;
			      --- 找第一个节有没有返整机维修许可 
        IF EXISTS ( SELECT  WorkflowPathId
                    FROM    WorkflowPath a
                            INNER JOIN WorkflowStep b WITH ( NOLOCK ) ON ( b.WorkflowStepId = a.ToWorkflowStepId
                                                                           AND b.SpecificationId = 'SPE100000191'
                                                                         )
                    WHERE   a.WorkflowId = @LotWorkflowId
                            AND a.WorkflowStepId = @WorkflowStepId )
          BEGIN
            SELECT  @WorkflowStepId = a.WorkflowStepId ,
                    @ToWorkflowStepId = a.ToWorkflowStepId
            FROM    WorkflowPath a WITH ( NOLOCK )
                    INNER JOIN WorkflowStep b WITH ( NOLOCK ) ON ( b.WorkflowStepId = a.ToWorkflowStepId
                                                                   AND b.SpecificationId = 'SPE100000191'
                                                                 )
            WHERE   a.WorkflowId = @LotWorkflowId
                    AND a.WorkflowStepId = @WorkflowStepId;
          END;
        ELSE
          BEGIN     --- 找第二个节有没有返整机维修许可 
            SELECT  @WorkflowStepId = a.WorkflowStepId ,
                    @ToWorkflowStepId = a.ToWorkflowStepId
            FROM    WorkflowPath a
            WHERE   a.WorkflowId = @LotWorkflowId
                    AND a.WorkflowStepId = @WorkflowStepId
                    AND a.IsDefaultWorkflowPath = 1;

            IF EXISTS ( SELECT  WorkflowPathId
                        FROM    WorkflowPath a WITH ( NOLOCK )
                                INNER JOIN WorkflowStep b WITH ( NOLOCK ) ON ( b.WorkflowStepId = a.ToWorkflowStepId
                                                                               AND b.SpecificationId = 'SPE100000191'
                                                                             )
                        WHERE   a.WorkflowId = @LotWorkflowId
                                AND a.WorkflowStepId = @WorkflowStepId )
              BEGIN
                SELECT  @WorkflowStepId = a.WorkflowStepId,
				        @ToWorkflowStepId = a.ToWorkflowStepId
                FROM    WorkflowPath a WITH ( NOLOCK )
                        INNER JOIN WorkflowStep b WITH ( NOLOCK ) ON ( b.WorkflowStepId = a.ToWorkflowStepId
                                                                       AND b.SpecificationId = 'SPE100000191'
                                                                     )
                WHERE   a.WorkflowId = @LotWorkflowId
                        AND a.WorkflowStepId = @WorkflowStepId;
              END;
            ELSE
              BEGIN  --- 找第三个节有没有返整机维修许可 
                SELECT  @WorkflowStepId = a.WorkflowStepId,
                        @ToWorkflowStepId = a.ToWorkflowStepId
				        
                FROM    WorkflowPath a WITH ( NOLOCK )
                WHERE   a.WorkflowId = @LotWorkflowId
                        AND a.WorkflowStepId = @WorkflowStepId
                        AND a.IsDefaultWorkflowPath = 1;

                IF EXISTS ( SELECT  WorkflowPathId
                            FROM    WorkflowPath a WITH ( NOLOCK )
                                    INNER JOIN WorkflowStep b WITH ( NOLOCK ) ON ( b.WorkflowStepId = a.ToWorkflowStepId
                                                                                   AND b.SpecificationId = 'SPE100000191'
                                                                                 )
                            WHERE   a.WorkflowId = @LotWorkflowId
                                    AND a.WorkflowStepId = @WorkflowStepId )
                  BEGIN
                    SELECT  @WorkflowStepId = a.WorkflowStepId ,
                            @ToWorkflowStepId = a.ToWorkflowStepId
                    FROM    WorkflowPath a WITH ( NOLOCK )
                            INNER JOIN WorkflowStep b WITH ( NOLOCK ) ON ( b.WorkflowStepId = a.ToWorkflowStepId
                                                                           AND b.SpecificationId = 'SPE100000191'
                                                                         )
                    WHERE   a.WorkflowId = @LotWorkflowId
                            AND a.WorkflowStepId = @WorkflowStepId;
                  END;
              END;
          END;  

      END;
  END;

  --SELECT  '' AS LotSN ,
  --              'error.png' AS WarnImage;
  --   SET @I_ReturnMessage = 'ServerMessage:LotSN [' + ISNULL(@WorkflowStepId,'')  + '] 找不到工作流111' + ISNULL(@LotWorkflowId,'');
  --    RETURN -1;
  	
    SELECT  @LotSpecificationId = SpecificationId
    FROM    dbo.WorkflowStep WITH ( NOLOCK )
    WHERE   WorkflowStepId = @WorkflowStepId
            AND WorkflowId = @lotWorkflowId;

			 
	--IF @lotsn = '515l1A01M08/1010212870-09955' OR @lotsn = '515l1A01M08/1010212870-09955AVSN'
	--BEGIN
	--    SET @I_ReturnMessage = 'ServerMessage:LotSN [' + CONVERT(CHAR,ISNULL(@moid,'') ) + '] ，aaaaa' +  + CONVERT(CHAR,ISNULL(@soname,'') ) ;
 --       RETURN -1;
	--END

    IF NOT EXISTS ( SELECT  LotId
                    FROM    Lot WITH ( NOLOCK )
                    WHERE   LotSN = @LotSN )
      BEGIN
	    
        EXEC SysGetObjectPKId '', 'lot', @LotId OUTPUT;
        INSERT  INTO dbo.Lot
                ( LotId ,
                  LotSN ,
                  LotStatus ,
                  ProductId ,
                  OriginalQty ,
                  Qty ,
                  PriorityLevel ,
                  UOMId ,
                  ShiftId ,
                  WorkcenterId ,
                  ResourceId ,
                  BoxId ,
                  BoxSN ,
                  MOId ,
                  WorkflowId ,
                  WorkflowStepId ,
                  SpecificationId ,
                  IsMoveIn ,
                  NextWorkflowStepId ,
                  PreviousWorkflowStepId ,
                  LatestTxnCode ,
                  LatestUserId ,
                  LatestMoveDate ,
                  LatestActivityDate ,
                  CreateDate 
                )
        VALUES  ( @LotId ,
                  @LotSN ,
                  '1' ,
                  @LotProductId ,
                  1 ,
                  1 ,
                  '' ,
                  'UOM10000001O' ,
                  '' ,
                  @WorkcenterId ,
                  @I_ResourceId ,
                  '' ,
                  '' ,
                  @MOId ,
                  @lotWorkflowId ,
                  @WorkflowStepId ,
                  @LotSpecificationId ,
                  '0' ,
                  @ToWorkflowStepId ,
                  '' ,
                  'START' ,
                  @I_OrBitUserId ,
                  GETDATE() ,
                  GETDATE() ,
                  GETDATE()
                );

      END;
    ELSE
      BEGIN
        UPDATE  Lot
        SET     WorkflowId = @lotWorkflowId ,
                WorkflowStepId = @WorkflowStepId ,
				nextworkflowstepid = @ToWorkflowStepId,
				moid = @moid,
                SpecificationId = @LotSpecificationId
        WHERE   LotSN = @LotSN;

      END;
   
					
    SELECT  @LotId = LotId ,
            @LotMOId = MOId ,
            @LotStatus = LotStatus ,
            @LotProductId = ProductId ,
            @moitemid = MOItemId ,
            @LotWorkflowId = WorkflowId ,
            @LotWorkflowStepId = WorkflowStepId ,
            @LotSpecificationId = SpecificationId
    FROM    Lot WITH ( NOLOCK )
    WHERE   LotSN = @LotSN;
  
    IF ISNULL(@LotStatus, '0') <> '1'
      BEGIN
        SELECT  '' AS LotSN ,
                'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:LotSN [' + @LotSN + '] 状态不可用，请检查!';
        RETURN -1;
      END;
    SELECT  @ProductName = prdname
    FROM    Product
    WHERE   ProductId = @LotProductId;

	--检查是否允许操作此规程
    EXEC @return_value= dbo.[SysCheckSpecification] @I_ReturnMessage = @I_ReturnMessage OUTPUT,
      @WorkcenterId = @WorkcenterId OUTPUT, @LotId = @LotId, @I_OrBitUserId = '', @I_OrBitUserName = '',
      @I_ResourceId = '', @I_ResourceName = '', @SpecificationId = @LotSpecificationId,
      @MESTxnObjectName = @MESTxnObjectName;

    IF @return_value = -1
      BEGIN
        SELECT  '' AS LotSN ,
                'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:' + @I_ReturnMessage;
        RETURN -1;
      END;


    SELECT  @DefectWorkflowStepName = WorkflowStepName
    FROM    WorkflowStep WITH ( NOLOCK )
    WHERE   WorkflowStepId = @LotWorkflowStepId;
	--获取 Lot 产品信息
	

    SELECT  @WorkcenterName = WorkcenterName
    FROM    dbo.Workcenter
    WHERE   WorkcenterId = @WorkcenterId;

	--获取 Lot 工单信息
    SELECT  @Soname = SOName,@moname = Moname
    FROM    MO
    WHERE   MOId = @MOId;

    SELECT  @Soname AS SOName ,
            @ProductName AS ProductName ,
            @WorkcenterName AS WorkcenterName ,
            0 AS Qty ,
            @ProductDescription AS ProductDescription ,
            @LotSN AS HideLotSN ,@moname AS moname,
            @pcbsn AS PcbLotSn ,
            @lotWorkflowId AS WorkFlowid ,
            @LotWorkflowStepId AS DefectWorkflowStepId ,
            @DefectWorkflowStepName AS DefectWorkflowStepName,'OK.png' AS WarnImage;

    SET @I_ExceptionFieldName = 'DefectWorkflowStepName';
    SET @I_ReturnMessage = 'ServerMessage:SN:' + @LotSN + '采集成功，请输入不良信息!';

    RETURN 0;
END


















