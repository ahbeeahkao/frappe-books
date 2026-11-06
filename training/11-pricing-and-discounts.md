# Module 11 — Pricing: Discounts, Pricing Rules, Item Tax Overrides

**Roles:** 👤 + 🔧 · **Time:** 60 min
**Prerequisite:** Module 10

## 11.1 Objectives

1. Apply a row discount and predict every number the form will show.
2. Distinguish **discount before tax** from **discount after tax** — including the ledger
   line the after-tax case adds.
3. Drive a discount automatically with a **Pricing Rule**.
4. Override a tax rate for one item with an **Item Tax Template**, and know when Books
   ignores it.

> Every lab in this module is **✎ draft-only**. Discounts and pricing rules change totals,
> so submitting one would move the Module 14 checkpoint. Drafts never reach the ledger.

## 11.2 Lab 11.1 — a 10 % row discount (draft)

New Sales Invoice, `Kopi Hub`, `15/10/2026`, template `SST 8%`, one row:
`LT-CUP50`, qty `10`, rate `24.00`, **Discount Percentage `10`**, discount **before** tax
(`Discount After Tax` unticked at header level).

### Expect

| Field | Expect |
|---|---|
| `price_list_rate` | 24.00 |
| `discount_amount` | **2.40** (round(24.00 × 10 / 100)) |
| `rate` / `net_rate` | **21.60** |
| `amount` / `net_amount` | **216.00** |
| `net_total` | 216.00 |
| tax row | 8 % of 216.00 = **17.28** |
| `grand_total` | **233.28** |

Tax is computed on the **discounted** net. If you also want the invoice-level
`additional_discount_percentage`, that comes off `net_total` before tax as well.

## 11.3 Lab 11.2 — the same discount, **after** tax (draft)

Same rows, but tick **Discount After Tax** on the header (the flag lives on the invoice,
not the row).

### Expect

| Field | Expect |
|---|---|
| `price_list_rate` / `rate` | 24.00 / **24.00** (the discount no longer touches the rate) |
| `discount_amount` | 2.40 (kept for reference) |
| `amount` | **240.00** |
| `net_total` | 240.00 |
| tax | 8 % of 240.00 = **19.20** |
| `grand_total` | **235.20** (259.20 − 24.00) |

**If you submitted it, the ledger would be:**

| Account | Debit | Credit |
|---|---|---|
| `Debtors` | 235.20 | |
| `Discounts` | **24.00** | |
| `Sales` | | 240.00 |
| `SST Payable` | | 19.20 |

Note the extra line: the after-tax discount is posted to the company's
`default_discount_account` (`Discounts`), debited — an Income account debited reduces
income. Books computes it as
`item_discount = gross_amount + total_taxes − grand_total`, and refuses to save if
`default_discount_account` is empty: *Set a discount account in Books Company.*

**Which to use?** In Malaysia SST is charged on the net price actually paid, so
before-tax discount (Lab 11.1) is normally the correct one. After-tax discounts exist for
regimes where the tax is assessed on the list price, or for post-invoice rebates.

## 11.4 Lab 11.3 — a pricing rule (draft)

1. `/books` → Settings → Accounting Settings → **Enable Pricing Rule ✔**
2. `/books` → Settings → **Pricing Rule** → *Add*:

| Field | Value |
|---|---|
| Title | `Beans 5% from 20 kg` |
| Company | Little Oven Supply |
| Items → row | `LT-BEAN1KG` |
| Price or Product Discount | **Price** |
| Rate or Discount | **Discount Percentage** |
| Discount Percentage | `5` |
| Min Qty | `20` |
| Valid From | `01/09/2026` |
| Disabled | ✘ |

3. New Sales Invoice, `Sunrise Cafe`, `16/10/2026`, `Wholesale` list, one row
   `LT-BEAN1KG` qty `20`.

### Expect

| Field | Expect |
|---|---|
| `price_list_rate` | **72.00** (Wholesale Item Price) |
| `discount_percentage` | **5** (filled by the rule) |
| `discount_amount` | **3.60** |
| `rate` | **68.40** |
| `amount` | **1,368.00** |
| `pricing_rules` (child table) | one row referencing `Beans 5% from 20 kg` |
| `net_total` / tax / `grand_total` | 1,368.00 / 109.44 / **1,477.44** |

### Check the `min_qty` boundary

| Qty | Rule applies | `rate` | `amount` |
|---|---|---|---|
| 20 | yes | 68.40 | **1,368.00** |
| 19 | no | 72.00 | **1,368.00** |
| 10 | no | 72.00 | **720.00** |

20 × 68.40 and 19 × 72.00 both give 1,368.00 — a coincidence worth warning clients about.
Use the qty `10` row to see the rule's effect unambiguously.

