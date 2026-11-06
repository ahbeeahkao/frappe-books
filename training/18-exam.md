# Module 18 — Exam

**Roles:** 👤 + 🔧 · **Time:** 75 min · **Closed book**, calculator allowed.

Part A (functional) is compulsory. Part B (technical) is compulsory for technical
consultants and optional for functional consultants. Part C is compulsory for everyone and
is graded against the exact figures used throughout the course.

**Total: 100 marks.** Pass 70. You must score at least 15/20 in Part C.

---

## Part A — Functional (40 marks, 2 each)

1. List, in order, the five things the setup wizard creates and one thing it deliberately
   leaves empty.
2. Which four statuses can a submitted sales invoice show, and what exactly makes it
   `Partly Paid`?
3. A customer is also a supplier. What do you create in Books, and why can you not use one
   record for both?
4. Give the two accounts touched by a Purchase Receipt that has **not** been invoiced, and
   say what the balance sheet shows.
5. Why does a Delivery Note — not the invoice — carry the Cost of Goods Sold posting?
6. A client sells 10 units at 100.00 with 10 % discount, SST 8 %. Give `net_total`,
   `total_taxes_and_charges` and `grand_total`.
7. In one sentence each: when do you use a credit note **without** a return delivery note?
8. What is the difference between `Stock Adjustment` and `Cost of Goods Sold`, and which
   report line separates them?
9. A POS shift opens with 200.00 float and sells 1,000.00 cash. What does the closing entry
   expect, and what happens if the cashier counts 1,180.00?
10. Which single setting decides whether submitting an invoice creates a delivery note?
11. Name three things Books v16 cannot do that a client will assume it can.
12. Why must the opening-balance journal balance to `Opening Balance Equity` rather than to
    profit?
13. Give the ledger rows (accounts + sides) for a customer refund of 691.20.
14. What does `outstanding_amount` mean on a **credit note**, and how do you clear it?
15. Which two fields must a tax template row carry for it to post correctly, and what
    happens if the account has no account type?

## Part B — Technical (30 marks, 2.5 each)

16. Which function decides whether an invoice debits or credits the party? Give the
    expression.
17. Where are ledger amounts converted to base currency, and what does that mean for a
    multi-currency report?
18. Name the counter account used by a Stock Entry and the company field that supplies it.
19. What is `stock_queue`, where does it live, and why does each stock ledger row carry one?
20. Which call re-posts the transactions affected by a back-dated stock movement?
21. Why can a script not fix an invoice by writing `outstanding_amount`?
22. Give the doctype, `autoname` mechanism and an example name for a POS Closing Entry and a
    Sales Invoice.
23. Which four roles ship with Books, and which one may not create a Journal Entry?
24. Write the REST call that creates a `Books Item` and the one that submits an existing
    invoice.
25. Which switch cannot be turned off once enabled, and what does that imply for go-live?
26. Why does `SHPM-1003` refund stock at 420.00 instead of today's average cost?
27. What must you check before a `bench update` on a site with a modified print format?

## Part C — Practical (30 marks)

**C1 (10 marks).** A customer buys 12 packs of `LT-CUP50` on the Wholesale list and returns
3 packs five days later.

| Required | Answer |
|---|---|
| Invoice: `net_total`, SST, `grand_total` | ? |
| COGS of the sale (cups at 15.00) | ? |
| Credit note totals | ? |
| Stock and COGS after the return | ? |
| Status of the original invoice | ? |

**C2 (10 marks).** Post the following and give the full Trial Balance effect of each:
1. A purchase receipt of 20 kg beans at 54.00 with no invoice;
2. The purchase invoice for it;
3. A sale of 45 kg beans at 72.00 + 8 % SST when the stack holds 38 kg at 52.00 and 30 kg at
   54.00;
4. The delivery note's COGS;
5. The state of `Stock Received But Not Billed` after step 2.

**C3 (10 marks).** The Trial Balance of a live site shows `Debtors` 12,400.00 Dr while every
invoice is marked `Paid`, and `Stock In Hand` is 800.00 higher than the Stock Balance report.

| Required | Answer |
|---|---|
| Three likely causes of the `Debtors` gap, most likely first | ? |
| Two likely causes of the stock gap | ? |
| The queries you run to prove each | ? |

---

## Answer key

### Part A

1. (a) the Standard Chart of Accounts, (b) the named **bank account** under *Bank Accounts*,
   (c) the ensured `Cash` account, (d) the ensured `Discounts` account, (e) the company's
   eight accounting defaults + POS settings + modes of payment + number series.
   Left empty: `delivery_note_location` / `purchase_receipt_location` (or the payment
   accounts) — so invoices neither move stock nor pay themselves.
2. `Unpaid`, `Partly Paid`, `Paid`, `Credit Note Issued` (plus `Return` on the credit note
   itself and `Cancelled`). `Partly Paid` when `0 < outstanding_amount < base_grand_total −
   loyalty_amount`.
3. Two records: `Books Customer` and `Books Supplier`. The ledger control account differs
   (`Debtors` vs `Creditors`) and `Payment Entry.party_type` is a single value per document,
   so one record cannot carry both subledgers.
4. Dr `Stock In Hand`, Cr `Stock Received But Not Billed`. The balance sheet shows stock as
   an asset and an equal *unbilled* liability — goods received, not yet invoiced.
5. Because stock value leaves the asset ledger when the goods physically leave, and the
   delivery note is the document that models physical movement
   (`STOCK_COUNTER_ACCOUNTS["Books Delivery Note"] = default_expense_account`).
6. 900.00 · 72.00 · **972.00**.
7. Price adjustment, rebate or goodwill where the goods are **not** returned — a credit note
   alone moves money, no stock.
