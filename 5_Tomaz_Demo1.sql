USE SQLR;
GO


ALTER PROCEDURE SP_24HOP_5_graph
(
@nof_cluster TINYINT
)

AS

DECLARE @RScript nvarchar(max)
SET @RScript = N'library(cluster)	 
				cust.data <- InputDataSet
				newcust.data <- cust.data
				newcust.data$Category <- NULL
				newcust.data$Name <- NULL
				kc <- kmeans(newcust.data, '+CAST(@nof_cluster AS VARCHAR(4))+')					
				dd <- data.frame(table(cust.data$Category, kc$cluster))
				OutputDataSet <- dd'

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
	,@output_data_1_name = N'dd'
WITH RESULT SETS (
					 (Var1 VARCHAR(100)
					,Var2 INT
					,Freq INT)
				 )


DECLARE @Cluster_centers TABLE 
					(Var1 VARCHAR(100)
					,Var2 INT
					,Freq INT)
INSERT INTO @Cluster_centers (Var1, Var2, Freq)
EXECUTE SP_24HOP_5_graph 3

SELECT * FROM @Cluster_centers

SELECT Var1 AS Category, [1], [2],  [3]
FROM
	(SELECT Var1, Var2, Freq FROM @Cluster_centers) AS Orig
PIVOT
(
SUM(Freq)
FOR Var2 IN ([1], [2],  [3])

) AS Piv_Orig