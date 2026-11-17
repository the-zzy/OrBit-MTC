 
 
CREATE PROCEDURE [dbo].[PDA_GetPanDianRefListDoMethod]   ---设备盘点清单显示,PanDianRef事务对象使用 
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKid char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@stocktakeid VARCHAR(12)='' ,
@PDOperator VARCHAR(20)='',
@DepartName NVARCHAR(50)='',
@assetnum  VARCHAR(20)=''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	---解析盘点计划，读出计划单号
	----PD1500008;生产部;冲压一车间
	DECLARE @planSN NVARCHAR(30)
	DECLARE @divisionid VARCHAR(12)=''
	IF ISNULL(@stocktakeid,'') ='' AND @I_PlugInCommand ='PDOT'
	BEGIN
      SET @I_ReturnMessage ='ServerMessage: 请退回主画面选择盘点计划表'
	  RETURN -1
	END
	--取地址
	IF @I_Sender = 'GetPanDianLocation'
	BEGIN
	  SELECT @divisionid = divisionid FROM dbo.SysUser WHERE userid = @I_OrBitUserId 
	  IF @divisionid = 'DIV10000000P'
	    SET @divisionid = 'DIV1000000SX'
       SELECT LocationName,LocationDescription FROM dbo.Location WHERE DivisionId IN('DIV10000000K','DIV10000000P','DIV1000000SX')
	   RETURN 0
	end
    IF @I_Sender = 'GetNoPanDianList'
	BEGIN
	  IF @I_PlugInCommand ='PDOT '
	  begin
       SELECT Row_Number() over ( order by getdate() ) as init,assetnum,descriptionx,'未盘点' AS 状态,roomer,IsSoftAsset 
	   FROM assetdetail where activer = 1 AND ISNULL(stocktakeid,'') <> @stocktakeid AND IsSoftAsset = @DepartName
	   RETURN 0
	  END
      ELSE
      BEGIN
          SELECT Row_Number() over ( order by getdate() ) as init,assetnum,descriptionx,'未盘点' AS 状态,roomer,IsSoftAsset 
	      FROM assetdetail where activer = 1 AND CONVERT(CHAR,ModifiDate,23)<> CONVERT(CHAR,GETDATE(),23) 
		       AND Operator = @PDOperator
	   RETURN 0
	  end
	END
    --取已盘点
	IF @I_Sender = 'GetPanDianRecordList'
	BEGIN
	   IF @I_PlugInCommand ='PDOT '
	   begin
       SELECT a.assetnum,a.descriptionx,'已盘点' AS 状态,a.roomer,a.IsSoftAsset,a.RunStauts,b.LocationDescription  存放
	   FROM assetdetail a 
	      INNER JOIN dbo.Location b ON b.LocationName = a.ZoneCode
	   WHERE activer = 1 AND ISNULL(stocktakeid,'') = @stocktakeid AND IsSoftAsset = @DepartName
	   RETURN 0
	   END
       ELSE
       BEGIN
       SELECT a.assetnum,a.descriptionx,'已盘点' AS 状态,a.roomer,a.IsSoftAsset,a.RunStauts,b.LocationDescription 存放
	   FROM assetdetail a 
	      INNER JOIN dbo.Location b ON b.LocationName = a.ZoneCode
	   WHERE activer = 1 AND ISNULL(Operator,'') <> ''
		  AND CONVERT(CHAR,ModifiDate,23)= CONVERT(CHAR,GETDATE(),23)
		  RETURN 0
	   end
	end
	IF @I_Sender ='DeleteRecordData'
	BEGIN
	   IF @I_PlugInCommand ='DDPD'
	   BEGIN
	   SET @I_ReturnMessage ='ServerMessage:不能取消'
	   RETURN 0
	   END
       UPDATE  assetdetail SET stockTakeid='' where activer = 1 AND ISNULL(stocktakeid,'') = @stocktakeid AND AssetNum = @assetnum
	   SET @I_ReturnMessage ='ServerMessage: 取消成功'
	   RETURN 0
	end

	--得到SN
	IF ISNULL(@PDOperator,'')=''
 	  SELECT  assetnum,descriptionx,operator,roomer FROM assetdetail WHERE stocktakeid = @stocktakeid 
	ELSE 
	  SELECT assetnum,descriptionx,operator,roomer FROM assetdetail WHERE stocktakeid = @stocktakeid  AND operator = @PDOperator 
return 0
END









