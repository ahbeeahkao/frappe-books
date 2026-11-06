# Module 5 — Masters: UOMs, Items, Tax Template, Parties, Price List

**Roles:** 👤 + 🔧 · **Time:** 75 min
**Prerequisite:** Module 4

## 5.1 Objectives

1. Create the two UOMs Books does not ship (Pack, Box) and one conversion.
2. Create four items covering the three cases that matter: **stock + batch**,
   **stock + FIFO**, **stock + serial**, **non-stock service**.
3. Create the `SST 8%` sales tax template on the account from Module 4.
4. Create the parties and the `Wholesale` price list used later in the course.

## 5.2 What Books ships at install

`setup.py:bootstrap()` seeds six UOMs — **Unit** (whole numbers only), Kg, Gram, Meter,
Hour, Day — the `Stores` warehouse, the `Cash` and `Bank` modes of payment, eight number
series starting at 1001, and the default print formats. **Pack and Box are not seeded.**

---

## 5.3 Lab 5.1 — UOMs

`/books` → Settings → **UOM** → *Add*:

| UOM Name | Must be whole number |
|---|---|
| `Pack` | ✔ |
| `Box` | ✔ |

### Expect

| Check | Expect |
|---|---|
| UOM list | 8 rows: `Unit, Kg, Gram, Meter, Hour, Day, Pack, Box` |
| Selling 1.5 Pack later | refused — `must_be_whole_number = 1` |

## 5.4 Lab 5.2 — The four items

`/books` → Items → **Add Item**. Key in exactly these. The `Stock`/`Service` behaviours
are driven by *Type* + *Is Stock Item*.

### Item 1 — `LT-CUP50`

| Field | Value |
|---|---|
| Item Code | `LT-CUP50` |
| Item Name | `Paper Cup 8oz (Pack of 50)` |
| Type | **Product** |
| Is Stock Item | ✔ |
| Stock UOM | `Pack` |
| Standard Rate | `24.00` |
| Description | `Double-wall paper cup, 8 oz, 50 per pack` |
| Has Batch No | ✔ |
| Batch Number Series | `CUP-.####` |
| UOM Conversions → row | UOM `Box`, Conversion Factor `12` |
| Barcodes → row | `9551234500017` (type EAN) |

