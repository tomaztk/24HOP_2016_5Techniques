USE SQLR;
GO


WITH CTE
AS 
(SELECT 
		 sum(sod.[OrderQty]) AS OrderQty
		,so.[DiscountPct]
		,CASE WHEN pc.name = 'Clothing' THEN 1
			  WHEN pc.name = 'Bikes' THEN 2
			  WHEN pc.name = 'Accessories' THEN 3
			  WHEN pc.name = 'Components' THEN 4 END Category


		,sod.salesorderID
        ,SUM(CASE WHEN PC.name in ('Components','Accessories') THEN 1 ELSE 0 END) AS customer_bought

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
			--	WHEN SUM(customer_bought) > 2 THEN 'Heavy Cross_sell'
			--	WHEN SUM(customer_bought) = 0 THEN 'No Cross_sell'
			--	ELSE 'Light Cross_sell' END
			--			AS Cross_sell
			,CASE WHEN SUM(customer_bought) > 0 THEN 'Is Cross_sell' 
					ELSE 'Not cross_sell' END AS cross_sell
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

-- DROP TABLE Crosssell_data
INTO Crosssell_data

FROM CTE 
JOIN CROSS_SELL
on CTE.SalesorderID = CROSS_SELL.salesorderID

-- (71870 row(s) affected)
-- Duration 00:00:00

select * from Crosssell_data order by id