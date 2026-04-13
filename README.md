# 🚚 Order Shipping Timeliness Analysis – ODS Transformation (T‑SQL)

## 📌 Overview
This project implements an **Operational Data Store (ODS) transformation** in **T‑SQL** to analyze **order shipping timeliness** based on real business rules and Service Level Agreements (SLA).

The business problem originates from customer complaints about late deliveries. The objective was to replace assumptions with **data‑driven insight** by calculating shipping deadlines for each order and classifying orders as **OnTime**, **Delayed**, or **InProgress**.

The solution reflects a real‑world operational analytics scenario, where ODS acts both as a **transformation layer** and a **source for near‑real‑time reporting**.

---

## 📂 Data Sources (ODS Layer)

The project uses multiple ODS tables:

- **[ods].[Orders]**
  - `OrderCreatedAt` – exact order creation timestamp
  - `ActualShipDateKey` – actual shipment date (NULL = not shipped yet)
  - `IsExpress` – express shipment flag

- **[ods].[CustomerSLA]**
  - `MaxShipDays` – allowed shipping time per customer (1–3 days)
  - `SLA_Label` – Standard / Priority / Express‑Ready  
  - *Note: not every customer has an SLA assigned*

- **[ods].[ShipmentDelays]**
  - External shipment delays
  - `NewDeadlineDateKey` overrides calculated SLA deadline

- **[ods].[DimDate]**
  - Calendar dimension
  - Used for `IsWeekend` and `IsHoliday_PL` flags

- **[ods].[DimProduct]**
  - Product category analysis

---

## 🎯 Project Objective
- Calculate **shipping deadlines** per order based on SLA rules
- Adjust deadlines for:
  - Express shipments
  - Weekends and public holidays
  - External shipment delays
- Classify orders as:
  - **OnTime**
  - **Delayed**
  - **InProgress**
- Answer operational business questions regarding shipping performance

---

## 🛠 Methodology & Business Logic

### **Step 1 – Base SLA Deadline**
- Deadline = `OrderCreatedAt (DATE)` + `MaxShipDays`
- If customer has no SLA → default **3 days**

---

### **Step 2 – Express Shipments**
- If `IsExpress = 1`, deadline is shortened by **1 day**
- Deadline **cannot be earlier than order creation date**

---

### **Step 3 – Weekends & Holidays**
- If deadline falls on:
  - Sunday
  - Polish public holiday (`IsHoliday_PL = 1`)
- Deadline is moved to the **next working day**

---

### **Step 4 – External Deadline Overrides**
- If order exists in `[ods].[ShipmentDelays]`
- `NewDeadlineDateKey` **overrides calculated deadline**

---

### **Step 5 – Timeliness Flags**
Orders are classified as:
- **OnTime** – `ActualShipDateKey ≤ final deadline`
- **Delayed** – `ActualShipDateKey > final deadline`
- **InProgress** – `ActualShipDateKey IS NULL`

---

## 🧠 SQL Techniques Used
- Common Table Expressions (**CTEs**) for layered business logic
- Conditional logic (`CASE`, `IIF`, `COALESCE`)
- Date calculations and conversions
- Calendar‑based logic (weekends & holidays)
- Temporary tables for analytical queries
- Defensive handling of NULL values

---

## 📊 Business Questions Answered

1. **What percentage of orders in March 2026 were OnTime vs Delayed?**
   - ✅ **82.68% OnTime**
   - ❌ **17.32% Delayed**

2. **Which customer has the highest delay rate?**
   - Identified using delay percentage per customer

3. **How many orders were affected by external shipment delays?**
   - ✅ **44 orders**

4. **How is the edge case handled when SLA = 1 and IsExpress = 1?**
   - Deadline is never earlier than the order creation date

5. **On‑time performance by product category**
   - Example: **Category = “Zajaczki” → 82.75% OnTime**

---

## ✅ Final Output
- Fully transformed **ODS dataset** with:
  - Final deadlines
  - Timeliness classification flags
- Data ready for:
  - Operational reporting
  - Power BI consumption
  - Ongoing SLA monitoring

---

## 🧰 Tools & Technologies
- **T‑SQL**
- Operational Data Store (ODS)
- Calendar‑based data modeling
- SLA‑driven business logic
- Data quality handling

---

## 💡 Key Skills Demonstrated
- Advanced SQL for analytics  
- ODS transformation design  
- Business rule implementation  
- SLA‑based performance analysis  
- Handling real‑world edge cases  
- Translating business problems into SQL logic  

---

## 🎯 Why This Project Matters
This project demonstrates the ability to:
- Work with **operational data**, not just reporting layers
- Translate **business requirements** into SQL transformations
- Design reusable, readable, and scalable logic
- Deliver **real‑time operational insight** supporting decision‑making

It closely reflects the type of SQL and data logic used in day‑to‑day analytical and BI roles.

---
