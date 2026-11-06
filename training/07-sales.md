# Module 7 — Sales: Invoice, automatic Delivery Note, and COGS

**Roles:** 👤 + 🔧 · **Time:** 90 min
**Prerequisite:** Module 6

## 7.1 Objectives

1. Read the invoice form as a calculation: `price_list_rate → rate → amount → net_total → taxes → grand_total`.
2. Submit a sales invoice and get **two** documents and **two** postings: the invoice
   (revenue) and its delivery note (stock + COGS).
3. Prove COGS comes from FIFO valuation, not from the selling rate.
4. Run the official Save → Submit → Cancel lifecycle without corrupting the ledger.

---

## 7.2 The calculation chain (memorise this)

For each row (`accounting/invoice.py`):

```
price_list_rate = item price on the invoice's price list, else item standard_rate
if discount_percentage and not discount_after_tax:
    discount_amount = round(price_list_rate × discount_percentage / 100)
rate      = net_rate  = round(price_list_rate − discount)       # per UOM
amount    = net_amount = round(rate × qty)
stock_uom_rate = round(rate / conversion_factor)
```

Then the header:

```
net_total               = Σ row.amount
total_taxes_and_charges = Σ tax rows          (TaxCalculation, Module 11)
grand_total             = round(net_total + total_taxes_and_charges − discount_after_tax)
base_grand_total        = round(grand_total × conversion_rate)
outstanding_amount      = grand_total − allocated payments
```

Tax is charged **on `net_total`**, i.e. after row discounts. A discount marked
*discount after tax* leaves `rate` at the price-list rate and comes off the taxed total
instead — Module 11 does both.

---

## 7.3 Lab 7.1 — `SINV-1001` (Kopi Hub, 15/09/2026)

`/books` → Selling → **Sales Invoice** → *Add*.

| Header | Value |
|---|---|
| Customer | `Kopi Hub` |
| Debit To | `Debtors` (auto) |
| Posting Date | `15/09/2026` |
| Selling Price List | *(leave empty — use standard rates)* |
| Taxes and Charges Template | `SST 8%` (default) |
| Terms | `Goods once sold are not returnable.` (only if you set it in Module 3) |
| Make Auto Stock Transfer | ✔ (ticked by default — Module 3) |

| # | Item | Qty | UOM | Rate | Batch / Serial | Income Account |
|---|---|---|---|---|---|---|
| 1 | `LT-CUP50` | 20 | Pack | 24.00 | Batch `CUP-1001` | `Sales` |
| 2 | `LT-BEAN1KG` | 10 | Kg | 78.00 | — | `Sales` |
| 3 | `LT-GRINDX1` | 1 | Unit | 640.00 | Serial `GRND-1001` | `Sales` |

Save → **Submit** → confirm.

### Expect — the form

| Field | Expect |
|---|---|
| Document name | `SINV-1001` |
| Row 1 | `price_list_rate` 24.00 · `rate` 24.00 · `amount` **480.00** |
| Row 2 | `price_list_rate` 78.00 · `rate` 78.00 · `amount` **780.00** |
| Row 3 | `price_list_rate` 640.00 · `rate` 640.00 · `amount` **640.00** |
| `net_total` | **1,900.00** |
| Tax row | `On Net Total · SST Payable · 8.000` · `tax_amount` **152.00** |
| `total_taxes_and_charges` | 152.00 |
| `grand_total` | **2,052.00** |
| `outstanding_amount` | 2,052.00 |
| Status | **Unpaid** |
| `stock_not_transferred` | 0 (stock moved) |

### Expect — the documents it created

| Document | Details |
|---|---|
| `SHPM-1001` — Delivery Note | 3 rows, same items/quantities, customer `Kopi Hub`, `against_sales_invoice = SINV-1001`, status **Completed**, value **1,200.00** |
| `Books Serial No` `GRND-1001` | status **Delivered** |
| `Books Batch` `CUP-1001` | 20 consumed, 80 left |

### Expect — the ledger (both vouchers)

**`SINV-1001`** (revenue side):

| Account | Debit | Credit |
|---|---|---|
| `Debtors` | 2,052.00 | |
| `Sales` | | 1,900.00 |
| `SST Payable` | | 152.00 |

**`SHPM-1001`** (stock side — this is the COGS posting):

| Account | Debit | Credit |
|---|---|---|
| `Cost of Goods Sold` | 1,200.00 | |
| `Stock In Hand` | | 1,200.00 |

**How the 1,200 was computed** — not from the selling prices:

