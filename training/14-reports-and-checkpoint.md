# Module 14 — Reports and the Course Checkpoint

**Roles:** 👤 + 🔧 · **Time:** 90 min
**Prerequisite:** Modules 1–13

## 14.1 Objectives

1. Run the six reports Books ships and read them the way an auditor does.
2. Prove the whole dataset: every voucher balanced, the Trial Balance closes, the Balance
   Sheet balances, stock ties to the ledger.
3. Know what Books **does not** have, so you can plan the controls around it.

## 14.2 The six reports (and nothing else)

`/books` → Reports (inventory-dependent ones appear only with inventory on):

| Report | Route | Answers |
|---|---|---|
| General Ledger | `/report/GeneralLedger` | every posted line by account |
| Profit and Loss | `/report/ProfitAndLoss` | income − expenses for a period |
| Balance Sheet | `/report/BalanceSheet` | assets = liabilities + equity at a date |
| Trial Balance | `/report/TrialBalance` | closing debits = closing credits |
| Stock Ledger | `/report/StockLedger` | movements with qty/rate/value and running balance |
| Stock Balance | `/report/StockBalance` | qty and value per item/warehouse at a date |

Filters matter: every report takes a **date range** (`fromDate` / `toDate`) or an
`asOnDate`. The P&L for `01/01/2026 – 31/10/2026` is not the same as for
`01/09/2026 – 31/10/2026`; the course uses the fiscal-year start so it matches the Balance
Sheet's "current year earnings".

## 14.3 General Ledger — the complete expected output

49 lines, grouped here by account. This is the entire ledger of the course; if one line
differs, the module that created it is wrong.

