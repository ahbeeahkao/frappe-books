# Module 15 — Technical: Doctypes, Fields, Naming and the API

**Roles:** 🔧 technical · **Time:** 90 min
**Prerequisite:** Modules 1–14

## 15.1 Objectives

1. Find any field or document type in the code inside a minute.
2. Trace a document from the form to the database table and back.
3. Drive the whole system from the REST API — create, submit, cancel, report.
4. Know which whitelisted methods the `/books` SPA itself calls.

## 15.2 Layout of the app

```
frappe_books/
  hooks.py            app hooks, fixtures, boot session data
  setup.py            install/bootstrap: UOMs, warehouse, modes of payment, number series, roles
  setup_service.py    what the Setup Wizard writes (Module 2)
  coa.py              chart loading, account lookup by name/type
  company.py          the single Books Company + company_value() helpers
  series.py           naming series (SINV-, PINV-, SHPM-, …)
  settings.py         FEATURES map, require_feature(), one-way switches
  status.py           list status of every submittable document
  permissions.py      has_app_permission(), preview permissions
  accounting/         invoice.py, taxes.py, payment.py, ledger.py, settlement.py, returns.py
  inventory/          stock_posting.py, valuation.py, returns.py, invoice_transfer.py,
                      units.py, availability.py, transaction.py
  commerce/           pos.py, pricing.py
  reports/            dashboard.py, financial_statements.py, general_ledger.py, stock.py, gst.py
  printing.py         print formats + preview_print_format
  frappe_books/doctype/   every DocType (JSON schema + Python controller + tests)
```

Rule of thumb: **every business rule you saw in Modules 1–14 lives in `accounting/`,
`inventory/` or `commerce/`; the doctype folders hold schema and thin controllers.**

## 15.3 The DocType map

| Group | DocTypes |
|---|---|
| Transactions | `Books Sales Invoice`, `Books Purchase Invoice`, `Books Quotation`, `Books Delivery Note`, `Books Purchase Receipt`, `Books Stock Entry`, `Books Payment Entry`, `Books Journal Entry` |
| POS | `Books POS Opening Entry`, `Books POS Closing Entry`, `Books POS Settings`, `Books POS Profile` |
| Masters | `Books Item`, `Books Item Price`, `Books Price List`, `Books Item Group`, `Books Item Tax Template`, `Books Customer`, `Books Supplier`, `Books Lead`, `Books Account`, `Books UOM`, `Books Warehouse`, `Books Batch`, `Books Serial No`, `Books Mode of Payment`, `Books Pricing Rule`, `Books Loyalty Program`, `Books Coupon Code` |
| Tax | `Books Sales Taxes and Charges Template`, `Books Purchase Taxes and Charges Template`, `Books Tax Category` |
| Settings | `Books Accounting Settings`, `Books Inventory Settings`, `Books Defaults`, `Books Print Settings`, `Books System Settings`, `Books Company`, `Books Number Series` |
| Child tables | `Books Sales Invoice Item`, `Books Purchase Invoice Item`, `Books Sales Invoice Payment`, `Books Sales Taxes and Charges`, `Books Payment Entry Reference`, `Books Payment Entry Deduction`, `Books Journal Entry Account`, `Books Stock Entry Detail`, `Books Delivery Note Item`, `Books Item Default`, `Books Party Account`, `Books UOM Conversion Detail`, `Books Item Barcode`, `Books Item Tax`, `Books Pricing Rule Detail` |
| Reports (query/report doctypes) | the six pages are **not** DocTypes; they are `/books` SPA pages backed by `frappe_books.reports.*` whitelisted methods |

### Field map you will use constantly — `Books Sales Invoice`

```
naming_series, customer, debit_to, posting_date, posting_time, status, selling_price_list,
is_return, return_against, is_fully_returned, items, taxes_and_charges, taxes,
net_total, total_taxes_and_charges, loyalty_amount, grand_total, base_grand_total,
currency, conversion_rate, outstanding_amount, stock_not_transferred, discount_after_tax,
make_auto_payment, make_auto_stock_transfer, payments, pricing_rules,
item_wise_tax_details, terms, amended_from, company
```

