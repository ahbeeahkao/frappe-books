# Module 12 — Point of Sale: Shift, Sale, Close

**Roles:** 👤 + 🔧 · **Time:** 75 min
**Prerequisite:** Module 11

## 12.1 Objectives

1. Configure the POS and open a shift with a counted float.
2. Ring up a cash sale and see the three documents it creates.
3. Close the shift, reconcile the drawer, and read the closing journal — or the absence of
   one, when the count is exact.
4. Know how a cash difference is posted and which account absorbs it.

## 12.2 Configuration (mostly done for you)

| Setting | Value | Set by |
|---|---|---|
| `Books Inventory Settings.enable_point_of_sale` | ✔ | Module 3 |
| `Books POS Settings.warehouse` | `Stores` | wizard |
| `Books POS Settings.cash_account` | `Cash` (the **counter**) | wizard |
| `Books POS Settings.default_account` | `Debtors` (POS receivable) | wizard |
| `Books POS Settings.write_off_account` | `Write Off` | wizard |
| `Books Defaults.pos_customer` | `Walk-in Customer` | **you, in Module 5** |
| `Books POS Settings.allow_rate_change` | ✘ | default |
| `Books POS Settings.allow_discount_change` | ✘ | default |
| `Books POS Settings.ignore_pricing_rule` | ✘ | default |

`Books POS Settings.pos_profile` is optional — leave it empty and Books uses the settings
above. A POS Profile only exists to override the warehouse and default customer per till.

> Books demands a **literal account named `Cash`** for a shift
> (`pos.cash_account()`: *"The standard Cash account is required for POS shifts."*).
> Pointing the counter (`POS Settings.cash_account`) at that same `Cash` account is fine
> and is what this course does — you will see why in 12.5. In production, a separate
> `POS Counter Cash` account makes the "cash in drawer" explicit; the closing journal then
> moves the shift's takings from the counter to the safe.

## 12.3 Lab 12.1 — open a shift

`/books` → Selling → **Point of Sale** → *Open Shift*.

| Field | Value |
|---|---|
| Period Start Date | `05/10/2026` (pre-filled with "now"; type the date) |
| Balance Details → Cash → Opening Amount | `0.00` |
| Opening Cash (denominations) | *(none — the drawer starts empty)* |

Save → **Submit**.

### Expect

| Check | Expect |
|---|---|
| Document name | a hash name (e.g. `k3j9x2m1q0`) — POS documents are **not** numbered by series |
| `journal_entry` | **empty** — opening 0.00 posts nothing |
| Sidebar / POS screen | shows an open shift; a second Open Shift is refused: *A POS shift is already open.* |

*If you want a float*, enter denominations totalling e.g. 200.00 and opening amount
200.00. Books then posts `Dr Cash 200 / Cr Cash 200` — nets to nothing on the same account,
so a float is bookkeeping, not accounting. With a separate counter account it becomes
`Dr POS Counter Cash / Cr Cash`, which is why that pattern is preferred at scale.

## 12.4 Lab 12.2 — sell 3 packs for cash

In the POS screen: tap **`LT-CUP50`** three times (or scan `9551234500017` with
*Show Barcode Field* on), then **Pay**.

| Check on screen | Expect |
|---|---|
| Rate | 24.00 (rate changes are blocked) |
| Qty | 3 |
| Tax | `SST 8%` applied |
| Total | **77.76** |
| Payment | `Cash`, amount `77.76` |

Confirm. Books creates **three** documents from one screen action.

### Expect

| Document | Details |
|---|---|
| `SINV-1004` | `is_pos = 1`, customer `Walk-in Customer`, `debit_to` `Debtors`, net 72.00, SST 5.76, grand **77.76**, status **Paid** |
| `PAY-1006` | Receive, mode `Cash`, allocated 77.76 → `Dr Cash 77.76 / Cr Debtors 77.76` |
| `SHPM-1004` | delivery note from `Stores`, value **45.00** → `Dr COGS 45.00 / Cr Stock In Hand 45.00` |

**Ledger for the sale:**

| Voucher | Account | Debit | Credit |
|---|---|---|---|
| SINV-1004 | Debtors | 77.76 | |
| SINV-1004 | Sales | | 72.00 |
| SINV-1004 | SST Payable | | 5.76 |
| PAY-1006 | Cash | 77.76 | |
| PAY-1006 | Debtors | | 77.76 |
| SHPM-1004 | Cost of Goods Sold | 45.00 | |
| SHPM-1004 | Stock In Hand | | 45.00 |

### Assert

