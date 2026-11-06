# Module 3 — Settings and Defaults (and the switches you can never turn off)

**Roles:** 👤 + 🔧 · **Time:** 45 min
**Prerequisite:** Module 2

## 3.1 Objectives

1. Know the six settings screens and what each one actually controls.
2. Flip the switches this course needs — **before** creating any document.
3. Understand `Books Defaults` transfer locations, which decide whether an invoice
   moves stock on submit.
4. Know the seven switches that **cannot be turned off** once turned on.

---

## 3.2 The six settings screens

| Screen | DocType (single) | Controls |
|---|---|---|
| Accounting Settings | `Books Accounting Settings` | feature switches, fiscal year, GSTIN, setup flag |
| Inventory Settings | `Books Inventory Settings` | batches, serial numbers, UOM conversion, POS, barcode |
| Books Defaults | `Books Defaults` | payment accounts, stock transfer locations, number series, terms, print templates, POS customer & denominations |
| POS Settings | `Books POS Settings` | POS warehouse, counter cash account, POS receivable, sale rounding |
| Print Settings | `Books Print Settings` | logo, company name, address, colours, amount in words |
| System Settings (Frappe) | `System Settings` | currency, country, date/number format, currency precision |

## 3.3 The feature switches — exact field names

A feature is a boolean on a settings single, and **every write path re-checks it
server-side**: switching a feature off does not merely hide a field, it makes the
API reject the field's use with *"<label> is turned off in <settings>"*.

| Field | On settings | Turn on in this course? | What it unlocks |
|---|---|---|---|
| `enable_inventory` | Accounting Settings | **Yes** | warehouses, stock ledgers, delivery notes, stock entries |
| `enable_invoice_returns` | Accounting Settings | **Yes** | credit notes, purchase returns, return transfers |
| `enable_discounts_and_margin` | Accounting Settings | **Yes** | `discount_percentage` / `discount_amount` on rows, margin |
| `enable_price_list` | Accounting Settings | **Yes** | price lists + item prices |
| `enable_pricing_rule` | Accounting Settings | No (Module 11 side lab) | automatic pricing rules |
| `enable_item_group` | Accounting Settings | No | item groups |
| `enable_lead` | Accounting Settings | No | `Books Lead` as a party |
| `enable_loyalty_point_program` / `enable_coupon_code` | Accounting Settings | No | POS loyalty / coupons |
| `enable_point_of_sale_with_out_inventory` | Accounting Settings | No | POS without stock |
| `enable_partial_payment` | Accounting Settings | No | part-payment UI |
| `enable_form_customization` | Accounting Settings | No | in-app form edits |
| `enable_batches` | Inventory Settings | **Yes** | batch tracking |
| `enable_serial_number` | Inventory Settings | **Yes** | serial numbers |
| `enable_uom_conversions` | Inventory Settings | **Yes** | Box → Pack conversions |
| `enable_point_of_sale` | Inventory Settings | **Yes** | the POS screen (Module 12) |
| `show_barcode_field` | Inventory Settings | No | POS barcode input |

### The one-way switches 🔒

These seven are validated by `validate_one_way_switches()` — once on, turning them
off raises *"<label> cannot be disabled once enabled."*

```
enable_discounts_and_margin  enable_inventory  enable_item_group  enable_lead
enable_invoice_returns  enable_loyalty_point_program  enable_point_of_sale_with_out_inventory
```

Practically: **decide inventory/returns/discounts before your first real document.**
On a live site with history you cannot undo `enable_inventory`, so a wrong decision
means a new site and a data migration.

## 3.4 Lab 3.1 — Turn on the course switches

`/books` → Settings → **Accounting Settings**:

| Field | Value |
|---|---|
| Enable Inventory | ✔ |
| Enable Invoice Returns | ✔ |
| Enable Discounts and Margin | ✔ |
| Enable Price List | ✔ |
| Fiscal Year Start / End | `01/01/2026` / `31/12/2026` (already set by the wizard) |

`/books` → Settings → **Inventory Settings**:

| Field | Value |
|---|---|
| Enable Batches | ✔ |
| Enable Serial Number | ✔ |
| Enable UOM Conversions | ✔ |
| Enable Point of Sale | ✔ |
| Show Barcode Field | ✘ |
| Enable Point of Sale (without inventory) | ✘ |

### Expect

| Check | Expect |
|---|---|
| Sidebar → Reports | now shows **Stock Balance** and **Stock Ledger** (hidden while inventory is off) |
| Item form | shows *Is Stock Item*, *Has Batch No*, *Has Serial No*, *UOMs* tab |
| Sidebar → Selling | shows **Point of Sale** |
| Turn *Enable Inventory* back off | error: *Enable Inventory cannot be disabled once enabled.* |

## 3.5 Lab 3.2 — Stock transfer locations (this is what makes invoices move stock)

