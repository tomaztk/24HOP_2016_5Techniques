USE SQLR;
GO

ALTER PROCEDURE SP_24HOP_2_graph

AS
DECLARE @RScript nvarchar(max)
DECLARE @SQLScript nvarchar(max)

SET @RScript = N'library(plotly)
				library(ggplot2)
				library(htmlwidgets)
				#setwd("C:/DataTK/HTML")
				 image_file <- tempfile()
				 jpeg(filename = image_file, width = 500, height = 500)
				 df <- InputDataSet
				 d <- df[sample(nrow(df), 10), ]
				 p <- plot_ly(d, x = OrderQty, y = DiscountPct, text = paste("OrderQty: ", OrderQty),
						 mode = "markers", color = OrderQty, size = OrderQty)
				 saveWidget(as.widget(p), "index.html")
				 OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6))' 


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
EXECUTE SP_24HOP_2_graph
SELECT * FROM @Plot;
GO
