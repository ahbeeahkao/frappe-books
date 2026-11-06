# Module 6 — The Purchase Cycle: Receipt → Invoice → Payment

**Roles:** 👤 + 🔧 · **Time:** 75 min
**Prerequisite:** Module 5

## 6.1 Objectives

1. Enter a Purchase Receipt and predict the **two** ledger lines it posts, without any
   invoice existing yet.
2. Convert the receipt into a Purchase Invoice and watch `Stock Received But Not Billed`
   fall back to zero.
3. Pay the supplier and reconcile `Creditors` to zero.
4. Repeat the cycle at a **higher price** and see the FIFO layer it creates.

This module's most important idea: **goods and money are two separate postings.** The
receipt moves stock and credits a *not-billed* liability; the invoice converts that into a
real supplier liability. If you ever post a purchase invoice with `make_auto_stock_transfer`
on **and** a receipt, you will double the stock — Books blocks that with
`validate_moved_quantities` ("Received quantities exceed…").

---

## 6.2 Lab 6.1 — `PREC-1001` (Purchase Receipt, 02/09/2026)

`/books` → Purchases → **Purchase Receipt** → *Add*.

| Header | Value |
|---|---|
| Supplier | `Nusantara Supplies` |
| Posting Date | `02/09/2026` |
| Terms | *(blank — Books only fills terms if you set them in Books Defaults, Module 3)* |

| # | Item | Qty | Rate | Extra you must set |
|---|---|---|---|---|
| 1 | `LT-CUP50` | 100 | 15.00 | Batch `CUP-1001` · Warehouse `Stores` |
| 2 | `LT-BEAN1KG` | 40 | 48.00 | Warehouse `Stores` |
| 3 | `LT-GRINDX1` | 5 | 420.00 | Serials `GRND-1001` … `GRND-1005` · Warehouse `Stores` |

> **Where does 15.00 / 48.00 / 420.00 come from?** The purchase rate is the supplier's
> cost, not the selling rate. Type it; Books shows it as `price_list_rate` and `rate`.
> The batch `CUP-1001` is auto-created from the item's `CUP-.####` series — accept the
> suggested name (yours may differ if the series was already used; the amounts will not).

### Expect

| Field / check | Expect |
|---|---|
| Document name | `PREC-1001` |
| Status (after submit) | **To Bill** |
| `grand_total` | **5,520.00** (no tax on purchases in this course) |
| `per_billed` | 0 % |
| Batch created | `Books Batch` has `CUP-1001` for `LT-CUP50`, qty 100 |
| Serials created | 5 × `Books Serial No` for `LT-GRINDX1`, status **Active** |

**Ledger posted by the receipt** (`stock_posting._post_stock_value`, value > 0):

| Account | Debit | Credit |
|---|---|---|
| `Stock In Hand` | 5,520.00 | |
| `Stock Received But Not Billed` | | 5,520.00 |

**Stock ledger** (Stock Ledger report, warehouse `Stores`):

| Date | Voucher | Item | Qty | Rate | Value | Balance qty | Balance value |
|---|---|---|---|---|---|---|---|
| 02/09/2026 | PREC-1001 | LT-CUP50 | +100 | 15.00 | 1,500.00 | 100 | 1,500.00 |
| 02/09/2026 | PREC-1001 | LT-BEAN1KG | +40 | 48.00 | 1,920.00 | 40 | 1,920.00 |
| 02/09/2026 | PREC-1001 | LT-GRINDX1 | +5 | 420.00 | 2,100.00 | 5 | 2,100.00 |

### Assert

| Check | Expect |
|---|---|
| Stock Balance at 02/09 | `LT-CUP50` 100 / 1,500.00 · `LT-BEAN1KG` 40 / 1,920.00 · `LT-GRINDX1` 5 / 2,100.00 · total **5,520.00** |
| Trial Balance at 02/09 | `Stock In Hand` 5,520.00 Dr · `Stock Received But Not Billed` 5,520.00 Cr |
| `Creditors` | **0.00** — you have not been billed yet. This is not a mistake; it is accrual accounting working. |

## 6.3 Lab 6.2 — `PINV-1001` (bill the receipt, 03/09/2026)

Open `PREC-1001` → `…` → **Make Purchase Invoice**. Books maps the supplier, items,
quantities, batches, serials and the `purchase_receipt` / `pr_detail` links; you only
change the date.

| Header | Value |
|---|---|
| Supplier | `Nusantara Supplies` (mapped) |
| Posting Date | `03/09/2026` |
| Credit To | `Creditors` (auto from the supplier) |
| Items | 3 mapped rows, `received_qty` = 100 / 40 / 5 |
| Taxes | none |

> **Consulting note (gap in v16.1.0).** `Books Purchase Invoice` has **no supplier-bill-number
> field**. For an audit trail you either put `NS-8842` in the payment's `Reference No`, or add
> a custom field (Module 17 shows how). Verify with
> `bench --site <site> execute frappe.get_meta --args '["Books Purchase Invoice"]'`.

Save → **Submit**.

### Expect

| Check | Expect |
|---|---|
| Document name | `PINV-1001` |
| `grand_total` | **5,520.00** |
| `outstanding_amount` | **5,520.00** |
| Status | **Unpaid** |
| `per_received` | **100 %** |
| `PREC-1001` status | **Completed** |

**Ledger posted by the invoice:**

| Account | Debit | Credit |
|---|---|---|
| `Stock Received But Not Billed` | 5,520.00 | |
| `Creditors` | | 5,520.00 |

### Assert — the SRBNB account must be back to zero

| Check | Expect |
|---|---|
| `Stock Received But Not Billed` balance | **0.00** |
| `Creditors` balance | 5,520.00 Cr |
| `Stock In Hand` | 5,520.00 Dr (unchanged by the invoice — the invoice posts **no** stock) |