| Account | Date | Voucher | Debit | Credit |
|---|---|---|---|---|
| `Capital Stock` | 2026-09-01 | JV-1001 |  | 20000.00 |
| `Maybank Current` | 2026-09-01 | JV-1001 | 20000.00 |  |
| `Creditors` | 2026-09-10 | PAY-1001 | 5520.00 |  |
| `Maybank Current` | 2026-09-10 | PAY-1001 |  | 5520.00 |
| `Creditors` | 2026-10-14 | PAY-1002 | 2080.00 |  |
| `Maybank Current` | 2026-10-14 | PAY-1002 |  | 2080.00 |
| `Debtors` | 2026-09-25 | PAY-1003 |  | 2052.00 |
| `Maybank Current` | 2026-09-25 | PAY-1003 | 2052.00 |  |
| `Debtors` | 2026-10-22 | PAY-1004 |  | 3058.56 |
| `Maybank Current` | 2026-10-22 | PAY-1004 | 3058.56 |  |
| `Debtors` | 2026-10-28 | PAY-1005 | 691.20 |  |
| `Maybank Current` | 2026-10-28 | PAY-1005 |  | 691.20 |
| `Cash` | 2026-10-05 | PAY-1006 | 77.76 |  |
| `Debtors` | 2026-10-05 | PAY-1006 |  | 77.76 |
| `Creditors` | 2026-09-03 | PINV-1001 |  | 5520.00 |
| `Stock Received But Not Billed` | 2026-09-03 | PINV-1001 | 5520.00 |  |
| `Creditors` | 2026-10-13 | PINV-1002 |  | 2080.00 |
| `Stock Received But Not Billed` | 2026-10-13 | PINV-1002 | 2080.00 |  |
| `Stock In Hand` | 2026-09-02 | PREC-1001 | 1500.00 |  |
| `Stock In Hand` | 2026-09-02 | PREC-1001 | 1920.00 |  |
| `Stock In Hand` | 2026-09-02 | PREC-1001 | 2100.00 |  |
| `Stock Received But Not Billed` | 2026-09-02 | PREC-1001 |  | 5520.00 |
| `Stock In Hand` | 2026-10-12 | PREC-1002 | 2080.00 |  |
| `Stock Received But Not Billed` | 2026-10-12 | PREC-1002 |  | 2080.00 |
| `Cost of Goods Sold` | 2026-09-15 | SHPM-1001 | 1200.00 |  |
| `Stock In Hand` | 2026-09-15 | SHPM-1001 |  | 300.00 |
| `Stock In Hand` | 2026-09-15 | SHPM-1001 |  | 480.00 |
| `Stock In Hand` | 2026-09-15 | SHPM-1001 |  | 420.00 |
| `Cost of Goods Sold` | 2026-10-20 | SHPM-1002 | 1904.00 |  |
| `Stock In Hand` | 2026-10-20 | SHPM-1002 |  | 360.00 |
| `Stock In Hand` | 2026-10-20 | SHPM-1002 |  | 1544.00 |
| `Cost of Goods Sold` | 2026-10-25 | SHPM-1003 |  | 420.00 |
| `Stock In Hand` | 2026-10-25 | SHPM-1003 | 420.00 |  |
| `Cost of Goods Sold` | 2026-10-05 | SHPM-1004 | 45.00 |  |
| `Stock In Hand` | 2026-10-05 | SHPM-1004 |  | 45.00 |
| `Debtors` | 2026-09-15 | SINV-1001 | 2052.00 |  |
| `SST Payable` | 2026-09-15 | SINV-1001 |  | 152.00 |
| `Sales` | 2026-09-15 | SINV-1001 |  | 1900.00 |
| `Debtors` | 2026-10-20 | SINV-1002 | 3058.56 |  |
| `SST Payable` | 2026-10-20 | SINV-1002 |  | 226.56 |
| `Sales` | 2026-10-20 | SINV-1002 |  | 2832.00 |
| `Debtors` | 2026-10-25 | SINV-1003 |  | 691.20 |
| `SST Payable` | 2026-10-25 | SINV-1003 | 51.20 |  |
| `Sales` | 2026-10-25 | SINV-1003 | 640.00 |  |
| `Debtors` | 2026-10-05 | SINV-1004 | 77.76 |  |
| `SST Payable` | 2026-10-05 | SINV-1004 |  | 5.76 |
| `Sales` | 2026-10-05 | SINV-1004 |  | 72.00 |
| `Stock Adjustment` | 2026-10-30 | SMOV-1001 | 30.00 |  |
| `Stock In Hand` | 2026-10-30 | SMOV-1001 |  | 30.00 |

## 14.4 Trial Balance — as on 31/10/2026

| Account | Total Debit | Total Credit | Closing Debit | Closing Credit |
|---|---|---|---|---|
| `Capital Stock` | 0.00 | 20000.00 | 0.00 | 20000.00 |
| `Cash` | 77.76 | 0.00 | 77.76 | 0.00 |
| `Cost of Goods Sold` | 3149.00 | 420.00 | 2729.00 | 0.00 |
| `Creditors` | 7600.00 | 7600.00 | 0.00 | 0.00 |
| `Debtors` | 5879.52 | 5879.52 | 0.00 | 0.00 |
| `Maybank Current` | 25110.56 | 8291.20 | 16819.36 | 0.00 |
| `SST Payable` | 51.20 | 384.32 | 0.00 | 333.12 |
| `Sales` | 640.00 | 4804.00 | 0.00 | 4164.00 |
| `Stock Adjustment` | 30.00 | 0.00 | 30.00 | 0.00 |
| `Stock In Hand` | 8020.00 | 3179.00 | 4841.00 | 0.00 |
| `Stock Received But Not Billed` | 7600.00 | 7600.00 | 0.00 | 0.00 |
| **Total** | **58158.04** | **58158.04** | **24497.12** | **24497.12** |

Read it this way:
* **Total Debit / Total Credit** are the *movement* columns — every debit ever posted,
  every credit ever posted. 58,158.04 each.
* **Closing Debit / Closing Credit** are the balances — 24,497.12 each. This is the pair
  that must be equal; the movement pair is a by-product.
