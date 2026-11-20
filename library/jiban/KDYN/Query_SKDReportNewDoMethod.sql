
-- =============================================
-- Author:		<Orbit Team Phoenix>
-- Create date: <2017.06.03>
-- Description:	SKD散件订单查询
-- =============================================
CREATE PROCEDURE  [dbo].[Query_SKDReportNewDoMethod]
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
@I_Parameter nvarchar(100)=''	--插件参数

 --以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.


AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--写入查看日志
	insert into QueryLog(MethodName,ResourceId,UserId)values('Query_SKDReportNewDoMethod',@I_ResourceId,@I_OrBitUserId)
	
	if ISNULL(@I_PKid,'') =''
	begin
		set @I_ReturnMessage='ServerMessage:请选择订单号!'
		return -1
	end
	declare @CTNNO nvarchar(50)='',	---箱号
	@minKDBoxInfoid char(12)='',
	@maxKDBoxInfoid char(12)='',
	@num int=0,
	@ModuleName nvarchar(50)=''		---组件号

	----订单数据--
	select KDOrderInfoId,OrderName,OrderType,CustomerName,CustomerModel,OrderQTY,ProductCode,
	convert(nvarchar(10),OrderDate,111) as OrderDate,Brand,Panel,skd from KDOrderInfo where  KDOrderInfoId=@I_PKid

	--获取外箱装箱关系
	select a.*,c.BoxLevel,c.BoxType,c.BoxNumber,b.BoxLevel as ParentBoxLevel,b.BoxType as ParentBoxType,b.BoxNumber as ParentBoxNumber into #ParentCTN  from KDLoadBox a
	left join  KDBoxInfo b on a.ParentBoxInfoId=b.KDBoxInfoId
	left join  KDBoxInfo c on a.BoxInfoId=c.KDBoxInfoId
	and a.KDOrderInfoId=b.KDOrderInfoId
	where a.KDOrderInfoId=@I_PKid and a.IsCancel=0
	
	--箱号数据--
	select a.*,c.ParentBoxLevel,c.ParentBoxType,c.ParentBoxInfoId,c.ParentBoxNumber,b.ModuleName,b.ProductId,b.RealQty,convert(int,substring(a.BoxNumber,3,LEN(a.BoxNumber))) as BoxSeq  into  #tb from KDBoxItem b
	left join KDBoxInfo a  on a.KDBoxInfoId=b.KDBoxInfoId 
	left join  #ParentCTN c on a.KDBoxInfoId=c.BoxInfoId 
	where  a.KDOrderInfoId=@I_PKid and b.KDOrderInfoId=@I_PKid  and a.IsCancel=0 and b.IsCancel=0 
	
	--declare @CTNNO nvarchar(50)=''
	---从箱号数据中取出没有装箱的最大最小箱号
	select max(KDOrderInfoId) as KDOrderInfoId,min(KDBoxInfoid) as minKDBoxInfoid,max(KDBoxInfoid) as maxKDBoxInfoid,
	@CTNNO as CTNNO,count(distinct KDBoxInfoid) num,min(BoxSeq) as BoxSeq,
	 BoxLevel,BoxType,ModuleName,Productid,RealQty into #CTNtype  from  #tb 
	where KDBoxInfoId NOT IN(select distinct  ParentBoxInfoId  from #ParentCTN) and isnull(ParentBoxInfoId,'')='' 
	group by  BoxLevel,BoxType,ModuleName,Productid,RealQty
	
	
	---从箱号数据中取出层级A2装箱类型为L的装箱最大最小箱号
	insert into #CTNtype
	select max(KDOrderInfoId) as KDOrderInfoId,min(KDBoxInfoid) as minKDBoxInfoid,max(KDBoxInfoid) as maxKDBoxInfoid,
	@CTNNO as CTNNO,count(distinct KDBoxInfoid) num,min(BoxSeq) as BoxSeq,
	 BoxLevel,BoxType,ModuleName,Productid,RealQty   from  #tb 
	where KDBoxInfoId NOT IN(select distinct  ParentBoxInfoId  from #ParentCTN) and isnull(ParentBoxInfoId,'')<>'' 
	and BoxLevel='A2' and BoxType='L'
	group by  BoxLevel,BoxType,ModuleName,Productid,RealQty
	
	--箱号分类数据--
	 update #CTNtype set CTNNO=b.BoxNumber+'-'+substring(c.BoxNumber,3,len(c.BoxNumber)-2) from #CTNtype a 
													inner join #tb b on a.minKDBoxInfoid=b.KDBoxInfoId 
													inner join #tb c on a.maxKDBoxInfoid=c.KDBoxInfoId
													where maxKdboxinfoid<>minkdboxinfoid

	 update #CTNtype set CTNNO=b.BoxNumber from #CTNtype a 
													inner join #tb b on a.minKDBoxInfoid=b.KDBoxInfoId 
													inner join #tb c on a.maxKDBoxInfoid=c.KDBoxInfoId
													where maxKdboxinfoid=minkdboxinfoid
	---求A0层M类型的最大最小箱号
	--declare @CTNNO nvarchar(50)=''
	select  ParentBoxInfoId, max(BoxInfoId) as maxKDBoxInfoId,min(BoxInfoId) as minKdBoxInfoId,
	ParentBoxLevel,ParentBoxType,BoxLevel,BoxType,@CTNNO as ParentCTNNO, 0 as BoxSeq,count(distinct BoxInfoId) as num into  #CTNtype1   from  #ParentCTN 
	where ParentBoxInfoId IN(select distinct  ParentBoxInfoId from #ParentCTN where ParentBoxLevel='A0' and ParentBoxType='M')
	and BoxLevel='A2' and BoxType='L'
	 group by ParentBoxLevel,ParentBoxType,BoxLevel,BoxType,ParentBoxInfoId	 

	--A0层级M类型按装箱数量不同要区分尾箱	
	select max(ParentBoxInfoId) as  maxParentBoxInfoId,min(ParentBoxInfoId) as minParentBoxInfoId,@CTNNO as ParentBoxNumber,num
	into #temp from #CTNtype1 group by num

	update #temp set ParentBoxNumber=b.ParentBoxNumber+'-'+substring(c.ParentBoxNumber,3,len(c.ParentBoxNumber)-2) from #temp a  
	left join  #ParentCTN b on a.minParentBoxInfoId=b.ParentBoxInfoId
	left join  #ParentCTN c on a.maxParentBoxInfoId=c.ParentBoxInfoId
	 where a.maxParentboxinfoid<>a.minParentboxinfoid


	 update #temp set ParentBoxNumber=b.ParentBoxNumber from #temp a  
					 left join  #ParentCTN b on a.maxParentBoxInfoId=b.ParentBoxInfoId
					 where a.maxParentboxinfoid=a.minParentboxinfoid

	 update #CTNtype1 set ParentCTNNO=b.ParentBoxNumber from #CTNtype1 a 
					inner join #temp b on a.num=b.num
	
	 update #CTNtype1 set BoxSeq=b.BoxSeq from #CTNtype1 a 
					left join #tb b on a.ParentBoxInfoid=b.ParentBoxInfoId
	
	---更新外箱数量--
	update #CTNtype1 set num=b.num from #CTNtype1 a 
	inner join (select ParentCTNNO,count(ParentCTNNO) as num  from #CTNtype1 group by  ParentCTNNO ) b
	on a.ParentCTNNO=b.ParentCTNNO
													

	----计算A2层级L的最大最小箱,如果层级A0外箱类型M有尾箱,先算整箱,再求尾箱---
		Create table  #ParentBox(ParentBoxInfoId char(12))
		if  (select count(distinct num) from #CTNtype1) >1
		begin
			insert into #ParentBox
			select distinct  ParentBoxInfoId from #ParentCTN a 
			inner join (select minKdBoxInfoId from #CTNtype1 where num in (select min(num) from #CTNtype1 )) b 
			on a.ParentBoxInfoId<b.minKdBoxInfoId
			where ParentBoxLevel<>'A0' and ParentBoxType<>'M' 
		end
		else
		begin
			insert into #ParentBox
			select distinct  ParentBoxInfoId from #ParentCTN  where ParentBoxLevel<>'A0' and ParentBoxType<>'M' 
		end

		---先求A0层级的拼箱A2的最大,最小箱号数--
		--declare @CTNNO nvarchar(50)=''
		select  max(KDOrderInfoId) as KDOrderInfoId,min(KDBoxInfoid) as minKDBoxInfoid,max(KDBoxInfoid) as maxKDBoxInfoid,
		ParentBoxLevel,ParentBoxType,BoxLevel,BoxType,ModuleName,@CTNNO as CTNNO,0 as num, min(BoxSeq) as BoxSeq,RealQty,Productid,
		min(ParentBoxInfoId) as MinParentBoxInfoId,	max(ParentBoxInfoId) as MaxParentBoxInfoId,@CTNNO as ParentCTNNO,count(distinct ParentBoxInfoId) Parentnum,
		0 as ParentBoxSeq into #CTNtype2  from  #tb where ParentBoxInfoId IN
		(select b.ParentBoxInfoId from #tb a inner join #ParentBox b on a.KDBoxInfoId=b.ParentBoxInfoId and isnull(a.ParentBoxInfoId,'')='')
		group by   ParentBoxLevel,ParentBoxType,BoxLevel,BoxType,ModuleName,ProductId,RealQty
		 
		---再求A2层级的拼箱A4的最大,最小箱号数--
		--declare @CTNNO nvarchar(50)=''
		insert into #CTNtype2 
		select  max(KDOrderInfoId) as KDOrderInfoId,min(KDBoxInfoid) as minKDBoxInfoid,max(KDBoxInfoid) as maxKDBoxInfoid,
		ParentBoxLevel,ParentBoxType,BoxLevel,BoxType,ModuleName,@CTNNO as CTNNO,0 as num, min(BoxSeq) as BoxSeq,RealQty,Productid,
		min(ParentBoxInfoId) as MinParentBoxInfoId,	max(ParentBoxInfoId) as MaxParentBoxInfoId,@CTNNO as ParentCTNNO,count(distinct ParentBoxInfoId) Parentnum,
		0 as ParentBoxSeq  from  #tb where ParentBoxInfoId IN
		(select b.ParentBoxInfoId from #tb a inner join #ParentBox b on a.KDBoxInfoId=b.ParentBoxInfoId and isnull(a.ParentBoxInfoId,'')<>'')
		group by   ParentBoxLevel,ParentBoxType,BoxLevel,BoxType,ModuleName,ProductId,RealQty


	--	declare @CTNNO nvarchar(50)=''
		if  (select count(distinct num) from #CTNtype1) >1
		begin
			----求A0层级M箱号类型拼箱A2层级L箱尾箱的最大最小箱号
			delete from #ParentBox

			insert into #ParentBox
			select distinct  ParentBoxInfoId from #ParentCTN a 
			inner join (select minKdBoxInfoId from #CTNtype1 where num in (select min(num) from #CTNtype1 )) b 
			on a.ParentBoxInfoId>=b.minKdBoxInfoId
			where ParentBoxLevel<>'A0' and ParentBoxType<>'M'

			
			insert into #CTNtype2
			select  max(KDOrderInfoId) as KDOrderInfoId,min(KDBoxInfoid) as minKDBoxInfoid,max(KDBoxInfoid) as maxKDBoxInfoid,
				ParentBoxLevel,ParentBoxType,BoxLevel,BoxType,ModuleName,@CTNNO as CTNNO,0 as num, min(BoxSeq) as BoxSeq,RealQty,Productid,
				min(ParentBoxInfoId) as MinParentBoxInfoId,	max(ParentBoxInfoId) as MaxParentBoxInfoId,@CTNNO as ParentCTNNO,count(distinct ParentBoxInfoId) Parentnum,
				0 as ParentBoxSeq   from  #tb where ParentBoxInfoId IN(select distinct  ParentBoxInfoId from #ParentBox)
			and IsBox=1
			group by    ParentBoxLevel,ParentBoxType,BoxLevel,BoxType,ModuleName,ProductId,RealQty
			
		end

		update #CTNtype2 set ParentCTNNO=b.BoxNumber+'-'+substring(c.BoxNumber,3,len(c.BoxNumber)-2),ParentBoxSeq=b.BoxSeq  from #CTNtype2 a 
															 left join #tb b on a.MinParentBoxInfoid=b.KDBoxInfoId
															 left join #tb c on a.MaxParentBoxInfoid=c.KDBoxInfoId
															 where maxParentboxinfoid<>minParentboxinfoid
	
		update #CTNtype2 set ParentCTNNO=b.BoxNumber,ParentBoxSeq=b.BoxSeq from #CTNtype2 a 
															left join #tb b on a.MinParentBoxInfoid=b.KDBoxInfoId
															left join #tb c on a.MaxParentBoxInfoid=c.KDBoxInfoId
														where maxParentboxinfoid=minParentboxinfoid

		update #CTNtype2 set CTNNO=b.BoxNumber+'-'+substring(c.BoxNumber,3,len(c.BoxNumber)-2) from #CTNtype2 a 
															 left join #tb b on a.MinKDBoxInfoid=b.KDBoxInfoId
															 left join #tb c on a.MaxKDBoxInfoid=c.KDBoxInfoId
															 where maxKDboxinfoid<>minKDboxinfoid
	
		update #CTNtype2 set CTNNO=b.BoxNumber from #CTNtype2 a 
															left join #tb b on a.MinKDBoxInfoid=b.KDBoxInfoId
														    where maxKDboxinfoid=minKDboxinfoid

		--更新装箱层次A0箱号类型M中有层级K4的箱数
		declare Cur cursor for
		select distinct minKDBoxInfoid,maxKDBoxInfoid from #CTNtype2
		OPEN Cur
		FETCH NEXT FROM Cur
		INTO @minKDBoxInfoid,@maxKDBoxInfoid
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			set @num=0
			select @num=count(distinct isnull(KDBoxInfoId,0)) from #tb where KDBoxInfoId>=@MinKDBoxInfoid and KDBoxInfoId<=@maxKDBoxInfoid
			update #CTNtype2 set num=@num where MinKDBoxInfoId=@MinKDBoxInfoid and maxKDBoxInfoId=@maxKDBoxInfoid
			fetch next from Cur into @minKDBoxInfoid,@maxKDBoxInfoid
		END
		CLOSE Cur
		DEALLOCATE Cur 
	
		--把装箱层次A0箱号类型M中有层级K4的更新到#CTNtype表中
		insert into #CTNtype
		select KDOrderInfoId,minKDBoxInfoid,maxKDBoxInfoid,
		CTNNO,num,BoxSeq,BoxLevel,BoxType,ModuleName,Productid,RealQty from #CTNtype2 
		where  BoxLevel='A4' and BoxType='K'
													
	
	-----更新拼箱时有尾箱时外箱箱号和数量(用于报表中合并项)--
	update #CTNtype2 set ParentCTNNO=e.ParentCTNNO,Parentnum=e.Parentnum from #CTNtype2 c inner join (
	select d.MaxParentBoxInfoId,d.MinParentBoxInfoId,c.ParentCTNNO,c.Parentnum from (
	select a.MaxParentBoxInfoId,a.MinParentBoxInfoId,a.ParentCTNNO,a.Parentnum from  #CTNtype2 a inner join (
	select ModuleName  from  #CTNtype2   group by ModuleName having count(ModuleName)>1 ) b 
	 on a.ModuleName=b.ModuleName and a.MaxParentBoxInfoId<>a.MinParentBoxInfoId
	) c inner join (
	select a.MaxParentBoxInfoId,a.MinParentBoxInfoId from  #CTNtype2 a inner join (
	select ModuleName  from	 #CTNtype2   group by ModuleName having count(ModuleName)>1 ) b on a.ModuleName=b.ModuleName 
	 and a.MaxParentBoxInfoId=a.MinParentBoxInfoId and  a.minKDBoxInfoid=a.maxKDBoxInfoid) d 
	  on c.MaxParentBoxInfoId=d.MaxParentBoxInfoId and c.MaxParentBoxInfoId=d.MinParentBoxInfoId) e
	 on c.MaxParentBoxInfoId=e.MaxParentBoxInfoId and c.MinParentBoxInfoId=e.MinParentBoxInfoId
		
	
	----从箱号数据中删除没有包装物料的外箱箱号
	--delete from #tb where KDBoxInfoId in (select distinct ParentBoxInfoId from #ParentCTN)
	--delete from #tb where KDBoxInfoId in (select distinct ParentBoxInfoId from #ParentCTN where ParentBoxInfoId 
	--not in (select distinct BoxInfoId from #ParentCTN))

	select  distinct
	d.KDOrderInfoId,d.KDBoxInfoId,a.ProductId,c.ProductName as ProductName,b.ProductDescription,
	a.CustomerNumber,d.ModuleName,a.EnglishDescription,a.QtyPack,convert(int,a.ItemQtyRequired) as ItemQtyRequired,
	convert(int,d.RealQty) as RealQty,e.BoxLevel,e.BoxType,e.num,e.CTNNO,d.BoxSeq,
	convert(int,d.RealQty) as RealQty2,e.BoxLevel as BoxLevel2,e.BoxType as BoxType2,e.num as num2,e.CTNNO as CTNNO2,d.BoxSeq as BoxSeq2,
	convert(int,d.RealQty) as RealQty4,e.BoxLevel as BoxLevel4,e.BoxType as BoxType4,e.num as num4,e.CTNNO as CTNNO4,d.BoxSeq as BoxSeq4,
	convert(int,d.BoxLength) as BoxLength,convert(int,d.BoxWidth) as BoxWidth,convert(int,d.BoxHeight) as BoxHeight,
	d.NetWeight,d.GrossWeight,0 as isTotal,0 as  isA0,0 as isA2,0 AS isA4,0 as isRealQty0,0 as isRealQty2,0 AS isRealQty4,
	0 as isSize,0 as IsWeight,0 as isModuleName  into  #CTN from  #tb d 
	left join product b on d.ProductId=b.ProductId 
	left join ProductRoot c on b.ProductRootId=c.ProductRootId
	left join KDOrderItem a  on a.KDOrderInfoId=d.KDOrderInfoId and a.ProductId=d.ProductId and a.ModuleName=d.ModuleName
	inner join #CTNtype e on d.KDBoxInfoId=e.minKDBoxInfoid and d.KDOrderInfoId=e.KDOrderInfoId 
	where a.KDOrderInfoId=@I_PKid and d.IsCancel=0 and a.IsIgnore=0 and a.IsValidity=1 order by e.BoxLevel,e.BoxType,e.CTNNO asc


	update  #CTN set BoxLevel='',BoxType='',num=null,CTNNO='', RealQty=null,BoxSeq=null where BoxLevel<>'A0'
	update  #CTN set BoxLevel2='',BoxType2='',num2=null,CTNNO2='', RealQty2=null,BoxSeq2=null where BoxLevel2<>'A2'
	update  #CTN set BoxLevel4='',BoxType4='',num4=null,CTNNO4='', RealQty4=null,BoxSeq4=null where BoxLevel4<>'A4'


									
	--更新A4装箱到A2层的关系
	update  #CTN set num2=b.Parentnum,CTNNO2=b.ParentCTNNO,BoxSeq2=b.ParentBoxSeq,BoxLevel2=b.ParentBoxLevel,BoxType2=b.ParentBoxType from #CTN a 
									inner join #CTNtype2 b ON a.KDBoxInfoId=b.minKDBoxInfoid
									where  a.BoxLevel4='A4'
	--更新A4装箱到A2层的关系
	update  #CTN set num2=b.Parentnum,CTNNO2=b.ParentCTNNO,BoxSeq2=b.ParentBoxSeq,BoxLevel2=b.ParentBoxLevel,BoxType2=b.ParentBoxType from #CTN a 
									inner join #CTNtype2 b ON a.KDBoxInfoId=b.maxKDBoxInfoid
									where  a.BoxLevel4='A4'
	-----更新A2装箱到A0层的关系
	---取出A0层级M箱号类型首,尾箱数据--
	select max(maxKdBoxInfoId) as maxKdBoxInfoId,ParentBoxLevel,ParentBoxType,ParentCTNNO,num,max(BoxSeq) as BoxSeq into #UpdateA0M  from #CTNtype1
	group by ParentBoxLevel,ParentBoxType,ParentCTNNO,num

	update  #UpdateA0M set  maxKdBoxInfoId=b.maxKdBoxInfoId from #UpdateA0M a inner join 
	(select maxKdBoxInfoId,num from  #UpdateA0M where num in (select max(num) from #UpdateA0M)) b on a.num<b.num 

	---更新包装在A0层级M箱号外箱的A2层级L类型
	update #CTN set  num=d.num,CTNNO=d.ParentCTNNO,BoxSeq=d.BoxSeq,BoxLevel=d.ParentBoxLevel,BoxType=d.ParentBoxType from #CTN a inner join 
	 #CTNtype1 d on  a.KDBoxInfoId>=d.minKDBoxInfoid and a.KDBoxInfoId<=d.maxKDBoxInfoid and  isnull(a.RealQty2,0)>0

	 update #CTN set  num=d.num,CTNNO=d.ParentCTNNO,BoxSeq=d.BoxSeq,BoxLevel=d.ParentBoxLevel,BoxType=d.ParentBoxType from #CTN a inner join
	 (select a.BoxInfoId,b.ParentBoxInfoId,b.BoxSeq,b.ParentBoxLevel,b.ParentBoxType,b.num,b.ParentCTNNO from #ParentCTN a inner join
	  #CTNtype1 b on a.ParentBoxInfoId>=b.minKDBoxInfoid and a.ParentBoxInfoId<=b.maxKDBoxInfoid
	 ) d on a.KDBoxInfoId=d.BoxInfoId
	
	---更新A0层级M箱号尾箱数据--
	if  (select count(distinct num) from #CTNtype1) >1
	begin
		 update #CTN set  num=d.num,CTNNO=d.ParentCTNNO,BoxSeq=d.BoxSeq,BoxLevel=d.ParentBoxLevel,BoxType=d.ParentBoxType  from #CTN a inner join (
		 select distinct b.minKDBoxInfoid,b.maxKDBoxInfoid,c.ParentBoxLevel,c.ParentBoxType,c.ParentCTNNO,c.num,c.BoxSeq from  #CTNtype2 b 
		inner join #UpdateA0M c ON b.MaxParentBoxInfoId<=c.maxKdBoxInfoId
		 where c.num in (select max(num) from #UpdateA0M)) d  on a.KDBoxInfoId>=d.minKDBoxInfoid and a.KDBoxInfoId<=d.maxKDBoxInfoid

		 update #CTN set  num=d.num,CTNNO=d.ParentCTNNO,BoxSeq=d.BoxSeq,BoxLevel=d.ParentBoxLevel,BoxType=d.ParentBoxType from #CTN a inner join (
		 select distinct b.minKDBoxInfoid,b.maxKDBoxInfoid,c.ParentBoxLevel,c.ParentBoxType,c.ParentCTNNO,c.num,c.BoxSeq from  #CTNtype2 b 
		inner join #UpdateA0M c ON b.MaxParentBoxInfoId>c.maxKdBoxInfoId
		 where c.num in (select min(num) from #UpdateA0M)) d  on a.KDBoxInfoId>=d.minKDBoxInfoid and a.KDBoxInfoId<=d.maxKDBoxInfoid								
	end								

	----生成新的临时表
	select top 1 IDENTITY(int,1,1)as RowNum,* into #CTN1 from #CTN where 1>1

	---生成用于计算尾箱的临时表
	select 0 as RowNum,KDBoxInfoId into #CTNtemp  from #CTN where 1>1
	---生成用于计算尾箱的临时表
	select * into #CTNA  from #CTNtemp

	----用于记录同种组件有3种装箱方式的组件临时表
	select ModuleName into #Module  from #CTN1

	
		----同种组件有3种拼箱方式的计算方法--

	insert into #Module
	select ModuleName from (
	SELECT   ModuleName,ProductId FROM  #CTN group by ModuleName,ProductId having count(productid)>2) a group by ModuleName
	having count(ModuleName)>=2

	declare CurCTN Cursor for select ModuleName from  #Module
	OPEN CurCTN
	FETCH NEXT FROM CurCTN
	INTO @ModuleName
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		----获取同种组件物料的各种装箱方式--
		select ROW_NUMBER() over ( order by KDOrderInfoId) as Rownum, KDOrderInfoId,KDBoxInfoid,BoxLevel,BoxType,ModuleName,CTNNO,num,BoxSeq,
		RealQty,BoxLevel2,BoxType2,CTNNO2,num2,BoxSeq2,RealQty2,BoxLevel4,BoxType4,CTNNO4,num4,BoxSeq4,RealQty4,
		BoxLength,BoxWidth,BoxHeight,NetWeight,GrossWeight into #Moduletemp  from #CTN  where ModuleName=@ModuleName
		group by KDOrderInfoId,KDBoxInfoid,ModuleName,BoxLevel,BoxType,CTNNO,num,BoxSeq,RealQty,
		BoxLevel2,BoxType2,CTNNO2,num2,BoxSeq2,RealQty2,BoxLevel4,BoxType4,CTNNO4,num4,BoxSeq4,RealQty4,BoxLength,BoxWidth,BoxHeight,NetWeight,GrossWeight
		
		----获取同种组件物料全部装箱内容-
		select ROW_NUMBER() over ( order by KDOrderInfoId) as Rownum, * into #ModuleAlltemp  from #CTN  where ModuleName=@ModuleName
		
		----保留一种装箱方式--
		delete from #ModuleAlltemp from #ModuleAlltemp a inner join #Moduletemp b on a.KDBoxInfoId=b.KDBoxInfoId and b.Rownum>1 

		----删除原有内容
		delete from #CTN  where ModuleName=@ModuleName
	
		----更新装箱方式
		update #ModuleAlltemp set KDBoxInfoid=b.KDBoxInfoId,
		BoxLevel=b.BoxLevel,BoxType=b.BoxType,CTNNO=b.CTNNO,num=b.num,BoxSeq=b.BoxSeq,
		RealQty=b.RealQty,BoxLevel2=b.BoxLevel2,BoxType2=b.BoxType2,CTNNO2=b.CTNNO2,num2=b.num2,BoxSeq2=b.BoxSeq2,RealQty2=b.RealQty2,
		BoxLevel4=b.BoxLevel4,BoxType4=b.BoxType4,CTNNO4=b.CTNNO4,num4=b.num4,BoxSeq4=b.BoxSeq4,RealQty4=b.RealQty4,
		BoxLength=b.BoxLength,BoxWidth=b.BoxWidth,BoxHeight=b.BoxLength,NetWeight=b.NetWeight,GrossWeight=b.GrossWeight
		from #ModuleAlltemp a inner join #Moduletemp b on a.ModuleName=b.ModuleName and a.Rownum=b.Rownum and
		 a.Rownum <=(select max(Rownum) from #Moduletemp)

		 update #ModuleAlltemp set KDBoxInfoid=b.KDBoxInfoId,
		BoxLevel=b.BoxLevel,BoxType=b.BoxType,CTNNO=b.CTNNO,num=b.num,BoxSeq=b.BoxSeq,
		RealQty=b.RealQty,BoxLevel2=b.BoxLevel2,BoxType2=b.BoxType2,CTNNO2=b.CTNNO2,num2=b.num2,BoxSeq2=b.BoxSeq2,RealQty2=b.RealQty2,
		BoxLevel4=b.BoxLevel4,BoxType4=b.BoxType4,CTNNO4=b.CTNNO4,num4=b.num4,BoxSeq4=b.BoxSeq4,RealQty4=b.RealQty4,
		BoxLength=b.BoxLength,BoxWidth=b.BoxWidth,BoxHeight=b.BoxLength,NetWeight=b.NetWeight,GrossWeight=b.GrossWeight
		from #ModuleAlltemp a inner join #Moduletemp b on a.ModuleName=b.ModuleName and  a.Rownum>=b.Rownum and
		 b.Rownum=(select max(Rownum) from #Moduletemp)

		 ---把更新的数据插入
		insert into #CTN
		select KDOrderInfoId,KDBoxInfoId,ProductId,ProductName,ProductDescription,
		CustomerNumber,ModuleName,EnglishDescription,QtyPack,ItemQtyRequired,
		RealQty,BoxLevel,BoxType,num,CTNNO,BoxSeq,
		RealQty2,BoxLevel2,BoxType2,num2,CTNNO2,BoxSeq2,
		RealQty4,BoxLevel4,BoxType4,num4,CTNNO4,BoxSeq4,
		BoxLength,BoxWidth,BoxHeight,NetWeight,GrossWeight,isTotal,isA0,isA2,isA4,
		0 as isRealQty0,0 as isRealQty2,0 AS isRealQty4,0 as isSize,0 as IsWeight,0 as isModuleName from  #ModuleAlltemp
				
		drop table #Moduletemp
		drop table #ModuleAlltemp
		fetch next from CurCTN INTO @ModuleName
	END
	CLOSE CurCTN
	DEALLOCATE CurCTN

	
	insert #Module (ModuleName)
	select b.ModuleName from #ParentBox a inner join #tb b
	 on a.ParentBoxInfoId=b.ParentBoxInfoId
	group by b.ModuleName having count(b.ModuleName)>2	
	except
	select ModuleName from #Module

----判断同层箱号是否装有相同物料,用于解决尾箱要并列在一起的问题
	if exists(SELECT ModuleName FROM  #CTN  where BoxLevel='A0'  group by ModuleName having count(CTNNO)>=2)
	begin
		insert into #CTN1
		select * from #CTN where  BoxLevel='A0' and isnull(RealQty,0)>0   order by BoxLevel,BoxType,BoxSeq,BoxLevel2,BoxType2,BoxSeq2,ModuleName,ProductName asc
		

	---获取有超过2种物料的模组箱号最小RowNum
		insert into #CTNtemp
		select  min(a.RowNum) as RowNum,min(a.KDBoxInfoId) as KDBoxInfoId from  #CTN1 a inner join  
		(SELECT  ProductId,ModuleName FROM  #CTN1  where BoxLevel='A0'  group by  ProductId,ModuleName having  count(distinct CTNNO)>1 and  count(distinct RealQty)>1) b
		on a.ProductId=b.ProductId and a.ModuleName=b.ModuleName  where BoxLevel='A0' and a.ModuleName not in (select ModuleName from #Module)
		group by a.ProductId,a.ModuleName
	
	
	---获取有超过2种物料的模组箱号最大RowNum
		insert into #CTNA
		select  max(a.RowNum) as RowNum,min(a.KDBoxInfoId) as KDBoxInfoId from  #CTN1 a inner join  
		(SELECT  ProductId,ModuleName FROM  #CTN1  where BoxLevel='A0'  group by  ProductId,ModuleName having  count(distinct CTNNO)>1 and  count(distinct RealQty)>1) b
		on a.ProductId=b.ProductId and a.ModuleName=b.ModuleName  where BoxLevel2='A0' and a.ModuleName not in (select ModuleName from #Module)
		group by a.ProductId,a.ModuleName
	
	
	---从#CTNtemp剔除最小RowNum的箱号
		delete from #CTNtemp from #CTNtemp a where  RowNum in (
		select min(RowNum) as RowNum from #CTNtemp group by KDBoxInfoId)
	
	---删除剩下的RowNum的箱号		
		delete from #CTN1 where  RowNum in (select RowNum from #CTNtemp)
	
	---删除#CTNA中只有一个箱号的RowNum
		delete from #CTNA from #CTNA a where  RowNum in (
		select min(RowNum) as RowNum from #CTNA group by KDBoxInfoId having COUNT(KDBoxInfoId)=1)
	
	---删除#CTNA中最小的RowNum的箱号				
		delete from #CTN1 where  RowNum in (select min(RowNum) as RowNum from #CTNA group by KDBoxInfoId)
	
	---清空 #CTNtemp
		delete from #CTNtemp
	
	---从#CTNA获取最小RowNum的箱号
		insert into  #CTNtemp
		select min(RowNum) as RowNum,KDBoxInfoId from #CTNA group by KDBoxInfoId

	---更新尾箱RowNum数据
		update #CTN1 set CTNNO=b.CTNNO,Num=b.num,RealQty=b.RealQty,NetWeight=b.NetWeight,GrossWeight=b.GrossWeight from  #CTN1 a
		 inner join(select * from #CTN1 where RowNum in (select RowNum from  #CTNtemp))  b on a.BoxLevel=b.BoxLevel
		and a.ProductId=b.ProductId and a.ModuleName=b.ModuleName and a.RowNum>=b.RowNum

		delete from  #CTNA
		delete from #CTNtemp
		---删除BoxLevel='A0'的资料
		delete from #CTN where  BoxLevel='A0'and isnull(RealQty,0)>0
	end
	else
	begin
		insert into #CTN1
		select * from #CTN where  BoxLevel='A0' order by  BoxLevel,BoxType,BoxSeq,ModuleName,ProductName asc
		---删除BoxLevel='A0'的资料
		delete from #CTN where  BoxLevel='A0'
	end
	
	----判断同层箱号是否装有多种物料,用于解决尾箱要并列在一起的问题
	if exists(SELECT ModuleName FROM  #CTN  where BoxLevel2='A2'  group by ModuleName having count(CTNNO2)>=2)
	begin
		insert into #CTN1
		select * from #CTN where  BoxLevel2='A2' and BoxType2='L'  order by BoxLevel2,BoxType2,BoxSeq2,BoxSeq4,ModuleName,ProductName asc
		

	---获取有超过2种物料品号箱号最小RowNum
		insert into #CTNtemp
		select  min(a.RowNum) as RowNum,min(a.KDBoxInfoId) as KDBoxInfoId from  #CTN1 a inner join  
		(SELECT  ProductId,ModuleName FROM  #CTN1  where BoxLevel2='A2'  group by  ProductId,ModuleName having  count(distinct CTNNO2)>1 
		and  count(distinct RealQty2)>1) b
		on a.ProductId=b.ProductId and a.ModuleName=b.ModuleName  where BoxLevel2='A2' and a.ModuleName not in (select ModuleName from #Module)
		 group by a.ProductId,a.ModuleName
	---获取有超过2种物料品号箱号最大RowNum
		insert into  #CTNA
		select  max(a.RowNum) as RowNum,min(a.KDBoxInfoId) as KDBoxInfoId from  #CTN1 a inner join  
		(SELECT  ProductId,ModuleName FROM  #CTN1  where BoxLevel2='A2'  group by  ProductId,ModuleName having  count(distinct CTNNO2)>1 and  count(distinct RealQty2)>1) b
		on a.ProductId=b.ProductId and a.ModuleName=b.ModuleName  where BoxLevel2='A2' and a.ModuleName not in (select ModuleName from #Module)
		group by a.ProductId,a.ModuleName
	
	---从#CTNtemp剔除最小RowNum的箱号
		delete from #CTNtemp where  RowNum in (
		select min(RowNum) as RowNum from #CTNtemp group by KDBoxInfoId)

	
	---删除剩下的RowNum的箱号		
		delete from #CTN1 where  RowNum in (select RowNum from #CTNtemp)
	
	---删除#CTNA中只有一个箱号的RowNum
		delete from #CTNA from #CTNA a where  RowNum in (
		select min(RowNum) as RowNum from #CTNA group by KDBoxInfoId having COUNT(KDBoxInfoId)=1)
	
	---删除#CTNA中最小的RowNum的箱号				
		delete from #CTN1 where  RowNum in (select min(RowNum) as RowNum from #CTNA group by KDBoxInfoId)
	
	---清空 #CTNtemp
		delete from #CTNtemp
	
	---从#CTNA获取最小RowNum的箱号
		insert into  #CTNtemp
		select min(RowNum) as RowNum,KDBoxInfoId from #CTNA group by KDBoxInfoId

	---更新尾箱RowNum数据
		update #CTN1 set CTNNO2=b.CTNNO2,Num2=b.num2,RealQty2=b.RealQty2,NetWeight=b.NetWeight,GrossWeight=b.GrossWeight from  #CTN1 a
		 inner join(select * from #CTN1 where RowNum in (select RowNum from  #CTNtemp))  b on a.BoxLevel2=b.BoxLevel2
		and a.ProductId=b.ProductId and a.ModuleName=b.ModuleName and a.RowNum>=b.RowNum

		delete from  #CTNA
		delete from #CTNtemp

		delete from #CTN where  BoxLevel2='A2'and BoxType2='L'

	end
	else
	begin
		insert into #CTN1
		select * from  #CTN where BoxLevel2='A2' and BoxType2='L' order by BoxLevel2,BoxType2,BoxSeq2,BoxSeq4,ModuleName,ProductName asc
		delete from #CTN where  BoxLevel2='A2' and BoxType2='L'
	end

	
		----判断同层箱号是否装有多种物料,用于解决尾箱要并列在一起的问题
	if exists(SELECT ModuleName FROM  #CTN  where BoxLevel4='A4'  group by ModuleName having count(CTNNO4)>=2)
	begin
		insert into #CTN1
		select * from  #CTN where BoxLevel4='A4' order by BoxLevel4,BoxType4,BoxSeq4,ModuleName,ProductName asc
	
	---获取有超过2种物料的模组箱号最小RowNum
		insert into #CTNtemp
		select  min(a.RowNum) as RowNum,min(a.KDBoxInfoId) as KDBoxInfoId from  #CTN1 a inner join  
		(SELECT  ProductId,ModuleName FROM  #CTN1  where BoxLevel4='A4'  group by  ProductId,ModuleName having  count(distinct CTNNO4)>1 and  count(distinct RealQty4)>1) b
		on a.ProductId=b.ProductId and a.ModuleName=b.ModuleName  where BoxLevel4='A4' and a.ModuleName not in (select ModuleName from #Module)
		group by a.ProductId,a.ModuleName
	
	---获取有超过2种物料的模组箱号最大RowNum
		insert into #CTNA
		select  max(a.RowNum) as RowNum,min(a.KDBoxInfoId) as KDBoxInfoId from  #CTN1 a inner join  
		(SELECT  ProductId,ModuleName FROM  #CTN1  where BoxLevel4='A4'  group by  ProductId,ModuleName having  count(distinct CTNNO4)>1 and  count(distinct RealQty4)>1) b
		on a.ProductId=b.ProductId and a.ModuleName=b.ModuleName  where BoxLevel4='A4' and a.ModuleName not in (select ModuleName from #Module)
		group by a.ProductId,a.ModuleName
	
	---从#CTNtemp剔除最小RowNum的箱号
		delete from #CTNtemp where  RowNum in (
		select min(RowNum) as RowNum from #CTNtemp group by KDBoxInfoId)
	
	---删除剩下的RowNum的箱号		
		delete from #CTN1 where  RowNum in (select RowNum from #CTNtemp)

	---删除#CTNA中只有一个箱号的RowNum
		delete from #CTNA from #CTNA a where  RowNum in (
		select min(RowNum) as RowNum from #CTNA group by KDBoxInfoId having COUNT(KDBoxInfoId)=1)
	
	---删除#CTNA4中最小的RowNum的箱号		
		delete from #CTN1 where  RowNum in (select min(RowNum) as RowNum from #CTNA group by KDBoxInfoId)
	
	---清空 #CTNtemp
		delete from #CTNtemp
	
	---从#CTNA获取最小RowNum的箱号
		insert into  #CTNtemp
		select min(RowNum) as RowNum,KDBoxInfoId from #CTNA group by KDBoxInfoId

	---更新尾箱RowNum数据
		update #CTN1 set CTNNO4=b.CTNNO4,Num4=b.num4,RealQty4=b.RealQty4,NetWeight=b.NetWeight,GrossWeight=b.GrossWeight from  #CTN1 a
		 inner join(select * from #CTN1 where RowNum in (select RowNum from  #CTNtemp))  b on a.BoxLevel4=b.BoxLevel4
		and a.ProductId=b.ProductId and a.ModuleName=b.ModuleName and a.RowNum>=b.RowNum

		delete from  #CTNA
		delete from #CTNtemp

	end
	else
	begin
		insert into #CTN1
		select * from  #CTN where BoxLevel4='A4' order by BoxLevel4,BoxType4,BoxSeq4,ModuleName,ProductName asc
	end
	delete from #CTN where  BoxLevel4='A4'
	----合并相同品号的总数量与尾箱数量
	update #CTN1 set isTotal=1 from #CTN1 a inner join (
	select RowNum from #CTN1 a inner join (
	select  ProductName,QtyPack,ItemQtyRequired from #CTN1 group by  ProductName,QtyPack,ItemQtyRequired having 
	count(ProductName)>1 and count(QtyPack)>1 and count(ItemQtyRequired)>1) b on a.ProductName=b.ProductName and
	a.QtyPack=b.QtyPack and a.ItemQtyRequired=b.ItemQtyRequired) c on a.RowNum=c.RowNum

	-----合并相同箱号
	update #CTN1 set isA0=1 from #CTN1 a inner join ( 
	select RowNum from #CTN1 a inner join (
	select  CTNNO,num from #CTN1  where BoxLevel='A0' group by  CTNNO,num having isnull(CTNNO,'')<>'' and  isnull(num,0)>0 and
	count(CTNNO)>1 and count(num)>1) b on a.CTNNO=b.CTNNO and	a.num=b.num ) c on a.RowNum=c.RowNum

	update #CTN1 set isA2=1 from #CTN1 a inner join ( 
	select RowNum from #CTN1 a inner join (
	select  CTNNO2,num2 from #CTN1  where BoxLevel2='A2' group by  CTNNO2,num2 having isnull(CTNNO2,'')<>'' and  isnull(num2,0)>0 and
	count(CTNNO2)>1 and count(num2)>1) b on a.CTNNO2=b.CTNNO2 and	a.num2=b.num2 ) c on a.RowNum=c.RowNum

	update #CTN1 set isA4=1 from #CTN1 a inner join ( 
	select RowNum from #CTN1 a inner join (
	select  CTNNO4,num4 from #CTN1  where BoxLevel4='A4' group by  CTNNO4,num4 having isnull(CTNNO4,'')<>'' and  isnull(num4,0)>0 and
	count(CTNNO4)>1 and count(num4)>1) b on a.CTNNO4=b.CTNNO4 and	a.num4=b.num4 ) c on a.RowNum=c.RowNum

	---合并相同箱号实进数
	update #CTN1 set isrealQty0=1 from #CTN1 a inner join (
		select  CTNNO from #CTN1  where BoxLevel='A0' and  isnull(RealQty,0)>0 group by  CTNNO having isnull(CTNNO,'')<>''  and
		count(CTNNO)>1 and count(RealQty)>1 and count(distinct CTNNO)=count(distinct RealQty)) b on a.CTNNO=b.CTNNO

	update #CTN1 set isrealQty2=1 from #CTN1 a inner join (
		select  CTNNO2 from #CTN1  where BoxLevel2='A2' and  isnull(RealQty2,0)>0 group by  CTNNO2 having isnull(CTNNO2,'')<>'' and
		count(CTNNO2)>1 and count(RealQty2)>1 and count(distinct CTNNO2)=count(distinct RealQty2)) b on a.CTNNO2=b.CTNNO2

	update #CTN1 set isrealQty4=1 from #CTN1 a inner join (
		select  CTNNO4 from #CTN1  where BoxLevel4='A4' and  isnull(RealQty4,0)>0 group by  CTNNO4 having isnull(CTNNO4,'')<>''  and
		count(CTNNO4)>1 and count(RealQty4)>1 and count(distinct CTNNO4)=count(distinct RealQty4)) b on a.CTNNO4=b.CTNNO4


	---合并相同长宽高的箱号
	update #CTN1 set isSize=1 from #CTN1 a inner join (
		select  BoxLevel,BoxType,BoxLength,BoxWidth,BoxHeight from #CTN1 where  isnull(RealQty,0)>0  group by  BoxLevel,BoxType,BoxLength,BoxWidth,BoxHeight having
		BoxLevel='A0'  and count( BoxLevel+BoxType)>1 and count(BoxLength+BoxWidth+BoxHeight)>1) b on a.BoxLevel=b.BoxLevel and a.BoxType=b.BoxType and 	a.BoxLength=b.BoxLength and 
		a.BoxWidth=b.BoxWidth and a.BoxHeight=b.BoxHeight
	
	update #CTN1 set isSize=1 from #CTN1 a inner join (
		select  BoxLevel2,BoxType2,BoxLength,BoxWidth,BoxHeight from #CTN1 where isnull(RealQty2,0)>0  group by  BoxLevel2,BoxType2,BoxLength,BoxWidth,BoxHeight having
		BoxLevel2='A2' and count( BoxLevel2+BoxType2)>1 and count(BoxLength+BoxWidth+BoxHeight)>1) b on a.BoxLevel2=b.BoxLevel2 and a.BoxType2=b.BoxType2 and 	a.BoxLength=b.BoxLength and 
		a.BoxWidth=b.BoxWidth and a.BoxHeight=b.BoxHeight

	update #CTN1 set isSize=1 from #CTN1 a inner join (
		select  BoxLevel4,BoxType4,BoxLength,BoxWidth,BoxHeight from #CTN1 where isnull(RealQty4,0)>0  group by  BoxLevel4,BoxType4,BoxLength,BoxWidth,BoxHeight having
		BoxLevel4='A4' and count( BoxLevel4+BoxType4)>1 and count(BoxLength+BoxWidth+BoxHeight)>1) b on a.BoxLevel4=b.BoxLevel4 and a.BoxType4=b.BoxType4 and 	a.BoxLength=b.BoxLength and 
		a.BoxWidth=b.BoxWidth and a.BoxHeight=b.BoxHeight
	---合并相同重量的箱号
	update #CTN1 set IsWeight=1 from #CTN1 a inner join (
		select  KDBoxInfoId,NetWeight,GrossWeight from #CTN1  group by  KDBoxInfoId,NetWeight,GrossWeight having
		count(KDBoxInfoId)>1 and count(NetWeight+GrossWeight)>1) b on a.KDBoxInfoId=b.KDBoxInfoId and	a.NetWeight=b.NetWeight and 
		a.GrossWeight=b.GrossWeight
	---合并相同的客户编号
	update #CTN1 set isModuleName=1 from #CTN1 a inner join (
		select  CustomerNumber from #CTN1  group by  CustomerNumber having	count(CustomerNumber)>1 and isnull(CustomerNumber,'')<>'' )
		 b on a.CustomerNumber=b.CustomerNumber

	--select * from #CTN  order by BoxLevel4,BoxType4,BoxSeq4,BoxLevel2,BoxType2,BoxSeq2,BoxLevel,BoxType,BoxSeq
	select * from #CTN1  order by RowNum



	drop table #tb
	drop table #ParentCTN
	drop table #ParentBox
	drop table #CTNtype
	drop table #CTNtype1
	drop table #CTNtype2
	drop table #temp
	drop table #CTN	
	drop table #CTN1
	drop table #CTNA
	drop table #CTNtemp
	drop table #UpdateA0M
	drop table #Module

	return 0
END
