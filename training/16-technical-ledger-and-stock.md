# Module 16 — Technical: Ledger and Stock Internals

**Roles:** 🔧 technical · **Time:** 90 min
**Prerequisite:** Module 15

## 16.1 Objectives

1. Know the two posting primitives everything else is built on.
2. Be able to predict, without opening the UI, the exact ledger rows of any document.
3. Debug the four failures that actually happen in the field: unbalanced voucher, stock that
   will not post, a return that does not restore cost, and a restatement nobody expected.
4. State the invariants you must never break when writing a patch or data fix.

## 16.2 The two primitives

### 1. `accounting/ledger.py` — `LedgerPosting`

```python
posting = ledger.LedgerPosting(doc)      # doc supplies voucher_type, voucher_no, posting_date
posting.debit(account, amount)           # amount in BASE currency
posting.credit(account, amount)
posting.post()
```

Rules it enforces:
* Every amount is positive; the side is expressed by `debit()`/`credit()`.
* `exchange_rate` multiplies non-base amounts before they are stored.
* `post()` writes one `Books Ledger Entry` per call and is **transactional** with the
  document: if the document rolls back, the entries never existed.
* Cancelling does **not** delete rows — the controller posts the mirror entries, so the
  General Ledger always shows both sides of history.

`Books Ledger Entry` fields to query: `account`, `party_type`, `party`, `debit`, `credit`,
`voucher_type`, `voucher_no`, `posting_date`, `against`, plus the usual audit columns.

### 2. Posting is a *document concern*, not a report concern

There is no "post to GL" job. Every submittable doctype implements
`get_ledger_posting()`; `on_submit()` calls `.post()`, `on_cancel()` calls the reverse.
That means: **if a document submits, it is posted; if it is a draft, it is nowhere.** No
half-posted states exist that a report can find.

## 16.3 Predicting the sides

```python
# accounting/invoice.py — InvoicePosting
self.is_party_credited = invoice.is_purchase != bool(invoice.get("return_against"))
```

| Case | `is_purchase` | `return_against` | Party side |
|---|---|---|---|
| Sales invoice | False | — | **debit** party |
| Credit note (sales return) | False | set | **credit** party |
| Purchase invoice | True | — | **credit** party |
| Debit note (purchase return) | True | set | **debit** party |

Then, per item row: `on_item_side(row.income_account or row.expense_account, gross_amount)`
and, per tax row: `on_item_side(tax.account_head, tax.tax_amount)` — on the *opposite* side
to the party. A discount gets one more party-side row to `default_discount_account` when
`discount_after_tax` is used.

**Worked check** (`SINV-1001`, grand 2,052.00, sales, items 1,900, tax 152):
party debit 2,052.00; income credit 1,900.00; tax credit 152.00 → Dr 2,052.00 = Cr 2,052.00
✔. If these three do not tie, the document did not submit — there is no way to store them
unbalanced.

## 16.4 `accounting/payment.py` and `settlement.py`

* Payment posting is `Receive: debit(paid_to), credit(paid_from)`; `Pay:` the reverse.
  Write-offs post to `write_off_account` on the same side as the money movement's
  counterpart; an unallocated remainder simply never touches an invoice.
* `settlement.refresh_party(party_type, party)` and `reload_balance(invoice)` recompute
  `outstanding_amount` **from the ledger**, not from arithmetic on the invoice. Consequences:
  * you cannot "fix" an invoice by editing `outstanding_amount` (the next settlement
    overwrites it);
  * a cancelled payment re-opens the invoice automatically;
  * a party's `outstanding_amount` on the Customer/Supplier record is a cached sum of open
    invoices.

## 16.5 Stock posting

`inventory/stock_posting.py`:

```python
STOCK_COUNTER_ACCOUNTS = {
    "Books Delivery Note":    "default_expense_account",
    "Books Purchase Receipt": "stock_received_but_not_billed",
    "Books Stock Entry":      "stock_adjustment_account",
}
```

