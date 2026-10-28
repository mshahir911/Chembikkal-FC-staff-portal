# Chembikkal Food Court (CFC) - Supabase Database Schema

This document details every table utilized by the Chembikkal Food Court POS and Delivery applications, including column definitions, data types, nullability, constraints, purpose, DDL `CREATE TABLE` statements, and example rows.

---

## Table of Contents
1. [Core Tables & Enums](#core-enums)
2. [public.profiles](#1-publicprofiles)
3. [public.shops](#2-publicshops)
4. [public.products](#3-publicproducts)
5. [public.dining_tables](#4-publicdining_tables)
6. [public.table_sessions](#5-publictable_sessions)
7. [public.table_session_tables](#6-publictable_session_tables)
8. [public.table_activity_logs](#7-publictable_activity_logs)
9. [public.orders](#8-publicorders)
10. [public.order_items](#9-publicorder_items)
11. [public.bills](#10-publicbills)
12. [public.bill_versions](#11-publicbill_versions)
13. [public.bill_items](#12-publicbill_items)
14. [public.payments](#13-publicpayments)
15. [public.void_refund_requests](#14-publicvoid_refund_requests)
16. [public.customers](#15-publiccustomers)

---

## Core Enums

```sql
CREATE TYPE order_type_enum AS ENUM ('DINE_IN', 'TAKE_AWAY', 'DELIVERY');
CREATE TYPE order_status_enum AS ENUM ('OPEN', 'IN_PROGRESS', 'READY', 'COMPLETED', 'CANCELLED', 'PRINTED');
CREATE TYPE table_status_enum AS ENUM ('AVAILABLE', 'OCCUPIED', 'MERGED', 'RESERVED');
CREATE TYPE session_status_enum AS ENUM ('OPEN', 'CLOSED', 'MERGED', 'CANCELLED');
CREATE TYPE payment_method_enum AS ENUM ('CASH', 'UPI', 'CARD', 'OTHER');
CREATE TYPE user_role_enum AS ENUM ('ADMIN', 'CASHIER', 'KITCHEN');
```

---

## 1. `public.profiles`
**Purpose**: Stores staff member profile data linked directly to Supabase `auth.users` for role-based authentication and permissions.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | - | Primary key referencing `auth.users(id)`. |
| `full_name` | `TEXT` | **NO** | - | Full name of the staff member or manager. |
| `role` | `user_role_enum` | **NO** | `'CASHIER'` | Access tier: `'ADMIN'`, `'CASHIER'`, or `'KITCHEN'`. |
| `phone` | `TEXT` | YES | `NULL` | Contact phone number of the employee. |
| `is_active` | `BOOLEAN` | **NO** | `true` | Whether the user account is enabled for login. |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp when profile was created. |
| `updated_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp of last profile update. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role user_role_enum NOT NULL DEFAULT 'CASHIER',
    phone TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | full_name | role | phone | is_active | created_at | updated_at |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `a0000000-0000-0000-0000-000000000001` | Muhammed Shahir | ADMIN | +919876543210 | true | 2026-09-01 10:00:00+00 | 2026-09-01 10:00:00+00 |
| `a0000000-0000-0000-0000-000000000002` | Rahul Cashier | CASHIER | +919876543211 | true | 2026-09-05 08:30:00+00 | 2026-09-05 08:30:00+00 |
| `a0000000-0000-0000-0000-000000000003` | Chef Anwar | KITCHEN | +919876543212 | true | 2026-09-10 11:15:00+00 | 2026-09-10 11:15:00+00 |

---

## 2. `public.shops`
**Purpose**: Represents the individual food stalls/kitchens operating within the unified Chembikkal Food Court.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique identifier for the food stall/shop. |
| `name` | `TEXT` | **NO** | - | Display name of the shop (e.g. "Shop 1 - Biriyani & Meals"). |
| `code` | `TEXT` | **NO** (UNIQUE) | - | Short identifier code (e.g. `'SHOP-1'`, `'SHOP-2'`). |
| `description` | `TEXT` | YES | `NULL` | Overview of cuisine and specialty offerings. |
| `status` | `TEXT` | **NO** | `'ACTIVE'` | Operational status (`'ACTIVE'` or `'INACTIVE'`). |
| `display_order` | `INT` | **NO** | `1` | Ordering index for UI tab display. |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp when the shop record was registered. |
| `updated_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp of last shop configuration change. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    display_order INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | name | code | description | status | display_order | created_at |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `11111111-1111-1111-1111-111111111101` | Thejaj | THEJAJ | Authentic Shawarma & Shawaya Specialists | ACTIVE | 1 | 2026-09-01 00:00:00+00 |
| `11111111-1111-1111-1111-111111111102` | Fruvia | FRUVIA | Fresh Juices, Coolers & Thick Shakes | ACTIVE | 2 | 2026-09-01 00:00:00+00 |
| `11111111-1111-1111-1111-111111111103` | Chai Latte | CHAI-LATTE | Freshly Brewed Tea, Coffee & Hot Evening Snacks | ACTIVE | 3 | 2026-09-01 00:00:00+00 |
| `11111111-1111-1111-1111-111111111104` | Smoochos | SMOOCHOS | Kunafa Bowls, Flavour Storm Cakes, Signature Desserts & Milk Specials | ACTIVE | 4 | 2026-09-01 00:00:00+00 |
| `11111111-1111-1111-1111-111111111105` | Shop 5 (Legacy) | SHOP-5 | Archived Shop 5 | INACTIVE | 99 | 2026-09-01 00:00:00+00 |

---

## 3. `public.products`
**Purpose**: Catalog of menu items assigned to a specific shop, storing active prices, categories, and availability.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique identifier for the menu product. |
| `shop_id` | `UUID` | **NO** (FK) | - | References `shops(id)` that produces this item. |
| `name` | `TEXT` | **NO** | - | Name of the food item or drink (e.g. "Chicken Biriyani"). |
| `description` | `TEXT` | YES | `NULL` | Ingredients and description of the preparation. |
| `category` | `TEXT` | YES | `'General'` | Filter tag (e.g. `'Biriyani'`, `'Breads'`, `'Beverages'`). |
| `price` | `NUMERIC(10,2)` | **NO** | - | Current selling price in INR (must be >= 0). |
| `sku` | `TEXT` | YES | `NULL` | Stock Keeping Unit code (e.g. `'SKU-SH1-001'`). |
| `image_url` | `TEXT` | YES | `NULL` | URL path to product photo. |
| `is_active` | `BOOLEAN` | **NO** | `true` | Toggles item visibility in the POS menu. |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp when product was created. |
| `updated_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp of last price/info update. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'General',
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    sku TEXT,
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | shop_id | name | category | price | sku | is_active |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `22222222-2222-2222-2222-222222222201` | `11111111-1111-1111-1111-111111111101` | Normal Roll Shawarma | Shawarma | 100.00 | SKU-THJ-001 | true |
| `22222222-2222-2222-2222-222222222202` | `11111111-1111-1111-1111-111111111102` | Mango Shake | Shakes | 110.00 | SKU-FRU-020 | true |
| `22222222-2222-2222-2222-222222222203` | `11111111-1111-1111-1111-111111111103` | Tea | Hot Drinks | 15.00 | SKU-CHL-001 | true |
| `22222222-2222-2222-2222-222222222204` | `11111111-1111-1111-1111-111111111104` | Pista Biscoff Kunafa | Kunafa Bowls | 279.00 | SKU-SMO-003 | true |

---

## 4. `public.dining_tables`
**Purpose**: Physical table inventory for the dine-in area, tracking capacity and current occupancy status.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique identifier for the dining table. |
| `table_number` | `INT` | **NO** (UNIQUE) | - | Table sequence number (e.g. `1`, `2`, `3`). |
| `table_name` | `TEXT` | **NO** | - | Display label (e.g. `'Table 1'`). |
| `capacity` | `INT` | **NO** | `4` | Max seating capacity (must be > 0). |
| `status` | `table_status_enum` | **NO** | `'AVAILABLE'` | `'AVAILABLE'`, `'OCCUPIED'`, `'MERGED'`, or `'RESERVED'`. |
| `is_active` | `BOOLEAN` | **NO** | `true` | Whether this table is in active service. |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp when table was registered. |
| `updated_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp when table status was last modified. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.dining_tables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_number INT NOT NULL UNIQUE,
    table_name TEXT NOT NULL,
    capacity INT NOT NULL DEFAULT 4 CHECK (capacity > 0),
    status table_status_enum NOT NULL DEFAULT 'AVAILABLE',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | table_number | table_name | capacity | status | is_active | created_at |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `33333333-3333-3333-3333-333333333301` | 1 | Table 1 | 2 | AVAILABLE | true | 2026-09-01 00:00:00+00 |
| `33333333-3333-3333-3333-333333333302` | 2 | Table 2 | 4 | OCCUPIED | true | 2026-09-01 00:00:00+00 |
| `33333333-3333-3333-3333-333333333304` | 4 | Table 4 | 6 | MERGED | true | 2026-09-01 00:00:00+00 |

---

## 5. `public.table_sessions`
**Purpose**: Manages a customer group's seating lifecycle (supports merging multiple tables into one party).

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique identifier for the dining session. |
| `session_number` | `TEXT` | **NO** (UNIQUE) | - | Human-readable code (e.g. `'SESS-20260926-0012'`). |
| `status` | `session_status_enum` | **NO** | `'OPEN'` | `'OPEN'`, `'CLOSED'`, `'MERGED'`, or `'CANCELLED'`. |
| `guest_count` | `INT` | YES | `1` | Number of seated guests. |
| `started_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp when guests were seated. |
| `closed_at` | `TIMESTAMPTZ` | YES | `NULL` | Timestamp when session ended and table cleared. |
| `created_by` | `UUID` | YES | `NULL` | References `auth.users(id)` of waiter/cashier. |
| `notes` | `TEXT` | YES | `NULL` | Special guest requests or seating notes. |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Record creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | **NO** | `now()` | Last session update timestamp. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.table_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_number TEXT NOT NULL UNIQUE,
    status session_status_enum NOT NULL DEFAULT 'OPEN',
    guest_count INT DEFAULT 1,
    started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    closed_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | session_number | status | guest_count | started_at | closed_at | notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `44444444-4444-4444-4444-444444444401` | SESS-20260926-0001 | CLOSED | 2 | 2026-09-26 12:15:00+00 | 2026-09-26 13:00:00+00 | Regular dine-in |
| `44444444-4444-4444-4444-444444444402` | SESS-20260926-0002 | OPEN | 5 | 2026-09-26 13:30:00+00 | NULL | High chair needed |
| `44444444-4444-4444-4444-444444444403` | SESS-20260926-0003 | OPEN | 8 | 2026-09-26 14:00:00+00 | NULL | Merged Table 4 & 5 |

---

## 6. `public.table_session_tables`
**Purpose**: Junction table mapping one or more dining tables to a table session (enables table merging).

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Primary key for the session-table mapping. |
| `session_id` | `UUID` | **NO** (FK) | - | References `table_sessions(id)`. |
| `table_id` | `UUID` | **NO** (FK) | - | References `dining_tables(id)`. |
| `joined_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp when table joined the session. |
| `left_at` | `TIMESTAMPTZ` | YES | `NULL` | Timestamp when table was unmerged or released. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.table_session_tables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.table_sessions(id) ON DELETE CASCADE,
    table_id UUID NOT NULL REFERENCES public.dining_tables(id) ON DELETE RESTRICT,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    left_at TIMESTAMPTZ,
    CONSTRAINT unique_active_session_table UNIQUE (session_id, table_id)
);
```

### Example Rows
| id | session_id | table_id | joined_at | left_at |
| :--- | :--- | :--- | :--- | :--- |
| `55555555-5555-5555-5555-555555555501` | `44444444-4444-4444-4444-444444444402` | `33333333-3333-3333-3333-333333333302` | 2026-09-26 13:30:00+00 | NULL |
| `55555555-5555-5555-5555-555555555502` | `44444444-4444-4444-4444-444444444403` | `33333333-3333-3333-3333-333333333304` | 2026-09-26 14:00:00+00 | NULL |
| `55555555-5555-5555-5555-555555555503` | `44444444-4444-4444-4444-444444444403` | `33333333-3333-3333-3333-333333333301` | 2026-09-26 14:00:00+00 | NULL |

---

## 7. `public.table_activity_logs`
**Purpose**: Audit log recording table operations (merging, unmerging, transferring tables, session releases).

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Primary key for audit log entry. |
| `action_type` | `TEXT` | **NO** | - | Operation: `'MERGE'`, `'UNMERGE'`, `'TRANSFER'`, `'RELEASE'`. |
| `session_id` | `UUID` | YES (FK) | `NULL` | Associated session from `table_sessions(id)`. |
| `primary_table_id` | `UUID` | YES (FK) | `NULL` | Main target table from `dining_tables(id)`. |
| `secondary_table_id` | `UUID` | YES (FK) | `NULL` | Secondary table joined during a merge. |
| `details` | `JSONB` | YES | `'{}'` | Context metadata (guest count, reasons). |
| `performed_by` | `UUID` | YES (FK) | `NULL` | User who performed action (`auth.users(id)`). |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp when operation occurred. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.table_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action_type TEXT NOT NULL CHECK (action_type IN ('MERGE', 'UNMERGE', 'TRANSFER', 'RELEASE')),
    session_id UUID REFERENCES public.table_sessions(id) ON DELETE SET NULL,
    primary_table_id UUID REFERENCES public.dining_tables(id) ON DELETE SET NULL,
    secondary_table_id UUID REFERENCES public.dining_tables(id) ON DELETE SET NULL,
    details JSONB DEFAULT '{}'::jsonb,
    performed_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | action_type | session_id | primary_table_id | secondary_table_id | details | created_at |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `66666666-6666-6666-6666-666666666601` | MERGE | `44444444-4444-4444-4444-444444444403` | `33333333-3333-3333-3333-333333333304` | `33333333-3333-3333-3333-333333333301` | `{"reason": "Big family"}` | 2026-09-26 14:00:00+00 |
| `66666666-6666-6666-6666-666666666602` | RELEASE | `44444444-4444-4444-4444-444444444401` | `33333333-3333-3333-3333-333333333302` | NULL | `{"reason": "Bill paid"}` | 2026-09-26 13:00:00+00 |

---

## 8. `public.orders`
**Purpose**: Central order entity handling Dine-In, Walkin, Parcel, and Delivery orders with customer details.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique identifier for the order. |
| `order_number` | `TEXT` | **NO** (UNIQUE) | - | Formatted sequence code (e.g. `'ORD-0037'`). |
| `order_type` | `order_type_enum` | **NO** | - | `'DINE_IN'`, `'TAKE_AWAY'`, or `'DELIVERY'`. |
| `status` | `order_status_enum` | **NO** | `'OPEN'` | `'OPEN'`, `'IN_PROGRESS'`, `'READY'`, `'PRINTED'`, `'COMPLETED'`, `'CANCELLED'`. |
| `table_session_id` | `UUID` | YES (FK) | `NULL` | Links to `table_sessions(id)` (Dine-in only). |
| `customer_name` | `TEXT` | YES | `NULL` | Name of the customer placing order. |
| `customer_phone` | `TEXT` | YES | `NULL` | Phone number for contact / WhatsApp. |
| `delivery_address` | `TEXT` | YES | `NULL` | House/street delivery address for doorstep handover. |
| `delivery_notes` | `TEXT` | YES | `NULL` | Delivery landmarks, parcel charges `[PARCEL:20.0]`, or `[DELIVERED]` tags. |
| `subtotal` | `NUMERIC(10,2)` | **NO** | `0.00` | Sum of item totals before discounts/taxes. |
| `discount` | `NUMERIC(10,2)` | **NO** | `0.00` | Discount applied to the order. |
| `tax` | `NUMERIC(10,2)` | **NO** | `0.00` | Tax applied to the order. |
| `total_amount` | `NUMERIC(10,2)` | **NO** | `0.00` | Final payable total. |
| `created_by` | `UUID` | YES (FK) | `NULL` | References `auth.users(id)` of order taker. |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Order placement timestamp. |
| `updated_at` | `TIMESTAMPTZ` | **NO** | `now()` | Last modification timestamp. |
| `completed_at` | `TIMESTAMPTZ` | YES | `NULL` | Timestamp when order was finalized / delivered. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT NOT NULL UNIQUE,
    order_type order_type_enum NOT NULL,
    status order_status_enum NOT NULL DEFAULT 'OPEN',
    table_session_id UUID REFERENCES public.table_sessions(id) ON DELETE SET NULL,
    customer_name TEXT,
    customer_phone TEXT,
    delivery_address TEXT,
    delivery_notes TEXT,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0),
    discount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    tax NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (tax >= 0),
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ
);
```

### Example Rows
| id | order_number | order_type | status | customer_name | customer_phone | delivery_address | total_amount |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `77777777-7777-7777-7777-777777777701` | ORD-0035 | DINE_IN | COMPLETED | Ali | 9847123456 | NULL | 320.00 |
| `77777777-7777-7777-7777-777777777702` | ORD-0036 | TAKE_AWAY | COMPLETED | Naufal | 9847654321 | NULL | 150.00 |
| `77777777-7777-7777-7777-777777777703` | ORD-0037 | DELIVERY | PRINTED | Shah | 9745123987 | Flat 4B, Emerald Heights, Chembikkal | 290.00 |

---

## 9. `public.order_items`
**Purpose**: Stores individual items inside an order, retaining historical sale price and shop ownership.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Primary key for the item entry. |
| `order_id` | `UUID` | **NO** (FK) | - | References `orders(id)` parent record. |
| `shop_id` | `UUID` | **NO** (FK) | - | References `shops(id)` that cooked/prepared the item. |
| `product_id` | `UUID` | YES (FK) | `NULL` | References `products(id)` (retains name if product deleted). |
| `product_name` | `TEXT` | **NO** | - | Historical snapshot of product title at order time. |
| `quantity` | `INT` | **NO** | - | Units ordered (must be > 0). |
| `unit_price` | `NUMERIC(10,2)` | **NO** | - | Price per unit at purchase time. |
| `subtotal` | `NUMERIC(10,2)` | **NO** | - | Line subtotal (`quantity * unit_price`). |
| `notes` | `TEXT` | YES | `NULL` | Kitchen instructions (e.g. "Less spice", "No ice"). |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Item addition timestamp. |
| `updated_at` | `TIMESTAMPTZ` | **NO** | `now()` | Last modification timestamp. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE RESTRICT,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | order_id | shop_id | product_name | quantity | unit_price | subtotal |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `88888888-8888-8888-8888-888888888801` | `77777777-7777-7777-7777-777777777703` | `11111111-1111-1111-1111-111111111101` | Chicken Biriyani | 1 | 150.00 | 150.00 |
| `88888888-8888-8888-8888-888888888802` | `77777777-7777-7777-7777-777777777703` | `11111111-1111-1111-1111-111111111101` | Chicken Roast | 1 | 140.00 | 140.00 |
| `88888888-8888-8888-8888-888888888803` | `77777777-7777-7777-7777-777777777701` | `11111111-1111-1111-1111-111111111102` | Special Masala Chai | 2 | 20.00 | 40.00 |

---

## 10. `public.bills`
**Purpose**: Official customer invoice managing versions, paid amounts, payment status, and printing state.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique identifier for the bill. |
| `bill_number` | `TEXT` | **NO** (UNIQUE) | - | Invoice sequence (e.g. `'BILL-20260926-0037'`). |
| `order_id` | `UUID` | **NO** (UNIQUE, FK) | - | References `orders(id)` parent record. |
| `subtotal` | `NUMERIC(10,2)` | **NO** | `0.00` | Subtotal amount of bill items. |
| `discount` | `NUMERIC(10,2)` | **NO** | `0.00` | Total bill discount applied. |
| `tax` | `NUMERIC(10,2)` | **NO** | `0.00` | Total tax applied. |
| `total_amount` | `NUMERIC(10,2)` | **NO** | - | Net payable amount. |
| `paid_amount` | `NUMERIC(10,2)` | **NO** | `0.00` | Cumulative amount paid by customer. |
| `current_version` | `INT` | **NO** | `1` | Incrementing version number of printed snapshots. |
| `status` | `TEXT` | **NO** | `'PRINTED'` | `'PRINTED'`, `'UNPAID'`, `'PARTIALLY_PAID'`, `'PAID'`, `'VOID_PENDING'`, `'CANCELLED'`, `'REFUNDED'`. |
| `payment_method` | `TEXT` | YES | `NULL` | Summary method: `'CASH'`, `'GPAY'`, `'SPLIT'`, etc. |
| `payment_status` | `TEXT` | **NO** | `'UNPAID'` | Payment condition: `'UNPAID'`, `'PAID'`, `'REFUNDED'`. |
| `created_by` | `UUID` | YES (FK) | `NULL` | Cashier who initiated billing (`auth.users(id)`). |
| `printed_at` | `TIMESTAMPTZ` | YES | `now()` | Timestamp of last physical bill print. |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Invoice creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | YES | `now()` | Last payment/status change timestamp. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_number TEXT NOT NULL UNIQUE,
    order_id UUID NOT NULL UNIQUE REFERENCES public.orders(id) ON DELETE RESTRICT,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0),
    discount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    tax NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (tax >= 0),
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    paid_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    current_version INT NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'PRINTED' 
        CHECK (status IN ('PRINTED', 'UNPAID', 'PARTIALLY_PAID', 'PAID', 'VOID_PENDING', 'CANCELLED', 'REFUND_PENDING', 'REFUNDED')),
    payment_method TEXT,
    payment_status TEXT NOT NULL DEFAULT 'UNPAID',
    created_by UUID REFERENCES auth.users(id),
    printed_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | bill_number | order_id | total_amount | paid_amount | status | payment_method | payment_status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `99999999-9999-9999-9999-999999999901` | BILL-20260926-0035 | `77777777-7777-7777-7777-777777777701` | 320.00 | 320.00 | PAID | CASH | PAID |
| `99999999-9999-9999-9999-999999999902` | BILL-20260926-0036 | `77777777-7777-7777-7777-777777777702` | 150.00 | 150.00 | PAID | GPAY | PAID |
| `99999999-9999-9999-9999-999999999903` | BILL-20260926-0037 | `77777777-7777-7777-7777-777777777703` | 290.00 | 0.00 | UNPAID | PENDING | UNPAID |

---

## 11. `public.bill_versions`
**Purpose**: Immutable historical snapshots created every time a bill is printed or reprinted (for audit/tax compliance).

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique identifier for version snapshot. |
| `bill_id` | `UUID` | **NO** (FK) | - | References `bills(id)` parent invoice. |
| `version_number` | `INT` | **NO** | - | Version index (`1`, `2`, etc.). |
| `subtotal` | `NUMERIC(10,2)` | **NO** | `0.00` | Subtotal at print moment. |
| `discount` | `NUMERIC(10,2)` | **NO** | `0.00` | Discount at print moment. |
| `tax` | `NUMERIC(10,2)` | **NO** | `0.00` | Tax at print moment. |
| `total_amount` | `NUMERIC(10,2)` | **NO** | - | Total payable printed on the bill. |
| `print_reason` | `TEXT` | YES | `NULL` | Reason (e.g. `'Initial Print'`, `'Items Added'`). |
| `created_by` | `UUID` | YES (FK) | `NULL` | User who generated printout (`auth.users(id)`). |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp of this print version. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.bill_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0),
    discount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    tax NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (tax >= 0),
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    print_reason TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE (bill_id, version_number)
);
```

### Example Rows
| id | bill_id | version_number | total_amount | print_reason | created_at |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1` | `99999999-9999-9999-9999-999999999901` | 1 | 320.00 | Initial Print | 2026-09-26 12:45:00+00 |
| `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2` | `99999999-9999-9999-9999-999999999903` | 1 | 290.00 | Initial Print | 2026-09-26 15:10:00+00 |

---

## 12. `public.bill_items`
**Purpose**: Immutable item snapshots for each bill version, guaranteeing shop revenue reporting even if items change later.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Primary key of bill item record. |
| `bill_id` | `UUID` | **NO** (FK) | - | References `bills(id)`. |
| `bill_version_id` | `UUID` | YES (FK) | `NULL` | References `bill_versions(id)`. |
| `shop_id` | `UUID` | **NO** (FK) | - | References `shops(id)` for payout revenue attribution. |
| `product_id` | `UUID` | YES (FK) | `NULL` | References original `products(id)`. |
| `product_name` | `TEXT` | **NO** | - | Product title on the printed bill. |
| `quantity` | `INT` | **NO** | - | Quantity billed (must be > 0). |
| `unit_price` | `NUMERIC(10,2)` | **NO** | - | Price per unit on invoice. |
| `subtotal` | `NUMERIC(10,2)` | **NO** | - | Line subtotal (`quantity * unit_price`). |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp of billing item snapshot. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.bill_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
    bill_version_id UUID REFERENCES public.bill_versions(id) ON DELETE CASCADE,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE RESTRICT,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | bill_id | shop_id | product_name | quantity | unit_price | subtotal |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1` | `99999999-9999-9999-9999-999999999903` | `11111111-1111-1111-1111-111111111101` | Chicken Biriyani | 1 | 150.00 | 150.00 |
| `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2` | `99999999-9999-9999-9999-999999999903` | `11111111-1111-1111-1111-111111111101` | Chicken Roast | 1 | 140.00 | 140.00 |

---

## 13. `public.payments`
**Purpose**: Transactional payment entries supporting single or split payments (Cash, GPay, Card) for a bill.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique payment transaction ID. |
| `bill_id` | `UUID` | **NO** (FK) | - | References `bills(id)` invoice. |
| `payment_method` | `TEXT` | **NO** | - | Method: `'CASH'`, `'GPAY'`, `'CARD'`, `'UPI'`, `'OTHER'`. |
| `amount` | `NUMERIC(10,2)` | **NO** | - | Amount tendered in this transaction (> 0). |
| `status` | `TEXT` | **NO** | `'COMPLETED'` | Status: `'COMPLETED'` or `'REFUNDED'`. |
| `created_by` | `UUID` | YES (FK) | `NULL` | Cashier or delivery driver (`auth.users(id)`). |
| `created_at` | `TIMESTAMPTZ` | **NO** | `now()` | Timestamp when payment was collected. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
    payment_method TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'COMPLETED',
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | bill_id | payment_method | amount | status | created_at |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `cccccccc-cccc-cccc-cccc-ccccccccccc1` | `99999999-9999-9999-9999-999999999901` | CASH | 320.00 | COMPLETED | 2026-09-26 12:50:00+00 |
| `cccccccc-cccc-cccc-cccc-ccccccccccc2` | `99999999-9999-9999-9999-999999999902` | GPAY | 150.00 | COMPLETED | 2026-09-26 13:40:00+00 |
| `cccccccc-cccc-cccc-cccc-ccccccccccc3` | `99999999-9999-9999-9999-999999999903` | CASH | 200.00 | COMPLETED | 2026-09-26 16:00:00+00 |
| `cccccccc-cccc-cccc-cccc-ccccccccccc4` | `99999999-9999-9999-9999-999999999903` | GPAY | 90.00 | COMPLETED | 2026-09-26 16:00:00+00 |

---

## 14. `public.void_refund_requests`
**Purpose**: Authorization queue and audit trail for voiding printed bills or issuing customer refunds.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique request ID. |
| `bill_id` | `UUID` | **NO** (FK) | - | References `bills(id)` to be voided/refunded. |
| `request_type` | `TEXT` | **NO** | - | Type: `'VOID'` (unpaid) or `'REFUND'` (paid). |
| `reason` | `TEXT` | **NO** | - | Reason provided by cashier (e.g. "Customer left"). |
| `requested_by` | `UUID` | YES (FK) | `NULL` | Cashier user ID (`auth.users(id)`). |
| `requested_at` | `TIMESTAMPTZ` | **NO** | `now()` | Request submission timestamp. |
| `approved_by` | `UUID` | YES (FK) | `NULL` | Manager who approved/rejected the request. |
| `approved_at` | `TIMESTAMPTZ` | YES | `NULL` | Approval/rejection timestamp. |
| `status` | `TEXT` | **NO** | `'PENDING'` | `'PENDING'`, `'APPROVED'`, or `'REJECTED'`. |
| `notes` | `TEXT` | YES | `NULL` | Manager response notes. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.void_refund_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
    request_type TEXT NOT NULL CHECK (request_type IN ('VOID', 'REFUND')),
    reason TEXT NOT NULL,
    requested_by UUID REFERENCES auth.users(id),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    notes TEXT
);
```

### Example Rows
| id | bill_id | request_type | reason | status | requested_at | approved_at |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `dddddddd-dddd-dddd-dddd-ddddddddddd1` | `99999999-9999-9999-9999-999999999901` | REFUND | Wrong item ordered | APPROVED | 2026-09-26 13:05:00+00 | 2026-09-26 13:10:00+00 |
| `dddddddd-dddd-dddd-dddd-ddddddddddd2` | `99999999-9999-9999-9999-999999999903` | VOID | Customer cancelled phone order | PENDING | 2026-09-26 15:30:00+00 | NULL |

---

## 15. `public.customers`
**Purpose**: Customer directory capturing phone numbers, order count, and total spend for CRM, repeat visits, and address lookup.

### Columns
| Column Name | Data Type | Nullable | Default | One-Line Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | **NO** (PK) | `gen_random_uuid()` | Unique customer identity. |
| `phone` | `TEXT` | **NO** (UNIQUE) | - | Primary lookup phone number. |
| `name` | `TEXT` | **NO** | - | Customer full name. |
| `total_orders` | `INT` | YES | `1` | Count of orders placed by customer. |
| `total_spent` | `NUMERIC(10,2)` | YES | `0.00` | Lifetime spend across all shops. |
| `last_order_at` | `TIMESTAMPTZ` | YES | `now()` | Timestamp of most recent order. |
| `created_at` | `TIMESTAMPTZ` | YES | `now()` | Timestamp of first registration. |

### SQL DDL
```sql
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    total_orders INT DEFAULT 1,
    total_spent NUMERIC(10, 2) DEFAULT 0.00,
    last_order_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);
```

### Example Rows
| id | phone | name | total_orders | total_spent | last_order_at |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1` | 9847123456 | Ali | 8 | 2450.00 | 2026-09-26 12:45:00+00 |
| `eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee2` | 9847654321 | Naufal | 3 | 580.00 | 2026-09-26 13:30:00+00 |
| `eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3` | 9745123987 | Shah | 2 | 640.00 | 2026-09-26 15:10:00+00 |
