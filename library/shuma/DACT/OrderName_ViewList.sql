  -- =============================================  
  -- Author:  <OrBit Phoenix>  -- Create date: <2016.06.14>  -- Description: <获取订单号>  -- Rev:1.00  
  -- ============================================= 
   CREATE PROCEDURE [dbo].[OrderName_ViewList]   
   @QueryParameter nvarchar(100)=''  
   AS  BEGIN   -- 
     SET NOCOUNT ON;  
	  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED   
	   select distinct     OrderFieldSetting.OrderFieldSettingId,    OrderFieldSetting.OrderName,   
	    OrderFieldSetting.productName,    OrderFieldSetting.OrderType   
	   FROM OrderFieldSetting   where IsClose=0  AND OrderType ='AV'  order by OrderFieldSetting.OrderName   
	    return 0 
   END      