* `Creditors`, `Debtors` and `Stock Received But Not Billed` close at **0.00** — every
  purchase and sale in the course is fully settled and fully billed. That is the sign of a
  clean dataset. (Books lists a zero-balance account if it has movement; the row is not an
  error.)

## 14.5 Profit and Loss — 01/01/2026 to 31/10/2026

| Line | Amount (MYR) |
|---|---|
| Sales (gross 4,804.00 less credit note 640.00) | **4,164.00** |
| Cost of Goods Sold | 2,729.00 |
| **Gross profit** | **1,435.00** |
| Stock Adjustment (damaged stock) | 30.00 |
| **Net profit** | **1,405.00** |

Cross-checks:
* Gross margin 34.5 %. Compare with the invoice-level margins: `SINV-1001` 36.8 %,
  `SINV-1002` 32.8 %, POS 37.5 %.
* COGS is **3,149.00 of debits less 420.00 of return credits** — the return's COGS reversal
  is what the negative line in the GL represents. Never report "COGS = 3,149".
* `Stock Adjustment` 30.00 is *not* COGS. A client who lumps it in will overstate margin by
  a hair every month; keep the line separate.

## 14.6 Balance Sheet — as on 31/10/2026

| Section | Account | Amount (MYR) |
|---|---|---|
| Assets | Bank Accounts — `Maybank Current` | 16,819.36 |
| Assets | Cash | 77.76 |
| Assets | Stock In Hand | 4,841.00 |
| | **Total assets** | **21,738.12** |
| Liabilities | `SST Payable` | 333.12 |
| Equity | `Capital Stock` | 20,000.00 |
| Equity | Current Year Earnings | 1,405.00 |
| | **Total liabilities and equity** | **21,738.12** |

`Debtors` and `Creditors` do not appear at all — they are zero. `SST Payable` 333.12 =
152.00 + 226.56 + 5.76 − 51.20, i.e. output tax on every sale less the credit note. That is
what you remit to the tax authority for the period (ignoring input tax, which this course
does not claim).

## 14.7 Stock

| Item | Qty | Value (MYR) | Average rate |
|---|---|---|---|
| `LT-BEAN1KG` | 38.00 | 1976.00 | 52.00 |
| `LT-CUP50` | 51.00 | 765.00 | 15.00 |
| `LT-GRINDX1` | 5.00 | 2100.00 | 420.00 |
| **Total** | | **4841.00** | |

Full Stock Ledger (11 movements):

| Date | Voucher | Item | Qty | Rate | Value | Balance qty | Balance value |
|---|---|---|---|---|---|---|---|
| 2026-09-02 | PREC-1001 | `LT-CUP50` | 100.00 | 15.00 | 1500.00 | 100.00 | 1500.00 |
| 2026-09-02 | PREC-1001 | `LT-BEAN1KG` | 40.00 | 48.00 | 1920.00 | 40.00 | 1920.00 |
| 2026-09-02 | PREC-1001 | `LT-GRINDX1` | 5.00 | 420.00 | 2100.00 | 5.00 | 2100.00 |
| 2026-09-15 | SHPM-1001 | `LT-CUP50` | -20.00 | 15.00 | -300.00 | 80.00 | 1200.00 |
| 2026-09-15 | SHPM-1001 | `LT-BEAN1KG` | -10.00 | 48.00 | -480.00 | 30.00 | 1440.00 |
| 2026-09-15 | SHPM-1001 | `LT-GRINDX1` | -1.00 | 420.00 | -420.00 | 4.00 | 1680.00 |
| 2026-10-12 | PREC-1002 | `LT-BEAN1KG` | 40.00 | 52.00 | 2080.00 | 70.00 | 3520.00 |
| 2026-10-20 | SHPM-1002 | `LT-CUP50` | -24.00 | 15.00 | -360.00 | 56.00 | 840.00 |
| 2026-10-20 | SHPM-1002 | `LT-BEAN1KG` | -32.00 | 48.25 | -1544.00 | 38.00 | 1976.00 |
| 2026-10-25 | SHPM-1003 | `LT-GRINDX1` | 1.00 | 420.00 | 420.00 | 5.00 | 2100.00 |
| 2026-10-30 | SMOV-1001 | `LT-CUP50` | -2.00 | 15.00 | -30.00 | 54.00 | 810.00 |
| 2026-10-05 | SHPM-1004 | `LT-CUP50` | -3.00 | 15.00 | -45.00 | 51.00 | 765.00 |

