
-- =============================================
-- Author:		<OrBit Team benson>
-- Create date: <2016.06.08>
-- Description:	<打印栈板号_散件>
-- Rev: 10.00
--=============================================
CREATE PROCEDURE  [dbo].[PrintKDPalletSNDoMethod]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
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

@StartPalletSN nvarchar(50)='',        --开始批号
@EndPalletSN nvarchar(50)=''           --截止批号

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON; 
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
			declare @return_value int
	set @return_value=-1

	--检查元对象方法用户授权
	exec @return_value=[dbo].[MetadataPermissionCheckDoMethod]
		@I_ReturnMessage=@I_ReturnMessage output,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_Sender=@I_Sender

	if @return_value=-1
	begin
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end

	declare @PalletInfoId char(12)
	declare @OrderName nvarchar(50)
	declare @KDOrderInfoId char(12)
	declare @CustomerModel nvarchar(50)
	declare @ProductCode nvarchar(50)
	declare @CustomerName nvarchar(50)
	declare @OrderQty decimal(18,2)

	set @PalletInfoId=''
	set @OrderName=''
	set @KDOrderInfoId=''
	set @CustomerModel=''
	set @CustomerName=''
	set @ProductCode=''
	set @OrderQty=0
	
	--记录当前PKID
    declare @LotTemp table(
		PalletInfoId char(12)
	)

	if ISNULL(@StartPalletSN,'')='' or ISNULL(@EndPalletSN,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入打印的起始号和截止号!'
		return -1
	end 

	if LEFT(@StartPalletSN,1) not in ('P','M')
	begin
		set @I_ReturnMessage='ServerMessage:请输入有效的起始号! "P" or "M" 开头 '
		return -1
	end

	if LEFT(@EndPalletSN,1) not in ('P','M')
	begin
		set @I_ReturnMessage='ServerMessage:请输入有效的截止物料批号! "P" or "M" 开头 '
		return -1
	end

	if ISNULL(@I_PKId,'')='' or ISNULL(@I_ParentPKId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请选择有效项!'
		return -1
	end

	--获取订单信息
	select 
		@KDOrderInfoId=KDOrderInfoId,
		@OrderName=OrderName,
		@CustomerModel=CustomerModel,
		@ProductCode=ProductCode,
		@CustomerName=CustomerName,
		@OrderQty=Convert(float,OrderQty)
	from KDOrderInfo 
	where KDOrderInfoId=@I_ParentPKId

	--检查开始批号、截止批号是否存在此行
	if not exists(select 1 from KDPalletInfo where KDOrderInfoId=@KDOrderInfoId and PalletSN=@StartPalletSN)
	begin
		set @I_ReturnMessage='ServerMessage:起始号 ['+@StartPalletSN+'] 不存在!'
		return -1 
	end 

	--检查开始批号、截止批号是否存在此行
	if not exists(select 1 from KDPalletInfo where KDOrderInfoId=@KDOrderInfoId and PalletSN=@EndPalletSN)
	begin
		set @I_ReturnMessage='ServerMessage:截止号 ['+@EndPalletSN+'] 不存在!'
		return -1 
	end 

	if @StartPalletSN>@EndPalletSN
	begin
		set @I_ReturnMessage='ServerMessage:起始号 ['+@StartPalletSN+'] 不允许大于截止号 ['+@EndPalletSN+']，请检查!'
		return -1
	end

	--把信息写入表变量
	insert into @LotTemp (PalletInfoId) 
	select KDPalletInfoId
	from KDPalletInfo 
	where KDOrderInfoId=@KDOrderInfoId and PalletSN>=@StartPalletSN and PalletSN<=@EndPalletSN
	order by PalletSN

	--更新打印次数
	begin tran
		update KDPalletInfo set 
			PrintCount=PrintCount+1 
		where KDPalletInfoId in (select PalletInfoId from @LotTemp)
	commit TRAN
	
	IF @I_Sender = 'PrintPalletSN'
	BEGIN
		--打印数据
		select @CustomerModel as Model,@ProductCode as PN,@OrderQty as BatchQty,@CustomerName as Customer,PalletSN 
		from KDPalletInfo
		WHERE KDPalletInfoId in (SELECT PalletInfoId FROM @LotTemp)
		ORDER BY PalletSN
	END
	
	IF @I_Sender = 'PrintSKDPalletSN'
	BEGIN
		SELECT 
		    PalletSN, 
		    'T/' + CAST(CAST(RIGHT(PalletSN, 4) AS INT) AS VARCHAR) AS PalletNumber,
		    STUFF((
		        SELECT 
		            '+' + (CASE WHEN Count > 1 THEN CAST(Count AS VARCHAR) + 'x' ELSE '' END) + 
		            CAST(CAST(Qty AS INT) AS VARCHAR(20))
		        FROM (
		            SELECT Qty, COUNT(1) AS Count
		            FROM (
		                SELECT 
		                    a.BoxSN, 
		                    MAX(d.RealQty) AS Qty
		                FROM ShipPallet a
		                INNER JOIN KDBoxInfo c ON a.BoxSN = c.BoxSN
		                INNER JOIN KDBoxItem d ON c.KDBoxInfoId = d.KDBoxInfoId
		                WHERE a.PalletSN = KDPalletInfo.PalletSN
		                GROUP BY a.BoxSN
		            ) t
		            GROUP BY Qty
		        ) AS Agg
		        ORDER BY Count DESC
		        FOR XML PATH('')
		    ), 1, 1, '') + '=' + CAST(CAST(TotalQty AS INT) AS VARCHAR) AS BatchQtyStr -- 添加总数量和
		FROM KDPalletInfo
		OUTER APPLY (
		    -- 计算每个托盘的总数量
		    SELECT SUM(Qty * Count) AS TotalQty
		    FROM (
		        SELECT Qty, COUNT(1) AS Count
		        FROM (
		            SELECT 
		                a.BoxSN, 
		                MAX(d.RealQty) AS Qty
		            FROM ShipPallet a
		            INNER JOIN KDBoxInfo c ON a.BoxSN = c.BoxSN
		            INNER JOIN KDBoxItem d ON c.KDBoxInfoId = d.KDBoxInfoId
		            WHERE a.PalletSN = KDPalletInfo.PalletSN
		            GROUP BY a.BoxSN
		        ) t
		        GROUP BY Qty
		    ) AS Agg
		) AS Total
		WHERE KDPalletInfoId IN (SELECT PalletInfoId FROM @LotTemp)
		ORDER BY PalletSN
	END
	
	

	set @I_ReturnMessage='ServerMessage:栈板号打印成功.'
	     
	return 0
END


