| Check | Expect |
|---|---|
| `Debtors` | 0.00 (POS invoices are settled at the counter) |
| `Cash` | **77.76** Dr |
| `Stock In Hand` | **4,841.00** (4,886 − 45) |
| Stock Balance — cups | **51 / 765.00** |
| Batch `CUP-1001` | **51 of 100 packs left** (100 − 20 − 24 − 2 − 3) |

Note the POS invoice is dated **05/10/2026** but is the **last** invoice you create, so it
is numbered `SINV-1004`. Series follow creation; reports follow posting date.

## 12.5 Lab 12.3 — close the shift

`/books` → Point of Sale → *Close Shift* (`preview` fills the expected amounts without
saving; then key the count).

| Field | Value |
|---|---|
| POS Opening Entry | the shift from Lab 12.1 |
| Payment Reconciliation → Cash | `closing_amount` **77.76** |
| Closing Cash (denominations) | `50×1, 20×1, 5×1, 2×1, 0.50×1, 0.20×1, 0.05×1, 0.01×1` = **77.76** |

### Expect

| Field | Expect |
|---|---|
| `payment_reconciliation` row | opening 0.00 · expected **77.76** · closing **77.76** · difference **0.00** |
| Submit | succeeds |
| `journal_entry` | **empty — no journal is created** |
| General Ledger | no new voucher for the closing |
| Shift | closed; a new shift can be opened |

Why no journal? `_closing_journal_rows()` builds
`Dr Cash <counted>` / `Cr <counter> <expected>` (both the same account here) and Books
nets rows per account before writing the journal (`make_cash_journal`). With counted =
expected every net is zero, so **there is nothing to post**. The sale was already
accounted in 12.4; the close only moves cash *between* accounts.

### 🔁 Side lab — a short drawer

Open a new shift (05/10/2026), sell 1 pack (total 25.92), then close counting only
**23.16** (one 2.00 note short of the 25.92 expected).

| Expect | Value |
|---|---|
| `difference` | **−2.76** |
| Closing journal | `JV-1002`, voucher type **Cash Entry**, remark *POS closing shift <name>* |
| Journal rows | `Write Off` **2.76 Dr** / `Cash` **2.76 Cr** (the two counter rows net away) |
| `Cash` balance | falls by 2.76 — the drawer now matches reality |
| Net profit | falls by 2.76 (Write Off is an expense) |

An over-count posts the mirror: `Dr Cash / Cr Write Off`. If `POS Settings.write_off_account`
is empty the submit fails: *POS Write Off Account is not set. Please set it on POS Settings*.

## 12.6 Rule summary

| Rule | Message |
|---|---|
| One open shift at a time | *A POS shift is already open.* |
| Closing cash = denomination total | *Closing Cash amount must equal the denomination total.* |
| Expected cash = opening + cash payments | *Closing Cash amount must equal the denomination total.* (the check is on the count; the expectation is computed) |
| Shift must still be open to close it | *POS shift {0} is not open.* |
| Cannot cancel an opening entry while a later shift is open | *A later shift is open…* |
| No negative counts | *Cash denominations must be positive and counts cannot be negative.* |
| One row per payment method | *Payment method {0} is listed more than once.* |

## 12.7 🔧 Technical notes

* `commerce/pos.py`: `open_shift_name()` (the single open shift), `pos_customer()`
  (POS Profile → Books Defaults), `cash_account()` (must be literally `Cash`),
  `transacted_amounts(start, end)` (payments per mode inside the shift window),
  `make_cash_journal()` (nets rows per account, skips zero nets, submits a **Cash Entry**
  journal), `cancel_cash_journal()`.
* Opening entry `on_submit` posts `Dr counter / Cr Cash` for the float; closing entry
  `on_submit` stores `journal_entry`. Both doctypes are `autoname: hash`.
* `set_closing_amounts()` uses `now_datetime()` for `period_end_date`, so a shift always
  closes "now" — you cannot back-date a close, which is why POS testing is best done on a
  scratch site.
* `split_counted_cash()` shares the counted notes across cash modes, giving the first cash
  row any surplus.
* POS invoices skip the auto-payment path (`on_submit`: `… and not self.get("is_pos")`);
  the counter payment is created by the POS UI through `pay_pos_invoice` → `pay_at_counter`.

## 12.8 Exercises ✍

1. The shop counts 100.00 but expects 97.24. Write the closing journal and say which
   account and which side the 2.76 lands on.
2. A client wants card payments in the POS. What do you add, and what does the closing
   reconciliation look like when the card terminal settles 1.50 short?
3. Why does a POS invoice ignore `Books Defaults.sales_payment_account`
   (auto payment) but still end up `Paid`?

---

**Next:** Module 13 — multi-currency, then the full report checkpoint.
