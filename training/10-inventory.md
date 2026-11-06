# Module 10 — Inventory: FIFO, Stock Entries and Restatement

**Roles:** 👤 + 🔧 · **Time:** 75 min
**Prerequisite:** Module 9

## 10.1 Objectives

1. Read a Stock Ledger row like an accountant: qty, rate, value, balance.
2. Know the three counter-accounts Books uses for stock, and which document maps to which.
3. Post a stock adjustment and explain why it is an expense, not a purchase.
4. Understand **FIFO restatement**: what happens when you insert a movement in the past.

## 10.2 The valuation model

* Books values stock **FIFO per (item, warehouse, batch)**. Each `Books Stock Ledger Entry`
  stores a `stock_queue` — the remaining layers with their quantities and rates.
* An outgoing movement consumes the oldest layer first. If it spans layers, the row's
  `rate` is the **weighted average of that one movement** and `stock_value_difference`
  is the true cost. That is why `SINV-1002`'s beans row showed `48.25`.
* Value flows: `Stock In Hand` (asset) ↔ a counter account, chosen by document type:

```python
STOCK_COUNTER_ACCOUNTS = {
    "Books Delivery Note":     "default_expense_account",           # Cost of Goods Sold
    "Books Purchase Receipt":  "stock_received_but_not_billed",     # SRBNB
    "Books Stock Entry":       "stock_adjustment_account",          # Stock Adjustment
}
```

| Document | Value > 0 (in) | Value < 0 (out) |
|---|---|---|
| Purchase Receipt | Dr `Stock In Hand` / Cr `SRBNB` | Dr `SRBNB` / Cr `Stock In Hand` |
| Delivery Note | Dr `Stock In Hand` / Cr `COGS` (a return) | Dr `COGS` / Cr `Stock In Hand` |
| Stock Entry | Dr `Stock In Hand` / Cr `Stock Adjustment` | Dr `Stock Adjustment` / Cr `Stock In Hand` |

If either account is missing the submit fails with
*Set all inventory ledger accounts in Books Company.*

## 10.3 Lab 10.1 — `SMOV-1001` (damaged stock, 30/10/2026)

`/books` → Inventory → **Stock Entry** → *Add*.

| Field | Value |
|---|---|
| Type | **Material Issue** |
| Posting Date | `30/10/2026` |
| Items → row | `LT-CUP50` · From Warehouse `Stores` · Qty `2` · UOM `Pack` · Batch `CUP-1001` |

Save → **Submit**.

### Expect

| Check | Expect |
|---|---|
| Document name | `SMOV-1001` |
| `total_amount` | **30.00** (2 × 15.00 FIFO cost — not 48.00, the selling price) |
| Ledger | `Stock Adjustment` **30.00 Dr** / `Stock In Hand` **30.00 Cr** |
| Stock Balance — cups | **54 / 810.00** (was 56 / 840.00) |
| `Stock In Hand` GL | **4,886.00** (4,916 − 30) |
| Trial Balance | still balances: assets fall 30.00, expenses rise 30.00 |

## 10.4 Lab 10.2 — read the three inventory reports

| Report | Filters | Expect |
|---|---|---|
| **Stock Ledger** | item `LT-BEAN1KG` | 4 rows: +40 @48, −10 @48, +40 @52, −32 @**48.25** — closing 38 / 1,976.00 |
| **Stock Ledger** | item `LT-GRINDX1` | +5 @420, −1 @420, +1 @420 (the return) — closing 5 / 2,100.00 |
| **Stock Balance** | as on `31/10/2026` | `LT-BEAN1KG` 38 / 1,976.00 · `LT-CUP50` 54 / 810.00 · `LT-GRINDX1` 5 / 2,100.00 · total **4,886.00** |
| **Stock Balance** | as on `15/09/2026` | cups 80 / 1,200.00 · beans 60 / 3,520.00 · grinders 4 / 1,680.00 · total **6,400.00** |

A Stock Ledger row's `value` is the **change**, not the balance — students regularly read
the −1,544 as a balance. The last two columns (`balance_qty`, `balance_value`) are the
running position.

## 10.5 Lab 10.3 — a material receipt (🔁 side lab)

`30/10/2026`, Type **Material Receipt**, `LT-CUP50`, To Warehouse `Stores`, qty `1`,
`basic_rate` `15.00`, batch `CUP-1001`.

| Check | Expect |
|---|---|
| Ledger | `Stock In Hand` 15.00 Dr / `Stock Adjustment` 15.00 Cr |
| Stock Balance — cups | 55 / 825.00 |
| Net effect on profit | zero: stock +15, expense −15 |

That is the whole point: a stock adjustment is how you *correct* the shelf without
pretending you bought or sold anything. Used for damage, theft, and stock-take variances.

## 10.6 Lab 10.4 — FIFO restatement (🔁 side lab, the deepest one)