Tie-outs you must be able to perform:
* Stock Balance value **4,841.00** = `Stock In Hand` closing debit **4,841.00**.
* Cups 51 packs: **100 − 20 − 3 − 24 − 2 = 51** (purchase, invoice 1001, POS, invoice 1002, damage).
* Beans 38 kg = 40 + 40 − 10 − 32, all remaining kg in the **52.00** layer.
* Grinders 5 = 5 − 1 + 1 (the return brought one back).

## 14.8 All documents, in date order

| Document | Type | Date | Party | Net | Tax | Grand total | Status |
|---|---|---|---|---|---|---|---|
| `JV-1001` | Journal Entry | 2026-09-01 |  |  |  | **** | Submitted |
| `PREC-1001` | Purchase Receipt | 2026-09-02 | Nusantara Supplies |  |  | **5520.00** | Completed |
| `PINV-1001` | Purchase Invoice | 2026-09-03 | Nusantara Supplies |  |  | **5520.00** | Paid |
| `PAY-1001` | Payment Entry | 2026-09-10 | Nusantara Supplies |  |  | **5520.00** | Submitted |
| `SINV-1001` | Sales Invoice | 2026-09-15 | Kopi Hub | 1900.00 | 152.00 | **2052.00** | Unpaid |
| `SHPM-1001` | Delivery Note | 2026-09-15 |  |  |  | **1200.00** | Completed |
| `PAY-1003` | Payment Entry | 2026-09-25 | Kopi Hub |  |  | **2052.00** | Submitted |
| `SINV-1004` | Sales Invoice | 2026-10-05 | Walk-in Customer | 72.00 | 5.76 | **77.76** | Paid |
| `SHPM-1004` | Delivery Note | 2026-10-05 |  |  |  | **45.00** | Completed |
| `PAY-1006` | Payment Entry | 2026-10-05 | Walk-in Customer |  |  | **77.76** | Submitted |
| `PREC-1002` | Purchase Receipt | 2026-10-12 | Nusantara Supplies |  |  | **2080.00** | Completed |
| `PINV-1002` | Purchase Invoice | 2026-10-13 | Nusantara Supplies |  |  | **2080.00** | Paid |
| `PAY-1002` | Payment Entry | 2026-10-14 | Nusantara Supplies |  |  | **2080.00** | Submitted |
| `SINV-1002` | Sales Invoice | 2026-10-20 | Sunrise Cafe | 2832.00 | 226.56 | **3058.56** | Unpaid |
| `SHPM-1002` | Delivery Note | 2026-10-20 |  |  |  | **1904.00** | Completed |
| `PAY-1004` | Payment Entry | 2026-10-22 | Sunrise Cafe |  |  | **3058.56** | Submitted |
| `SINV-1003` | Sales Invoice | 2026-10-25 | Kopi Hub | -640.00 | -51.20 | **-691.20** | Return |
| `SHPM-1003` | Delivery Note | 2026-10-25 |  |  |  | **-420.00** | Return |
| `PAY-1005` | Payment Entry | 2026-10-28 | Kopi Hub |  |  | **691.20** | Submitted |
| `SMOV-1001` | Stock Entry | 2026-10-30 |  |  |  | **30.00** | Submitted |

`SINV-1001` shows `Unpaid` because that was its status **when submitted**; it became `Paid`
in Module 8 and then `Credit Note Issued` in Module 9. Status is a stored, evolving field —
this table records the state at creation so you can trace each module's effect.

