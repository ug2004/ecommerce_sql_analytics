import psycopg2
from faker import Faker
import random
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv
import sys

# Load environment variables from .env file
load_dotenv()

# Initialize Faker
fake = Faker()

# Database connection using environment variables
def connect_db():
    try:
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=os.getenv('DB_PORT', '5432'),
            database=os.getenv('DB_NAME', 'ecommerce_db'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD')
        )
        return conn
    except Exception as e:
        print(f"Error connecting to database: {e}")
        print("Please check your .env file configuration")
        sys.exit(1)

def generate_categories(conn):
    """Generate categories"""
    cursor = conn.cursor()
    
    categories = [
        'Electronics', 'Clothing', 'Home & Garden', 'Sports',
        'Books', 'Toys', 'Health & Beauty', 'Automotive',
        'Food & Grocery', 'Pet Supplies'
    ]
    
    print("Creating categories...")
    for cat in categories:
        cursor.execute("""
            INSERT INTO categories (category_name, description)
            VALUES (%s, %s)
        """, (cat, fake.sentence()))
    
    conn.commit()
    print(f"[DONE] {len(categories)} categories created")
    
    cursor.execute("SELECT category_id FROM categories")
    return [row[0] for row in cursor.fetchall()]

def generate_suppliers(conn, count=30):
    """Generate suppliers"""
    cursor = conn.cursor()
    print(f"Creating {count} suppliers...")
    
    for _ in range(count):
        cursor.execute("""
            INSERT INTO suppliers (supplier_name, country, contact_email, rating, active)
            VALUES (%s, %s, %s, %s, %s)
        """, (
            fake.company(),
            fake.country(),
            fake.company_email(),
            round(random.uniform(3.5, 5.0), 2),
            True
        ))
    
    conn.commit()
    print(f"[DONE] {count} suppliers created")
    
    cursor.execute("SELECT supplier_id FROM suppliers")
    return [row[0] for row in cursor.fetchall()]

def generate_products(conn, category_ids, supplier_ids, count=300):
    """Generate products"""
    cursor = conn.cursor()
    print(f"Creating {count} products...")
    
    adjectives = ['Premium', 'Ultra', 'Pro', 'Classic', 'Smart', 'Eco', 'Deluxe']
    nouns = ['Widget', 'Gadget', 'Device', 'Tool', 'Kit', 'Set', 'System']
    
    for i in range(count):
        cost = round(random.uniform(10, 300), 2)
        price = round(cost * random.uniform(1.5, 3.0), 2)
        
        cursor.execute("""
            INSERT INTO products (product_name, category_id, supplier_id, price, cost, 
                                sku, description, active)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            f"{random.choice(adjectives)} {random.choice(nouns)} {i+1}",
            random.choice(category_ids),
            random.choice(supplier_ids),
            price,
            cost,
            f"SKU-{fake.bothify(text='????-####')}",
            fake.sentence(),
            True
        ))
        
        if (i + 1) % 50 == 0:
            print(f"  Progress: {i + 1}/{count} products...")
    
    conn.commit()
    print(f"[DONE] {count} products created")
    
    cursor.execute("SELECT product_id FROM products")
    return [row[0] for row in cursor.fetchall()]

def generate_warehouses(conn, count=5):
    """Generate warehouses"""
    cursor = conn.cursor()
    print(f"Creating {count} warehouses...")
    
    for _ in range(count):
        cursor.execute("""
            INSERT INTO warehouses (warehouse_name, country, city, active)
            VALUES (%s, %s, %s, %s)
        """, (
            f"{fake.city()} Distribution Center",
            fake.country(),
            fake.city(),
            True
        ))
    
    conn.commit()
    print(f"[DONE] {count} warehouses created")
    
    cursor.execute("SELECT warehouse_id FROM warehouses")
    return [row[0] for row in cursor.fetchall()]

def generate_inventory(conn, product_ids, warehouse_ids):
    """Generate inventory"""
    cursor = conn.cursor()
    print("Creating inventory records...")
    
    count = 0
    for product_id in product_ids:
        # Each product in 1-2 warehouses
        num_wh = random.randint(1, 2)
        selected_wh = random.sample(warehouse_ids, min(num_wh, len(warehouse_ids)))
        
        for warehouse_id in selected_wh:
            cursor.execute("""
                INSERT INTO inventory (product_id, warehouse_id, stock_quantity, 
                                     reorder_level, last_restocked_date)
                VALUES (%s, %s, %s, %s, %s)
            """, (
                product_id,
                warehouse_id,
                random.randint(0, 500),
                random.randint(10, 50),
                fake.date_between(start_date='-6m', end_date='today')
            ))
            count += 1
    
    conn.commit()
    print(f"[DONE] {count} inventory records created")

def generate_customers(conn, count=3000):
    """Generate customers"""
    cursor = conn.cursor()
    print(f"Creating {count} customers...")
    
    for i in range(count):
        cursor.execute("""
            INSERT INTO customers (first_name, last_name, email, phone, country, 
                                 city, registration_date, segment)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            fake.first_name(),
            fake.last_name(),
            fake.unique.email(),
            fake.phone_number(),
            fake.country(),
            fake.city(),
            fake.date_between(start_date='-3y', end_date='today'),
            'New'
        ))
        
        if (i + 1) % 500 == 0:
            print(f"  Progress: {i + 1}/{count} customers...")
    
    conn.commit()
    print(f"[DONE] {count} customers created")
    
    cursor.execute("SELECT customer_id FROM customers")
    return [row[0] for row in cursor.fetchall()]

