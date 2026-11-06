# Module 8 — Payments, Allocations and Outstanding Amounts

**Roles:** 👤 + 🔧 · **Time:** 60 min
**Prerequisite:** Module 7

## 8.1 Objectives

1. Receive money against an invoice and watch `outstanding_amount` go to zero.
2. Know the difference between **allocated** and **unallocated** money, and why the
   unallocated case is how "advance from customer" appears in the books.
3. Post a partial payment and a bank-charge write-off (side labs).
4. Reconcile: `Debtors` and `Creditors` must be **zero** when every invoice is settled.

## 8.2 How a Payment Entry is shaped

| Field | Meaning on a **Receive** | Meaning on a **Pay** |
|---|---|---|
| `payment_type` | `Receive` | `Pay` |
| `party_type` / `party` | `Customer` / customer | `Supplier` / supplier |
| `paid_from` | the party account (`Debtors`) | the money account (`Maybank Current`) |
| `paid_to` | the money account (`Maybank Current`) | the party account (`Creditors`) |
| `paid_amount` / `received_amount` | what the customer gave you | what you sent |
| `references[]` | invoices this money settles (allocated) | same |
| `unallocated_amount` | money on account (an advance) | prepayment |
| `deductions[]` | bank charges, rounding | same |

Rule of thumb: **money side and party side**, in that order. `paid_from` is where value
leaves, `paid_to` is where it lands.

## 8.3 Lab 8.1 — `PAY-1003` (receive from Kopi Hub, 25/09/2026)

Open `SINV-1001` → `…` → **Make Payment**.

| Field | Value |
|---|---|
| Payment Type | **Receive** |
| Party Type / Party | `Customer` / `Kopi Hub` |
| Paid From | `Debtors` |
| Paid To | `Maybank Current` |
| Paid Amount | `2,052.00` |
| Mode of Payment | `Bank` |
| Reference No / Date | `MBB-44917` / `25/09/2026` |
| References → row | `Books Sales Invoice` · `SINV-1001` · `allocated_amount` **2,052.00** |

Submit.

### Expect

| Check | Expect |
|---|---|
| Document name | `PAY-1003` |
| `total_allocated_amount` | 2,052.00 |
| `unallocated_amount` | **0.00** |
| `SINV-1001` | `outstanding_amount` **0.00**, status **Paid** |
| `Debtors` GL balance | **0.00** |
| `Maybank Current` GL balance | **14,452.00** Dr (12,400 + 2,052) |

**Ledger:**

| Account | Debit | Credit |
|---|---|---|
| `Maybank Current` | 2,052.00 | |
| `Debtors` | | 2,052.00 |

## 8.4 Lab 8.2 — `PAY-1004` (receive from Sunrise Cafe, 22/10/2026)

Same pattern against `SINV-1002`.

| Field | Value |
|---|---|
| Payment Type | Receive |
| Party | `Sunrise Cafe` |
| Paid From / To | `Debtors` / `Maybank Current` |
| Paid Amount | `3,058.56` |
| References → row | `SINV-1002` · allocated `3,058.56` |
| Reference No | `MBB-45880` |

### Expect

| Check | Expect |
|---|---|
| Document name | `PAY-1004` |
| `SINV-1002` status | **Paid**, outstanding 0.00 |
| `Maybank Current` | **17,510.56** Dr |
| `Debtors` | **0.00** |
| `Creditors` | **0.00** |

### Assert — the control accounts are clean

| Check | Expect |
|---|---|
| Trial Balance after Module 8 | Dr: Bank 17,510.56 · Stock 4,496.00 · COGS 3,104.00 = **25,110.56** · Cr: Capital 20,000.00 · Sales 4,732.00 · SST 378.56 = **25,110.56** |
| `Debtors` / `Creditors` rows in the TB | absent or 0.00 — every invoice is settled, so the control accounts carry nothing |

## 8.5 🔁 Side lab — partial payment

*(After the Module 14 checkpoint. Expected deltas are given so you can undo them by
cancelling.)*

| Step | Key in | Expect |
|---|---|---|
| 1 | New Sales Invoice `28/10/2026`, `Kopi Hub`, 1 × `LT-CUP50` @ 24.00, template `SST 8%` | net 24.00 · SST 1.92 · grand **25.92** (a new number, e.g. `SINV-1005`) |
| 2 | Make Payment, amount **10.00**, allocated 10.00 | invoice status **Partly Paid**, `outstanding_amount` **15.92** |
| 3 | `Debtors` | 15.92 Dr — the only open item on the ledger |
| 4 | Second payment 15.92 | status **Paid**, `Debtors` back to 0.00 |

