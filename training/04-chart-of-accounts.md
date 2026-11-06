# Module 4 — Chart of Accounts and the Opening Journal

**Roles:** 👤 + 🔧 · **Time:** 60 min
**Prerequisite:** Module 3

## 4.1 Objectives

1. Read the chart Books creates and know which accounts the rest of the course uses.
2. Add one new liability account (`SST Payable`) correctly — under a group of type *Tax*.
3. Post the opening capital journal and see it in the General Ledger and Trial Balance.
4. Know which account fields on `Books Company` route each automatic posting.

---

## 4.2 Structure rules

* Five **root types**: `Assets`, `Liabilities`, `Income`, `Expenses`, `Equity`
  (the standard chart titles the roots *Application of Funds (Assets)* and
  *Source of Funds (Liabilities)* — the names are cosmetic; `root_type` is what matters).
* An account is either a **group** (`is_group = 1`) or a **ledger**. Groups hold
  accounts, ledgers hold amounts. Books refuses entries on a group.
* `account_type` is the machine-readable role: `Receivable`, `Payable`, `Bank`, `Cash`,
  `Stock`, `Tax`, `Cost of Goods Sold`, `Stock Adjustment`, `Stock Received But Not Billed`,
  `Round Off`, `Chargeable`, `Temporary`, `Fixed Asset`, `Accumulated Depreciation`,
  `Depreciation`, `Expenses Included In Valuation`, `Equity`.
  **The company defaults are chosen by `account_type` when a name doesn't match** — this
  is why renaming `Cost of Goods Sold` is safe only if its type stays `Cost of Goods Sold`.
* Books is single-company, so account names have no company suffix (`Debtors`, not
  `Debtors - LOS`).

## 4.3 The Standard Chart of Accounts as created

75 accounts. The ones this course touches are marked ★.

```
Application of Funds (Assets)
  Current Assets
    Accounts Receivable
      Debtors                       [Receivable] ★
    Bank Accounts                   [Bank]            ← Maybank Current is created here ★
    Cash In Hand                    [Cash]
      Cash                          [Cash] ★
    Loans and Advances (Assets)
    Securities and Deposits
      Earnest Money
    Stock Assets                    [Stock]
      Stock In Hand                 [Stock] ★
    Tax Assets
  Fixed Assets
    Capital Equipments / Electronic Equipments / Furnitures and Fixtures /
    Office Equipments / Plants and Machineries / Buildings / Softwares [Fixed Asset]
    Accumulated Depreciation        [Accumulated Depreciation]
  Investments
  Temporary Accounts
    Temporary Opening               [Temporary]
Expenses
  Direct Expenses
    Stock Expenses
      Cost of Goods Sold            [Cost of Goods Sold] ★
      Expenses Included In Valuation
      Stock Adjustment              [Stock Adjustment] ★
  Indirect Expenses
    Administrative Expenses / Commission on Sales / Depreciation [Depreciation] /
    Entertainment Expenses / Freight and Forwarding Charges [Chargeable] / Legal Expenses /
    Marketing Expenses [Chargeable] / Miscellaneous Expenses [Chargeable] /
    Office Maintenance Expenses / Office Rent / Postal Expenses / Print and Stationery /
    Round Off [Round Off] ★ / Salary / Sales Expenses / Telephone Expenses /
    Travel Expenses / Utility Expenses / Write Off ★ / Exchange Gain/Loss /
    Gain/Loss on Asset Disposal
Income
  Direct Income
    Sales ★
    Service ★
  Indirect Income                    ← Discounts is created here (Module 11) ★
Source of Funds (Liabilities)
  Current Liabilities
    Accounts Payable
      Creditors                     [Payable] ★
      Payroll Payable
    Stock Liabilities
      Stock Received But Not Billed  [Stock Received But Not Billed] ★
    Duties and Taxes                [Tax]              ← SST Payable goes here ★
    Loans (Liabilities)
      Secured Loans / Unsecured Loans / Bank Overdraft Account
Equity
  Capital Stock [Equity] ★ / Dividends Paid / Opening Balance Equity / Retained Earnings
```

Plus: **`Maybank Current`** (Bank, from the wizard) and **`Discounts`** (Income) = 77 accounts.

### Which company field routes which automatic entry

| Automatic posting | `Books Company` field | Account | Set by |
|---|---|---|---|
| Debtors on sales invoice | — (`debit_to` = party account) | `Debtors` | customer default / wizard POS receivable |
| Creditors on purchase invoice | — | `Creditors` | supplier default |
| Stock received on purchase receipt | `default_inventory_account` | `Stock In Hand` | wizard |
| Un-billed stock | `stock_received_but_not_billed` | `Stock Received But Not Billed` | wizard |
| COGS on delivery note | `default_expense_account` | `Cost of Goods Sold` | wizard |
| Stock write-off on stock entry | `stock_adjustment_account` | `Stock Adjustment` | wizard |
| Rounding | `round_off_account` | `Round Off` | wizard |
| Payment write-off | `write_off_account` | `Write Off` | wizard |
| Invoice-level discount | `default_discount_account` | `Discounts` | wizard |
| Default warehouse | `default_warehouse` | `Stores` | wizard |