> **Discount stacking order** (`commerce/pricing.py`): price list rate → pricing rule →
> manual row discount → invoice-level discount → tax. A manual rate (`is_manual_rate`)
> stops Books from overwriting your figure on the next recalculate.

## 11.5 Lab 11.4 — Item Tax Template overrides the tax rate (draft)

Give coffee beans a 5 % rate instead of the standard 8 %.

1. `/books` → Settings → **Item Tax Template** → *Add*:

| Field | Value |
|---|---|
| Title | `Beans 5%` |
| Company | Little Oven Supply |
| Taxes → row | Tax `SST Payable` · Tax Payment Account `SST Payable` · Tax Rate `5` |

2. `/books` → Items → `LT-BEAN1KG` → Taxes → *Add*: `Item Tax Template` = `Beans 5%`,
   **Valid From** `01/09/2026`.
3. New Sales Invoice, `Kopi Hub`, `17/10/2026`, template `SST 8%`, one row
   `LT-BEAN1KG` qty `10` @ 78.00.

### Expect

| Field | Expect |
|---|---|
| `net_total` | 780.00 |
| tax row `rate` | **5.000** |
| tax row `tax_amount` | **39.00** (not 62.40) |
| tax row `set_by_item_tax_template` | **1** |
| `grand_total` | **819.00** |

Mix two items with different item rates in one invoice and the tax row's `rate` shows the
**common** rate when all rows agree, otherwise `0` — while `tax_amount` is always the true
sum. That is `TaxCalculation.rows()` behaviour, and it confuses auditors who read the
rate column.

Attach two Item Tax Templates with different Valid From dates and the **latest** one wins
(`sort_taxes()` keeps newest first).

## 11.6 Lab 11.5 — an `Actual` charge (draft)

Add a second row to a tax template: Charge Type **Actual**, Account Head `Freight and
Forwarding Charges`, Amount `10.00`.

| Check | Expect |
|---|---|
| The row's `rate` | ignored |
| `tax_amount` | exactly **10.00** regardless of net total |
| `grand_total` | net + SST + 10.00 |

Charge types available (`accounting/taxes.py`): `On Net Total`, `Actual`,
`On Previous Row Amount`, `On Previous Row Total` (the last two use `row_id` to reference
an earlier row, which is how cascading levies are built).

## 11.7 Where discounts go wrong

| Symptom | Cause |
|---|---|
| *Item discount percent must be between 0 and 100.* | >100 or negative |
| *Item discount amount cannot exceed the row rate.* | discount bigger than the price |
| Discount field not visible | `enable_discounts_and_margin` off — **one-way**, cannot be switched back off (Module 3) |
| Pricing rule does not fire | rule disabled, `valid_from` in the future, `min_qty` unmet, item not listed, or `enable_pricing_rule` off |
| Item tax template ignored | different account from the invoice's tax row, or its `valid_from` is older than another template, or `enable_price_list`/feature off |
| *Set a discount account in Books Company.* | after-tax discount with no `default_discount_account` |

## 11.8 🔧 Technical notes

* Row maths live in `accounting/invoice.py:_calculate_row`; the header in
  `_calculate_totals`. Both run on every field change through `calculate()`.
* `pricing.py` resolves, in order: price list currency/compatibility
  (`validate_price_list`), Item Price for (item, list, uom, date), pricing rules
  (`_pricing_rules`, with `priority` and `min_qty`/`amount` bounds), then the manual row.
* `taxes.py:set_taxes()` copies the template rows onto the document; `calculate_taxes()`
  builds `TaxCalculation`, which:
  - walks rows in `charge_type` order,
  - applies `Actual` literally,
  - lets an Item Tax Template's rate for the **same account** override the row rate,
  - writes `item_wise_tax_details` (a JSON blob used by GST reports and by the print
    format's tax summary).
* `discount_after_tax` only changes **where** the discount is taken (header total) and
  triggers the extra party-side posting to `_discount_account()`.
* All amounts are rounded per row, then summed — never summed then rounded. Two 0.005
  rows give a different answer under each rule; Books uses round-then-sum.

## 11.9 Exercises ✍

1. A 12.5 % discount on 7 units at 33.33: give `discount_amount`, `rate`, `amount`,
   `net_total`, tax at 8 % and `grand_total`, using Books' rounding.
2. Which four fields decide whether a pricing rule applies, and in what order does Books
   evaluate them?
3. Explain to a client why a 10 % discount before tax gives a different SST amount from a
   10 % discount after tax, with the two totals for a 1,000.00 sale.

---

**Next:** Module 12 — Point of Sale: shift, sale, close, and the cash that must reconcile.
