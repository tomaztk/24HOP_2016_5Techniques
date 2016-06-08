USE SQLR;
GO


SELECT 
	DISTINCT OrderQty 
FROM Crosssell_data



SELECT 
	DISTINCT DiscountPct
FROM Crosssell_data
ORDER BY DiscountPct



SELECT
	DISTINCT Category AS ID
	,CASE WHEN Category = 1 THEN 'Clothing' 
		  WHEN Category = 2 THEN 'Bikes'
		  WHEN Category = 3 THEN 'Accessories'
		  WHEN Category = 4 THEN 'Components' END Category_desc
FROM Crosssell_data
ORDER BY ID



SELECT 
	DISTINCT Cross_sell
FROM Crosssell_data



SELECT 
	model_name
	,Model
	,dt AS DateTime_Of_Creation
	,Model_name + ' - DateOf: ' + CAST(dt AS VARCHAR(20)) AS Model_desc_time
 FROM [dbo].[TBL_24HOP_Cluster_Models]




 
ALTER PROCEDURE SP_24HOP_8_New_data_prediction
(
	 @model_name VARCHAR(100)
	,@OrderQty INT = 0
	,@DiscountPct DECIMAL(10,2) = 0.0
	,@Category INT = 1

)
AS
	BEGIN
	DECLARE @nb_model VARBINARY(MAX) 
	SET @nb_model = (SELECT  model FROM TBL_24HOP_Cluster_Models WHERE model_name = @model_name);


	
	DECLARE @RScript NVARCHAR(MAX)
	SET @RScript = N'
			library(e1071);				
			crosssellmodel<-unserialize(nb_model)
			cross<-predict(crosssellmodel, cust.data_new[,2:5])
			df_crosspredictions <- cbind(cust.data_new[1], cross, cust.data_new[5])
			colnames(df_crosspredictions) <- c("id", "Cross.Actual", "Cross.Expected")
			OutputDataSet <- df_crosspredictions;'

	DECLARE @Cross_sell_default VARCHAR(20) = 'Not cross_sell'
	DECLARE @SQLScript NVARCHAR(MAX)
	SET @SQLScript = N'SELECT
						  1 AS ID
						 ,'+CAST(@OrderQty AS VARCHAR(10))+' AS OrderQty
						 ,'+CAST(@DiscountPct AS VARCHAR(10))+' AS DiscountPct
						 ,'+CAST(@Category AS VARCHAR(10))+' AS Category
						 ,''Not cross_sell'' AS Cross_sell'
						 

   -- Predict cross_sell based on the specified model:
	EXEC sp_execute_external_script 
					@language = N'R'
				  , @script = @RScript
				  , @input_data_1 = @SQLScript
				  , @input_data_1_name = N'cust.data_new'
				  , @params = N'@nb_model varbinary(max)'
				  , @nb_model = @nb_model
	WITH result SETS ( (
						 ID INT
						,Cross_Actual VARCHAR(MAX)
						,Cross_Expected VARCHAR(MAX))
					 );
END;



EXECUTE SP_24HOP_8_New_data_prediction 
			 @model_name = 'Model3_NB'
			,@OrderQty = 2
			,@DiscountPct = 0
			,@Category = 1