`Books Sales Invoice Item`:

```
item_code, item_name, description, qty, uom, conversion_factor, stock_uom, stock_qty,
batch_no, serial_no, income_account, item_tax_template, price_list_rate,
discount_percentage, discount_amount, rate, amount, net_rate, net_amount,
stock_uom_rate, gst_hsn_code, delivered_qty, delivery_note, dn_detail,
is_free_item, pricing_rules, is_manual_rate
```

Note what is **not** there: no `warehouse` on an invoice row (the delivery note carries it),
no `bill_no` on a purchase invoice, no `party` column on an invoice (only `customer` /
`supplier`). Script writers trip on all three.

## 15.4 Naming

| Document | Series | Example |
|---|---|---|
| Sales Invoice | `SINV-.####` | `SINV-1001` |
| Purchase Invoice | `PINV-.####` | `PINV-1001` |
| Delivery Note | `SHPM-.####` | `SHPM-1001` |
| Purchase Receipt | `PREC-.####` | `PREC-1001` |
| Stock Entry | `SMOV-.####` | `SMOV-1001` |
| Payment Entry | `PAY-.####` | `PAY-1001` |
| Journal Entry | `JV-.####` | `JV-1001` |
| Quotation | `SQUOT-.####` | `SQUOT-1001` |
| Pricing Rule | `PRLE-.####` | `PRLE-1001` |
| POS Opening / Closing Entry | `hash` | `k3j9x2m1q0` |
| Batch / Serial | item's own series | `CUP-1001`, `GRND-1001` |

Mechanics: `Books Number Series` rows are seeded at install with `start = 1001`,
`pad_zeros = 4`; `autoname()` checks the series' `reference_type` matches the doctype, then
`make_autoname(pattern)`. `Books Defaults` holds *which* series each doctype uses, so a
client can rename the prefix without touching code. Changing a prefix mid-year gives you
two ranges — decide before go-live.

## 15.5 The API: what the SPA uses

`frontend/src/frappe/api.ts` wraps eleven helpers:

```
getDocument(doctype, name)            getDocuments(doctype, filters)
insertDocument(doc)                   updateDocument(doc)
deleteDocument(doctype, name)         runDocMethod(doctype, name, method)
getValue(doctype, fieldname, filters) getList(doctype, fields, filters)
getAllDocuments(doctype)              getDocPermissions(doctype, name)
getCount(doctype, filters)
```

They map onto standard Frappe endpoints — which means **anything the UI can do, you can do
with `curl`** (and with the same role restrictions, Module 1).

### Authenticate

```bash
# Desk → User → API Access → Generate Keys
export AUTH="Authorization: token <api_key>:<api_secret>"
export SITE="https://books.example.com"
```

### Read

```bash
# one invoice
curl -s -H "$AUTH" "$SITE/api/resource/Books Sales Invoice/SINV-1001" | jq '.data.grand_total'

# filtered list
curl -s -H "$AUTH" \
  "$SITE/api/resource/Books Sales Invoice?fields=[%22name%22,%22customer%22,%22grand_total%22,%22status%22]&filters=[[%22posting_date%22,%22%3E%3D%22,%222026-10-01%22]]"

# a settings single
curl -s -H "$AUTH" "$SITE/api/resource/Books Accounting Settings" | jq '.data.enable_inventory'
```

### Write

```bash
# create an item (Module 5, by API)
curl -s -H "$AUTH" -H "Content-Type: application/json" -X POST \
  "$SITE/api/resource/Books Item" -d '{
    "item_code": "LT-NAPKIN", "item_name": "Napkin (Pack of 100)",
    "item_type": "Product", "is_stock_item": 1, "stock_uom": "Pack",
    "standard_rate": 12.5,
    "item_defaults": [{"company": "Little Oven Supply", "default_warehouse": "Stores",
                       "income_account": "Sales",
                       "expense_account": "Stock Received But Not Billed"}]
  }'
```

