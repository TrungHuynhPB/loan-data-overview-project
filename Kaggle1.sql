SELECT [Loan_ID] 
      ,[Customer_ID]
      ,[Loan_Status] -- Fully Paid, Charged Off (Written off)
      ,[Current_Loan_Amount]
      ,[Term] -- long term, short term
      ,[Credit_Score]
      ,[Annual_Income]
      ,[Years_in_current_job]
      ,[Home_Ownership] -- Own Home / Rent / Home Mortgage
      ,[Purpose] --Take a trip, Debt consolidation, Buy a car, Home Improvement ...
      ,[Monthly_Debt]
      ,[Years_of_Credit_History]
      ,[Months_since_last_delinquent]
      ,[Number_of_Open_Accounts]
      ,[Number_of_Credit_Problems]
      ,[Current_Credit_Balance]
      ,[Maximum_Open_Credit]
      ,[Bankruptcies] -- 0 = no, 1 = yes
      ,[Tax_Liens] -- 0 = no, 1 = yes
  FROM [PortfolioProject].[dbo].[credit_train$]
-- view data type
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'credit_train$'
AND COLUMN_NAME IN ('Loan_ID', 'Customer_ID', 'Loan_Status', 'Current_Loan_Amount', 'Term', 'Credit_Score', 'Annual_Income', 'Years_in_current_job', 'Home_Ownership', 'Purpose', 'Monthly_Debt', 'Years_of_Credit_History', 'Months_since_last_delinquent', 'Number_of_Open_Accounts', 'Number_of_Credit_Problems', 'Current_Credit_Balance', 'Maximum_Open_Credit', 'Bankruptcies', 'Tax_Liens')
-- CONVERT months_since_last_deliquent to Integer -> Update table column
SELECT 
	CASE
	WHEN [Months_since_last_delinquent] <> 'NA' THEN CAST([Months_since_last_delinquent] AS INT)
	WHEN [Months_since_last_delinquent] = 'NA' THEN NULL
	END
FROM PortfolioProject.dbo.credit_train$
ORDER BY [Months_since_last_delinquent] ASC

UPDATE PortfolioProject.dbo.credit_train$
SET [Months_since_last_delinquent] =
	CASE
	WHEN [Months_since_last_delinquent] <> 'NA' THEN CAST([Months_since_last_delinquent] AS INT)
	WHEN [Months_since_last_delinquent] = 'NA' THEN NULL
	END
FROM PortfolioProject.dbo.credit_train$
--CONVERT from nvarchar to float
ALTER TABLE PortfolioProject.dbo.credit_train$
ALTER COLUMN [Months_since_last_delinquent] FLOAT
--REMOVE DUPLICATES DATA TABLE
WITH CTE AS (
SELECT *,
	ROW_NUMBER() OVER (
		PARTITION BY  Loan_ID,
					  Customer_ID,
					  Loan_Status,
					  Term,
					  Annual_Income,
					  Years_in_current_job,
					  Home_Ownership,
					  Purpose
					  ORDER BY
						Loan_ID
		) row_num
FROM PortfolioProject.dbo.credit_train$
)
SELECT *
FROM CTE
WHERE row_num > 1
--there are 13.794 rows that are duplicates -> REMOVING them
WITH CTE AS (
SELECT *,
	ROW_NUMBER() OVER (
		PARTITION BY  Loan_ID,
					  Customer_ID,
					  Loan_Status,
					  Term,
					  Annual_Income,
					  Years_in_current_job,
					  Home_Ownership,
					  Purpose
					  ORDER BY
						Loan_ID
		) row_num
FROM PortfolioProject.dbo.credit_train$
)
DELETE
FROM CTE
WHERE row_num > 1

-- Find out how many users have last deliquent in specified number of months
WITH CTE
AS
(
SELECT [Months_since_last_delinquent], COUNT(DISTINCT(Customer_ID)) AS number_of_users
FROM PortfolioProject.dbo.credit_train$
GROUP BY [Months_since_last_delinquent]
--ORDER BY [Months_since_last_delinquent] ASC
)
SELECT *, (CAST(number_of_users AS float) / 37378 * 100) AS Percentage_
FROM CTE
ORDER BY [Months_since_last_delinquent] ASC
-- Find out total amount of loan filter by loan status and filter by term
DECLARE @loan float
SET @loan = (SELECT SUM(Current_Loan_Amount) 
			FROM PortfolioProject.dbo.credit_train$);
