# Module 2 — The Setup Wizard: what it creates

**Roles:** 👤 + 🔧 · **Time:** 45 min
**Prerequisite:** Module 1

## 2.1 Objectives

1. Complete the wizard with the course company.
2. Know **exactly** which records the wizard writes — accounts, settings singles,
   modes of payment, number series — and which it deliberately leaves empty.
3. Predict the first "Settings not configured" error a client will hit.

The official docs show the form fields. This module shows the database effect.

---

## 2.2 Who may run it

* Opens automatically the first time `/books` is loaded on an unconfigured site.
* Only **Books Manager** or **System Manager** can complete it (the wizard checks
  `setup_complete` on `Books Accounting Settings`).
* Re-running it on a configured site does **not** re-run the chart: country and
  currency change, `setup_complete` stays `1`. Treat it as one-way.

## 2.3 Lab 2.1 — Key in the wizard

`/books` → **Set up your organization**:

| Field | Key in | Why it matters |
|---|---|---|
| Company Logo | (skip, or any PNG) | stored on `Books Print Settings.logo`; `display_logo` = 1 only if set |
| Company Name | **Little Oven Supply** | becomes the `Books Company` name |
| Full Name | **Siti Nurhaliza** | goes to `Books Accounting Settings.fullname` |
| Email | `accounts@littleoven.test` | print header, and `Books Company.email` |
| Country | **Malaysia** | drives currency, date format, locale |
| Currency | **MYR** | company + system currency; precision 2 |
| Time Zone | **Asia/Kuala_Lumpur** | Frappe `System Settings` |
| Bank Name | **Maybank Current** | creates a **Bank**-type account under *Bank Accounts* |
| Chart of Accounts | **Standard Chart of Accounts** | the account tree (see 2.5) |
| Fiscal Year Start | `01/01/2026` | `Books Accounting Settings.year_start_date` |
| Fiscal Year End | `31/12/2026` | `…year_end_date` |

Click through and submit. The wizard ends on the **Dashboard**.

> **Docs vs reality.** The documentation says a completed wizard "does not turn on
> auto payments". That is accurate and deliberate: the wizard leaves
> `Books Defaults.sales_payment_account` / `.purchase_payment_account` **empty**, so
> submitting an invoice never creates a payment behind your back. Module 3 shows how
> to switch it on when you want it.

## 2.4 Expect — the records created

### a) Accounts (see Module 4 for the full tree)

| Created / ensured | Parent | Type | Root type |
|---|---|---|---|
| the whole **Standard Chart of Accounts** | — | — | Assets / Liabilities / Equity / Income / Expenses |
| `Cash` | Cash In Hand | Cash | Assets |
| `Maybank Current` | Bank Accounts | Bank | Assets |
| `Discounts` | Indirect Income | Income Account | Income |

`Cash` and `Discounts` are *ensured*: created only if missing
(`coa.py:ensure_cash_account`, `ensure_discount_account`). The bank account is created
from the **Bank Name** you typed.

### b) `Books Company` — the accounting defaults the wizard wires

| Field | Value | Found by |
|---|---|---|
| `write_off_account` | `Write Off` | name |
| `round_off_account` | `Round Off` | name |
| `default_discount_account` | `Discounts` | ensured account |
| `default_warehouse` | `Stores` | (the `Stores` warehouse is seeded at install, `setup.py:bootstrap`) |
| `default_inventory_account` | `Stock In Hand` | name, else account type `Stock` |
| `stock_received_but_not_billed` | `Stock Received But Not Billed` | name, else type |
| `default_expense_account` | `Cost of Goods Sold` | name, else type |
| `stock_adjustment_account` | `Stock Adjustment` | name, else type |

This is the *whole reason* a fresh Books company can post stock movements without any
manual account mapping. If a chart has no suitable ledger, the field stays **empty** and
the related feature throws later — that is how country charts such as Guatemala behave.

### c) `Books POS Settings`

`warehouse = Stores`, `cash_account = Cash`, `write_off_account = Write Off`,
`default_account = Debtors`.