```bash
# create a sales invoice, then submit it
curl -s -H "$AUTH" -H "Content-Type: application/json" -X POST \
  "$SITE/api/resource/Books Sales Invoice" -d '{
    "customer": "Kopi Hub", "debit_to": "Debtors",
    "posting_date": "2026-09-15", "taxes_and_charges": "SST 8%",
    "make_auto_stock_transfer": 1,
    "items": [{"item_code": "LT-CUP50", "qty": 20, "uom": "Pack",
               "rate": 24, "batch_no": "CUP-1001"}]
  }'

curl -s -H "$AUTH" -H "Content-Type: application/json" -X POST \
  "$SITE/api/method/frappe.client.submit" \
  -d '{"doc": {"doctype": "Books Sales Invoice", "name": "SINV-1005"}}'
```

```bash
# cancel: the linked delivery note FIRST, then the invoice (order matters)
curl -s -H "$AUTH" -H "Content-Type: application/json" -X POST \
  "$SITE/api/method/frappe.client.cancel" \
  -d '{"doctype": "Books Delivery Note", "name": "SHPM-1005"}'

curl -s -H "$AUTH" -H "Content-Type: application/json" -X POST \
  "$SITE/api/method/frappe.client.cancel" \
  -d '{"doctype": "Books Sales Invoice", "name": "SINV-1005"}'
```

> The UI's cancel dialog cancels both at once by calling the document method
> `cancel_with_linked_docs(linked_docs)` through `runDocMethod`. From a script the two-step
> `frappe.client.cancel` above is simpler and equally safe — cancelling the invoice alone
> first would leave an orphan delivery note whose stock stays out.

### Whitelisted methods the UI calls (selection)

| Method | Used for |
|---|---|
| `frappe_books.meta.get_books_meta` | schema for the whole SPA (fields, links, permissions) |
| `frappe_books.search.search` | the search box |
| `frappe_books.reports.dashboard.get_invoice_summary` | dashboard cards |
| `frappe_books.reports.financial_statements.get_account_balances` | P&L / BS / TB data |
| `frappe_books.inventory.availability.get_sale_shortfalls` | "not enough stock" hints |
| `frappe_books.printing.preview_print_format` | print preview |
| `…books_sales_invoice.pay_pos_invoice` | POS counter payment (creates the PAY entry) |
| `…books_setup_wizard.complete_setup` | headless site setup |
| `preview()` on most documents | compute totals/links without saving |

**Preview methods are the cheapest test harness you have.** `preview()` runs the real
calculation path and returns the document without committing, so a script can validate a
whole import file before writing anything.

## 15.6 Tracing a document end to end

Take `SINV-1001`:

1. **Form** — the SPA posts the doc JSON to `/api/resource/Books Sales Invoice`.
2. **Controller** — `books_sales_invoice.py` → `validate()` → `calculate()`
   (`invoice.py`, pricing + taxes) → `before_submit()` (`invoice_transfer.validate_invoice`,
   `settlement.open_balance`) → `on_submit()`.
3. **Posting** — `get_ledger_posting()` returns an `InvoicePosting`; `.post()` writes
   `Books Ledger Entry` rows (one per account/party) inside the same transaction.
4. **Stock** — `invoice_transfer.on_invoice_submit()` inserts and submits `SHPM-1001`,
   which runs `stock_posting.post_transaction()` → `Books Stock Ledger Entry` rows with
   `stock_queue`, plus the COGS posting.
5. **Status** — `on_change()` → `status.store_status(doc)` writes `status`.
6. **Read back** — `/api/resource/Books Ledger Entry?filters=[["voucher_no","=","SINV-1001"]]`.

## 15.7 Exercises ✍

1. Write the `curl` that returns every submitted sales invoice with `stock_not_transferred = 1`.
2. Which child table holds a payment's allocation, and which three amounts does it snapshot?
3. Find, in the code, the function that decides a journal entry's Dr/Cr side for a purchase
   invoice, and state its formula.

---

**Next:** Module 16 — the ledger and stock internals you will debug against.