`_post_stock_value(transaction)`:
1. `value = valuation.transaction_stock_value(transaction)` (sum of the rows' value change);
2. `_validate_value_direction` — a stock entry with a positive value must be a receipt;
3. `stock, counter = company_value(["default_inventory_account", <counter field>])` — if
   either is empty: *Set all inventory ledger accounts in Books Company.*;
4. `debit, credit = (stock, counter) if value > 0 else (counter, stock)`; post `abs(value)`.

`post_transaction()` → `_create_entries()` → `_post_stock_value()` → `_repost(restated)`:
the set of transactions whose value changed is re-posted, which is the whole mechanism
behind Module 10's restatement lab.

## 16.6 FIFO internals

`inventory/valuation.py`:

| Function | Job |
|---|---|
| `insert_entry(...)` | append a `Books Stock Ledger Entry` with its `stock_queue`, then restate later entries |
| `delete_entries(doctype, name)` | remove a cancelled document's entries, restate later ones |
| `restate_after(anchor, previous)` | walk the later entries and rewrite their rate/value/queue; returns the set of affected `(voucher_type, voucher_no)` |
| `transaction_stock_value()` | sum of a transaction's value differences, for the GL posting |

The queue is per `(item_code, warehouse, batch_no)` and is serialised as JSON into
`stock_queue` on **each** entry — so a Stock Ledger row is a self-contained snapshot of the
valuation state. That is why the reports are cheap and why a restatement only touches rows
after the inserted one.

Pinned by tests:
`test_a_restated_movement_posts_its_new_value`,
`test_a_restated_transfer_passes_its_new_cost_on`,
`test_restated_delivery_note_cost_revalues_its_return`.

## 16.7 Debug recipes

```bash
# 1. every ledger line of one voucher
bench --site <site> execute frappe.get_all \
  --args '["Books Ledger Entry", {"filters": {"voucher_no": "SINV-1001"}, "fields": ["account","debit","credit","party"]}'

# 2. does any voucher fail to balance? (should always return [])
bench --site <site> execute frappe.db.sql --args '
  ["select voucher_type, voucher_no, round(sum(debit)-sum(credit),2) as d
    from `tabBooks Ledger Entry` group by voucher_type, voucher_no having d <> 0"]'

# 3. does stock value equal the Stock In Hand account?
bench --site <site> execute frappe_books.reports.financial_statements.get_account_balances \
  --args '["Asset", "2026-01-01", "2026-10-31"]'

# 4. stock ledger for one item
bench --site <site> execute frappe.get_all \
  --args '["Books Stock Ledger Entry", {"filters": {"item_code": "LT-BEAN1KG"}, "fields": ["posting_date","qty","rate","stock_value_difference","stock_queue"]}]'
```

| Symptom | First thing to check |
|---|---|
| A voucher is unbalanced | someone wrote `Books Ledger Entry` directly — never do this; the app never does |
| Stock will not post | both `default_inventory_account` and the doctype's counter account set? |
| Return did not restore cost | was the **return delivery note** created, or only the credit note? |
| COGS changed after a back-dated entry | expected — `restate_after` reposted; see Module 10.6 |
| `outstanding_amount` looks stale | run `settlement.refresh_party`, or re-save the payment |
| Stock Balance ≠ GL | a manual journal against `Stock In Hand` (allowed, and always wrong unless you document it) |

## 16.8 Invariants (for your patches and data fixes)

1. Every voucher's `Books Ledger Entry` rows must sum to zero on debits−credits.
2. Ledger amounts are **base currency**; never store a document-currency amount there.
3. Stock value changes only through `stock_posting`; never journal into `Stock In Hand` to
   "adjust" it.
4. `outstanding_amount` is derived — regenerate it, do not set it.
5. A cancelled document keeps its ledger rows (mirrored). Deleting `Books Ledger Entry` rows
   breaks every report silently, because reports read only that table.
6. `status` is stored on `on_change`; if you write a document with `frappe.db.set_value`,
   call `store_status()` afterwards or the list will lie.
7. Restatements are legitimate. Closed periods are a **policy** Books does not enforce
   (Module 14.10).

## 16.9 Exercises ✍

1. Write the four ledger rows for a purchase return of 5 kg beans at 48.00, with sides.
2. A colleague "fixed" a stock discrepancy with a journal: Dr `Stock In Hand` 500 / Cr
   `Miscellaneous Expenses` 500. List every report that now disagrees and why.
3. Add the missing SQL to find every `Books Stock Ledger Entry` whose `stock_value_difference`
   does not equal `qty × rate` (they legitimately differ on straddle rows — say why).

---

**Next:** Module 17 — extending the system and running it in production.