That zero is the proof the purchase cycle is complete on the goods side. If SRBNB is not
zero, either the receipt is not billed yet, or you entered the receipt *and* an invoice
with auto stock transfer on.

## 6.4 Lab 6.3 — `PAY-1001` (pay the supplier, 10/09/2026)

Open `PINV-1001` → `…` → **Make Payment** → set:

| Field | Value |
|---|---|
| Payment Type | **Pay** |
| Party Type / Party | `Supplier` / `Nusantara Supplies` |
| Paid From | `Maybank Current` |
| Paid To | `Creditors` |
| Paid Amount | `5,520.00` |
| References → row | `Books Purchase Invoice` · `PINV-1001` · allocated **5,520.00** |
| Reference No / Date | `TT-77310` / `10/09/2026` |

Submit.

### Expect

| Check | Expect |
|---|---|
| Document name | `PAY-1001` |
| `total_allocated_amount` | 5,520.00 |
| `unallocated_amount` | **0.00** |
| `PINV-1001` | `outstanding_amount` **0.00**, status **Paid** |
| `Creditors` balance | **0.00** |

**Ledger:**

| Account | Debit | Credit |
|---|---|---|
| `Creditors` | 5,520.00 | |
| `Maybank Current` | | 5,520.00 |

### Assert

| Check | Expect |
|---|---|
| `Maybank Current` balance | **14,480.00** Dr (20,000 − 5,520) |
| Supplier `Nusantara Supplies` → outstanding | 0.00 |

## 6.5 Lab 6.4 — Second cycle at a higher price (12–14/10/2026)

Repeat the three steps. This is the FIFO setup for Modules 7 and 10.

| Document | Date | Supplier | Item | Qty | Rate | Amount |
|---|---|---|---|---|---|---|
| `PREC-1002` | 12/10/2026 | Nusantara Supplies | `LT-BEAN1KG` | 40 | **52.00** | 2,080.00 |
| `PINV-1002` | 13/10/2026 | " | (billed) | | | 2,080.00 |
| `PAY-1002` | 14/10/2026 | " | (paid) | | | 2,080.00 |

### Expect

| Check | Expect |
|---|---|
| `Books Batch` / serials | no new batch or serial (beans are not tracked) |
| Stock Balance after Lab 6.4 | `LT-BEAN1KG` **80** kg / **4,000.00** (two FIFO layers: 40 @ 48.00 = 1,920 + 40 @ 52.00 = 2,080) |
| `Stock In Hand` balance | **7,600.00** Dr (cups 1,500 + beans 4,000 + grinders 2,100) |
| `Maybank Current` | **12,400.00** Dr (14,480 − 2,080) |
| `Creditors`, `SRBNB` | 0.00 / 0.00 |

**Stock Ledger (beans) — the two layers you must be able to read:**

| Date | Voucher | Qty | Rate | Value | Balance qty | Balance value |
|---|---|---|---|---|---|---|
| 02/09 | PREC-1001 | +40 | 48.00 | 1,920.00 | 40 | 1,920.00 |
| 12/10 | PREC-1002 | +40 | 52.00 | 2,080.00 | 80 | 4,000.00 |

Module 7 consumes them and proves Books takes the **48.00** layer first.

## 6.6 Common failures

| Message | Cause |
|---|---|
| *Received quantities exceed the quantity in the receipt* | invoice quantity > receipt quantity, or you invoiced a receipt twice |
| *Set all inventory ledger accounts in Books Company.* | `default_inventory_account` or `stock_received_but_not_billed` empty (a country chart that lacked them) |
| Receipt submits but stock does not move | inventory off, or the transfer was disabled |
| `Creditors` still not zero after payment | the payment was **unallocated** (no `References` row) — allocate it |
| Payment posts to `Debtors` | Payment Type is `Receive` instead of `Pay` |
| Serial numbers rejected | the serial count ≠ the quantity, or a serial is already `Delivered` |
| *A return cannot be dated before its original…* | Module 9 — return date precedes the original |

## 6.7 🔧 Technical notes

* On submit a receipt runs `_post_stock_value`, which reads
  `STOCK_COUNTER_ACCOUNTS = {"Books Delivery Note": "default_expense_account",
  "Books Purchase Receipt": "stock_received_but_not_billed",
  "Books Stock Entry": "stock_adjustment_account"}` and posts
  `Dr stock / Cr counter` (or the reverse when the value is negative).
* The **purchase invoice** posts *no* stock: `InvoicePosting.on_party_side(credit_to, grand_total)`
  and `on_item_side(row.expense_account, gross_amount)`.
* `per_received` is derived from `received_qty` on the mapped rows;
  `invoice_transfer.validate_invoice` stops over-billing against a transfer.
* Serials: receipt → `Active`; delivery → `Delivered`; stock-entry issue → `Consumed`;
  cancel of a leaving row → `Inactive` (`stock_posting._serial_status`).
* Rates: `stock_uom_rate = round(rate / conversion_factor)`. Buying cups as Boxes
  (factor 12) at 180.00 gives `stock_uom_rate` 15.00 and `stock_qty` = qty × 12.

## 6.8 Exercises ✍

1. Budget the ledger for a receipt **without** an invoice at month end: which two accounts
   carry the 5,520 and why is that acceptable to an auditor?
2. The client's purchase invoice has 2 extra rows for freight (1,200, no stock). Where does
   that post, and what happens to stock value?
3. Prove from the numbers in Lab 6.4 that the 40 kg at 52.00 did not revalue the earlier
   40 kg at 48.00.

---

**Next:** Module 7 — sales, with the automatic delivery note and the FIFO-driven COGS.
