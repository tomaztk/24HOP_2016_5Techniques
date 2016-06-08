USE [SQLR]
GO

ALTER PROCEDURE [dbo].[SP_24HOP_3_graph_statistics]
(
@nof_cluster TINYINT
)

AS

DECLARE @RScript nvarchar(max)
SET @RScript = N'
				 library(cluster)	
				 mydata <- InputDataSet
				 d <- dist(mydata, method = "euclidean") 
				 fit <- hclust(d, method="ward.D")
				 #plot(fit,xlab=" ", ylab=NULL, main=NULL, sub=" ")
				 groups <- cutree(fit, k='+CAST(@nof_cluster AS CHAR(4))+') 
				 #rect.hclust(fit, k='+CAST(@nof_cluster AS CHAR(4))+', border="DarkRed")
				 #merge mydata and clusters
				 cluster_p <- data.frame(groups)
				 mydata <- cbind(mydata, cluster_p)

				 df_qt <- data.frame(table(mydata$OrderQty, mydata$groups),name = ''Qty'')
				 df_pc <- data.frame(table(mydata$DiscountPct, mydata$groups),name = ''Pct'')
				 df_cat <- data.frame(table(mydata$Category, mydata$groups),name = ''Cat'')
				 df_total <- df_qt
				 df_total <- rbind(df_total, df_pc)
				 df_total <- rbind(df_total, df_cat)
				 OutputDataSet <- df_total'

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
	WITH result SETS ( (
						 Var1 VARCHAR(100)
						,Var2 VARCHAR(100)
						,Freq INT
						,name VARCHAR(100))
					 );
GO



DECLARE @TEMP TABLE (
						 Var1 VARCHAR(100)
						,Var2 VARCHAR(100)
						,Freq INT
						,name VARCHAR(100)
						)

INSERT INTO @TEMP
EXECUTE [dbo].[SP_24HOP_3_graph_statistics] @nof_cluster = 3


SELECT * FROM @TEMP
WHERE name = 'QTY'