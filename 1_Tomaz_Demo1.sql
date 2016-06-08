USE SQLR;
GO

--SELECT 
--ps.[Name]
--,AVG(sod.[OrderQty]) AS OrderQty
--,so.[DiscountPct]
--,pc.name AS Category
--FROM  [Sales].[SalesOrderDetail] sod
--INNER JOIN [Sales].[SpecialOffer] so
--ON so.[SpecialOfferID] = sod.[SpecialOfferID]
--INNER JOIN [Production].[Product] p
--ON p.[ProductID] = sod.[ProductID]
--INNER JOIN [Production].[ProductSubcategory] ps
--ON ps.[ProductSubcategoryID] = p.ProductSubcategoryID
--INNER JOIN [Production].[ProductCategory] pc
--ON pc.ProductCategoryID = ps.ProductCategoryID

--GROUP BY ps.[Name],so.[DiscountPct],pc.name


CREATE TABLE TBL_24HOP_1_graph_filter
(ID int, graphs varchar(20))

INSERT INTO TBL_24HOP_1_graph_filter
		  SELECT 1, 'Bar Chart' 
UNION ALL SELECT 2, 'Pie Chart'



ALTER PROCEDURE SP_24HOP_1_graph
(
    @GraphType INT
)
AS
DECLARE @RScript nvarchar(max)
DECLARE @RScript_Barchart NVARCHAR(MAX)
DECLARE @RScript_Piechart NVARCHAR(MAX)

SET @RScript_Barchart = N'library(ggplot2)
				 image_file <- tempfile()
				 jpeg(filename = image_file, width = 500, height = 500)
				 df <- InputDataSet
					bar2 <- table(df$OrderQty, df$Category)
					barplot(bar2, main="Average Order Quantity per Product Group",
					  xlab="Product Category", col=c("blue","red", "darkgreen", "magenta"),legend = rownames(df$OrderQty), beside=TRUE)
				 dev.off()
				 OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6))' 


SET @RScript_Piechart = N'library(ggplot2)
				 image_file <- tempfile()
				 jpeg(filename = image_file, width = 500, height = 500)
				 df <- InputDataSet
				 mytable <- table(df$Category)
				 lbls <- paste(names(mytable), "\n", mytable, sep="")
				 pie(mytable, labels = lbls, main="OrderQty per ProductCategory", col = c("purple", "violetred1", "green3","cornsilk")) 
				 dev.off()
				 OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6))' 

IF @GraphType = 1 BEGIN SET @RScript = @RScript_Barchart  END
IF @GraphType = 2 BEGIN SET @RScript = @RScript_Piechart  END

DECLARE @SQLScript nvarchar(max)
SET @SQLScript = N'SELECT 
					 ps.[Name]
					,AVG(sod.[OrderQty]) AS OrderQty
					,so.[DiscountPct]
					,pc.name AS Category
				FROM  Adventureworks.[Sales].[SalesOrderDetail] sod
				INNER JOIN Adventureworks.[Sales].[SpecialOffer] so
				ON so.[SpecialOfferID] = sod.[SpecialOfferID]
				INNER JOIN Adventureworks.[Production].[Product] p
				ON p.[ProductID] = sod.[ProductID]
				INNER JOIN Adventureworks.[Production].[ProductSubcategory] ps
				ON ps.[ProductSubcategoryID] = p.ProductSubcategoryID
				INNER JOIN Adventureworks.[Production].[ProductCategory] pc
				ON pc.ProductCategoryID = ps.ProductCategoryID
				GROUP BY ps.[Name],so.[DiscountPct],pc.name'

EXECUTE sp_execute_external_script
@language = N'R',
@script = @RScript,
@input_data_1 = @SQLScript
WITH RESULT SETS ((Plot varbinary(max)))
GO



-- GRAPH TEST - Graph Itself!

DECLARE @Plot TABLE (col1 varbinary(max))
INSERT INTO @Plot (col1)
EXECUTE SP_24HOP_1_graph @GraphType  = 1
SELECT * FROM @Plot;
GO



DECLARE @Plot TABLE (col1 varbinary(max))
INSERT INTO @Plot (col1)
-- EXECUTE SP_24HOP_1_graph @GraphType  = 2
EXECUTE SP_24HOP_1_graph 2

SELECT * FROM @Plot;
GO




SELECT * FROM TBL_24HOP_1_graph_filter