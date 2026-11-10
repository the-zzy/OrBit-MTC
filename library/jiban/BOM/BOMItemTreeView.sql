

-- =============================================

-- Author:		<OBit Team >

-- Create date: <2008.8.8>

-- Description:	<获取BOMItem导航树>

-- Rev: 10.00

-- =============================================

CREATE PROCEDURE [dbo].[BOMItemTreeView]

    @I_PlugInCommand VARCHAR(5) = '' ,			--插件命令

    @I_OrBitUserId CHAR(12) = '' ,				--用户ID

    @I_OrBitUserName NVARCHAR(100) = '' ,		--用户名

    @I_ResourceId CHAR(12) = '' ,			--资源ID(如果资源不在资源清单中，那么它将是空的)

    @I_ResourceName NVARCHAR(100) = '' ,		--资源名

    @I_FiltCondition NVARCHAR(MAX) = '' ,	--过滤条件表达式

    @I_PKId CHAR(12) = '' ,					--主键

    @I_ParentPKId CHAR(12) = '' ,				--用于过滤的上级主键

    @I_Parameter NVARCHAR(100) = ''			--插件参数

--以上8个变量为服务固定参数，必须在每一个TreeView过程中进行定义。

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;



	IF @I_PlugInCommand = 'BOMD'

	BEGIN

		SELECT TOP ( 100 ) PERCENT

                BOMItem.BOMItemId, BOMItem.ItemSequence, [dbo].[RemoveZero](BOMItem.ModuleName) AS ModuleName,

                BOMItem.FieldsA, BOMItem.FieldsB, [dbo].[RemoveZero](BOMItem.CustomerNumber) AS CustomerNumber,

                [dbo].[RemoveZero](ProductRoot.ProductName) AS ProductName, BOMItem.EnglishDescription,

                Product.ProductDescription, CONVERT(DECIMAL(18, 2), BOMItem.QtyRequired) AS QtyRequired,

                CONVERT(DECIMAL(18, 2), BOMItem.QtyPack) AS QtyPack,

                CONVERT(DECIMAL(18, 4), BOMItem.SingleWeight) AS SingleWeight, BOMItem.ReplaceGroup, UOM.UOMName,

                CASE WHEN BOMItem.IsIgnore = 1 THEN '[RowColor:X3]' 

				--when BOMItem.ModuleName='' then '[RowColor:XF]' 

                     ELSE ''

                END AS ColorControlId, ProductRoot.ItemName, ProductRoot.ProductType, ProductRoot.ProductSize,

                MachineNumber, PackingWay, BoxLength, BoxWidth, BoxHeight, BoxQty, ProductWeight, PalletRule,

                PalletALLRule, Remark, dbo.BOMItem.LTEXT

        FROM    BOMItem

        INNER JOIN Product ON BOMItem.ProductId = Product.ProductId

        INNER JOIN ProductRoot ON Product.ProductRootId = ProductRoot.ProductRootId

        LEFT OUTER JOIN UOM ON Product.UsageUOMId = UOM.UOMId

        LEFT OUTER JOIN SpecificationRoot

        INNER JOIN Specification ON SpecificationRoot.SpecificationRootId = Specification.SpecificationRootId ON BOMItem.SpecificationId = Specification.SpecificationId

        WHERE   ( BOMItem.BOMId = @I_ParentPKId )

        AND Product.ProductDescription LIKE '%散热器%'

        ORDER BY IsIgnore, ItemSequence;

        RETURN 0;

	END 

	

    IF @I_ParentPKId <> ''

    BEGIN



        SELECT TOP ( 100 ) PERCENT

                BOMItem.BOMItemId, BOMItem.ItemSequence, [dbo].[RemoveZero](BOMItem.ModuleName) AS ModuleName,

                BOMItem.FieldsA, BOMItem.FieldsB, [dbo].[RemoveZero](BOMItem.CustomerNumber) AS CustomerNumber,

                [dbo].[RemoveZero](ProductRoot.ProductName) AS ProductName, BOMItem.EnglishDescription,

                Product.ProductDescription, CONVERT(DECIMAL(18, 2), BOMItem.QtyRequired) AS QtyRequired,

                CONVERT(DECIMAL(18, 2), BOMItem.QtyPack) AS QtyPack,

                CONVERT(DECIMAL(18, 4), BOMItem.SingleWeight) AS SingleWeight, BOMItem.ReplaceGroup, UOM.UOMName,

                CASE WHEN BOMItem.IsIgnore = 1 THEN '[RowColor:X3]' 

				--when BOMItem.ModuleName='' then '[RowColor:XF]' 

                     ELSE ''

                END AS ColorControlId, ProductRoot.ItemName, ProductRoot.ProductType, ProductRoot.ProductSize,

                MachineNumber, PackingWay, BoxLength, BoxWidth, BoxHeight, BoxQty, ProductWeight, PalletRule,

                PalletALLRule, Remark, dbo.BOMItem.LTEXT

        FROM    BOMItem

        INNER JOIN Product ON BOMItem.ProductId = Product.ProductId

        INNER JOIN ProductRoot ON Product.ProductRootId = ProductRoot.ProductRootId

        LEFT OUTER JOIN UOM ON Product.UsageUOMId = UOM.UOMId

        LEFT OUTER JOIN SpecificationRoot

        INNER JOIN Specification ON SpecificationRoot.SpecificationRootId = Specification.SpecificationRootId ON BOMItem.SpecificationId = Specification.SpecificationId

        WHERE   ( BOMItem.BOMId = @I_ParentPKId )

        ORDER BY IsIgnore, ItemSequence;

        RETURN 0;



    END;



    IF @I_PKId <> ''

    BEGIN



        SELECT TOP ( 100 ) PERCENT

                BOMItem.BOMItemId, BOMItem.ItemSequence, BOMItem.ModuleName, BOMItem.CustomerNumber,

                [dbo].[RemoveZero](ProductRoot.ProductName) AS ProductName, BOMItem.EnglishDescription,

                Product.ProductDescription, CONVERT(DECIMAL(18, 2), BOMItem.QtyRequired) AS QtyRequired,

                CONVERT(DECIMAL(18, 2), BOMItem.QtyPack) AS QtyPack,

                CONVERT(DECIMAL(18, 2), BOMItem.SingleWeight) AS SingleWeight, BOMItem.ReplaceGroup, UOM.UOMName,

                CASE WHEN BOMItem.IsIgnore = 1 THEN '[RowColor:X3]' 

				--when BOMItem.ModuleName='' then '[RowColor:XF]' 

                     ELSE ''

                END AS ColorControlId, ProductRoot.ItemName, ProductRoot.ProductType, ProductRoot.ProductSize,

                MachineNumber, PackingWay, BoxLength, BoxWidth, BoxHeight, BoxQty, ProductWeight, PalletRule,

                PalletALLRule, Remark, dbo.BOMItem.LTEXT

        FROM    BOMItem

        INNER JOIN Product ON BOMItem.ProductId = Product.ProductId

        INNER JOIN ProductRoot ON Product.ProductRootId = ProductRoot.ProductRootId

        LEFT OUTER JOIN UOM ON Product.UsageUOMId = UOM.UOMId

        LEFT OUTER JOIN SpecificationRoot

        INNER JOIN Specification ON SpecificationRoot.SpecificationRootId = Specification.SpecificationRootId ON BOMItem.SpecificationId = Specification.SpecificationId

        WHERE   ( BOMItem.BOMItemId = @I_PKId )

        ORDER BY ItemSequence;

        RETURN 0;

    END;



    SELECT TOP ( 100 ) PERCENT

            BOMItem.BOMItemId, BOMItem.ItemSequence, BOMItem.ModuleName, BOMItem.CustomerNumber,

            [dbo].[RemoveZero](ProductRoot.ProductName) AS ProductName, BOMItem.EnglishDescription,

            Product.ProductDescription, CONVERT(DECIMAL(18, 2), BOMItem.QtyRequired) AS QtyRequired,

            CONVERT(DECIMAL(18, 2), BOMItem.QtyPack) AS QtyPack,

            CONVERT(DECIMAL(18, 2), BOMItem.SingleWeight) AS SingleWeight, BOMItem.ReplaceGroup, UOM.UOMName,

            CASE WHEN BOMItem.IsIgnore = 1 THEN '[RowColor:X3]' 

			--when BOMItem.ModuleName='' then '[RowColor:XF]' 

                 ELSE ''

            END AS ColorControlId, ProductRoot.ItemName, ProductRoot.ProductType, ProductRoot.ProductSize, MachineNumber,

            PackingWay, BoxLength, BoxWidth, BoxHeight, BoxQty, ProductWeight, PalletRule, PalletALLRule, Remark, dbo.BOMItem.LTEXT

    FROM    BOMItem

    INNER JOIN Product ON BOMItem.ProductId = Product.ProductId

    INNER JOIN ProductRoot ON Product.ProductRootId = ProductRoot.ProductRootId

    LEFT OUTER JOIN UOM ON Product.UsageUOMId = UOM.UOMId

    LEFT OUTER JOIN SpecificationRoot

    INNER JOIN Specification ON SpecificationRoot.SpecificationRootId = Specification.SpecificationRootId ON BOMItem.SpecificationId = Specification.SpecificationId

    ORDER BY ItemSequence, IsIgnore;



    RETURN 0;

END;























