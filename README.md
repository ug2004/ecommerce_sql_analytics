# E-Commerce SQL Analytics Project

Comprehensive SQL project demonstrating advanced database design, complex queries, and business analytics.

## Tech Stack
- PostgreSQL 16
- Python 3.12
- Power BI

## Setup Instructions

### 1. Clone Repository
```bash
git clone https://github.com/ug2004/ecommerce-sql-analytics.git
cd ecommerce-sql-analytics
```

### 2. Set Up Virtual Environment
```bash
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

### 3. Configure Database
```bash
# Copy environment template
copy .env.example .env

# Edit .env with your PostgreSQL credentials
```

### 4. Create Database Schema
```bash
psql -U postgres -d ecommerce_db -f schema/01_create_tables.sql
psql -U postgres -d ecommerce_db -f schema/02_create_indexes.sql
```

### 5. Generate Sample Data
```bash
python data/generate_data.py
```

## Project Structure
```
ecommerce-sql-analytics/
├── schema/              # Database DDL scripts
├── data/               # Data generation scripts
├── queries/            # Analytical SQL queries
├── optimization/       # Performance tuning
├── procedures/         # Stored procedures & functions
├── documentation/      # ERD diagrams & docs
└── requirements.txt    # Python dependencies
```

## Features
- Normalized database design (3NF)
- 10+ tables with complex relationships
- 30+ analytical queries
- Performance optimization
- Business intelligence dashboards

## Project Overview

This project simulates a real-world e-commerce analytics platform, handling data for **5,000+ orders**, **3,000+ customers**, and **300+ products** across multiple warehouses. The goal is to >

### Business Problems Solved:
- **Revenue Analysis**: Track sales trends, identify growth opportunities
- **Customer Segmentation**: RFM analysis for targeted marketing
- **Inventory Management**: Optimize stock levels, reduce dead stock
- **Profitability Tracking**: Product and category-level profit margins
- **Churn Prediction**: Identify at-risk customers

---

## Key Features

### Database & SQL
-  **Normalized database design** (3NF) with 10 interconnected tables
-  **40+ complex SQL queries** using CTEs, window functions, recursive queries
-  **5 stored procedures** for automated reporting and segmentation
-  **6 user-defined functions** for calculations and business logic
-  **6 triggers** for real-time data validation and inventory updates
-  **5 optimized views** for common business queries
-  **Comprehensive indexing** strategy for query performance

### Analytics & Insights
-  **Customer Lifetime Value (CLV)** calculation
-  **RFM Analysis** for customer segmentation
-  **Cohort retention analysis** tracking customer behavior over time
-  **Product affinity analysis** (market basket)
-  **Inventory turnover rate** and stock coverage analysis
-  **Time series analysis** with moving averages
-  **Churn prediction indicators**