`status.py` decides the label exactly this way: `outstanding == 0` → `Paid`;
`outstanding == base_grand_total` → `Unpaid`; anything in between → `Partly Paid`.

## 8.6 🔁 Side lab — write-off (bank charge / rounding)

Settle `SINV-1005` with **25.42** cash and let 0.50 be a bank charge.

| Field | Value |
|---|---|
| Paid Amount | `25.42` |
| Deductions → row | Account `Write Off`, Amount `0.50` |
| References → row | the invoice, allocated `25.92` |

### Expect

| Account | Debit | Credit |
|---|---|---|
| `Maybank Current` / `Cash` | 25.42 | |
| `Write Off` | 0.50 | |
| `Debtors` | | 25.92 |

| Check | Expect |
|---|---|
| Invoice status | **Paid** (outstanding 0.00) — the write-off closes it |
| `Write Off` GL | 0.50 Dr (an Expense, so it reduces profit) |
| Without `write_off_account` on the company | error *Set a write-off account in Books Company.* |

## 8.7 🔁 Side lab — customer advance (unallocated money)

Receive 500.00 from `Kopi Hub` with **no** References row.

| Check | Expect |
|---|---|
| `total_allocated_amount` | 0.00 |
| `unallocated_amount` | **500.00** |
| `Debtors` | **500.00 Cr** (a credit balance = you owe goods/money) |
| Balance Sheet | `Debtors` appears under liabilities or as a negative asset — same number, different presentation |

This is how a deposit or retainer looks before invoicing. When you later create the
invoice, allocate the advance to it instead of taking new money.

## 8.8 Common failures

| Message | Cause |
|---|---|
| `Debtors` not zero after "paying" | the payment was saved without a `References` row → it is an advance |
| *Allocated amount exceeds the invoice outstanding amount.* | you allocated more than the invoice still owes (e.g. to a partly-paid invoice) |
| *Payment allocations cannot exceed the settled amount, including the write-off.* | allocations + deductions > `paid_amount` |
| *The From and To accounts cannot be the same.* | `paid_from` = `paid_to` |
| *Invoice … does not belong to party …* | the References row points at another party's invoice |
| *Submit invoice … before allocating a payment to it.* | allocating to a draft invoice |
| Payment posts to the wrong side | `paid_from`/`paid_to` swapped — money must leave from the account you gave it from |
| *Set a write-off account in Books Company.* | `deductions` used with no `write_off_account` |
| Invoice still `Unpaid` after a full payment | the payment is a draft — submit it |
| Cancelling a payment leaves the invoice `Paid` | cancel is blocked while the invoice is settled; cancel the allocation relationship first by cancelling the invoice or amending |

## 8.9 🔧 Technical notes

* `accounting/payment.py` builds `LedgerPosting`: for `Receive`,
  `debit(paid_to)`, `credit(paid_from)`; for `Pay`, the reverse. Write-off rows post to
  `company_value("write_off_account")`, and an unallocated remainder is simply never
  debited to an invoice — it sits on the party account.
* `allocated_amount` is stored on each `Books Payment Entry Reference` row together with
  `total_amount` and `outstanding_amount` **at the time of payment** — that snapshot is
  what makes the invoice's ageing reproducible.
* `settlement.py` recalculates `outstanding_amount` from the party's ledger
  (`refresh_party` / `reload_balance`), so a cancelled payment re-opens the invoice.
  Never write `outstanding_amount` from a script; post a payment instead.
* `enable_partial_payment` on Accounting Settings governs the UI's part-pay helper only;
  the API accepts allocated amounts below the outstanding either way.

## 8.10 Exercises ✍

1. A customer pays 1,000 against two invoices of 600 and 400. Show the References table.
2. Your client receives a 500 deposit in March and invoices 2,000 in April. What is the
   April invoice's `outstanding_amount` before and after allocating the advance?
3. Why is posting an unallocated receipt better than editing an invoice's
   `outstanding_amount`? Give the ledger reason and the audit reason.

---

**Next:** Module 9 — returns: credit note, return delivery note, refund.
