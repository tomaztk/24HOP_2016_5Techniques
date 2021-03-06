USE SQLR;
GO



ALTER PROCEDURE SP_24HOP_6_Generate_Prediction_Model
AS
BEGIN
	DECLARE @RScript nvarchar(max)
	SET @RScript = N'
			library(e1071);
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
		, @input_data_1_name = N'cust.data'
		, @output_data_1_name = N'trained_model'
	WITH result SETS ((model varbinary(max)));
END;


-- drop table TBL_24HOP_Cluster_Models
CREATE TABLE TBL_24HOP_Cluster_Models
   ( model_name VARCHAR(30) NOT NULL
	,model VARBINARY(max) NOT NULL
	,dt DATETIME NOT NULL
	PRIMARY KEY CLUSTERED (model_name)
	)


DECLARE @model TABLE  (model VARBINARY(MAX))
INSERT INTO @model (model)
EXECUTE SP_24HOP_6_Generate_Prediction_Model

INSERT INTO TBL_24HOP_Cluster_Models (Model_name, model, dt)
SELECT 'Model4_NB',(SELECT model from @model), GETDATE()


SELECT * FROM TBL_24HOP_Cluster_Models




		  SELECT 10 AS ID, '10% for Training' AS DESC_ID
UNION ALL SELECT 20 AS ID, '20% for Training' AS DESC_ID
UNION ALL SELECT 30 AS ID, '30% for Training' AS DESC_ID
UNION ALL SELECT 40 AS ID, '40% for Training' AS DESC_ID
UNION ALL SELECT 50 AS ID, '50% for Training' AS DESC_ID
UNION ALL SELECT 60 AS ID, '60% for Training' AS DESC_ID
UNION ALL SELECT 70 AS ID, '70% for Training' AS DESC_ID
ORDER BY ID




USE SQLR;
GO


ALTER PROCEDURE SP_24HOP_7_Predict_Category
(
	@model VARCHAR(100)
)
AS
	BEGIN
	DECLARE @nb_model VARBINARY(MAX) 
	SET @nb_model = (SELECT  model FROM TBL_24HOP_Cluster_Models WHERE model_name = @model);


	
	DECLARE @RScript NVARCHAR(MAX)
	SET @RScript = N'
			library(e1071);				
			crosssellmodel<-unserialize(nb_model)
			cross<-predict(crosssellmodel, cust.data[,2:5])
			df_crosspredictions <- cbind(cust.data[1], cross, cust.data[5])
			colnames(df_crosspredictions) <- c("id", "Cross.Actual", "Cross.Expected")
			OutputDataSet <- subset(df_crosspredictions, Cross.Actual != Cross.Expected);'


	DECLARE @SQLScript NVARCHAR(MAX)
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




	-- Predict species based on the specified model:
	EXEC sp_execute_external_script 
					@language = N'R'
				  , @script = @RScript

	, @input_data_1 = @SQLScript
	, @input_data_1_name = N'cust.data'
	, @params = N'@nb_model varbinary(max)'
	, @nb_model = @nb_model
	WITH result SETS ( (
						 ID INT
						,Cross_Actual VARCHAR(MAX)
						,Cross_Expected VARCHAR(MAX))
					 );
END;






EXECUTE SP_24HOP_7_Predict_Category 'Model 3 on category prediction'