def generate_orders(conn, customer_ids, product_ids, count=5000):
    """Generate orders with items"""
    cursor = conn.cursor()
    print(f"Creating {count} orders...")
    
    statuses = ['Delivered', 'Delivered', 'Delivered', 'Shipped', 'Processing']
    payment_methods = ['Credit Card', 'Debit Card', 'PayPal']
    
    for i in range(count):
        customer_id = random.choice(customer_ids)
        order_date = fake.date_time_between(start_date='-1y', end_date='now')
        status = random.choice(statuses)
        
        # Shipping and delivery dates
        shipping_date = None
        delivery_date = None
        if status in ['Shipped', 'Delivered']:
            shipping_date = order_date + timedelta(days=random.randint(1, 3))
        if status == 'Delivered':
            delivery_date = shipping_date + timedelta(days=random.randint(2, 7))
        
        discount = float(round(random.uniform(0, 30), 2)) if random.random() < 0.2 else 0.0
        shipping = float(round(random.uniform(5, 20), 2))
        
        # Insert order (temporary total)
        cursor.execute("""
            INSERT INTO orders (customer_id, order_date, status, total_amount, 
                              discount_amount, shipping_cost, payment_method, 
                              shipping_date, delivery_date)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING order_id
        """, (
            customer_id, order_date, status, 0.0,
            discount, shipping, random.choice(payment_methods),
            shipping_date, delivery_date
        ))
        order_id = cursor.fetchone()[0]
        
        # Add 1-4 items to order
        num_items = random.randint(1, 4)
        subtotal = 0.0
        
        selected_products = random.sample(product_ids, min(num_items, len(product_ids)))
        
        for product_id in selected_products:
            cursor.execute("SELECT price FROM products WHERE product_id = %s", (product_id,))
            result = cursor.fetchone()
            unit_price = float(result[0])
            
            quantity = random.randint(1, 3)
            disc_pct = float(round(random.uniform(0, 20), 2)) if random.random() < 0.15 else 0.0
            line_total = float(round(unit_price * quantity * (1 - disc_pct/100), 2))
            subtotal += line_total
            
            cursor.execute("""
                INSERT INTO order_items (order_id, product_id, quantity, unit_price, 
                                       discount_percent, line_total)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (order_id, product_id, quantity, unit_price, disc_pct, line_total))
        
        # Update order total
        total = float(round(subtotal + shipping - discount, 2))
        cursor.execute("""
            UPDATE orders SET total_amount = %s WHERE order_id = %s
        """, (total, order_id))
        
        if (i + 1) % 500 == 0:
            conn.commit()
            print(f"  {i + 1}/{count} orders...")
    
    conn.commit()
    print(f"✓ {count} orders created")
    
def generate_reviews(conn, customer_ids, product_ids, count=1500):
    """Generate reviews"""
    cursor = conn.cursor()
    print(f"Creating {count} reviews...")
    
    for i in range(count):
        cursor.execute("""
            INSERT INTO reviews (product_id, customer_id, rating, review_title, 
                               review_text, review_date, verified_purchase)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            random.choice(product_ids),
            random.choice(customer_ids),
            random.randint(1, 5),
            fake.sentence(nb_words=5),
            fake.paragraph() if random.random() < 0.6 else None,
            fake.date_time_between(start_date='-1y', end_date='now'),
            random.choice([True, False])
        ))
        
        if (i + 1) % 300 == 0:
            print(f"  Progress: {i + 1}/{count} reviews...")
    
    conn.commit()
    print(f"[DONE] {count} reviews created")

def generate_tickets(conn, customer_ids, count=500):
    """Generate support tickets"""
    cursor = conn.cursor()
    print(f"Creating {count} support tickets...")
    
    issue_types = ['Product Issue', 'Shipping Delay', 'Payment Issue', 'Return Request']
    priorities = ['Low', 'Medium', 'High']
    statuses = ['Open', 'In Progress', 'Resolved', 'Closed']
    
    for i in range(count):
        created = fake.date_time_between(start_date='-6m', end_date='now')
        status = random.choice(statuses)
        resolved = None
        
        if status in ['Resolved', 'Closed']:
            resolved = created + timedelta(days=random.randint(1, 10))
        
        cursor.execute("""
            INSERT INTO customer_support_tickets (customer_id, issue_type, priority, 
                                                 status, description, created_date, resolved_date)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            random.choice(customer_ids),
            random.choice(issue_types),
            random.choice(priorities),
            status,
            fake.paragraph(),
            created,
            resolved
        ))
        
        if (i + 1) % 100 == 0:
            print(f"  Progress: {i + 1}/{count} tickets...")
    
    conn.commit()
    print(f"[DONE] {count} tickets created")

def main():
    print("=" * 60)
    print("E-COMMERCE DATABASE - DATA GENERATION")
    print("=" * 60)
    print()
    
    conn = connect_db()
    print("[SUCCESS] Connected to database")
    print()
    
    try:
        category_ids = generate_categories(conn)
        supplier_ids = generate_suppliers(conn)
        product_ids = generate_products(conn, category_ids, supplier_ids)
        warehouse_ids = generate_warehouses(conn)
        generate_inventory(conn, product_ids, warehouse_ids)
        customer_ids = generate_customers(conn)
        generate_orders(conn, customer_ids, product_ids)
        generate_reviews(conn, customer_ids, product_ids)
        generate_tickets(conn, customer_ids)
        
        print()
        print("=" * 60)
        print("[SUCCESS] DATA GENERATION COMPLETE!")
        print("=" * 60)
        
    except Exception as e:
        print(f"[ERROR] {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    main()