Item Defaults (auto-filled on save — verify, don't retype):

| Company | Default Warehouse | Income Account | Expense Account |
|---|---|---|---|
| Little Oven Supply | *(set to* `Stores` *)* | `Sales` | `Stock Received But Not Billed` |

### Item 2 — `LT-BEAN1KG`

| Field | Value |
|---|---|
| Item Code | `LT-BEAN1KG` |
| Item Name | `Arabica Beans 1 kg` |
| Type | Product |
| Is Stock Item | ✔ |
| Stock UOM | `Kg` |
| Standard Rate | `78.00` |
| Has Batch No | ✘ (this item demonstrates automatic FIFO) |
| Default Warehouse | `Stores` |

### Item 3 — `LT-GRINDX1`

| Field | Value |
|---|---|
| Item Code | `LT-GRINDX1` |
| Item Name | `Grinder X1` |
| Type | Product |
| Is Stock Item | ✔ |
| Stock UOM | `Unit` |
| Standard Rate | `640.00` |
| Has Serial No | ✔ |
| Serial Number Series | `GRND-.####` |
| Default Warehouse | `Stores` |

### Item 4 — `LT-SVC-INST`

| Field | Value |
|---|---|
| Item Code | `LT-SVC-INST` |
| Item Name | `Installation & Setup` |
| Type | **Service** |
| Is Stock Item | ✘ |
| Stock UOM | `Hour` |
| Standard Rate | `120.00` |

### Expect — the auto-filled accounts (do not type these)

| Item | Income Account | Expense Account | Why |
|---|---|---|---|
| `LT-CUP50`, `LT-BEAN1KG`, `LT-GRINDX1` | `Sales` | `Stock Received But Not Billed` | Product → Sales; stock item → SRBNB |
| `LT-SVC-INST` | **`Service`** | `Cost of Goods Sold` | Service → Service; non-stock → COGS |

Source of truth: `books_item.py`
```python
_default_income_account(item_type)  # "Sales" if Product else "Service"
_default_expense_account(is_stock_item)  # stock_received_but_not_billed if stock else "Cost of Goods Sold"
```

| Assert | Expect |
|---|---|
| `create_new_batch` on `LT-CUP50` | checked automatically (batch series present) |
| Save `LT-CUP50` with *Has Batch No* ticked but no series | allowed, but batches must then be typed by hand on every receipt |
| Save an item with Stock UOM `Nos` | error — that UOM does not exist; use `Unit` |

## 5.5 Lab 5.3 — The `SST 8%` tax template

`/books` → Settings → **Sales Taxes and Charges Template** → *Add*:

| Field | Value |
|---|---|
| Title | `SST 8%` |
| Company | Little Oven Supply |
| Is Default | ✔ |
| Disabled | ✘ |
| Taxes → row 1 | Charge Type **On Net Total** · Account Head `SST Payable` · Rate `8` · Description `Sales and Service Tax 8%` |

### Expect

| Check | Expect |
|---|---|
| Template saves with no "tax amount" | correct — the template holds a *rate*, the invoice computes the amount |
| New Sales Invoice → Taxes and Charges Template | `SST 8%` is pre-selected (it is the default) |
| The row that appears on the invoice | `On Net Total · SST Payable · 8.000 · <amount>` |

> **Charge types** (`accounting/taxes.py`): `On Net Total`, `Actual`,
> `On Previous Row Amount`, `On Previous Row Total`. Only the first is used in this
> course; Module 11 uses `Actual` for a fixed levy.

## 5.6 Lab 5.4 — Parties

| DocType | Name | Fields to set |
|---|---|---|
| Customer | **Kopi Hub** | Default Accounts → company `Little Oven Supply`, account `Debtors` |
| Customer | **Sunrise Cafe** | Default Accounts → `Debtors` *(its invoices will use the `Wholesale` price list — Books has no default-price-list field on a customer, so the list is chosen on each invoice)* |
| Customer | **Walk-in Customer** | Default Accounts → `Debtors` |
| Supplier | **Nusantara Supplies** | Default Accounts → `Creditors` |

Then `Books Defaults` → **POS Customer = `Walk-in Customer`**.

### Expect

| Check | Expect |
|---|---|
| Customer list | 3 customers, `outstanding_amount` 0.00 each |
| `Kopi Hub` → Default Accounts | exactly one row: company + `Debtors` |
| New Sales Invoice → customer `Kopi Hub` | `debit_to` auto-fills **`Debtors`** |
| New Purchase Invoice → supplier `Nusantara Supplies` | `credit_to` auto-fills **`Creditors`** |

If the party account row is missing, the invoice's party account stays empty and the
invoice will not save — the party ledger *is* the control account.

## 5.7 Lab 5.5 — The `Wholesale` price list

`/books` → Settings → **Price List** → *Add*: `Wholesale`, currency `MYR`, **Selling ✔**,
enabled ✔. Then `/books` → **Item Price** → *Add* twice:

| Item Code | Price List | UOM | Rate |
|---|---|---|---|
| `LT-CUP50` | `Wholesale` | `Pack` | `22.00` |
| `LT-BEAN1KG` | `Wholesale` | `Kg` | `72.00` |

### Expect

| Check | Expect |
|---|---|
| Item Price list | 2 rows, `selling = 1` |
| Invoice on the `Wholesale` list, item `LT-CUP50` | `price_list_rate = 22.00`, `rate = 22.00` |
| Invoice with **no** price list selected | `price_list_rate = 24.00` (the item's standard rate) |


## 5.8 Common failures

| Message | Cause |
|---|---|
| *UOM Nos not found* | Books seeds Unit/Kg/Gram/Meter/Hour/Day only |
| *Enable UOM Conversions is turned off in Books Inventory Settings* | conversion row on an item with the feature off |
| *Enable Batches is turned off…* | *Has Batch No* with batches off |
| Duplicate barcode | barcodes are unique across items |
| Tax template not selectable | it is `disabled`, or belongs to another company |
| *Set a discount account in Books Company* on a later invoice | you created the invoice-level discount, not a row discount — see Module 11 |

## 5.9 🔧 Technical notes

* `Books Item` fields that decide behaviour: `item_type` (Product/Service),
  `is_stock_item`, `stock_uom`, `has_batch_no` + `batch_number_series`,
  `has_serial_no` + `serial_no_series`, `uoms[]` (`uom`, `conversion_factor`),
  `taxes[]` (`item_tax_template`, `valid_from`), `barcodes[]`.
* `before_validate()` sets `create_new_batch = int(bool(has_batch_no and batch_number_series))`
  and `sort_taxes()` keeps the newest `valid_from` first — an item tax template with a
  later *Valid From* wins.
* `validate()` runs `require_features` for batch/serial/UOM/Tax fields, then
  `validate_unit_conversions`, `validate_series`, `validate_hsn_codes`.
* Tax templates are **per company** and per direction (`Books Sales Taxes and Charges
  Template` vs `Books Purchase Taxes and Charges Template`). The child row is
  `charge_type + account_head + rate + tax_amount + total + set_by_item_tax_template`;
  `set_by_item_tax_template` marks rows Books recomputed from item tax templates.
* Party accounts live in `Books Party Account` with fields **`company`, `account`** — not
  `default_account`. That asymmetry bites scripted imports.

## 5.10 Exercises ✍

1. The client buys cups by the **carton of 24 packs** but sells by the pack. What do you
   create, and what will the purchase receipt's `stock_qty` be for 5 cartons?
2. Why does Books give `LT-SVC-INST` the `Service` income account automatically, and what
   happens if that account does not exist in the chart?
3. A serial-numbered item is returned by a customer. Which serial status do you expect on
   the return, and which code path sets it?

---

**Next:** Module 6 — the purchase cycle: receipt → invoice → payment.