Reverse Lab 10.5 first (cancel `SMOV-1002`, so cups are back to 54 / 810.00), then enter a
**back-dated** purchase receipt: `PREC-1003`, date **01/09/2026**, `LT-CUP50`, qty `10`,
rate `30.00` — a premium lot you forgot, dated *before* the first purchase. Do **not**
invoice it.

Books must now re-cost every later cup movement, because the 30.00 lot became the oldest
layer and the 15/09 sale must consume it first.

| Effect | Expect |
|---|---|
| Cups layers | 10 @ 30.00 (01/09), then 100 @ 15.00 (02/09) |
| `SHPM-1001` re-costed | cups row: **10 @ 30.00 + 10 @ 15.00 = 450.00** (was 300.00) |
| `SHPM-1001` ledger re-posted | `COGS` **1,350.00** Dr · `Stock In Hand` 1,350.00 Cr (was 1,200.00) |
| Other movements | unchanged — `SHPM-1002` 360.00, `SMOV-1001` 30.00 |
| `COGS` | 2,879.00 (2,729 + 150) |
| `Stock In Hand` | **5,036.00** (4,886 + 150) |
| `Stock Received But Not Billed` | **300.00 Cr** (the receipt is unbilled) |
| Net profit | 1,228.00 (1,378 − 150) |
| Cups Stock Balance | **64 / 960.00** (was 54 / 810.00) |

### The arithmetic, in two lines

| Movement | Amount |
|---|---|
| stock added by the receipt | +300.00 (10 × 30.00) |
| extra cost pushed into 15/09 COGS | −150.00 (10 units cost 30.00 instead of 15.00) |
| **net change to `Stock In Hand`** | **+150.00** → 4,886.00 → 5,036.00 |

Balance check: assets rise 150.00, `SRBNB` rises 300.00, equity falls 150.00 — both sides
of the Trial Balance still agree.

> **The professional takeaway.** A back-dated stock document is never local: Books
> **reposts** every later transaction's value (`valuation.restate_after` →
> `stock_posting._repost`), so period COGS changes after the fact. That is why you verify
> before month-end close and never "fix history" casually. Cancel the receipt afterwards
> and Books restores the original figures.

## 10.7 Other purposes on a Stock Entry

| Purpose | Warehouses used | Ledger effect |
|---|---|---|
| Material Issue | `s_warehouse` only | Dr `Stock Adjustment` / Cr `Stock In Hand` |
| Material Receipt | `t_warehouse` only | Dr `Stock In Hand` / Cr `Stock Adjustment` |
| Material Transfer | both | **none** — value moves between warehouses, total unchanged |
| Repack | both (components → finished good) | value conserved across items |

## 10.8 Common failures

| Message | Cause |
|---|---|
| *Set all inventory ledger accounts in Books Company.* | `default_inventory_account` / `stock_adjustment_account` empty |
| *Enable Inventory is turned off in Books Accounting Settings.* | inventory off |
| Batch is required | item has `has_batch_no` — always name the batch |
| Serial count mismatch | serial numbers ≠ qty |
| Transfer posts no ledger | correct behaviour — a transfer only changes *where* the stock is |
| Stock goes negative | you issued more than the layers held; Books restates and the asset can flip negative — check Stock Balance per item/warehouse |

## 10.9 🔧 Technical notes

* `inventory/valuation.py` keeps one FIFO deque per `(item, warehouse, batch)`, serialised
  into the `stock_queue` field of the newest `Books Stock Ledger Entry`.
* `insert_entry()` returns the entry **and** the set of transactions it restated;
  `delete_entry()` does the same on cancel. `stock_posting._repost(restated)` re-runs the
  value posting for each — the tests `test_a_restated_movement_posts_its_new_value` and
  `test_restated_delivery_note_cost_revalues_its_return` pin this behaviour.
* `_validate_value_direction` rejects a stock entry whose value sign contradicts its
  warehouses, which is how Material Issue/Receipt are told apart from Transfers.
* Stock uom maths: `transfer_qty = qty × conversion_factor`, `stock_uom_rate =
  round(rate / conversion_factor)`, `amount = round(rate × qty)`.
* No negative-stock guard exists in v16.1.0 on the posting path; availability checks are a
  UI/API helper (`inventory/availability.get_sale_shortfalls`). Treat "can I oversell?" as
  a configuration discipline, not an enforced rule.

## 10.10 Exercises ✍

1. A stock-take finds 3 packs missing. Which purpose, which accounts, which amount (cups
   at 15.00)?
2. Recompute Lab 10.4's `Stock In Hand` delta yourself and show the two-account proof.
3. Why does a Material Transfer not post to `Stock Adjustment` even though the counter map
   names it? Find the guard in `stock_posting.py`.

---

**Next:** Module 11 — pricing: discounts, after-tax discounts, pricing rules, margins.
