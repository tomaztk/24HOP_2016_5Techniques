USE SQLR;
GO


ALTER PROCEDURE SP_24HOP_4_graph
(
@nof_cluster TINYINT
)

AS

DECLARE @RScript nvarchar(max)
SET @RScript = N'
				 library(cluster)	
				 image_file <- tempfile()
				 jpeg(filename = image_file, width = 400, height = 400)
				 cust.data <- InputDataSet
				 newcust.data <- cust.data
				 newcust.data$Category <- NULL
				 newcust.data$Name <- NULL
				 kc <- kmeans(newcust.data, '+CAST(@nof_cluster AS VARCHAR(4))+')
				 table(cust.data$Category, kc$cluster)
				 plot(newcust.data[c("OrderQty", "DiscountPct")], col=kc$cluster)
				 points(kc$centers[,c("OrderQty", "DiscountPct")], col=1:'+CAST(@nof_cluster AS VARCHAR(4))+', pch=8, cex=2)
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
					(Hierarchical_cluster_2 varbinary(max))
				 )




-- GRAPH TEST - Graph Itself!

DECLARE @Plot TABLE (col1 varbinary(max))
INSERT INTO @Plot (col1)
EXECUTE SP_24HOP_4_graph 3
SELECT * FROM @Plot;
GO



/*
newcust.data <- cust.data
newcust.data$Category <- NULL
newcust.data$Name <- NULL
kc <- kmeans(newcust.data, 4)
table(cust.data$Category, kc$cluster)
plot(newcust.data[c("OrderQty", "DiscountPct")], col=kc$cluster)
points(kc$centers[,c("OrderQty", "DiscountPct")], col=1:4, pch=8, cex=2)
*/

/*
CREATE TABLE Clusters (ID TINYINT, C_Desc VARCHAR(30))

INSERT INTO Clusters (ID, C_Desc)
		  SELECT 2, '2- Two Clusters'
UNION ALL SELECT 3, '3- Three Clusters'
UNION ALL SELECT 4, '4- Four Clusters'
UNION ALL SELECT 5, '5 - Five Clusters'
UNION ALL SELECT 6, '6 - Six Clusters'
UNION ALL SELECT 7, '7 - Seven Clusters'
UNION ALL SELECT 8, '8 - Eight Clusters'
*/