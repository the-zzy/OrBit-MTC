
-- =============================================
-- Author:		<OrBit Team Alick>
-- Create Date: <2020.06.02>
-- Description:	PDA 备料单发料扫描,备料明细含不合并，
-- =============================================
CREATE PROCEDURE  [dbo].[PDA_MaterialToStockListLotKG]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId char(12)='',			--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(max)='',  		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.

@StockListName nvarchar(50)='',      --备料单
@BoxOrLotSN nvarchar(50)='',           --最小包/外箱 SN
@WHPerson NVARCHAR(50) = '' ,
@HideStockListName NVARCHAR(50) = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @UFactoryId CHAR(12)=''
	DECLARE @UDivisionId CHAR(12) =''
	DECLARE @PWorkCenterId CHAR(12) =''
	DECLARE @UDivisionName NVARCHAR(50)=''
	Declare @FWorkcenterId CHAR(12)= '' 

	declare @StockListId char(12)=''
	--备料单信息
	DECLARE @FactoryId char(12)=''	 --工厂
	DECLARE @DivisionId char(12)=''	 --部门
	declare @WarehouseId char(12)=''
	DECLARE @StockListStates VARCHAR(20)=''	 --备料单状态
	DECLARE @CarProductid CHAR(12)=''
	DECLARE  @LotProductName  NVARCHAR(50) = ''
	DECLARE @StockListItemId CHAR(12) = ''
	DECLARE @StockListItemLotId	 CHAR(12) = ''
	Declare @TWorkcenterId CHAR(12)= ''
	--SET @TWorkcenterId = 'WKC100000083'

	DECLARE @returnValue INT 
		 --回传SAP返回状态信息
	Declare @IsOk BIT =0
	Declare @BillsType nvarchar(50)=''	--单据类型
	DECLARE @MCellId CHAR(12) = ''

	--工单列表
	Declare @MOList table
	(
		MaterialIssuanceId char(12), --领料单ID
		MOId char(12)  ,                     --工单
		ProductId char(12),
		CreateDate datetime
	)

	-- 发料单明细变量变
	Declare @MOItem table
	(
		WareHouseId char (12) ,   --仓库Id
		ProductId char (12) ,	--物料Id
		ItemRequiredQty decimal (18, 6) ,		--工单明细需求量
		ItemIssuedQty decimal (18, 6) ,	--工单明细已发放数量
		WHPerson nvarchar(50)
	)

	--物料信息
	Declare @LotType char(1)
	Declare @MLotType char(1)=''   --类别 R/B
	Declare @MLotId char(12)=''
	Declare @MLotSN nvarchar(50)=''
	Declare @MBoxSN nvarchar(50)=''
	Declare @MQty decimal(18,6)=0 --总数量（批号或箱号）
	Declare @MLotQty decimal(18,6)=0 --单个批号的数量。
	Declare @MUOMId char(12)=''
	Declare @MProductId char(12)=''  --产品ID
	Declare @MProductName nvarchar(50)=''	 --产品
	Declare @WWId char(12)=''
	--声明库存表变量
	Declare @LotList table
	(
		WWId  char(12),
		LotId  char(12),
		LotSN  nvarchar(40),
		LotStatus  char(1),
		LotQty  decimal(18, 6),
		BoxSN  nvarchar(40),
		ProductId  char(12),
		UOMId  char(12),
		WorkcenterId  char(12),
		CellId  char(12),
		ReceiveDate  datetime,
		InventoryQty  decimal(18, 6),
		IsStorage  bit,
		IsCheck bit,
		IsLock bit,
		FactoryId  char(12),
		DivisionId  char(12),
		BillsType nvarchar(50),
		BillsNumber nvarchar(50)
	)

	--用户负责的产品列表
	Declare @UProduct table
	(
		ProductId char(12)
	)

	declare @ReturnValues int=-1

	-- 亮灯开始
	Declare @NGuid nvarchar(36)
		SET @NGuid =''
		
	 
	--声明变量工单明细物料临时变量表
	DECLARE @MOItemProduct TABLE (ProductID CHAR(12),
									ItemQtyRequired decimal(18, 6),
									WHPerson NVARCHAR(50) )

	DECLARE @MOItemProduct1 TABLE (ProductID CHAR(12),
									ItemQtyRequired decimal(18, 6),
									WHPerson NVARCHAR(50) )

	--声明已发物料临临时变量表
	DECLARE @SKIProduct TABLE (ProductID CHAR(12),
								QtyIssued decimal(18, 6) )
	--声明计算完未发料的临时变量表
	DECLARE @NOProduct TABLE (ProductID CHAR(12),WHPerson NVARCHAR(50))

	--赋值
	SELECT
		@StockListId = StockListId,
		@StockListStates =StockListStates,
		@BillsType= StockListType,
		@FactoryId = FactoryId,
		@DivisionId = DivisionId
	FROM  StockList(nolock)
	WHERE StockListName = @StockListName 

	--判定是否存在发料单
	IF ISNULL( @StockListId ,'') = ''
	BEGIN
		SET @I_ReturnMessage='ServerMessage:备料单不存在!'
		SELECT '' as StockListName,'' AS BoxOrLotSN,'' as ProductName,'' as RequiredQty,'' as QtyIssued,'' as OweQty
		SET @I_ExceptionFieldName='StockListName'
		RETURN -1
	END

	--判定单据是否审核，没有审核不允许备料扫描。
	IF ISNULL(@StockListStates , '') NOT  IN ('20','30')
	BEGIN
		SET @I_ReturnMessage='ServerMessage:备料单没有审核，不允许备料扫描！！！'
		SELECT '' as StockListName,'' AS BoxOrLotSN,'' as ProductName,'' as RequiredQty,'' as QtyIssued,'' as OweQty
		SET @I_ExceptionFieldName='StockListName'
		RETURN -1
	END

	-- 切换备料单时开启亮灯
	IF ISNULL(@I_Sender,'') = 'ExeStockList'
	BEGIN
		 Set @NGuid=newid()

		--关闭上一个备料单灯数据
		IF ISNULL(@HideStockListName,'') <>'' AND ISNULL(@HideStockListName,'') <> ISNULL(@StockListName,'')
		BEGIN
			IF ISNULL(@WHPerson,'') = ''
			BEGIN	
				SET @I_ReturnMessage='ServerMessage:请输入工号！！！'
				SELECT '' AS BoxOrLotSN
				SET @I_ExceptionFieldName='BoxOrLotSN'
				RETURN -1
			END

			SELECT
				@StockListId = StockListId,
				@FactoryId = FactoryId,
				@DivisionId = DivisionId
			FROM  StockList(nolock)
			WHERE StockListName = @HideStockListName 

			--查询工单BOM产品及数量插入
			INSERT INTO @MOItemProduct
			(
				ProductID,
				ItemQtyRequired,
				WHPerson
			)
			SELECT
			DISTINCT
				MOItem.ProductId,
				ItemQtyRequired ,
				dbo.Product.WHPerson
			FROM StockList_MO  SLMO
			INNER JOIN MOItem ON SLMO.MOId = MOItem.MOId
			INNER JOIN MO ON MOItem.MOId = MO.MOID
			INNER JOIN Product ON MOItem.ProductId = Product.ProductId
			INNER JOIN ProductTypeSTD ON Product.ProductTypeSTDID =  ProductTypeSTD.ProductTypeSTDID
			WHERE SLMO.StockListId = @StockListId   			--	STLI00000020
			AND MO.ProductId <> MOItem.ProductId
			AND ItemQtyRequired >0
			AND ProductTypeName = 'A类'
			AND ISNULL(MOItem.DeleteFlag,'') <>'X'

			INSERT INTO @MOItemProduct1
			(
			    ProductID,
			    ItemQtyRequired,
			    WHPerson
			)
			SELECT
				ProductID ,
				ISNULL(SUM(ItemQtyRequired),0) AS ItemQtyRequired ,
				WHPerson
			FROM @MOItemProduct
			GROUP BY ProductID ,WHPerson

			--查询已发产品及数量并插入 
			INSERT INTO  @SKIProduct
			SELECT 
				ProductId,
				QtyIssued AS QtyIssued
			FROM StockListItem
			WHERE StockListId = @StockListId

			--计算未发料的产品进行插入
			INSERT INTO @NOProduct
			(
				ProductID,
				WHPerson
			)
			SELECT MIP.ProductID ,MIP.WHPerson 
			FROM 	@MOItemProduct1	MIP
			LEFT JOIN  @SKIProduct SKIPT ON MIP.ProductID = SKIPT.ProductID
			

		--插入亮灯记录表
		INSERT INTO WorkCenterCellOn
		(
			NGuid,
			FactoryId ,
			DivisionId ,
			WorkcneterId ,
			ProductId ,
			IsOn
		)SELECT DISTINCT
			@NGuid,
			@FactoryId,
			@DivisionId,
			Workcenter.WorkcenterId,
			--NOP.ProductID ,
			CASE LEFT(ISNULL(dbo.Product.prdname,''),2) WHEN 'KG'
				THEN (SELECT ProductId FROM dbo.Product 
				WHERE prdname=(SELECT RIGHT(prdname,LEN(prdname)-2) FROM dbo.Product WHERE ProductId=Product.ProductId))
				ELSE NOP.ProductId
                END,
			'1'
			FROM @NOProduct NOP
			inner join Cell_Product (nolock)on Cell_Product.ProductId = NOP.ProductId
			inner join Cell(nolock) on Cell.CellId = Cell_Product.CellId
			inner join Product_LGORT (nolock)on Product_LGORT.ProductId = NOP.ProductId
			inner join Workcenter(nolock) on Product_LGORT.LGORT=Workcenter.WorkcenterName
			INNER JOIN dbo.Product (NOLOCK) ON Product.ProductId = NOP.ProductID
			WHERE 
			NOP.WHPerson=@WHPerson
			and Product_LGORT.FactoryId=@FactoryId
	 
			IF EXISTS(Select 1 From WorkCenterCellOn(nolock) where NGuid=@NGuid)
			Begin
				Exec TxnBase_WorkCenterCellOn_StockList
					@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
					@I_LanguageId =@I_LanguageId ,                         -- char(1)
					@I_PlugInCommand =@I_PlugInCommand ,                      -- varchar(5)
					@I_OrBitUserId =@I_OrBitUserId ,                        -- char(12)
					@I_OrBitUserName = @I_OrBitUserName ,                     -- nvarchar(100)
					@I_ResourceId = @I_ResourceId ,                         -- char(12)
					@I_ResourceName = @I_ResourceName ,                      -- nvarchar(100)
					@FactoryId=@FactoryId,
					@DivisionId=@DivisionId,
					@NGuid =@NGuid ,                            
					@LotStatus = '1',
					@IsOn='0'
			END

			-- 打开当前选择备料单物料灯

			SET @StockListId = ''
			SET @FactoryId = ''
			SET @DivisionId = ''

			SELECT
				@StockListId = StockListId,
				@FactoryId = FactoryId,
				@DivisionId = DivisionId
			FROM  StockList(nolock)
			WHERE StockListName = @StockListName 

			-- 清空
			DELETE FROM @MOItemProduct

			--查询工单BOM产品及数量插入
			INSERT INTO @MOItemProduct
			(
			    ProductID,
			    ItemQtyRequired,
			    WHPerson
			)
			SELECT
			DISTINCT
				MOItem.ProductId,
				ItemQtyRequired ,
				dbo.Product.WHPerson
			FROM StockList_MO  SLMO
			INNER JOIN MOItem ON SLMO.MOId = MOItem.MOId
			INNER JOIN MO ON MOItem.MOId = MO.MOID
			INNER JOIN Product ON MOItem.ProductId = Product.ProductId
			INNER JOIN ProductTypeSTD ON Product.ProductTypeSTDID =  ProductTypeSTD.ProductTypeSTDID
			WHERE SLMO.StockListId = @StockListId   			--	STLI00000020
			AND MO.ProductId <> MOItem.ProductId
			AND ItemQtyRequired > 0
			AND ProductTypeName = 'A类'
			AND ISNULL(MOItem.DeleteFlag,'') <>'X'

			INSERT INTO @MOItemProduct1
			(
			    ProductID,
			    ItemQtyRequired,
			    WHPerson
			)
			SELECT
				ProductID ,
				ISNULL(SUM(ItemQtyRequired),0) AS ItemQtyRequired ,
				WHPerson
			FROM @MOItemProduct
			GROUP BY ProductID ,WHPerson

			-- 清空
			DELETE FROM @SKIProduct

			--查询已发产品及数量并插入 
			INSERT INTO  @SKIProduct
			SELECT 
				ProductId,
				QtyIssued AS QtyIssued
			FROM StockListItem
			WHERE StockListId = @StockListId

			-- 清空
			DELETE FROM @NOProduct

			--计算未发料的产品进行插入
			INSERT INTO @NOProduct
			(
			    ProductID,
			    WHPerson
			)
			SELECT MIP.ProductID ,MIP.WHPerson 
			FROM 	@MOItemProduct1	MIP
			LEFT JOIN  @SKIProduct SKIPT ON MIP.ProductID = SKIPT.ProductID
			WHERE ISNULL(MIP.ItemQtyRequired,0) > ISNULL(SKIPT.QtyIssued,0)

			SET @NGuid = ''

			SET @NGuid =NEWID()

			--插入亮灯记录表
			INSERT INTO WorkCenterCellOn
			(
				NGuid,
				FactoryId ,
				DivisionId ,
				WorkcneterId ,
				ProductId ,
				IsOn
			)
			SELECT DISTINCT
				@NGuid,
				@FactoryId,
				@DivisionId,
				Workcenter.WorkcenterId,
				--NOP.ProductID ,
							CASE LEFT(ISNULL(dbo.Product.prdname,''),2) WHEN 'KG'
				THEN (SELECT ProductId FROM dbo.Product 
				WHERE prdname=(SELECT RIGHT(prdname,LEN(prdname)-2) FROM dbo.Product WHERE ProductId=Product.ProductId))
				ELSE NOP.ProductId
                END,
				'1'
			FROM @NOProduct NOP
			inner join Cell_Product (nolock)on Cell_Product.ProductId = NOP.ProductId
			inner join Cell(nolock) on Cell.CellId = Cell_Product.CellId
			inner join Product_LGORT (nolock)on Product_LGORT.ProductId = NOP.ProductId
			inner join Workcenter(nolock) on Product_LGORT.LGORT=Workcenter.WorkcenterName
			INNER JOIN dbo.Product (NOLOCK) ON Product.ProductId = NOP.ProductID
			WHERE 
			NOP.WHPerson=@WHPerson
			and Product_LGORT.FactoryId=@FactoryId
	 
			IF EXISTS(Select 1 From WorkCenterCellOn(nolock) where NGuid=@NGuid)
			Begin
				Exec TxnBase_WorkCenterCellOn_StockList
					@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
					@I_LanguageId =@I_LanguageId ,                         -- char(1)
					@I_PlugInCommand =@I_PlugInCommand ,                      -- varchar(5)
					@I_OrBitUserId =@I_OrBitUserId ,                        -- char(12)
					@I_OrBitUserName = @I_OrBitUserName ,                     -- nvarchar(100)
					@I_ResourceId = @I_ResourceId ,                         -- char(12)
					@I_ResourceName = @I_ResourceName ,                      -- nvarchar(100)
					@FactoryId=@FactoryId,
					@DivisionId=@DivisionId,
					@NGuid =@NGuid ,                            
					@LotStatus = '1',
					@IsOn='1'
			END

			set @I_ReturnMessage='ServerMessage:备料单切换亮灯成功，请扫描物料! '
			set @I_ExceptionFieldName='BoxOrLotSN'
			select '' as BoxOrLotSN, @WHPerson as WHPerson,@StockListName AS HideStockListName
			return 0

		END

		set @I_ReturnMessage='ServerMessage:请扫描工号! '
		set @I_ExceptionFieldName='BoxOrLotSN'
		select '' as BoxOrLotSN,@StockListName AS HideStockListName,@WHPerson AS WHPerson

		RETURN 0
	end

	-- 关闭所有灯
	IF ISNULL(@I_Sender,'') = 'CloseAllLight'
	BEGIN
		Set @NGuid=newid()

		IF ISNULL(@WHPerson,'') = ''
		BEGIN	
			SET @I_ReturnMessage='ServerMessage:请输入工号！！！'
			SELECT '' AS BoxOrLotSN
			SET @I_ExceptionFieldName='BoxOrLotSN'
			RETURN -1
		END
		
		--查询工单BOM产品及数量插入
		INSERT INTO @MOItemProduct
		(
			ProductID,
			ItemQtyRequired,
			WHPerson
		)
		SELECT
		DISTINCT
			MOItem.ProductId,
			ItemQtyRequired ,
			dbo.Product.WHPerson
		FROM StockList_MO  SLMO
		INNER JOIN MOItem ON SLMO.MOId = MOItem.MOId
		INNER JOIN MO ON MOItem.MOId = MO.MOID
		INNER JOIN Product ON MOItem.ProductId = Product.ProductId
		INNER JOIN ProductTypeSTD ON Product.ProductTypeSTDID =  ProductTypeSTD.ProductTypeSTDID
		WHERE SLMO.StockListId = @StockListId   			--	STLI00000020
		AND MO.ProductId <> MOItem.ProductId
		AND ItemQtyRequired >0
		AND ProductTypeName = 'A类'
		AND ISNULL(MOItem.DeleteFlag,'') <>'X'

		INSERT INTO @MOItemProduct1
		(
			ProductID,
			ItemQtyRequired,
			WHPerson
		)
		SELECT
			ProductID ,
			ISNULL(SUM(ItemQtyRequired),0) AS ItemQtyRequired ,
			WHPerson
		FROM @MOItemProduct
		GROUP BY ProductID ,WHPerson

		--查询已发产品及数量并插入 
		INSERT INTO  @SKIProduct
		SELECT 
			ProductId,
			QtyIssued AS QtyIssued
		FROM StockListItem
		WHERE StockListId = @StockListId

		--计算未发料的产品进行插入
		INSERT INTO @NOProduct
		(
			ProductID,
			WHPerson
		)
		SELECT MIP.ProductID ,MIP.WHPerson 
		FROM 	@MOItemProduct1	MIP
		LEFT JOIN  @SKIProduct SKIPT ON MIP.ProductID = SKIPT.ProductID
			
		--插入亮灯记录表
		INSERT INTO WorkCenterCellOn
		(
			NGuid,
			FactoryId ,
			DivisionId ,
			WorkcneterId ,
			ProductId ,
			IsOn
		)
		SELECT DISTINCT
		@NGuid,
		@FactoryId,
		@DivisionId,
		Workcenter.WorkcenterId,
		--NOP.ProductID ,
					CASE LEFT(ISNULL(dbo.Product.prdname,''),2) WHEN 'KG'
				THEN (SELECT ProductId FROM dbo.Product 
				WHERE prdname=(SELECT RIGHT(prdname,LEN(prdname)-2) FROM dbo.Product WHERE ProductId=Product.ProductId))
				ELSE NOP.ProductId
                END,
		'1'
		FROM @NOProduct NOP
		inner join Cell_Product (nolock)on Cell_Product.ProductId = NOP.ProductId
		inner join Cell(nolock) on Cell.CellId = Cell_Product.CellId
		inner join Product_LGORT (nolock)on Product_LGORT.ProductId = NOP.ProductId
		inner join Workcenter(nolock) on Product_LGORT.LGORT=Workcenter.WorkcenterName
		INNER JOIN dbo.Product(NOLOCK) ON Product.ProductId = NOP.ProductID
		WHERE 
		NOP.WHPerson=@WHPerson
		and Product_LGORT.FactoryId=@FactoryId
	 
		IF EXISTS(Select 1 From WorkCenterCellOn(nolock) where NGuid=@NGuid)
		Begin
			Exec TxnBase_WorkCenterCellOn_StockList
				@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
				@I_LanguageId =@I_LanguageId ,                         -- char(1)
				@I_PlugInCommand =@I_PlugInCommand ,                      -- varchar(5)
				@I_OrBitUserId =@I_OrBitUserId ,                        -- char(12)
				@I_OrBitUserName = @I_OrBitUserName ,                     -- nvarchar(100)
				@I_ResourceId = @I_ResourceId ,                         -- char(12)
				@I_ResourceName = @I_ResourceName ,                      -- nvarchar(100)
				@FactoryId=@FactoryId,
				@DivisionId=@DivisionId,
				@NGuid =@NGuid ,                            
				@LotStatus = '1',
				@IsOn='0'
		END

		set @I_ReturnMessage='ServerMessage:货架储位灯已全关闭!'
		select '' as BoxOrLotSN, @WHPerson as WHPerson
		SET @I_ExceptionFieldName = 'BoxOrLotSN'
		return 0
	end


	DECLARE  @PersonInfoId CHAR(12)= ''
	DECLARE @IsActivity   BIT = 0
	DECLARE @PFactoryId CHAR(12) = ''
	DECLARE @PDivisionId  CHAR(12) = ''

	if exists(select 1 from PersonInfo where PersonNumber=@BoxOrLotSN)
	begin
			
		Set @NGuid=newid()

		Set @WHPerson=@BoxOrLotSN
		exec @ReturnValues=TxnBase_CheckUserPerson
			@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
			@I_LanguageId = @I_LanguageId ,                         -- char(1)
			@I_PlugInCommand = @I_PlugInCommand ,                      -- varchar(5)
			@I_OrBitUserId = @I_OrBitUserId ,                        -- char(12)
			@I_OrBitUserName = @I_OrBitUserName ,                     -- nvarchar(100)
			@I_ResourceId =@I_ResourceId,                         -- char(12)
			@I_ResourceName =@I_ResourceName ,                      -- nvarchar(100)
			@PersonNumber = @WHPerson ,                        -- nvarchar(50)
			@UFactoryId = @UFactoryId OUTPUT ,           -- char(12)
			@UDivisionId = @UDivisionId OUTPUT ,         -- char(12)
			@PWorkCenterId = @PWorkCenterId OUTPUT ,     -- char(12)
			@UDivisionName = @UDivisionName OUTPUT       -- nvarchar(50)

		if @ReturnValues=-1
		Begin
			set @I_ExceptionFieldName='BoxOrLotSN'
			select '' as BoxOrLotSN
			return -1
		End

		--查询工单BOM产品及数量插入
		INSERT INTO @MOItemProduct
		(
			ProductID,
			ItemQtyRequired,
			WHPerson
		)
		SELECT
		DISTINCT
			MOItem.ProductId,
			ItemQtyRequired ,
			dbo.Product.WHPerson
		FROM StockList_MO  SLMO
		INNER JOIN MOItem ON SLMO.MOId = MOItem.MOId
		INNER JOIN MO ON MOItem.MOId = MO.MOID
		INNER JOIN Product ON MOItem.ProductId = Product.ProductId
		INNER JOIN ProductTypeSTD ON Product.ProductTypeSTDID =  ProductTypeSTD.ProductTypeSTDID
		WHERE SLMO.StockListId = @StockListId   			--	STLI00000020
		AND MO.ProductId <> MOItem.ProductId
		AND ItemQtyRequired > 0
		AND ProductTypeName = 'A类'
		AND ISNULL(MOItem.DeleteFlag,'') <>'X'

		INSERT INTO @MOItemProduct1
		(
			ProductID,
			ItemQtyRequired,
			WHPerson
		)
		SELECT
			ProductID ,
			ISNULL(SUM(ItemQtyRequired),0) AS ItemQtyRequired ,
			WHPerson
		FROM @MOItemProduct
		GROUP BY ProductID ,WHPerson

		--查询已发产品及数量并插入 
		INSERT INTO  @SKIProduct
		SELECT 
			ProductId,
			QtyIssued AS QtyIssued
		FROM StockListItem
		WHERE StockListId = @StockListId

		--计算未发料的产品进行插入
		INSERT INTO @NOProduct
		(
			ProductID,
			WHPerson
		)
		SELECT MIP.ProductID ,MIP.WHPerson 
		FROM 	@MOItemProduct1	MIP
		LEFT JOIN  @SKIProduct SKIPT ON MIP.ProductID = SKIPT.ProductID
		WHERE ISNULL(MIP.ItemQtyRequired,0) > ISNULL(SKIPT.QtyIssued,0)

		--插入亮灯记录表
		INSERT INTO WorkCenterCellOn
		(
			NGuid,
			FactoryId ,
			DivisionId ,
			WorkcneterId ,
			ProductId ,
			IsOn
		)SELECT DISTINCT
			@NGuid,
			@FactoryId,
			@DivisionId,
			Workcenter.WorkcenterId,
			--NOP.ProductID ,
						CASE LEFT(ISNULL(dbo.Product.prdname,''),2) WHEN 'KG'
				THEN (SELECT ProductId FROM dbo.Product 
				WHERE prdname=(SELECT RIGHT(prdname,LEN(prdname)-2) FROM dbo.Product WHERE ProductId=Product.ProductId))
				ELSE NOP.ProductId
                END,
			'1'
			FROM @NOProduct NOP
			inner join Cell_Product (nolock)on Cell_Product.ProductId = NOP.ProductId
			inner join Cell(nolock) on Cell.CellId = Cell_Product.CellId
			inner join Product_LGORT (nolock)on Product_LGORT.ProductId = NOP.ProductId
			inner join Workcenter(nolock) on Product_LGORT.LGORT=Workcenter.WorkcenterName
			INNER JOIN dbo.Product(NOLOCK) ON Product.ProductId = NOP.ProductID
			WHERE 
			NOP.WHPerson=@WHPerson
			and Product_LGORT.FactoryId=@FactoryId
	 
			IF EXISTS(Select 1 From WorkCenterCellOn(nolock) where NGuid=@NGuid)
			Begin
				Exec TxnBase_WorkCenterCellOn_StockList
					@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
					@I_LanguageId =@I_LanguageId ,                         -- char(1)
					@I_PlugInCommand =@I_PlugInCommand ,                      -- varchar(5)
					@I_OrBitUserId =@I_OrBitUserId ,                        -- char(12)
					@I_OrBitUserName = @I_OrBitUserName ,                     -- nvarchar(100)
					@I_ResourceId = @I_ResourceId ,                         -- char(12)
					@I_ResourceName = @I_ResourceName ,                      -- nvarchar(100)
					@FactoryId=@FactoryId,
					@DivisionId=@DivisionId,
					@NGuid =@NGuid ,                            
					@LotStatus = '1',
					@IsOn='1'
			END

		set @I_ReturnMessage='ServerMessage:工号识别成功，亮灯，请扫描物料! '
		set @I_ExceptionFieldName='BoxOrLotSN'
		select '' as BoxOrLotSN, @WHPerson as WHPerson
		return 0
	End

	exec @ReturnValues=TxnBase_CheckUserPerson
		@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
		@I_LanguageId = @I_LanguageId ,                         -- char(1)
		@I_PlugInCommand = @I_PlugInCommand ,                      -- varchar(5)
		@I_OrBitUserId = @I_OrBitUserId ,                        -- char(12)
		@I_OrBitUserName = @I_OrBitUserName ,                     -- nvarchar(100)
		@I_ResourceId =@I_ResourceId,                         -- char(12)
		@I_ResourceName =@I_ResourceName ,                      -- nvarchar(100)
		@PersonNumber = @WHPerson ,                        -- nvarchar(50)
		@UFactoryId = @UFactoryId OUTPUT ,           -- char(12)
		@UDivisionId = @UDivisionId OUTPUT ,         -- char(12)
		@PWorkCenterId = @PWorkCenterId OUTPUT ,     -- char(12)
		@UDivisionName = @UDivisionName OUTPUT       -- nvarchar(50)

	if @ReturnValues=-1
	Begin
		set @I_ExceptionFieldName='BoxOrLotSN'
		select '' as BoxOrLotSN
		return -1
	End

	--手动按钮触发回传SAP
	IF ISNULL( @I_Sender,'') = 'SubmitSAPUp'
	BEGIN
		SET @NGuid = ''

		SET @NGuid = NEWID()

		--赋值
		SELECT
			@StockListId = StockListId,
			@FactoryId = FactoryId,
			@DivisionId = DivisionId
		FROM  StockList(nolock)
		WHERE StockListName = @StockListName 

		--查询工单BOM产品及数量插入
		INSERT INTO @MOItemProduct
		(
			ProductID,
			ItemQtyRequired,
			WHPerson
		)
		SELECT
		DISTINCT
			MOItem.ProductId,
			ItemQtyRequired ,
			dbo.Product.WHPerson
		FROM StockList_MO  SLMO
		INNER JOIN MOItem ON SLMO.MOId = MOItem.MOId
		INNER JOIN MO ON MOItem.MOId = MO.MOID
		INNER JOIN Product ON MOItem.ProductId = Product.ProductId
		INNER JOIN ProductTypeSTD ON Product.ProductTypeSTDID =  ProductTypeSTD.ProductTypeSTDID
		WHERE SLMO.StockListId = @StockListId   			--	STLI00000020
		AND MO.ProductId <> MOItem.ProductId
		AND ItemQtyRequired >0
		AND ProductTypeName = 'A类'
		AND ISNULL(MOItem.DeleteFlag,'') <>'X'

		INSERT INTO @MOItemProduct1
		(
			ProductID,
			ItemQtyRequired,
			WHPerson
		)
		SELECT
			ProductID ,
			ISNULL(SUM(ItemQtyRequired),0) AS ItemQtyRequired ,
			WHPerson
		FROM @MOItemProduct
		GROUP BY ProductID ,WHPerson

		--查询已发产品及数量并插入 
		INSERT INTO  @SKIProduct
		SELECT 
			ProductId,
			QtyIssued AS QtyIssued
		FROM StockListItem
		WHERE StockListId = @StockListId

		--计算未发料的产品进行插入
		INSERT INTO @NOProduct
		(
			ProductID,
			WHPerson
		)
		SELECT MIP.ProductID ,MIP.WHPerson 
		FROM 	@MOItemProduct1	MIP
		INNER JOIN  @SKIProduct SKIPT ON MIP.ProductID = SKIPT.ProductID
		WHERE ISNULL(MIP.ItemQtyRequired,0) = ISNULL(SKIPT.QtyIssued,0)
		AND ISNULL(MIP.ItemQtyRequired,0) > 0
		AND ISNULL(SKIPT.QtyIssued,0) > 0
			
		--插入亮灯记录表
		INSERT INTO WorkCenterCellOn
		(
			NGuid,
			FactoryId ,
			DivisionId ,
			WorkcneterId ,
			ProductId ,
			IsOn
		)
		SELECT DISTINCT
		@NGuid,
		@FactoryId,
		@DivisionId,
		Workcenter.WorkcenterId,
		--NOP.ProductID ,
					CASE LEFT(ISNULL(dbo.Product.prdname,''),2) WHEN 'KG'
				THEN (SELECT ProductId FROM dbo.Product 
				WHERE prdname=(SELECT RIGHT(prdname,LEN(prdname)-2) FROM dbo.Product WHERE ProductId=Product.ProductId))
				ELSE NOP.ProductId
                END,
		'1'
		FROM @NOProduct NOP
		inner join Cell_Product (nolock)on Cell_Product.ProductId = NOP.ProductId
		inner join Cell(nolock) on Cell.CellId = Cell_Product.CellId
		inner join Product_LGORT (nolock)on Product_LGORT.ProductId = NOP.ProductId
		inner join Workcenter(nolock) on Product_LGORT.LGORT=Workcenter.WorkcenterName
		INNER JOIN dbo.Product(NOLOCK) ON Product.ProductId = NOP.ProductID
		WHERE 
		NOP.WHPerson=@WHPerson
		and Product_LGORT.FactoryId=@FactoryId
	 
		IF EXISTS(Select 1 From WorkCenterCellOn(nolock) where NGuid=@NGuid)
		Begin
			Exec TxnBase_WorkCenterCellOn_StockList
				@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
				@I_LanguageId =@I_LanguageId ,                         -- char(1)
				@I_PlugInCommand =@I_PlugInCommand ,                      -- varchar(5)
				@I_OrBitUserId =@I_OrBitUserId ,                        -- char(12)
				@I_OrBitUserName = @I_OrBitUserName ,                     -- nvarchar(100)
				@I_ResourceId = @I_ResourceId ,                         -- char(12)
				@I_ResourceName = @I_ResourceName ,                      -- nvarchar(100)
				@FactoryId=@FactoryId,
				@DivisionId=@DivisionId,
				@NGuid =@NGuid ,                            
				@LotStatus = '1',
				@IsOn='0'
		END

		--更新状态
		UPDATE ProductIssueMOItem SET IsCompete = 1 WHERE StockListID = @StockListID AND Operator = @WHPerson and IsCompete = 0
		--判断备料，然后回传调用发料接口
		IF exists(SELECT 1 FROM ProductIssueMOItem where StockListID = @StockListID and Operator = @WHPerson And IsCompete = 1  and IsOK =0)
		Begin
				--执行回传SAP
			Exec @returnValue= Interface_CommonToExe
				@InterfaceName = N'MES_UpSAP_StockList' , -- nvarchar(50)
				@I_OrbitUserId = @I_OrBitUserId ,            -- char(12)
				@PersonNumber = @WHPerson ,              -- varchar(30)
				@ExeNote = N'备料单烧录类回传SAP' ,                     -- nvarchar(100)
				@BillType = @BillsType ,                         -- nvarchar(100)
				@BillNumber = @StocklistName ,            -- nvarchar(100)
				@ExeParameter1 = N'' ,                       -- nvarchar(500)
				@ExeParameter2 = N'' ,                       -- nvarchar(500)
				@ExeParameter3 = N'' ,                       -- nvarchar(500)
				@ExeParameter4 = N'' ,                       -- nvarchar(500)
				@IsOk = @IsOk OUTPUT ,                       -- bit
				@ReturnMessage = @I_ReturnMessage OUTPUT       -- nvarchar(max)

			If @returnValue = -1
			Begin
				SELECT '' as BoxOrLotSN,@LotProductName as ProductName
				SET  @I_ExceptionFieldName='BoxOrLotSN'
				return -1
			End

			If @IsOk = 0
			Begin
				SELECT '' as BoxOrLotSN,@LotProductName as ProductName
				SET  @I_ExceptionFieldName='BoxOrLotSN'
				return -1
			End
		End


		SELECT '' as BoxOrLotSN
		SET @I_ExceptionFieldName = 'BoxOrLotSN'
		RETURN 0

	END

	--写入工单清单
	Insert into @MOList
	(
		MaterialIssuanceId,
	    MOId,
		ProductId,
		CreateDate
	)
	Select
		DISTINCT
		MaterialIssuanceId ,
		StockList_MO.MOId ,
		ProductId ,
		StockList_MO.CreateDate
	from StockList_MO (nolock)
	inner join MO (nolock) on MO.MOId =  StockList_MO.MOId
	where StockList_MO.StockListId = @StockListId

	--查询备料工单明细物料仓库、产品、数量
	INSERT  INTO @MOItem
	(	WareHouseId ,
	    ProductId ,
	    ItemRequiredQty)
	SELECT WK.WorkcenterId,
	       MI.ProductId,
		   ISNULL(SUM(MI.ItemQtyRequired),0) AS ItemQtyRequired 
	 FROM @MOList MOL 
	INNER JOIN MOItem  MI(NOLOCK) ON MOL.MOId = MI.MOId AND MOL.ProductId <> MI.ProductId AND ISNULL(MI.DeleteFlag,'') = '' 
	INNER JOIN  (SELECT distinct ProductId,FactoryId,LGORT from  Product_LGORT  ) AS PL ON MI.ProductId = PL.ProductId	
	INNER JOIN Workcenter WK (NOLOCK) ON PL.LGORT = WK.WorkcenterName  
	WHERE PL.FactoryId = @FactoryId
	GROUP BY WK.WorkcenterId,  MI.ProductId

	-- 检查该发料单是否存在发料物料明细
	IF NOT EXISTS(SELECT 1 FROM @MOItem)
	BEGIN
		set @I_ReturnMessage='ServerMessage:该备料单 '+@StockListName+' 没有找到明细行项，不允许发料!'
		SELECT '' AS BoxOrLotSN
		set @I_ExceptionFieldName='BoxOrLotSN'
		return -1
	END

	--更新物料仓管员至临时表
	update @MOItem Set 
		WHPerson=Product.WHPerson
	from
		Product(nolock)
	Inner join @MOItem M on M.ProductId=Product.ProductId
	Where IsActivity=1


	--获取登陆用户负责的仓库/工作中心
	insert into @UProduct
	(
	    ProductId
	)
	select
		  ProductId
	 from @MOItem
	where WHPerson=@WHPerson

	--如果操作员不存在扫描的时候则报错
	if not exists(Select 1 From @UProduct)
	Begin
		SET @I_ReturnMessage='ServerMessage:操作员工号没有任何需要管理的物料，请检查!'
		SELECT '' as BoxOrLotSN,'' as PersonNumber
		SET @I_ExceptionFieldName = 'BoxOrLotSN'
		return -1
	End

	IF  ISNULL(@BoxOrLotSN,'') = ''
	BEGIN
		SET @I_ReturnMessage= 'ServerMessage:请扫描箱号或者小包条码！！！'
		SELECT '' AS BoxOrLotSN,'' as ProductName, @WHPerson AS  WHPerson,'' as RequiredQty,'' as QtyIssued,'' AS OweQty
		SET @I_ExceptionFieldName='BoxOrLotSN'
		RETURN -1
	END

	--转换扫描的条码区分是否为R/B
	SET @BoxOrLotSN  = UPPER(LTRIM(RTRIM(@BoxOrLotSN)))

	SET @LotType = left(@BoxOrLotSN,1)

	
	
	--判断批号
	insert into @LotList
	exec @ReturnValues=TxnBase_CheckStockLotSNBills
	 	 @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
		 @FactoryId = @UFactoryId ,                            -- char(12)
		 @WorkcenterId = '' ,                         -- char(12)
		 @MBoxSNOrLotSN = @BoxOrLotSN ,                       -- nvarchar(50)
		 @LotStatus = '1',                             -- char(1)
		 @WHPerson = @WHPerson

	if @ReturnValues=-1
	Begin
		set @I_ExceptionFieldName='BoxOrLotSN'
		select '' as BoxOrLotSN
		return -1
	End

	--检查是否存在发料批号
	if not exists(select 1 from @LotList)
	begin
		set @I_ReturnMessage='ServerMessage:没有找到可发料出库的物料批号，请检查!'
		SELECT '' AS BoxOrLotSN
		set @I_ExceptionFieldName='BoxOrLotSN'
		RETURN -1
	end 

	--获取扫描批号的ProductId
	SELECT TOP 1
		@MProductId    = ProductId ,
		@FWorkcenterId = WorkcenterId,
		@WarehouseId  = WorkcenterId ,
		@MUOMId        = UOMId
	FROM @LotList

	IF EXISTS(SELECT 1 FROM Workcenter WHERE WorkcenterId=@WarehouseId  AND ( IsClosed=1 or IsLock=1) )
	BEGIN		
		set @I_ReturnMessage='ServerMessage:仓库已关闭/锁定，请检查!'
		SELECT '' as BoxOrLotSN
		SET @I_ExceptionFieldName= 'BoxOrLotSN'
		return -1
	END 

	--判断扫描的物料是否在发料工单内，如果不存在，则转换再判断一次，都没有则报错
	IF NOT EXISTS(SELECT 1 FROM @MOItem WHERE ProductId=@MProductId)
	BEGIN
	DECLARE @KGProductid CHAR(12);--临时转换
	DECLARE @KGPrdname NVARCHAR(50);
	SELECT @KGPrdname=prdname FROM dbo.Product WHERE ProductId=@MProductId
	SELECT @KGProductid=ProductId FROM dbo.Product WHERE prdname='KG'+@KGPrdname

    IF  EXISTS (SELECT 1 FROM @MOItem WHERE ProductId=@KGProductid) AND ISNULL(@KGProductid,'')<>''
	BEGIN
    SET @MProductId=@KGProductid
	end
	end

	--update by 1001570 12-19,针对备料单判断是否备料


	IF EXISTS(select 1 from StockListItemLot(nolock) a
	INNER JOIN dbo.StockListItem b ON b.StockListItemId = a.StockListItemId
	INNER JOIN dbo.StockList c ON c.StockListId = b.StockListId
	WHERE c.StockListName=@StockListName AND  LotSN in(select Lotsn from @LotList)  )
	BEGIN
		set @I_ReturnMessage='ServerMessage:批号不能重复扫描，不能重复备料！！！'
		SELECT '' AS BoxOrLotSN
		set @I_ExceptionFieldName='BoxOrLotSN'
		RETURN -1
	END
  

	--获取本次扫描数量
	Select @MQty=Sum(IsNull(LotQty,0) )   from @LotList

  -----------------------------------------------------------------------------------------------------
	----判断其他备料单中是否存在与当前单号相同的数量
 --   DECLARE @BoxQty FLOAT = 0
	
	----如果存在箱号
	--IF EXISTS (SELECT 1 FROM StockListItemLot WHERE BoxSN  =  @BoxOrLotSN)
	--BEGIN
	--	   SET @BoxQty = 0

	--	   --赋值存在的箱号数量
	--	   SELECT @BoxQty = SUM(Qty) FROM  StockListItemLot 
	--	   WHERE BoxSN = @BoxOrLotSN
	--		--如果箱号总数大于0， 并且箱号总数量等于 扫描的数量则该箱号存在此表中
	--	   IF ISNULL (@BoxQty,0)>0 AND ISNULL (@BoxQty,0) = ISNULL (@MQty,0)
	--	   BEGIN
	--			SET @I_ReturnMessage='ServerMessage:扫描批号【'+@BoxOrLotSN+'】已备料，备料单【'+@StockListName+'】'
	--			+'ServerMessage:箱数【'+CAST(@BoxQty AS VARCHAR)+'】,批号数【'+CAST(@MQty AS VARCHAR)+'】.'
	--			SELECT '' AS BoxOrLotSN
	--			SET @I_ExceptionFieldName='BoxOrLotSN'
	--			RETURN -1
	--	   END
	--END

 --  --如果扫描的是批号可直接判定
	--IF EXISTS(SELECT 1 FROM dbo.StockListItemLot WHERE LotSN = @BoxOrLotSN AND Qty = @MQty)
	--BEGIN
		
	--	SET @I_ReturnMessage='ServerMessage:扫描批号【'+@BoxOrLotSN+'】已备料.备料单【'+@StockListName+'】'
	--	+'ServerMessage:批号数【'+CAST(@MQty AS VARCHAR)+'】.'
	--	SELECT '' AS BoxOrLotSN
	--	SET @I_ExceptionFieldName='BoxOrLotSN'
	--	RETURN -1
	--end