`Books Defaults` → **Delivery Note Location = `Stores`**, **Purchase Receipt Location = `Stores`**.
Leave **Sales Payment Account** and **Purchase Payment Account** empty.

### Why this matters (the mechanism)

On a new invoice Books computes two follow-up flags before you ever see them:

```python
# accounting/invoice.py — set_follow_up_defaults()
self.make_auto_payment = int(bool(default_payment_account(self.doctype)))          # from Books Defaults
self.make_auto_stock_transfer = int(bool(inventory and invoice_transfer.default_location(self)))
```

* `default_location()` returns the **POS warehouse** for a POS sale, otherwise
  `Books Defaults.delivery_note_location` / `.purchase_receipt_location`.
* So with the locations set and inventory on, **`make_auto_stock_transfer` defaults to 1**
  and a submitted invoice creates its delivery note / purchase receipt by itself.
* With the locations empty (the wizard's default) the flag is 0 and **nothing moves** —
  the invoice's `stock_not_transferred` stays 1. This is the #1 "why is my stock wrong?" cause.

### Expect

| Check | Expect |
|---|---|
| New Sales Invoice → `…`/more → *Make Auto Stock Transfer* | checked by default |
| New Purchase Invoice → same flag | checked by default |
| Submit a test invoice with the flag unticked | invoice submits, `stock_not_transferred = 1`, no delivery note is created, **stock does not move** |
| Delete the test invoice | no ledger effect (draft/cancelled only) |

> **✎ Draft-only lab.** Do not submit a real invoice here; Modules 6–7 create the
> course documents.

## 3.6 Lab 3.3 — Payment accounts (deliberately left empty)

| Field | Value | Effect |
|---|---|---|
| Sales Payment Account | *(empty)* | invoices stay **Unpaid** until you post a Payment Entry |
| Purchase Payment Account | *(empty)* | same on the purchase side |

If you set *Sales Payment Account = Maybank Current*, a submitted invoice with an
outstanding amount immediately creates and submits a Payment Entry, and the invoice
status jumps straight to **Paid** — fine for a card-online business, wrong for this
course, which teaches payment allocation explicitly in Module 8.

## 3.7 Other defaults you will use later

| `Books Defaults` field | Course value | Module |
|---|---|---|
| Sales Invoice Terms | `Goods once sold are not returnable.` | 7 |
| Delivery Note Terms | `Received in good order.` | 7 |
| POS Customer | `Walk-in Customer` | 12 |
| POS Cash Denominations | `50, 20, 10, 5, 1, 0.5, 0.2, 0.1, 0.05, 0.01` | 12 |
| Sales Invoice Print Template | `Business - Sales Invoice` (seeded) | 7 |
| POS Print Template | `Business-POS - Sales Invoice` (seeded) | 12 |

## 3.8 Common failures

| Message / symptom | Cause |
|---|---|
| *Enable Inventory is turned off in Books Accounting Settings* | you created a stock item / delivery note with inventory off |
| Stock reports missing from the sidebar | inventory off (`isInventoryOff()` hides them) |
| Invoice submitted but stock unchanged | transfer location empty, or the flag unticked |
| *Enable Batches is turned off in Books Inventory Settings* | ticking *Has Batch No* while batches are off |
| Number series error on a new document | `Books Defaults` series field blank — reset to `SINV-`, `PAY-`, etc. |

## 3.9 🔧 Technical notes

* `frappe_books/settings.py` defines the whole feature map as data:
  ```python
  FEATURES = {"enable_inventory": "Books Accounting Settings", "enable_batches": "Books Inventory Settings", …}
  ```
  `require_feature(field)` reads the single, and `require_features(doc, {field: feature})`
  is applied per doctype (e.g. an invoice item's `batch_no` requires `enable_batches`).
* The one-way rule lives in `books_accounting_settings.py`:
  ```python
  ONE_WAY_SWITCHES = ("enable_discounts_and_margin", "enable_inventory", "enable_lead",
                      "enable_invoice_returns", "enable_loyalty_point_program",
                      "enable_point_of_sale_with_out_inventory", "enable_item_group")
  ```
  It compares `get_doc_before_save()` with the new value, so it also blocks a REST PATCH.
* Settings are Frappe *singles*: one row per site, no company dimension. Books v16 is a
  **single-company** product; multi-company means multi-site.
* Caching: settings values are read through `frappe.db.get_single_value` (no long cache),
  so a change is effective on the next request — no `bench clear-cache` needed.

## 3.10 Exercises ✍

1. A client enabled inventory six months ago, then decided to sell services only. What
   are their options, and why is "just switch it off" not one of them?
2. Which two fields decide whether submitting an invoice creates a Delivery Note?
   Give the function that reads them.
3. You must create 300 invoices overnight through the API. Which setting would make each
   one auto-create a payment, and why would you leave it off for a month-end import?

---

**Next:** Module 4 — the chart of accounts, and the first journal entry.
