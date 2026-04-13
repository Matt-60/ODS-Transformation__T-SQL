--1. Fact table - [ods].[Orders]

SELECT TOP (1000) [OrderID]
      ,[OrderDateKey]
      ,[ProductKey]
      ,[CustomerKey]
      ,[Quantity]
      ,[Revenue]
      ,[Cost]
      ,[IsReturned]
      ,[OrderCreatedAt] --- dok³adny moment utworzenia zamówienia (data + godzina)
      ,[ActualShipDateKey] -- kiedy zamówienie realnie wyjecha³o. NULL = jeszcze nie wys³ane
      ,[IsExpress], -- czy klient dop³aci³ za ekspresow¹ wysy³kê
      IsHoliday_PL
  FROM [ods].[Orders] o
  LEFT JOIN ODS.DimDate d ON o.OrderDateKey=d.DateKey

  -- 2. Dimension tables
    -- 2.1 [ods].[CustomerSLA]

  SELECT TOP (1000) [CustomerKey] -- klucz klienta
      ,[MaxShipDays] -- ile dni od z³o¿enia zamówienia manufaktura ma na wysy³kê (1, 2 lub 3 dni)
      ,[SLA_Label] -- opis: Standard / Priority / Express-Ready
  FROM [ods].[CustomerSLA]

  --?Uwaga: nie ka¿dy klient ma wpis w tej tabeli! Dummy row (CustomerKey = -1) nie ma SLA.

    -- 2.2 [ods].[ShipmentDelays]

    SELECT TOP (1000) [DelayID]
      ,[OrderID] -- które zamówienie dotyczy
      ,[DelayReason] -- powód opóŸnienia (np. „Transport nie przyjecha³”, „Warunki pogodowe”)
      ,[NewDeadlineDateKey] -- nowy deadline po przesuniêciu
      ,[ReportedAt],
      IsHoliday_PL
  FROM [ods].[ShipmentDelays] sd
  LEFT JOIN ODS.DimDate d ON sd.NewDeadlineDateKey=d.DateKey

  --Jeœli zamówienie ma wpis w tej tabeli - nowy deadline nadpisuje wyliczony z SLA.

      -- 2.3 [ods].[DimDate] - wykorzystaj kolumny IsWeekend i IsHoliday_PL


  -- Data overview

  SELECT * FROM ods.Orders 
  WHERE CustomerKey = -1

  SELECT COUNT(*) FROM ods.Orders 

  SELECT
  TOP 100 *
  --COUNT(*)
  FROM ods.Orders o
  LEFT JOIN ODS.CustomerSLA c ON o.CustomerKey=c.CustomerKey
  LEFT JOIN ods.ShipmentDelays sd ON o.OrderID=sd.OrderID
  LEFT JOIN (SELECT * FROM ODS.DimDate) dd ON sd.NewDeadlineDateKey=dd.DateKey
  LEFT JOIN ODS.DimDate d ON o.OrderDateKey=d.DateKey

--Start:

WITH Deadline AS
  (SELECT o.OrderID,
          o.OrderDateKey,
          o.CustomerKey,
          o.OrderCreatedAt,
          o.ActualShipDateKey,
          o.IsExpress,
          c.MaxShipDays,
          c.SLA_Label,
          sd.DelayReason,
          sd.NewDeadlineDateKey,
          sd.ReportedAt,
          d.FullDate AS FullDate1,
          d.IsHoliday_PL AS IsHoliday_PL1,
          d.IsWeekend AS IsWeekend1,
          d.YearMonth AS YearMonth1,
          dd.FullDate AS FullDate2,
          p.Category,
          CASE
              WHEN o.CustomerKey >0 THEN DATEADD(DAY, MaxShipDays, CAST(OrderCreatedAt AS DATE))
              ELSE DATEADD(DAY, 3, CAST(OrderCreatedAt AS DATE))
          END AS Deadline
   FROM ods.Orders o
   LEFT JOIN ODS.CustomerSLA c ON o.CustomerKey=c.CustomerKey
   LEFT JOIN ods.ShipmentDelays sd ON o.OrderID=sd.OrderID
   LEFT JOIN
     (SELECT *
      FROM ODS.DimDate) dd ON sd.NewDeadlineDateKey=dd.DateKey
   LEFT JOIN ODS.DimDate d ON o.OrderDateKey=d.DateKey
   LEFT JOIN ods.DimProduct p ON o.ProductKey=p.ProductKey),