---------------------------------------------------------------------------------------	
	--获取备料单行信息
	DECLARE @QtyRequired decimal(18,6) = 0	  --产品总需求数
	DECLARE @QtyIssued decimal(18,6) = 0		  --产品总已发数

	--SELECT 
	--	@QtyRequired=SUM(ISNULL(ItemRequiredQty,0))   --产品总需求数
	--FROM @MOItem
	--WHERE  ProductId=@MProductId

	--产品总数量
	declare  @table table 
	(
		moid  char(12)
	)

	insert into @table
	select distinct MOId from StockList_MO where StockListId = @StockListId

  	SELECT 
 		@QtyRequired= SUM(ISNULL(MI.ItemQtyRequired,0)) 
	FROM @table t
	inner join MOItem (nolock) mi ON T.MOID = MI.MOId
	WHERE  MI.ProductId=@MProductId
	AND MI.DeleteFlag <> 'X'
   
	--计算发料数量
	SELECT 
		@StockListItemId = StockListItemId	,
		@QtyIssued = ISNULL(QtyIssued,0)		 --产品总已发数
	FROM StockListItem (nolock)
	WHERE StockListId = @StockListId 
		AND ProductId = @MProductId

    --获取发料扫描的条码产品号
	select @LotProductName=ProductName 
	from Product	(NOLOCK)
	inner join ProductRoot (NOLOCK)on ProductRoot.ProductRootId = Product.ProductRootId
	where ProductId=@MProductId    
	
	--如果已发数已等于需求数不允许发料
	IF ISNULL(@QtyIssued,0) >= ISNULL(@QtyRequired,0)
	BEGIN
		SET @I_ReturnMessage='ServerMessage:物料 ['+@LotProductName+'] 已备料数已满足需备料总数!'+cast(isnull(@QtyRequired,0) as nvarchar(50))
		SELECT '' AS BoxOrLotSN,@LotProductName as ProductName,@QtyRequired as RequiredQty,@QtyIssued as QtyIssued,(@QtyRequired-@QtyIssued) as OweQty
		SET @I_ExceptionFieldName='BoxOrLotSN'
		RETURN -1
	END

	--不允许超发
	IF ISNULL(@QtyIssued,0)+ISNULL(@MQty,0)>ISNULL(@QtyRequired,0)
	BEGIN
		SET @I_ReturnMessage='ServerMessage:物料 ['+@LotProductName+'] 已备料数加本发料数超过需备料总数！'
		SELECT '' AS BoxOrLotSN,@LotProductName as ProductName,@QtyRequired as RequiredQty,@QtyIssued as QtyIssued,(@QtyRequired-@QtyIssued) as OweQty
		SET @I_ExceptionFieldName='BoxOrLotSN'
		RETURN -1
	END
		
	--------------------------------------------2020 12 19 Alick 增加烧录类备料回传SAP ------------------------------------------------
	DECLARE @ProductTypeSTDID char(12) = ''	  --产品类别

	--获取扫描的产品类型
	SELECT 
	  @ProductTypeSTDID = ProductTypeSTDID 
	FROM  Product 
	WHERE ProductId = @MProductId

	--如果是A类物料
	IF ISNULL(@ProductTypeSTDID, '') = 'PSTD00000001'
	BEGIN

		IF ISNULL (@StockListItemId,'') = ''
		BEGIN
			EXEC SysGetObjectPKid '','StockListItem',@StockListItemId OUTPUT
			INSERT INTO StockListItem (
					StockListItemId,
					StockListId,
					ProductId,
					QtyRequired,
					QtyIssued ,
					WorkcenterId,
					UOMId,
					IsCompete,
					CreateDate)
				VALUES
					(@StockListItemId,
					@StockListId,
					@MProductId,
					@QtyRequired,
					@MQty,
					@WarehouseId,
					@MUOMId,
					'0',
					GETDATE())
		END
		ELSE
		BEGIN
			UPDATE StockListItem SET 
				QtyIssued = @QtyIssued + @MQty
			WHERE StockListID = @StockListId 
			  AND ProductId = @MProductId
		END

		--声明游标变量
		DECLARE @TempWWID CHAR(12) ='',
	      		@TempLotSN NVARCHAR(50) = '',
				@TempBoxSN NVARCHAR(50) = '',
				@TempQty  decimal(18,6) = 0,
				@TempProductId CHAR(12) ='', 
				@TempWarehouseId CHAR(12) ='',
				@TempUomID char(12)=''

		--游标循环
		DECLARE CURSORLotTemp CURSOR FOR 
		SELECT WWId,LotSN,BoxSN,LotQty,WorkcenterId,ProductId,UOMId FROM @LotList
		OPEN CURSORLotTemp 
		FETCH NEXT FROM  CURSORLotTemp 
		INTO @TempWWID,@TempLotSN, @TempBoxSN,@TempQty ,@TempWarehouseId ,@TempProductId,@TempUomID
		WHILE @@FETCH_STATUS = 0 
		BEGIN 

			Exec TxnBase_LotTrack
				@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
				@I_PlugInCommand = @I_PlugInCommand ,                      -- varchar(5)
				@I_OrBitUserId = @I_OrBitUserId ,                        -- char(12)
				@I_OrBitUserName = @I_OrBitUserName,                     -- nvarchar(100)
				@I_ResourceId = @I_ResourceId ,                         -- char(12)
				@I_ResourceName = @I_ResourceName ,                      -- nvarchar(100)
				@LotId = '' ,                                -- char(12)
				@LotSN = @TempLotSN ,                               -- nvarchar(50)
				@LotQty = @TempQty ,                             -- decimal(18, 6)
				@IsRelease = 1 ,                            -- bit
				@PersonNumber = @WHPerson ,                        -- nvarchar(50)
				@BillsNumber = @StockListName ,                         -- nvarchar(50)
				@BillsType = N'备料单' ,                           -- nvarchar(50)
				@FromWorkcenrerId ='',
				@WorkcenterId=@WarehouseId,
				@ToWorkcenterId=@WarehouseId,
				@WarehouseInOut='',
				@TxnCode = N'备料下架' ,                             -- nvarchar(50)
				@Remark = N''                                -- nvarchar(200)
		   
			EXEC SysGetObjectPKid '','StockListItemLot',@StockListItemLotId OUTPUT
			-- 写入发料表
			INSERT INTO StockListItemLot(
					StockListItemLotId,
					StockListItemId,
					ProductId,
					LotSN,
					BoxSN,
					Qty,
					StockType,
					CreateUserId,
					CreateDate)
				VALUES(
					@StockListItemLotId, -- StockListItemLotId - char(12)
					@StockListItemId, -- StockListItemId - char(12)
					@MProductId, -- ProductId - char(12)
					@TempLotSN, -- LotSN - nvarchar(50)
					@TempBoxSN,
					@TempQty, -- Qty - decimal(18, 8)
					@LotType, -- StockType - char(1)
					@I_OrBitUserId, -- CreateUserId - char(12)
					GETDATE() -- CreateDate - datetime
					)

			SET @TempWWID  =''
			SET @TempLotSN  = ''
			SET @TempBoxSN  = ''
			SET @TempQty =0
			SET @TempWarehouseId  =''
			SET @TempProductId = '' 
			SET @TempUomID 	= ''
			FETCH NEXT FROM  CURSORLotTemp 
			INTO @TempWWID,@TempLotSN, @TempBoxSN,@TempQty ,@TempWarehouseId, @TempProductId,@TempUomID    
		END
		CLOSE CURSORLotTemp 
		DEALLOCATE CURSORLotTemp

		SET @QtyIssued=isnull(@QtyIssued,0)+isnull(@MQty,0)

		if @StockListStates='20'
		Begin
			UPDATE StockList SET 
				StockListStates = '30' 
			WHERE StockListId = @StockListId
		END
        
		IF   NOT EXISTS (select 1 from StockListItem where StockListId = @StockListId and ProductId = @MProductId and QtyRequired > QtyIssued )
	    BEGIN
	     
		SELECT 	@CarProductid=		CASE LEFT(ISNULL(dbo.Product.prdname,''),2) WHEN 'KG'
				THEN (SELECT ProductId FROM dbo.Product 
				WHERE prdname=(SELECT RIGHT(prdname,LEN(prdname)-2) FROM dbo.Product WHERE ProductId=ProductId))
				ELSE ProductId
                end FROM dbo.Product
				WHERE ProductId=@MProductId

			set @NGuid=''
			Set @NGuid=newid()
			insert into WorkCenterCellOn
			(
				NGuid,
				FactoryId ,
				DivisionId ,
				WorkcneterId ,
				ProductId ,
				IsOn
			)values(
				@NGuid,
				@UFactoryId,
				@UDivisionId,
				@WarehouseId,
				@CarProductid,
				'0')

			Exec TxnBase_WorkCenterCellOn_StockList
				@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
				@I_LanguageId =@I_LanguageId ,                         -- char(1)
				@I_PlugInCommand =@I_PlugInCommand ,                      -- varchar(5)
				@I_OrBitUserId =@I_OrBitUserId ,                        -- char(12)
				@I_OrBitUserName = @I_OrBitUserName ,                     -- nvarchar(100)
				@I_ResourceId = @I_ResourceId ,                         -- char(12)
				@I_ResourceName = @I_ResourceName ,                      -- nvarchar(100)
				@FactoryId=@UFactoryId,
				@DivisionId=@UDivisionId,
				@NGuid =@NGuid , 
				@LotStatus = '1' ,
				@IsOn='0'

	    END

		SELECT  '' AS BoxOrLotSN,
			   @LotProductName as ProductName,
			   isnull(@QtyRequired,0) as RequiredQty,
			   isnull(@QtyIssued,0) as QtyIssued,
			   (isnull(@QtyRequired,0)-isnull(@QtyIssued,0)) as OweQty ,
			   @StockListName AS HideStockListName

		set @I_ReturnMessage= 'ServerMessage:物料 ['+@BoxOrLotSN+'] 备料成功，备料数量：'+CAST(isnull(@MQty,0) as varchar)
		set @I_ExceptionFieldName='BoxOrLotSN'
	   
		RETURN 0
	END
	
	--如果是 烧录类物料
	IF ISNULL (@ProductTypeSTDID ,'') = 'PSTD00000006'
	BEGIN
	  --发料单内工单明细表
		DECLARE @MOItem1 TABLE
		(			   
			MOItemId char(12),
			LineSequence nvarchar(50),
			WareHouseId char (12) ,   --仓库Id
			MOId char (12) ,	--工单Id
			ProductId char (12) ,	--物料Id
			ItemRequiredQty decimal (18, 6) ,		--工单明细需求量
			ItemIssuedQty decimal (18, 6) ,	--工单明细已发放数量
			IsCompete bit ,
			WHPerson nvarchar(50),
			CreateDate datetime
		)
		
		DECLARE @DefaultWarehouseId CHAR(12) = ''

		-- 获取默认仓库Id
		SELECT
			@DefaultWarehouseId = WorkcenterId
		FROM dbo.Product_LGORT
		INNER JOIN dbo.Workcenter ON Workcenter.WorkcenterName = Product_LGORT.LGORT
		WHERE Product_LGORT.ProductId = @MProductId
			AND Product_LGORT.FactoryId = @FactoryId
 
		--获取备料单中各工单明细列表
		insert into @MOItem1
		(
			MOItemId,
			LineSequence,
			WareHouseId ,
			MOId ,
			ProductId ,
			ItemRequiredQty ,
			ItemIssuedQty ,
			CreateDate
		)
		SELECT
			distinct
			MOItem.MOItemId,
			LineSequence,
			Workcenter.WorkcenterId  ,
			ML.MOId ,
			MOItem.ProductId ,
			MOItem.ItemQtyRequired ,
			IsNull(MOItem.ItemQtyIssued,0),
			ML.CreateDate
		FROM
			@MOList ML 
		Inner join MOItem (nolock) on ML.MOId = MOItem.MOId and ML.ProductId<>MOItem.ProductId
		Inner join Product(NoLock) on Product.ProductId = MOItem.ProductId
		Inner join Product_LGORT (NoLock)on Product_LGORT.ProductId = MOItem.ProductId 
		left join Workcenter on Product_LGORT.LGORT=Workcenter.WorkcenterName
		WHERE MOItem.DeleteFlag <>'X'
			And isnull(MOItem.ItemQtyRequired,0)>0
			And Product.ProductTypeSTDID='PSTD00000006'
			And Product_LGORT.FactoryId=@UFactoryId
		ORDER BY ML.CreateDate

	   --获取发出的仓库
		SELECT TOP 1 
			@TWorkcenterId = SLMO.WorkcenterID
		FROM @MOItem1 MOIM
		INNER JOIN StockList_MO SLMO (NOLOCK) ON MOIM.MOId = SLMO.MOId
		WHERE ProductId = @MProductId

		--备料单信息检查
		SELECT @StocklistitemId=StockListItemId 
		from Stocklistitem(nolock) 
		where StockListId=@StockListId 
			AND ProductId=@MProductId

		IF ISNULL (@StocklistitemId, '') =''
		BEGIN

			SET @FWorkcenterId = @DefaultWarehouseId

			exec SysGetObjectPKId '' , 'Stocklistitem' , @StocklistitemId OUTPUT
			insert into Stocklistitem(
					StockListItemId ,
					StockListId ,
					WorkcenterId ,
					ProductId ,
					QtyRequired,
					QtyIssued ,
					UOMId ,
					ModifyDate,
					CreateDate)
				VALUES(
					@StocklistitemId ,         -- MaterialIssuanceItemID - char(12)
					@StockListId ,         -- MaterialIssuanceID - char(12)
					@FWorkcenterId ,         -- WareHouseId - char(12)
					@MProductId ,         -- ProductId - char(12)
					@QtyRequired,
					0,       -- QtyIssued - decimal(18, 6)
					@MUOMId ,         -- UOMId - char(12)
					GETDATE () ,
					GETDATE ()   -- CreateDate - datetime
				)
		end

		 --插入记录表
		insert into ProductIssueHistory(
				BillsNumber ,
				BoxOrLotSN ,
				createdate
			)
			VALUES
			(
				@StocklistName , -- BillsNumber - nvarchar(50)
				@BoxOrLotSN ,  -- BoxOrLotSN - nvarchar(50)
				GETDATE()
			)
	
		--发料成功，更新库存信息
		UPDATE WW_RMInventory SET
			DivisionId = '' ,
			WorkcenterId = @TWorkcenterId ,
			CellId = '' ,
			IsStorage = 1 ,
			IsIssueToPickingList=1
		where LotSN in(Select LotSN from @LotList)

		--游标循环，生成发料明细批号
		Declare cursor1 CURSOR FOR
		select WWId ,LotSN ,BoxSN ,LOTQty ,ISNULL (CellId, '')
		from @LotList 
		open cursor1
		fetch next from cursor1
		into @WWId , @MLotSN , @MBoxSN , @MLotQty ,@MCellId
		while @@FETCH_STATUS = 0
		BEGIN
			SET @FWorkcenterId = @DefaultWarehouseId

			--写入批号追溯表
			exec TxnBase_LotTrack
				@I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
				@I_PlugInCommand = @I_PlugInCommand ,                      -- varchar(5)
				@I_OrBitUserId = @I_OrBitUserId,                        -- char(12)
				@I_OrBitUserName = @I_OrBitUserName ,                     -- nvarchar(100)
				@I_ResourceId = @I_ResourceId ,                         -- char(12)
				@I_ResourceName =@I_ResourceName ,                      -- nvarchar(100)
				@LotId = '' ,                                -- char(12)
				@LotSN = @MLotSN ,                               -- nvarchar(50)
				@LotQty = @MLotQty ,                             -- decimal(18, 6)
				@IsRelease = 1 ,                            -- bit
				@PersonNumber = @WHPerson ,                        -- nvarchar(50)
				@BillsNumber = @StocklistName ,                         -- nvarchar(50)
				@BillsType =@BillsType ,                           -- nvarchar(50)
				@WorkcenterId=@FWorkcenterId,
				@ToWorkcenterId=@TWorkcenterId,
				@WarehouseInOut='Out',
				@TxnCode = N'备料下架' ,                             -- nvarchar(50)
				@Remark = N''                                -- nvarchar(200)

			Update StocklistitemLot Set 
				  IsMaterials=1
			where StockListItemId=@StocklistitemId And LotSN =@MLotSN

			exec SysGetObjectPKId '','StocklistItemLot',@StocklistItemLotId OUTPUT -- char(12)		
			--写入发料明细批号
			INSERT INTO.StocklistItemLot(
					StocklistItemLotId ,
					StocklistItemId ,
					ProductId ,
					LotSN ,
					BoxSN ,
					Qty ,
					CreateUserId ,
					CreateDate)
				values(
					@StocklistItemLotId,
					@StocklistItemId ,
					@MProductId ,
					@MLotSN,
					@MBoxSN,
					@MLotQty,		
					@I_OrBitUserId,
					GETDATE ()
				)

			set @StocklistItemLotId=''
			Set @WWId=''
			Set @MLotSN=''
			Set @MBoxSN=''
			Set @MLotQty=null
			Set @MCellId=''
			fetch next from cursor1
			into @WWId , @MLotSN , @MBoxSN , @MLotQty ,@MCellId
		end
		close cursor1
		deallocate cursor1

  		DECLARE @MOId CHAR(12) 	--工单
		DECLARE @MOItemId CHAR(12) 	 --工单明细
		DECLARE @LineSequence NVARCHAR(10)	--行号
		DECLARE @ItemRequiredQty float	 --需求数量
		DECLARE @ItemIssuedQty float	----已发数量
		DECLARE @NowIssuedQty FLOAT=0  --剩余发料数量
		DECLARE @IsCompete bit=0

		DECLARE @ProductIssueMOItemId CHAR(12)
				
		--已发数量加上本次发料数量
		SET @QtyIssued=@QtyIssued+@MQty

		--按工单分配数量，更新工单行已发数量
		WHILE(IsNull(@MQty,0)>0) 
		BEGIN
			SET @FWorkcenterId = @DefaultWarehouseId

			if not exists(Select 1 from @MOItem1 WHERE ProductId = @MProductId AND isnull(ItemRequiredQty,0)>IsNull(ItemIssuedQty,0))
				set @MQty=0

			if exists(Select 1 from @MOItem1 WHERE ProductId = @MProductId AND isnull(ItemRequiredQty,0)>IsNull(ItemIssuedQty,0))
			Begin
				set @MOId=''
				set @MOItemId=''
				set @LineSequence=''
				set @ItemRequiredQty=0
				set @ItemIssuedQty=0

				SELECT TOP 1
					@MOId = MOId ,
					@MOItemId = MOItemId ,
					@LineSequence=LineSequence,
					@ItemRequiredQty = ItemRequiredQty ,
					@ItemIssuedQty = isNull(ItemIssuedQty,0)
				FROM @MOItem1
				WHERE ProductId = @MProductId
				  AND ItemRequiredQty > Isnull(ItemIssuedQty,0)
				ORDER BY CreateDate

				--当前行次剩余发料数 判断
				if @MQty <isnull(@ItemRequiredQty,0)-isnull(@ItemIssuedQty,0) 
				Begin
					Set @NowIssuedQty = @MQty
					Set @IsCompete=0
				End
				else
				Begin
					Set @NowIssuedQty=isnull(@ItemRequiredQty,0)-isnull(@ItemIssuedQty,0)
					Set @IsCompete=1
				End

				--更新发料单明细表已发数量
				Update StockListItem set QtyIssued=IsNull(QtyIssued,0)+@NowIssuedQty where StockListItemId=@StockListItemId
			
				--更新变量表发料单明细发料数
				Update @MOItem1 Set ItemIssuedQty=IsNull(ItemIssuedQty,0)+@NowIssuedQty,IsCompete=@IsCompete where MOItemId=@MOItemId
			
				--更新工单明细表已发数量
				Update MOItem Set ItemQtyIssued=IsNull(ItemQtyIssued,0)+ @NowIssuedQty where MOItemId=@MOItemId

				Set @ProductIssueMOItemId='' 
				select
					@ProductIssueMOItemId = ProductIssueMOItemId
				from ProductIssueMOItem
				where StocklistID = @StockListId
					And MOId=@MOId
					And MOItemId=@MOItemId
					And ProductId = @MProductId			
					And IsCompete = 0
					AND WareHouseId = @FWorkcenterId

				IF ISNULL (@ProductIssueMOItemId, '') =''
				begin
					exec SysGetObjectPKId '' , 'ProductIssueMOItem' , @ProductIssueMOItemId OUTPUT
					insert into ProductIssueMOItem(
							ProductIssueMOItemId ,
							MaterialIssuanceId,
							StockListId,
							MOId ,
							MOItemId,
							LineSequence,
							WareHouseId ,
							ProductId ,
							ItemIssuedQty ,
							UOMId ,
							IsOK ,
							BillNumber ,
							ProveNumber ,
							ProveYear ,
							UpLoadDate ,
							IsCompete ,
							OperatorId ,
							Operator,
							CreateDate)
						VALUES(
							@ProductIssueMOItemId ,         -- MaterialIssuanceItemID - char(12)
							'',
							@StockListId ,
							@MOId ,         -- MOId - char(12)
							@MOItemId,
							@LineSequence,
							@FWorkcenterId ,         -- WareHouseId - char(12)
							@MProductId ,         -- ProductId - char(12)
							@NowIssuedQty,       -- ItemIssuedQty - decimal(18, 6)
							@MUOMId ,         -- UOMId - char(12)
							0 ,       -- IsOK - bit
							N'' ,        -- BillNumber - nvarchar(50)
							N'' ,        -- ProveNumber - nvarchar(50)
							N'' ,        -- ProveYear - nvarchar(50)
							GETDATE () , -- UpLoadDate - datetime
							@IsCompete ,       -- IsCompete - bit
							@I_OrBitUserId ,         -- OperatorId - char(12)
							@WHPerson,
							GETDATE ()   -- CreateDate - datetime
						)
				end
				else
				begin					
					Update ProductIssueMOItem set 
						ItemIssuedQty+=@NowIssuedQty,
						IsCompete=@IsCompete
					where ProductIssueMOItemId=@ProductIssueMOItemId			
				end

				Set @MQty-=isNull(@NowIssuedQty,0)   --减去本次发料数量

			end --发料结束
		
			IF ISNULL(@MQty, 0 ) = 0
				BREAK

			Set @MOId=''
			Set @MOItemId=''
			Set @LineSequence=''
			Set @ItemRequiredQty=0
			Set @ItemIssuedQty =0

			IF IsNull( @MQty,0) <= 0  --如果批号被发完
				BREAK
		End  




		--while 循环结束

		--SET @QtyIssued =ISNULL(@QtyIssued,0) + ISNULL(@NowIssuedQty,0)
		--SET @QtyIssuedSMT += @MTotalQty

		--更新备料单状态
		Update StockList Set
			StockListStates = '30' 
		where StockListId = @StockListId
	 	-------------------------------------------------------先注释掉，1月份使用再注释回来-----------------------------------------------

		--if not exists(select 1 from @MOItem1 where WHPerson=@WHPerson and  ItemRequiredQty>@ItemIssuedQty)
		--Begin
		--	UPDATE ProductIssueMOItem SET IsCompete = 1 WHERE StockListId = @StockListID AND Operator = @WHPerson and IsCompete = 0
		--	--判断发料，然后回传调用发料接口
		--	if exists(Select 1 from ProductIssueMOItem where StockListID = @StockListID and Operator = @WHPerson And IsCompete = 1 and IsOK =0)
		--	Begin
		--		 --执行回传SAP
		--		Exec @returnValue= Interface_CommonToExe
		--			@InterfaceName = N'MES_UpSAP_StockList' , -- nvarchar(50)
		--			@I_OrbitUserId = @I_OrBitUserId ,            -- char(12)
		--			@PersonNumber = @WHPerson ,              -- varchar(30)
		--			@ExeNote = N'发料单回传SAP' ,                     -- nvarchar(100)
		--			@BillType = @BillsType ,                         -- nvarchar(100)
		--			@BillNumber = @StocklistName ,            -- nvarchar(100)
		--			@ExeParameter1 = N'' ,                       -- nvarchar(500)
		--			@ExeParameter2 = N'' ,                       -- nvarchar(500)
		--			@ExeParameter3 = N'' ,                       -- nvarchar(500)
		--			@ExeParameter4 = N'' ,                       -- nvarchar(500)
		--			@IsOk = @IsOk OUTPUT ,                       -- bit
		--			@ReturnMessage = @I_ReturnMessage OUTPUT       -- nvarchar(max)

		--		If @returnValue = -1
		--		Begin
		--			SELECT
		--				''             as BoxOrLotSN ,
		--				@LotProductName  as ProductName ,
		--				cast(@QtyRequired as int) as QtyRequired,
		--				cast(@QtyIssued as int) as QtyIssued,
		--				(@QtyRequired-@QtyIssued) as OweQty
		--			SET  @I_ExceptionFieldName='BoxOrLotSN'
		--			return -1
		--		End

		--		If @IsOk = 0
		--		Begin
		--			SELECT
		--				''             as BoxOrLotSN ,
		--				@LotProductName  as ProductName ,
		--				cast(@QtyRequired as int) as QtyRequired,
		--				cast(@QtyIssued as int) as QtyIssued,
		--				(@QtyRequired-@QtyIssued) as OweQty
		--			SET  @I_ExceptionFieldName='BoxOrLotSN'
		--			return -1
		--		End
		--	End

		-- END

	-------------------------------------------------------先注释掉，1月份使用再注释回来-----------------------------------------------
		SELECT '' AS BoxOrLotSN,
			@LotProductName as ProductName,
			cast(@QtyRequired as float) as RequiredQty,
			cast(@QtyIssued as float) as QtyIssued ,
			(@QtyRequired-@QtyIssued) as OweQty

		set @I_ReturnMessage= 'ServerMessage: '+@BoxOrLotSN+' 发料数：'+ CAST(@MQty as varchar)+',如已发完，手动回传SAP!'
		set @I_ExceptionFieldName='BoxOrLotSN'

		RETURN 0
	END
	RETURN 0
END









