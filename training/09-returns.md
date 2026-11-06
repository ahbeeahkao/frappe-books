# Module 9 — Returns: Credit Note, Return Delivery Note, Refund

**Roles:** 👤 + 🔧 · **Time:** 60 min
**Prerequisite:** Module 8

## 9.1 Objectives

1. Create a credit note from an invoice — never by typing a negative invoice by hand.
2. Get the paired **return delivery note** and the stock/COGS reversal that comes with it.
3. Refund the customer and close the party balance to zero.
4. Know the status chain: `Paid` → `Credit Note Issued`, and the return's own `Return`.

## 9.2 The rules Books enforces

| Rule | Message when broken |
|---|---|
| Returns need `enable_invoice_returns` | *Enable Invoice Returns is turned off in Books Accounting Settings.* |
| A return must point at a **submitted** original | *A return must reference a submitted original …* |
| You cannot return more than was sold | *Returns of … exceed the quantity of …* |
| A return cannot be dated before its original | *A return cannot be dated before its original …* |
| Create a return **from** the original, not from a return | *Create a return from the original invoice.* |
| A fully returned invoice cannot be returned again | *This invoice is already fully returned.* |

A return keeps the original's **rates and costs**: the stock comes back at the cost it
left with, not at today's FIFO. That is what `validate_transfer_return` documents with
the comment *"A sales return is valued at its shipment's cost"*.

## 9.3 Lab 9.1 — `SINV-1003` (credit note for the grinder, 25/10/2026)

Open `SINV-1001` → `…` → **Make Return** (Credit Note). Books maps the whole invoice
with **negated** quantities.

| Step | Action |
|---|---|
| 1 | On the mapped document, **delete** the `LT-CUP50` and `LT-BEAN1KG` rows |
| 2 | Keep the `LT-GRINDX1` row: qty `-1`, rate `640.00`, serial `GRND-1001` |
| 3 | Posting Date `25/10/2026` |
| 4 | Taxes template stays `SST 8%` |
| 5 | `Is Return` is ticked and `Return Against = SINV-1001` (do not edit these) |
| 6 | Save → **Submit**; when asked, also confirm the return delivery note |

### Expect

| Field | Expect |
|---|---|
| Document name | `SINV-1003` (invoices 1001 and 1002 exist already) |
| `is_return` / `return_against` | 1 / `SINV-1001` |
| Row | qty **−1**, `rate` 640.00, `amount` **−640.00** |
| `net_total` | **−640.00** |
| `total_taxes_and_charges` | **−51.20** |
| `grand_total` | **−691.20** |
| Status | **Return** |
| `SINV-1001` status | **Credit Note Issued** |
| Return delivery note | `SHPM-1003`, `return_against = SHPM-1001`, value **−420.00**, status **Return** |
| `Books Serial No` `GRND-1001` | **Active** again |

**Ledger — credit note (`SINV-1003`):**

| Account | Debit | Credit |
|---|---|---|
| `Sales` | 640.00 | |
| `SST Payable` | 51.20 | |
| `Debtors` | | 691.20 |

**Ledger — return delivery note (`SHPM-1003`):**

| Account | Debit | Credit |
|---|---|---|
| `Stock In Hand` | 420.00 | |
| `Cost of Goods Sold` | | 420.00 |

### Assert

| Check | Expect |
|---|---|
| `Debtors` | **691.20 Cr** — you now owe the customer (the invoice was already paid) |
| `Stock In Hand` | **4,916.00** (4,496 + 420) |
| `COGS` | **2,684.00** (3,104 − 420) |
| `Sales` | **4,092.00** Cr (4,732 − 640) |
| `SST Payable` | **327.36** Cr (378.56 − 51.20) |
| Stock Balance — grinders | **5 / 2,100.00** |
| `SINV-1001` `outstanding_amount` | −691.20 (a credit the party can use) |

## 9.4 Lab 9.2 — `PAY-1005` (refund the customer, 28/10/2026)

Open `SINV-1003` → `…` → **Make Payment**. Because the credit note is negative, Books
maps a **Pay** entry.

| Field | Value |
|---|---|
| Payment Type | **Pay** |
| Party Type / Party | `Customer` / `Kopi Hub` |
| Paid From | `Debtors` |
| Paid To | `Maybank Current` |
| Paid Amount | `691.20` |
| References → row | `Books Sales Invoice` · `SINV-1003` · allocated `691.20` |
| Reference No | `MBB-46112` |

### Expect