| Item | Qty | FIFO layer used | COGS |
|---|---|---|---|
| `LT-CUP50` | 20 | 20 @ 15.00 | 300.00 |
| `LT-BEAN1KG` | 10 | 10 @ 48.00 | 480.00 |
| `LT-GRINDX1` | 1 | 1 @ 420.00 | 420.00 |
| | | **Total** | **1,200.00** |

### Assert

| Check | Expect |
|---|---|
| Stock Balance after Lab 7.1 | cups 80 / 1,200.00 · beans **60 / 3,520.00** · grinders 4 / 1,680.00 · **6,400.00** |
| Trial Balance after Lab 7.1 | Dr: `Bank` 12,400.00 · `Stock In Hand` 6,400.00 · `COGS` 1,200.00 · `Debtors` 2,052.00 = **22,052.00** · Cr: `Capital` 20,000.00 · `Sales` 1,900.00 · `SST Payable` 152.00 = **22,052.00** |
| Gross margin on the invoice | 1,900 − 1,200 = **700.00** (36.8 %) |
| `SHPM-1001` → Stock Ledger | three negative rows, rates 15.00 / 48.00 / 420.00 |

> **Consulting insight.** The invoice shows 2,052.00 but the profit is only 700.00 before
> overhead. Consultants who quote "revenue = profit" get caught by exactly this gap;
> the delivery note's counter-account is what makes the margin statement honest.

## 7.4 Lab 7.2 — `SINV-1002` (Sunrise Cafe, 20/10/2026, Wholesale + FIFO straddle)

`/books` → Selling → **Sales Invoice**:

| Header | Value |
|---|---|
| Customer | `Sunrise Cafe` |
| Posting Date | `20/10/2026` |
| Selling Price List | **`Wholesale`** |
| Taxes and Charges Template | `SST 8%` |
| Make Auto Stock Transfer | ✔ |

| # | Item | Qty | Rate (auto from Wholesale) | Batch |
|---|---|---|---|---|
| 1 | `LT-CUP50` | 24 | 22.00 | `CUP-1001` |
| 2 | `LT-BEAN1KG` | **32** | 72.00 | — |

### Expect

| Field | Expect |
|---|---|
| Document name | `SINV-1002` |
| Row 1 | `price_list_rate` **22.00** (from the Wholesale Item Price) · `amount` **528.00** |
| Row 2 | `price_list_rate` **72.00** · `amount` **2,304.00** |
| `net_total` | **2,832.00** |
| Tax | `tax_amount` **226.56** |
| `grand_total` | **3,058.56** |
| Status | **Unpaid** |
| Delivery note | `SHPM-1002`, value **1,904.00** |

**COGS — the FIFO straddle you must be able to explain:**

| Item | Qty | Layers consumed | COGS |
|---|---|---|---|
| `LT-CUP50` | 24 | 24 @ 15.00 | 360.00 |
| `LT-BEAN1KG` | 32 | **30 @ 48.00 + 2 @ 52.00** | **1,544.00** |
| | | **Total** | **1,904.00** |

The Stock Ledger row for beans reads **qty −32, rate 48.25, value −1,544.00**: Books used
the whole 48.00 layer first (30 kg, from `PREC-1001`) and only then 2 kg of the 52.00 layer
(from `PREC-1002`). The `48.25` is a *weighted average of that single movement*, not a
change of policy — Books is FIFO throughout.

### Assert

| Check | Expect |
|---|---|
| Stock Balance after Lab 7.2 | cups 56 / 840.00 · beans **38 / 1,976.00** · grinders 4 / 1,680.00 · **4,496.00** |
| Trial Balance after Module 7 | Dr: Bank 12,400.00 · Stock 4,496.00 · Debtors 5,110.56 · COGS 3,104.00 → **25,110.56** · Cr: Capital 20,000.00 · Sales 4,732.00 · SST 378.56 → **25,110.56** |
| `Stock In Hand` GL | **4,496.00** Dr (7,600 − 1,200 − 1,904) |
| Beans Stock Ledger | balance 38 kg, value 1,976.00 = 38 × 52.00 |
| `COGS` GL | **3,104.00** Dr (1,200 + 1,904) |
| `Sales` GL | **4,732.00** Cr (1,900 + 2,832) |

> **Module 12 will insert the POS sale dated 05/10.** It consumes 3 cups @ 15.00, so COGS
> becomes 3,149.00 and stock 4,451.00. Nothing else moves — the checkpoint in Module 14
> assumes all modules are done.

## 7.5 Lab 7.3 — Save → Submit → Cancel → Delete (the documented lifecycle)

The official docs describe exactly this. Do it on a **Quotation**, which never touches the
ledger, so your numbers stay valid.

