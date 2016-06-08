USE SQLR;
GO


ALTER PROCEDURE SP_24HOP_3_graph
(
@nof_cluster TINYINT
)

AS

DECLARE @RScript nvarchar(max)
SET @RScript = N'
				 library(cluster)	
				 image_file <- tempfile()
				 jpeg(filename = image_file, width = 400, height = 400)
				 mydata <- InputDataSet
				 d <- dist(mydata, method = "euclidean") 
				 fit <- hclust(d, method="ward.D")
				 plot(fit,xlab=" ", ylab=NULL, main=NULL, sub=" ")
				 groups <- cutree(fit, k='+CAST(@nof_cluster AS CHAR(4))+') 
				 rect.hclust(fit, k='+CAST(@nof_cluster AS CHAR(4))+', border="DarkRed")
				 dev.off() 
				 OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6))'

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
	 @language = N'R'
	,@script = @RScript
	,@input_data_1 = @SQLScript
WITH RESULT SETS (
					(Hierarchical_cluster varbinary(max))
				 )


-- GRAPH TEST - Graph Itself!

DECLARE @Plot TABLE (col1 varbinary(max))
INSERT INTO @Plot (col1)
EXECUTE SP_24HOP_3_graph 3
SELECT * FROM @Plot;
GO