| Check | Expect |
|---|---|
| Document name | `PAY-1005` |
| Ledger | `Debtors` **691.20 Dr** / `Maybank Current` **691.20 Cr** |
| `Debtors` balance | **0.00** |
| `Maybank Current` | **16,819.36** Dr |

### Assert — full picture after Module 9

| Check | Expect |
|---|---|
| Trial Balance | Dr: Bank 16,819.36 · Stock 4,916.00 · COGS 2,684.00 = **24,419.36** · Cr: Capital 20,000.00 · Sales 4,092.00 · SST 327.36 = **24,419.36** |
| `Debtors`, `Creditors` | 0.00 / 0.00 |
| Stock Balance | cups 56 / 840.00 · beans 38 / 1,976.00 · grinders 5 / 2,100.00 · **4,916.00** |

## 9.5 Return types you will meet

| Case | Document | Stock effect | Party effect |
|---|---|---|---|
| Customer returns goods | Credit note + return delivery note | +qty at original cost | party credited |
| Customer keeps goods, gets money back (price adjustment) | Credit note only (no transfer) | none | party credited |
| You return goods to a supplier | Purchase return (debit note) + return purchase receipt | −qty at original cost | supplier debited |
| Wrong item shipped, replaced | Return + new invoice | back in, then out again | net zero |

**Never** create a negative-quantity invoice by hand: `return_against` is what drives the
original's status, `per_returned`, and the "already fully returned" guard.

## 9.6 🔁 Side lab — purchase return (debit note)

*(After the Module 14 checkpoint.)*

Open `PREC-1001` → `…` → **Make Return**, keep the `LT-BEAN1KG` row and set qty `-5`
(the beans went back to the supplier at **48.00**, their original receipt cost).

| Document | Expect |
|---|---|
| Return receipt `PREC-1003` | qty −5 @ 48.00 = **−240.00**; status **Return** |
| Debit note `PINV-1003` | total **−240.00**; status **Return**; `PINV-1001` → **Debit Note Issued**; `PREC-1001` stays **Completed** (`per_returned` is only 11 %) |
| Ledger (receipt) | `Stock In Hand` **240.00 Cr** · `Stock Received But Not Billed` 240.00 Dr |
| Ledger (debit note) | `Stock Received But Not Billed` **240.00 Cr** · `Creditors` 240.00 Dr |
| `Stock In Hand` | 4,841.00 − 240.00 = **4,601.00** |
| Beans Stock Balance | 33 kg / **1,736.00** |

Note the valuation nuance: the beans currently sit in a 52.00 layer, but the return leaves
at its **original 48.00** cost, so the average cost of the remaining stock changes. That is
deliberate — a return reverses the original transaction, it does not re-price the shelf.

## 9.7 Common failures

| Message | Cause |
|---|---|
| *This invoice is already fully returned.* | the whole invoice was returned once |
| *A return must reference a submitted original …* | you pointed at a draft, or at another return |
| *Create a return from the original invoice.* | you tried to return a credit note |
| Return has no stock effect | `make_auto_stock_transfer` off / no `delivery_note_location` — the credit note alone never moves stock |
| `Debtors` not zero after refund | the refund was unallocated, or allocated to the wrong invoice |
| Serial number error on the return | you returned a different serial from the one that left |

## 9.8 🔧 Technical notes

* `map_return()` (`accounting/returns.py`) uses `get_mapped_doc` with
  `field_map {"name": "return_against"}`, drops the posting date/time and the loyalty
  fields, then `return_unreturned_rows()` negates what earlier returns have not taken.
* `books_sales_invoice.return_unreturned_rows` is shared with the inventory side through
  `batch_quantities` — that is how a return respects (batch, serial) pairs.
* On submit of a return, `update_return_status()` sets the original's `per_returned` and
  `is_fully_returned`, and `store_status()` refreshes the original's list status.
* The transfer return is created by `invoice_transfer` (`map_transfer_return`) with
  `_returned_transfer(invoice)` as its `return_against`; a credit note **without** its
  transfer leaves the stock out — Books warns by leaving `stock_not_transferred` set.
* `_serial_status`: a return receipt has `t_warehouse` and no `s_warehouse`, so the serial
  goes back to **Active**.

## 9.9 Exercises ✍

1. A customer returns 2 of 20 packs three weeks later. Give the credit note total
   (24.00 selling rate, 15.00 cost) and the four ledger lines it plus its return create.
2. Why must the return's posting date be ≥ the original's? What would break in the FIFO
   queue if Books allowed a back-dated return?
3. The client wants "exchange only, no refund". Which documents do you post, and which
   account proves no money moved?

---

**Next:** Module 10 — inventory: valuation, stock entries, and why the ledger follows the shelf.