**Consulting insight:** a new country chart fails exactly when one of these lookups
returns `None`. The first symptom is usually *"Set a discount account in Books Company."*
during the first discounted invoice — that message is `_discount_account()` in `invoice.py`.

## 4.4 Lab 4.1 — Create `SST Payable`

`/books` → Accounting → **Chart of Accounts** → open **Duties and Taxes** → *Add Child*
(or the `+` next to the node):

| Field | Value |
|---|---|
| Account Name | **SST Payable** |
| Parent Account | `Duties and Taxes` (pre-filled) |
| Root Type | `Liability` (inherited) |
| Account Type | **Tax** |
| Is Group | ✘ |

### Expect

| Check | Expect |
|---|---|
| Tree | `Source of Funds (Liabilities) → Current Liabilities → Duties and Taxes → SST Payable` |
| `Books Account` count | **78** (was 77) |
| Account list filter `account_type = Tax` | now two rows: the group `Duties and Taxes` and the ledger `SST Payable` |

## 4.5 Lab 4.2 — Opening capital: `JV-1001`

`/books` → Accounting → **Journal Entry** *(Books Manager only — Module 1)*.

| Header | Value |
|---|---|
| Voucher Type | **Journal Entry** |
| Posting Date | `01/09/2026` |
| User Remark | `Opening capital and bank balance` |

| Row | Account | Debit | Credit |
|---|---|---|---|
| 1 | `Maybank Current` | 20,000.00 | 0 |
| 2 | `Capital Stock` | 0 | 20,000.00 |

Header footer shows **Total Debit 20,000.00 / Total Credit 20,000.00**. Save → **Submit**.

### Expect

| Check | Expect |
|---|---|
| Document name | `JV-1001` |
| Status | **Submitted** |
| General Ledger filtered to `Maybank Current` | 01/09/2026 · JV-1001 · debit 20,000.00 |
| General Ledger filtered to `Capital Stock` | 01/09/2026 · JV-1001 · credit 20,000.00 |
| Trial Balance as of 31/10/2026 | `Maybank Current` 20,000.00 Dr · `Capital Stock` 20,000.00 Cr · totals equal |

### Try the failure modes (✎ then discard)

| Attempt | Expect |
|---|---|
| Dr 20,000 / Cr 19,000 and Save | refused — debits and credits must match |
| Post to the group `Current Assets` instead of a ledger | refused — a group cannot hold an entry |
| Same account on both sides with the same amount | allowed by Books' balance check; do not use it — netting hides detail |

## 4.6 Opening balances — the professional pattern

For a real go-live you need **every** balance, not just cash:

1. One journal dated the day before go-live.
2. Debit each asset (bank, debtors, stock) and credit each liability (creditors, tax).
3. Balance the difference to **`Opening Balance Equity`** (Equity) — *not* to profit.
4. Enter debtors/creditors as **party-wise** rows so the subledger matches the control
   account. In Books the party ledger is the same account with a `party` on the row;
   a bulk journal without parties will make the ageing reports disagree with the GL.

`Temporary Opening` exists in the chart for the ERPNext-style two-step opening (post
everything against it, then clear it to equity). Books does not automate that step — if
you use the account, document the second journal, because **Books will not remind you**.

## 4.7 Common failures

| Message | Cause |
|---|---|
| *Cannot create ledger under a non-group account* | parent is a ledger, not a group |
| *Set a discount account in Books Company* | `default_discount_account` empty and the invoice has an invoice-level discount |
| Account missing from a Link search | it is a group, or its `root_type` is wrong for the field (e.g. picking an Income account for `paid_to`) |
| Journal Entry missing from the menu | you are not a Books Manager |

## 4.8 🔧 Technical notes

* Chart data lives in `frappe_books/data/charts/*.json` — `standardCOA.json` plus
  `ae ca ch fr gt hu id in mx ni nl sg`. That is the full set; **there is no Malaysian
  chart**, which is why Module 2 insists on the Standard chart.
* `coa.py:load_chart(name)` flattens the nested JSON into `ChartAccount` rows in tree
  order; `ensure_chart` then inserts parents before children.
* A journal's ledger rows are produced by `books_journal_entry.get_ledger_posting()`
  and posted through the same `post_invoice_ledger` primitive as invoices — one balanced
  set of `Books Ledger Entry` rows per voucher (Module 16).
* `Books Ledger Entry` fields you will query in Module 14: `account`, `party_type`,
  `party`, `debit`, `credit`, `voucher_type`, `voucher_no`, `posting_date`, `against`.
* Deleting an account with ledger rows is blocked; the safe path is to *disable* it
  (rename with a `[OLD]` prefix is **not** safe — the ledger keeps the old name and the
  reports split).

## 4.9 Exercises ✍

1. Add `SST Payable` twice — once under `Duties and Taxes` with type `Tax`, once under
   `Current Liabilities` with no type. Which one can the `SST 8%` tax template use, and why?
2. The client wants opening debtors of 12,500 across 4 customers. Write the journal
   structure (accounts, party, amounts) and say what report proves it.
3. Which `Books Company` field would you inspect first for each error:
   *"Set a discount account…"*, *"Set a write-off account…"*, a stock entry that cannot post?

---

**Next:** Module 5 — items, UOMs, batches, serial numbers, taxes and parties.
