USE [SQLR]
GO
/****** Object:  StoredProcedure [dbo].[SP_24HOP_7_Predict_Category]    Script Date: 22. 05. 2016 12:04:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[SP_24HOP_7_Predict_Category]
(
	@model VARCHAR(100)
)
AS
	BEGIN
	DECLARE @nb_model VARBINARY(MAX) 
	SET @nb_model = (SELECT TOP 1 model FROM TBL_24HOP_Cluster_Models WHERE model_name = @model ORDER BY dt DESC);


	
	DECLARE @RScript nvarchar(max)
	SET @RScript = N'
			library(e1071);				
			crosssellmodel<-unserialize(nb_model)
			cross<-predict(crosssellmodel, cust.data[,2:5])
			df_crosspredictions <- cbind(cust.data[1], cross, cust.data[5])
			colnames(df_crosspredictions) <- c("id", "Cross.Actual", "Cross.Expected")
			OutputDataSet <- subset(df_crosspredictions, Cross.Actual != Cross.Expected);'


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




	-- Predict species based on the specified model:
	exec sp_execute_external_script 
					@language = N'R'
				  , @script = @RScript

	, @input_data_1 = @SQLScript
	, @input_data_1_name = N'cust.data'
	, @params = N'@nb_model varbinary(max)'
	, @nb_model = @nb_model
	WITH result SETS ( (
						 ID INT
						,Cross_Actual varchar(max)
						,Cross_Expected varchar(max))
					 );
END;





ALTER PROCEDURE [dbo].[SP_24HOP_7_Predict_Category_Confusion_Matrix]
(
	@model VARCHAR(100)
)
AS
	BEGIN
	DECLARE @nb_model VARBINARY(MAX) 
	SET @nb_model = (SELECT TOP 1 model FROM TBL_24HOP_Cluster_Models WHERE model_name = @model);


	
	DECLARE @RScript nvarchar(max)
	SET @RScript = N'
			library(e1071);				
			crosssellmodel<-unserialize(nb_model)
			cross<-predict(crosssellmodel, cust.data[,2:5])
			df_crosspredictions <- cbind(cust.data[1], cross, cust.data[5])
			colnames(df_crosspredictions) <- c("id", "Cross.Actual", "Cross.Expected")
			df_crosspredictions_All <- (df_crosspredictions)
			df_confusion_matrix <- data.frame(table(pred=df_crosspredictions_All$Cross.Actual, True=df_crosspredictions_All$Cross.Expected))
			OutputDataSet <- df_confusion_matrix;'


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




	-- Predict species based on the specified model:
	exec sp_execute_external_script 
					@language = N'R'
				  , @script = @RScript

	, @input_data_1 = @SQLScript
	, @input_data_1_name = N'cust.data'
	, @params = N'@nb_model varbinary(max)'
	, @nb_model = @nb_model
	WITH result SETS ( (
						 Pred VARCHAR(1000)
						,True VARCHAR(1000)
						,Freq INT)
					 );
END;




EXECUTE SP_24HOP_7_Predict_Category_Confusion_Matrix 'Model3_NB'








ALTER PROCEDURE [dbo].[SP_24HOP_7_Predict_Category_Correct_predictions]
(
	@model VARCHAR(100)
)
AS
	BEGIN
	DECLARE @nb_model VARBINARY(MAX) 
	SET @nb_model = (SELECT TOP 1 model FROM TBL_24HOP_Cluster_Models WHERE model_name = @model);


	
	DECLARE @RScript nvarchar(max)
	SET @RScript = N'
			library(e1071);				
			crosssellmodel<-unserialize(nb_model)
			cross<-predict(crosssellmodel, cust.data[,2:5])
			df_crosspredictions <- cbind(cust.data[1], cross, cust.data[5])
			colnames(df_crosspredictions) <- c("id", "Cross.Actual", "Cross.Expected")
			df_crosspredictions_All <- (df_crosspredictions)
			df_confusion_matrix <- data.frame(table(pred=df_crosspredictions_All$Cross.Actual, True=df_crosspredictions_All$Cross.Expected))
			df_mean <- data.frame(mean(cross==cust.data$Cross_sell))
			colnames(df_mean) <- ''Mean''
			OutputDataSet <- df_mean;'


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




	-- Predict species based on the specified model:
	exec sp_execute_external_script 
					@language = N'R'
				  , @script = @RScript

	, @input_data_1 = @SQLScript
	, @input_data_1_name = N'cust.data'
	, @params = N'@nb_model varbinary(max)'
	, @nb_model = @nb_model
	WITH result SETS ( (
						 Mean DECIMAL(10,6)
						 )
					 );
END;



EXECUTE SP_24HOP_7_Predict_Category_Correct_predictions 'Model3_NB'