| Step | Key in | Expect |
|---|---|---|
| 1 | Selling → Quotation → Add · Customer `Kopi Hub` · date `21/10/2026` · 2 rows (`LT-CUP50` 10 @ 24.00, `LT-BEAN1KG` 2 @ 78.00) · template `SST 8%` | name `SQUOT-1001`, `net_total` **396.00**, tax **31.68**, `grand_total` **427.68** |
| 2 | **Save** | status **Draft**; nothing in the ledger |
| 3 | **Save → Submit** (confirm) | status **Open**; still nothing in the ledger |
| 4 | `…` → **Cancel** → confirm *Cancel Quotation*, or press **Keep** to abort | status **Cancelled** |
| 5 | `…` → **Delete** | document gone; `SQUOT-1001` is not reused |

**On a real invoice, cancel does three things** — the exact mirror image of submit:

| Cancelling `SINV-1001` | Ledger effect |
|---|---|
| reverse revenue | `Sales` 1,900.00 Dr · `Debtors` 2,052.00 Cr · `SST Payable` 152.00 Dr |
| reverse stock (its delivery note) | `Stock In Hand` 1,200.00 Dr · `COGS` 1,200.00 Cr |
| free the serial | `GRND-1001` back to **Active** |

Books posts **reversing ledger entries**; it does not delete the original rows. If linked
documents exist, the cancel dialog lists them and asks which to cancel with it
(`cancel_with_linked_docs`) — cancelling the invoice alone leaves an orphan delivery note
whose stock stays out. Always cancel the pair.

> **🔁 Side lab (after Module 14).** Cancel `SINV-1002` and confirm: Trial Balance still
> balances, `Sales` drops by 2,832.00, `Stock In Hand` rises by 1,904.00, and the Beans
> balance returns to 70 kg / 3,520.00. Then re-submit by **amending** — the amended copy
> gets a new number, which is precisely why you do not experiment on live documents.

## 7.6 Common failures

| Message | Cause |
|---|---|
| *At least one invoice item is required.* | submitted an empty invoice |
| *Item quantity cannot be zero.* | qty 0 or blank |
| *Item rate cannot be negative.* | negative rate (use a credit note instead) |
| *Item discount percent must be between 0 and 100.* | discount_percentage out of range |
| *Item discount amount cannot exceed the row rate.* | discount > rate |
| *Set an exchange rate from MYR to … above zero.* | conversion_rate 0 (Module 13) |
| Invoice saves but `Debtors` stays 0 | customer has no Default Accounts row (Module 5) |
| Submitted, but no delivery note and stock unchanged | `make_auto_stock_transfer` unticked, or `delivery_note_location` empty |
| `SST` not charged | template not selected, or `SST Payable` account has no `Tax` type |
| Batch quantity error | the batch does not hold enough of that item |
| Selling more than the FIFO layers hold | Books permits it in some builds with negative stock — check Stock Balance immediately; never let a live site run negative |

## 7.7 🔧 Technical notes

* `InvoicePosting.get_ledger_posting()` builds all rows in memory first:
  ```python
  posting.on_party_side(row.get(item_account_field), gross_amount(self, row))
  posting.on_item_side(tax.account_head, tax.tax_amount)
  ```
  All amounts are converted to **base currency** with `conversion_rate` before posting.
* Side selection: `is_party_credited = is_purchase != bool(return_against)` — a sales
  invoice debits the party, a credit note credits it (Module 9).
* `gross_amount(row)` returns `amount` when `discount_after_tax` is set, else
  `price_list_rate × qty`; the difference between `gross_amount` and `grand_total`
  (after tax) is the invoice's `item_discount` and is posted to the **discount account**
  (`Discounts`) against the party.
* Status is stored, not computed on read: `status.py:get_status()` runs on every
  `on_change`. `Paid` requires `outstanding_amount == 0`; `Unpaid` requires
  `outstanding == base_grand_total − loyalty_amount`; anything else is `Partly Paid`.
* The delivery note is created by `invoice_transfer.on_invoice_submit()` →
  `map_invoice_transfer`, which copies rows and links `against_sales_invoice` / `si_detail`.
  Quantities can never exceed the transfer (`validate_moved_quantities`).

## 7.8 Exercises ✍

1. Recompute `SINV-1002`'s COGS if the client had sold **28** kg of beans instead of 32.
2. What does `stock_not_transferred = 1` tell you, and which report would you run to catch
   every invoice with a stock backlog?
3. The client wants revenue split between `Sales` and `Service`. Which row field do you set,
   and what is the fallback when it is blank?
4. Prove that cancelling an invoice does not reduce `SST Payable` twice if you also cancel
   its delivery note.

---

**Next:** Module 8 — payments, allocations, and the outstanding-amount discipline.