deadline_express AS
  (SELECT *,
          CASE
              WHEN IsExpress = 1 THEN DATEADD(DAY, CASE WHEN Deadline > CAST(OrderCreatedAt AS DATE) THEN -1 ELSE 0 END , Deadline)
              ELSE Deadline
          END AS deadline_express
   FROM Deadline),

deadline_isholidayweekend AS
  (SELECT OrderID,
          OrderDateKey,
          CustomerKey,
          OrderCreatedAt,
          ActualShipDateKey,
          IsExpress,
          MaxShipDays,
          SLA_Label,
          DelayReason,
          NewDeadlineDateKey,
          ReportedAt,
          FullDate1,
          IsHoliday_PL1,
          IsWeekend1,
          YearMonth1,
          FullDate2,
          Category,
          Deadline,
          deadline_express,

     (SELECT TOP 1 d2.FullDate
      FROM [ods].[DimDate] d2
      WHERE d2.FullDate >= deadline_express
        AND d2.DayOfWeek <> 7
        AND d2.IsHoliday_PL = 0
      ORDER BY d2.FullDate) AS AdjustedDeadline
   FROM deadline_express),

Final_deadline AS
  (SELECT *,
          COALESCE(FullDate2, AdjustedDeadline) AS final_deadline
   FROM deadline_isholidayweekend),
 
delay_flags AS
  (SELECT *,
          CASE
              WHEN CONVERT(DATE, CAST(ActualShipDateKey AS VARCHAR(8)), 112) <= final_deadline THEN 1
              ELSE 0
          END AS OnTime,
          CASE
              WHEN CONVERT(DATE, CAST(ActualShipDateKey AS VARCHAR(8)), 112) > final_deadline THEN 1
              ELSE 0
          END AS Delayed,
          CASE
              WHEN ActualShipDateKey IS NULL THEN 1
              ELSE 0
          END AS InProgress
   FROM Final_deadline)

SELECT * INTO #FinalTable FROM delay_flags

SELECT CAST(100.0 * SUM(OnTime) / COUNT(*) AS DECIMAL(5, 2)) AS OnTimePct,
       CAST(100.0 * SUM(Delayed) / COUNT(*) AS DECIMAL(5, 2)) AS DelayedPct,
       CAST(100.0 * SUM(InProgress) / COUNT(*) AS DECIMAL(5, 2)) AS InProgressPct,
       COUNT(*) AS Total,
       100.0 * SUM(OnTime) / COUNT(*) + 100.0 * SUM(Delayed) / COUNT(*) + 100.0 * SUM(InProgress) / COUNT(*) AS Check1,
       SUM(OnTime) + SUM(Delayed) + SUM(InProgress) AS Check2
FROM #FinalTable
WHERE YearMonth1 = '2026-03'

-- 1. 82,68% OnTime, 17,32% Delayed

SELECT CustomerKey,
       100.0 * SUM(Delayed) / NULLIF(SUM(OnTime) + SUM(Delayed), 0) AS DelayedPct
FROM #FinalTable
GROUP BY CustomerKey
ORDER BY 100.0 * SUM(Delayed) / NULLIF(SUM(OnTime) + SUM(Delayed), 0) DESC

--2. PERC - 49.18 CUSTOMERKEY - 13

SELECT COUNT( DISTINCT OrderID ) FROM ods.ShipmentDelays

--3. 44

--4. CASE WHEN IsExpress = 1 THEN DATEADD(DAY, CASE WHEN Deadline > CAST(OrderCreatedAt AS DATE) THEN -1 ELSE 0 END , Deadline)

SELECT Category,
       100.0 * SUM(OnTime) / NULLIF(SUM(OnTime) + SUM(Delayed), 0) AS OnTimePct
FROM #FinalTable
GROUP BY Category
HAVING Category = 'Zajaczki'
--5. 82,75%