## 14.9 The checkpoint — 15 assertions

Tick every one. This is the graded part of the course.

| # | Check | Expected |
|---|---|---|
| 1 | Documents submitted | **20** (1 JV, 2 PREC, 2 PINV, 6 PAY, 4 SINV, 4 SHPM, 1 SMOV) |
| 2 | Trial Balance closing debit | **24,497.12** |
| 3 | Trial Balance closing credit | **24,497.12** |
| 4 | Trial Balance movement debit / credit | 58,158.04 / 58,158.04 |
| 5 | `Sales` closing | **4,164.00 Cr** |
| 6 | `Cost of Goods Sold` closing | **2,729.00 Dr** |
| 7 | `Stock Adjustment` closing | 30.00 Dr |
| 8 | `SST Payable` closing | **333.12 Cr** |
| 9 | `Maybank Current` closing | **16,819.36 Dr** |
| 10 | `Cash` closing | **77.76 Dr** |
| 11 | `Stock In Hand` closing | **4,841.00 Dr** |
| 12 | `Debtors`, `Creditors`, `SRBNB` closing | 0.00 / 0.00 / 0.00 |
| 13 | Stock Balance total | **4,841.00** (cups 51/765, beans 38/1,976, grinders 5/2,100) |
| 14 | Net profit | **1,405.00** |
| 15 | Balance Sheet totals | assets **21,738.12** = liabilities + equity **21,738.12** |

If all 15 hold, every mechanism in the course worked: wizard defaults, tax template, FIFO
valuation across two cost layers, automatic delivery notes, returns with cost restoration,
POS with a counter payment, and a stock adjustment.

### Regenerate the expectations from code

```bash
python3 training/data/build_expected.py     # rewrites expected-results.json
```

Every figure in this module comes from that file, which is itself derived from the posting
rules in `invoice.py`, `taxes.py`, `payment.py`, `stock_posting.py`, `valuation.py` and
`status.py`. If your site disagrees with the file, the site is wrong — or you deviated from
the module instructions.

## 14.10 What Books does **not** have (plan around it)

| Missing capability | Consequence | Mitigation |
|---|---|---|
| Period lock / closing entries | anyone can post into a closed month | freeze by policy, export a signed Trial Balance PDF, restrict `Books Manager` |
| Bank reconciliation | no statement matching | keep a spreadsheet, or clear `clearance_date` on payments and review |
| Debtor ageing report | no ageing buckets | derive from `Payment Entry Reference.outstanding_amount` snapshots |
| Malaysian SST/GST return | only India GST reports ship | export GL + tax ledger rows and file manually |
| Multi-company | one company per site | one site (and one database) per entity |
| Stock ageing / expiry report | batches carry `expiry_date` but no report | query `Books Batch` + Stock Balance |
| Approval workflow | submission is immediate | Frappe workflow on `Books Sales Invoice`, or a role split (Module 1) |

## 14.11 Common failures

| Symptom | Cause |
|---|---|
| Trial Balance does not balance | you posted a journal with unequal sides via the API (Books blocks it in the UI, not always in scripts) |
| P&L differs from the Balance Sheet's earnings | different date ranges — use the fiscal-year start for both |
| Stock Balance ≠ `Stock In Hand` | an invoice moved stock without its delivery note value, or a FX revaluation was posted to stock |
| `Debtors` not zero with all invoices paid | an unallocated advance/receipt sits on the account |
| Report shows nothing | filter dates exclude every posting (a common mistake with `toDate` = today on a future-dated dataset) |

## 14.12 Exercises ✍

1. Reconcile the Bank account from `JV-1001` to 16,819.36 in five lines.
2. The client asks "how much GST/SST do I owe". Which account, which report, which two
   numbers, and what else must you check before filing?
3. Give the four journal entries that would take the Balance Sheet from 31/10 to opening
   balances on a new site, assuming the same figures.

---

**Next:** Module 15 — technical: doctypes, fields, naming, and the API surface.