### d) Modes of payment — one accounts row each

| Mode | Default account |
|---|---|
| `Cash` | `Cash` |
| `Bank` | `Maybank Current` |

### e) `Books Defaults` — number series only

`sales_invoice_number_series = SINV-`, `purchase_invoice_number_series = PINV-`,
`journal_entry_number_series = JV-`, `payment_number_series = PAY-`,
`stock_entry_number_series = SMOV-`, `delivery_note_number_series = SHPM-`,
`purchase_receipt_number_series = PREC-`, `quotation_number_series = SQUOT-`.

The series themselves (`Books Number Series`) were seeded at install with
`start = 1001`, `pad_zeros = 4`, so the first sales invoice is **`SINV-1001`**.

**Left empty on purpose:** `sales_payment_account`, `purchase_payment_account`,
`delivery_note_location`, `purchase_receipt_location`, `pos_customer`, print templates.

### Assert

| Check | Expect |
|---|---|
| Accounting Settings → `setup_complete` | checked |
| Company → all 8 account fields | filled as the table above |
| `bench --site <site> execute frappe.db.count --args '["Books Account"]'` | **77** = 75 accounts in the standard chart + `Maybank Current` + `Discounts` (a country chart will differ) |
| Open `/books` again | Dashboard, **not** the wizard |

## 2.5 What the wizard does *not* do

| Not done | Consequence | Fixed in |
|---|---|---|
| Enable inventory / POS / returns / discounts | stock features are hidden and rejected | Module 3 |
| Set `delivery_note_location` / `purchase_receipt_location` | invoices will **not** move stock on submit | Module 3 |
| Set `pos_customer` | the POS cannot default a party | Module 12 |
| Set a payment account | no automatic payments | Module 8 (optional) |
| Create items, parties, taxes | nothing to sell | Module 5 |
| Open a fiscal year / period closing | reports still run; Books has no period lock in v16 | Module 14 |

## 2.6 Common failures

| Message | Cause |
|---|---|
| `Country and currency are required` | you skipped Country — currency field never populated |
| Wizard never appears | `Books Accounting Settings.setup_complete` is already 1 (wipe the site or clear the flag) |
| `Duplicate entry … for key 'name'` on submit | a company already exists on the site; Books is single-company |
| Chart shows country names you did not type | `chart_of_accounts` defaults to `get_country_chart(country.code)`; Malaysia has no bundled chart so you must pick **Standard Chart of Accounts** explicitly |

## 2.7 🔧 Technical notes

* `books_setup_wizard.py` stores the form, then `frappe_books/setup_service.py:run_setup(wizard)`
  does the work in a fixed order: `complete_site_setup` → `save_company` → `load_chart`/`ensure_chart`
  → regional records + address template → `ensure_bank_account` → `ensure_discount_account`
  → `enable_currency` → `default_accounts(chart)` → `_update_company_accounts`
  → `_update_accounting_settings` → `_update_books_system_settings` → `_update_print_settings`
  → `_update_pos_settings` → `_update_modes_of_payment` → `_update_defaults`.
* `default_accounts()` is a *name-first, type-fallback* lookup:
  ```python
  "cost_of_goods_sold": find_ledger_account(chart, ["Cost of Goods Sold"], "Cost of Goods Sold")
  ```
  `find_ledger_account` returns the first ledger of the given `account_type` when no
  name matches — so a translated chart still works.
* The wizard is callable headless: `frappe_books.frappe_books.doctype.books_setup_wizard.books_setup_wizard.complete_setup`
  is whitelisted and takes the same field dict (Module 15 shows the REST call). Useful
  for spinning up demo sites.

## 2.8 Exercises ✍

1. The client insists on the **India - Chart of Accounts**. Name three company fields
   whose values will differ from the standard chart, and the function that decides them.
2. Why does the wizard leave `delivery_note_location` empty? What would break if it
   defaulted to `Stores` on an existing site with historical invoices?
3. Write the one-line `bench execute` that proves the wizard set the discount account.

---

**Next:** Module 3 — settings and defaults, including the switches you can never turn back off.