WITH CTE AS
(
	SELECT Loan_Status, Term, SUM(Current_Loan_Amount) AS Total_loan_amount
	FROM PortfolioProject.dbo.credit_train$
	GROUP BY Loan_Status, Term
)
SELECT *, (Total_loan_amount / @loan) AS Percentage_
FROM CTE
ORDER BY Total_loan_amount DESC
--Calculate Debt To Income Ratio
SELECT Loan_ID, Customer_ID, Loan_Status, Current_Loan_Amount, Annual_Income, Monthly_Debt,
	CASE
		WHEN Annual_Income > 350000 THEN 'Rich'
		WHEN  Annual_Income > 100000 AND Annual_Income <=  350000  THEN 'Upper middle class'
		WHEN Annual_Income > 50000 AND Annual_Income <=  100000 THEN 'Middle Class'
		WHEN Annual_Income > 30000 AND Annual_Income <=  50000 THEN 'Lower Middle Class'
		WHEN Annual_Income <= 30000 THEN 'Poor'
	END AS SES_Breakdown,
	 (Monthly_Debt / (Annual_Income / 12)) AS Debt_To_Income_Ratio
FROM PortfolioProject.dbo.credit_train$
WHERE Annual_Income <> 0 OR Annual_Income IS NOT NULL
ORDER BY Debt_To_Income_Ratio DESC

WITH CTE AS
(
SELECT Loan_ID, Customer_ID, Loan_Status, Current_Loan_Amount, Annual_Income, Monthly_Debt,
	CASE
		WHEN Annual_Income > 350000 THEN 'Rich'
		WHEN  Annual_Income > 100000 AND Annual_Income <=  350000  THEN 'Upper middle class'
		WHEN Annual_Income > 50000 AND Annual_Income <=  100000 THEN 'Middle Class'
		WHEN Annual_Income > 30000 AND Annual_Income <=  50000 THEN 'Lower Middle Class'
		WHEN Annual_Income <= 30000 THEN 'Poor'
	END AS SES_Breakdown,
	 (Monthly_Debt / (Annual_Income / 12)) AS Debt_To_Income_Ratio
FROM PortfolioProject.dbo.credit_train$
WHERE Annual_Income <> 0 OR Annual_Income IS NOT NULL
)
SELECT SES_Breakdown, COUNT(DISTINCT(Customer_ID)) AS number_of_users, SUM(Current_Loan_Amount) total_loan_amount
FROM CTE
GROUP BY SES_Breakdown
ORDER BY SUM(Current_Loan_Amount) DESC
--Years in current job group
SELECT Years_in_current_job, COUNT(DISTINCT(Customer_ID)) AS number_of_customers
FROM PortfolioProject.dbo.credit_train$
GROUP BY Years_in_current_job
-- Purpose of taking loan
SELECT Purpose, Term, COUNT(DISTINCT(Customer_ID)) AS number_of_customers
FROM PortfolioProject.dbo.credit_train$
GROUP BY Purpose, Term
ORDER BY  COUNT(DISTINCT(Customer_ID)) DESC, Term

SELECT Purpose, COUNT(DISTINCT(Customer_ID)) AS number_of_customers
FROM PortfolioProject.dbo.credit_train$
GROUP BY Purpose
ORDER BY  COUNT(DISTINCT(Customer_ID)) DESC
-- Own Property
SELECT Home_Ownership, Term, COUNT(DISTINCT(Customer_ID)) AS number_of_customers
FROM PortfolioProject.dbo.credit_train$
GROUP BY Home_Ownership, Term
ORDER BY  COUNT(DISTINCT(Customer_ID)) DESC, Term

SELECT Home_Ownership, COUNT(DISTINCT(Customer_ID)) AS number_of_customers
FROM PortfolioProject.dbo.credit_train$
GROUP BY Home_Ownership
ORDER BY  COUNT(DISTINCT(Customer_ID)) DESC
-- CustomerID
SELECT Customer_ID, COUNT(Loan_ID) AS Number_of_loans, SUM(Current_Loan_Amount) AS Total_Loan, AVG(Annual_Income) AS AVG_INCOME
FROM PortfolioProject.dbo.credit_train$
GROUP BY Customer_ID
ORDER BY COUNT(Loan_ID) DESC