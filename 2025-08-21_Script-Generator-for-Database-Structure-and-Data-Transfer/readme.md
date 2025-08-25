# Script Generator for Database Structure and Data Transfer

## 🔍 About the Project
This project was designed to **transfer database structures and data** between two environments of the same type (SQL Server ↔ SQL Server or Oracle ↔ Oracle).  
It helps with synchronizing development and production databases or preparing clean testing environments.

The main focus was to **automatically generate scripts** for database objects and data, based on object dependencies and defined rules.

> ⚠️ Note: Due to confidentiality, the full source code cannot be shared.  
> Instead, this repository provides documentation and a sample code snippet (dependency graph builder) to illustrate part of the implementation.

---

## ⚙️ Technologies Used
- **SQL Server side**  
  - T-SQL for core logic  
  - PowerShell for saving scripts  
  - SMO (SQL Server Management Objects) for object scripting  

- **Oracle side**  
  - PL/SQL for core logic  
  - PowerShell for file generation  
  - Oracle built-in functions to extract object definitions  

---

## 🧠 Challenges Addressed
- Building a **dependency graph** between objects (tables, views, packages, triggers, …).  
- Managing complex relations and schema matching.  
- Handling **large data types** like CLOB and BLOB in Oracle.  
- Respecting foreign key constraints and correct object ordering.  
- Supporting **batching** for large table data transfer.  

---

## 🔄 Process Workflow
1. **Preparation Phase** – create helper/configuration tables.  
2. **Dependency Analysis** – find object dependencies using system views, CTEs, and cursors.  
3. **Graph Building** – organize objects from independent to dependent.  
4. **Object Processing** – decide whether to `CREATE`, `ALTER`, or `INSERT`.  
5. **Constraint Handling** – disable FKs during inserts, re-enable afterward.  
6. **Oracle specifics** – handle packages, triggers, and sequences carefully.  

---

## 📥 Script Generation Details
- **SQL Server** – SMO was accurate but slower on large objects.  
- **Oracle** – Built-in functions were faster but less flexible.  
- **Large Tables** – INSERT scripts generated in small batches.  

---

## 🎯 Use Cases
- Synchronization between dev and prod  
- Versioning and deployment  
- Environment setup for QA, training, or testing  

---

## 🚀 Results
- Reduced manual effort in deployment and synchronization.  
- Improved speed and accuracy.  
- Provided a flexible base to extend with more features (data comparison, security, …).  

---

## 📌 Sample Code: Dependency Graph Builder

Below is a **simplified example** (PL/SQL) showing how the **dependency graph** was built for Oracle objects:

![Create dependency graph Script](./scripts/Filling-objects-graph.sql)


```sql
-- Sample: Build dependency graph for schema objects
```

- Gallery:
![To show parts of procejts](./images/Pic2.jpg")

-----------------------------------------------




























# Optimizing Query for Performance

## 1) Context
- Oracle Version/Edition: Oracle 19 
- Workload Type: OLTP
- Objects:  Table / Query / View / UDF
- Approx. Data Size: 800MB

---

## 2) Problem
- Symptom: long duration, excessive logical reads
- Baseline snapshot
  - Duration: 3.086s
  
- Example (Before Plan):
![Before Plan](./images/"Execute-Query_OLD-1.jpg")
![Before Plan](./images/Execute-Query_OLD-2.jpg)
![Before Plan](./images/Execute-Query_OLD-3.jpg)

---

## 3) Investigation
This view was very large and heavy, so I started analyzing the query structure.
After my review, I found that part of the query used a subquery which returned around 3,600,000 rows, and for some columns of these rows it was calling UDFs (User Defined Functions).
I began to optimize and rewrite the query structure by removing all extra columns that were not needed in the final output, and I also removed or reduced the usage of UDFs as much as possible.

---

## 4) Results
![Execution Time](./images/Execute-Query_New.jpg)

---

## 5) Results
- Duration: 0.385s

---

## 6) Performance Comparison
| Metric        | Before       | After   | Improvement |
|---------------|-------------:|--------:|------------:|
| Duration      | 3.086 s      | 0.385 s | 87.5%       |

---

## 7) Change Applied
- Query rewriting
- Removing unused columns
- Eliminating or reducing the frequency of UDF usage

---

## 8) Scripts Used
| Original Script (Before Optimization)               | New Script (After Optimization)                     |
|-----------------------------------------------------|----------------------------------------------------:|
| [View full Before Script](./scripts/Query_Old.sql)  | [View full After Script](./scripts/Query_New.sql)   |

---

## 9) Risks & Rollback
- Risks: For each subquery or UDF review, the output before and after optimization had to remain exactly the same.
It was also important to make sure that the results did not change in any other scenarios.