8. `Stock Adjustment` is the counter account for stock **entries** (damage, stock-take,
   free samples); COGS is the counter for **sales** deliveries. The P&L keeps them on
   separate lines, so lumping them overstates margin.
9. Expected 1,200.00 (200 + 1,000). Counting 1,180.00 is a 20.00 shortfall: Books posts a
   Cash Entry `Dr Write Off 20.00 / Cr Cash 20.00`.
10. `Books Defaults.delivery_note_location` (with `enable_inventory` on) — the flag
    `make_auto_stock_transfer` defaults from it.
11. Any three: period lock, bank reconciliation, debtor ageing, Malaysian SST return,
    multi-company, stock ageing/expiry, approval workflow.
12. Because the counterpart of an opening asset is a claim on the business (equity), not a
    result of the period. Booking it to profit would fabricate earnings that were never
    made.
13. Dr `Debtors` 691.20 / Cr `Maybank Current` 691.20 (a `Pay` payment to a customer).
14. It is negative: a credit the customer holds. Clear it with a refund (`Pay`), by
    allocating it to a later invoice, or by a journal to the customer's account.
15. `charge_type` and `account_head` (with `rate` for anything but `Actual`). Without an
    account type the template can be saved but the account will not appear in the tax-typed
    Link searches, and country-chart defaults cannot find it.

### Part B

16. `InvoicePosting` in `accounting/invoice.py`:
    `is_party_credited = invoice.is_purchase != bool(invoice.get("return_against"))`.
17. In `accounting/ledger.py` (`LedgerPosting`, via `exchange_rate`) and in
    `InvoicePosting`, before the row is stored. Consequence: every report is in **company
    currency**; the document currency exists only on the document.
18. `stock_adjustment_account` → `Stock Adjustment`.
19. It is the FIFO layer list (qty + rate per layer) serialised as JSON on each
    `Books Stock Ledger Entry`. Each row is a self-contained valuation snapshot, so reports
    need no replay and a restatement only rewrites rows after the inserted movement.
20. `stock_posting._repost(restated)`, fed by `valuation.insert_entry` →
    `restate_after`.
21. `outstanding_amount` is recomputed from the ledger on every settlement
    (`settlement.reload_balance` / `refresh_party`); an edit is overwritten or makes the
    invoice disagree with the party account.
22. POS Closing Entry: `autoname: hash`, e.g. `k3j9x2m1q0`. Sales Invoice:
    `make_autoname("SINV-.####")` from `Books Number Series` (start 1001, pad 4), e.g.
    `SINV-1001`.
23. `System Manager`, `Books Manager`, `Books User`, `Books Cashier`. Only `Books Cashier`
    (of the three Books roles) cannot create a Journal Entry — in fact neither Cashier nor
    Books User can; only Manager and System Manager.
24. `POST /api/resource/Books Item` with the item JSON; then
    `POST /api/method/frappe.client.submit` with
    `{"doc": {"doctype": "Books Sales Invoice", "name": "SINV-1005"}}`.
25. Any of the seven one-way switches — most importantly `enable_inventory`,
    `enable_invoice_returns`, `enable_discounts_and_margin`, `enable_item_group`. Implication:
    these decisions are irreversible on a live site, so they must be settled in UAT, before
    the first real document.
26. A return reverses the original movement at the cost it left with
    (`validate_transfer_return`: *"A sales return is valued at its shipment's cost"*); it
    does not re-price the shelf.
27. That the format is a database `Print Format` / `Custom Field`, not an edit under
    `apps/frappe_books` (which `bench update` overwrites), and that a backup exists.

### Part C

**C1** — 12 packs × 22.00 = 264.00; SST 21.12; **grand 285.12**.
COGS 12 × 15.00 = **180.00**. Credit note: net **−66.00**, SST **−5.28**, grand **−71.28**;
return delivery note restores **3 × 15.00 = 45.00** → stock +3 packs, `Stock In Hand` +45.00,
COGS −45.00. Original invoice status → **Credit Note Issued**.

**C2**
1. Dr `Stock In Hand` 1,080.00 / Cr `SRBNB` 1,080.00.
2. Dr `SRBNB` 1,080.00 / Cr `Creditors` 1,080.00.
3. Sale: net 45 × 72 = 3,240.00, SST 259.20, grand 3,499.20 →
   Dr `Debtors` 3,499.20 / Cr `Sales` 3,240.00 / Cr `SST Payable` 259.20.
4. FIFO: 38 @ 52.00 = 1,976.00 + 7 @ 54.00 = 378.00 → **2,354.00** →
   Dr `COGS` 2,354.00 / Cr `Stock In Hand` 2,354.00.
5. `SRBNB` back to **0.00**.

**C3**
* `Debtors` causes: (1) unallocated receipts posted as advances (no `References` row),
  (2) a payment posted to the wrong party, (3) a credit note or journal sitting on the
  account. Proof: General Ledger for `Debtors` with party, then
  `select party, round(sum(debit-credit),2) from tabBooks Ledger Entry where account='Debtors' group by party`.
* Stock causes: (1) a manual journal against `Stock In Hand`, (2) an invoice with
  `stock_not_transferred = 1` (stock never moved), (3) a restated movement whose repost was
  interrupted. Proof: compare `Stock Balance` to the account, then list
  `Books Sales Invoice where stock_not_transferred = 1`, then re-run the per-voucher
  balance query from Module 16.7.

---

## Marking notes

* Part A/B: award marks for the **account names and sides**; terminology variations are fine.
* Part C: exact figures. A single wrong sign on a return or a straddle that ignores the
  second FIFO layer loses the whole sub-question — that is the point of the course.
* Distinction (85+) requires Part C to be fully correct **and** the Module 14 checkpoint to
  reproduce on a fresh site in under four hours.
