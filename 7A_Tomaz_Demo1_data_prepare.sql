USE [SQLR]
GO
 


ALTER PROCEDURE [dbo].[SP_24HOP_6_Generate_Prediction_Model_based_on_Clusters]
(
 @nof_cluster TINYINT
,@cluster_number TINYINT
)

AS
BEGIN
	DECLARE @RScript nvarchar(max)
	SET @RScript = N'
			library(e1071);
		    d <- dist(mydata, method = "euclidean") 
			fit <- hclust(d, method="ward.D")
			groups <- cutree(fit, k='+CAST(@nof_cluster AS CHAR(4))+') 
			#merge mydata and clusters
			cluster_p <- data.frame(groups)
			mydata2 <- cbind(mydata, cluster_p)
			cust.data <- mydata2[mydata2$groups == '+CAST(@cluster_number AS CHAR(4))+', ]
			crosssellmodel <-naiveBayes(cust.data[,1:4], cust.data[,5])
			trained_model <- data.frame(payload = as.raw(serialize(crosssellmodel, connection=NULL)));'

	DECLARE @SQLScript nvarchar(max)
	SET @SQLScript = N'
	WITH CTE
AS 
(SELECT 
		 sum(sod.[OrderQty]) AS OrderQty
		,so.[DiscountPct]
		,CASE WHEN pc.name = ''Clothing'' THEN 1
			  WHEN pc.name = ''Bikes'' THEN 2
			  WHEN pc.name = ''Accessories'' THEN 3
			  WHEN pc.name = ''Components'' THEN 4 END Category


		,sod.salesorderID
        ,SUM(CASE WHEN PC.name in (''Components'',''Accessories'') THEN 1 ELSE 0 END) AS customer_bought

	FROM  Adventureworks.[Sales].[SalesOrderDetail] sod
	INNER JOIN Adventureworks.[Sales].[SpecialOffer] so
	ON so.[SpecialOfferID] = sod.[SpecialOfferID]
	INNER JOIN Adventureworks.[Production].[Product] p
	ON p.[ProductID] = sod.[ProductID]
	INNER JOIN Adventureworks.[Production].[ProductSubcategory] ps
	ON ps.[ProductSubcategoryID] = p.ProductSubcategoryID
	INNER JOIN Adventureworks.[Production].[ProductCategory] pc
	ON pc.ProductCategoryID = ps.ProductCategoryID
	GROUP BY ps.[Name],so.[DiscountPct],pc.name,sod.salesorderID
)
,CROSS_SELL AS
(
	SELECT

			salesorderID
			--,CASE 
			--	WHEN SUM(customer_bought) > 2 THEN ''Heavy Cross_sell''
			--	WHEN SUM(customer_bought) = 0 THEN ''No Cross_sell''
			--	ELSE ''Light Cross_sell'' END
			--			AS Cross_sell
			,CASE WHEN SUM(customer_bought) > 0 THEN ''Is Cross_sell''
					ELSE ''Not cross_sell'' END AS Cross_sell
	FROM cte
	GROUP BY
			 salesorderID
)

SELECT 
	 ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS ID
	,CTE.OrderQty
	,CTE.DiscountPct
	,CTE.Category
	,CROSS_SELL.Cross_sell
FROM CTE 
JOIN CROSS_SELL
on CTE.SalesorderID = CROSS_SELL.salesorderID'


 EXECUTE sp_execute_external_script
		  @language = N'R'
		, @script = @RScript
		, @input_data_1 = @SQLScript
		, @input_data_1_name = N'mydata'
		, @output_data_1_name = N'trained_model'
	WITH result SETS ((model varbinary(max)));
END;




-- EXECUTE SP_24HOP_6_Generate_Prediction_Model_based_on_Clusters 4,1

DECLARE @ModelName VARCHAR(100) = 'Test clusters'
DECLARE @model TABLE  (model VARBINARY(MAX))
INSERT INTO @model (model)
EXECUTE SP_24HOP_6_Generate_Prediction_Model_based_on_Clusters   @nof_cluster = 4, @cluster_number = 1

INSERT INTO TBL_24HOP_Cluster_Models (Model_name, model, dt)
SELECT @ModelName, (SELECT model from @model), GETDATE()


SELECT 'Model Created' AS RESULT