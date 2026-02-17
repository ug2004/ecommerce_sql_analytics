# E-Commerce SQL Analytics Project

Comprehensive SQL project demonstrating advanced database design, complex queries, and business analytics.

## Tech Stack
- PostgreSQL 16
- Python 3.12
- Power BI
- Tableau

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
