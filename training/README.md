# Frappe Books — Consultant Training Course

A hands-on course for **functional** and **technical** consultants, built on
**Frappe Books v16.1.0** (Frappe Framework 16) as it exists in this repository.

The official [Getting Started with Frappe Books](https://docs.frappe.io/books/getting-started-with-frappe-books)
document covers five things: opening `/books`, running the setup wizard, the Get
Started page, Draft → Submitted → Cancelled, and a "next steps" list. This course
uses that document as the baseline and takes it all the way to a closed, reconciled
month: every lab has **exact data to key in** and **exact output to expect** —
document totals, ledger lines, stock valuation, report figures and statuses.

---

## 1. Who this is for

| Role | What they take away |
|---|---|
| **Functional consultant** | Configuration order, chart of accounts, tax and item setup, the purchase → sale → pay cycle, returns, POS shifts, and how to read General Ledger / Trial Balance / P&L / Balance Sheet / Stock reports. |
| **Technical consultant** | Everything above **plus** doctype and field maps, naming series, the ledger and stock posting code paths (`InvoicePosting`, `post_stock_value`, FIFO valuation), the Frappe REST/whitelisted API, roles and permissions, print formats, backups and upgrades. |

Modules 1–14 are the functional core (technical consultants do them too — you cannot
debug what you cannot operate). Modules 15–17 are technical-only. Module 18 is the
closing exam.

**Time budget:** about 15 classroom hours (2 days) for the functional path;
about 21 hours (3 days) with the technical modules and the exam.

---

## 2. How the "expected output" figures in this course were produced

There is no MariaDB, Redis or Python 3.14 in the environment this course was
authored in, so Books was **not** executed to capture screenshots. Every number is
derived from the source of truth — the application code — and cross-checked with a
reference ledger model:

| Figure | Derived from |
|---|---|
| Row `rate`/`amount`, discounts, totals | `frappe_books/accounting/invoice.py` (`_calculate_row`, `_calculate_totals`, `gross_amount`, `item_discount`) |
| Tax amounts, charge types, item-tax overrides | `frappe_books/accounting/taxes.py` |
| Journal sides (which account is Dr/Cr) | `invoice.py` `InvoicePosting`, `accounting/ledger.py`, `accounting/payment.py` |
| Stock value, FIFO layers, COGS | `inventory/stock_posting.py`, `inventory/valuation.py` |
| Company/settings defaults created by setup | `setup_service.py`, `coa.py` |
| Statuses | `status.py` (`Paid`, `Unpaid`, `Partly Paid`, `Credit Note Issued`, `Return`, …) |
| Numbering | `series.py` (`SINV-`, `PINV-`, `SHPM-`, `PREC-`, `SMOV-`, `PAY-`, `JV-`, `SQUOT-`) |

`training/data/expected-results.json` holds the same figures in machine-readable
form; every document in the course also balances when the model is re-run
(each voucher's debits equal its credits, and the Trial Balance closes).

**Tolerance to allow when you grade:** amounts exact to 2 dp. Two things are
*not* fixed and must not be marked wrong — **document names** (they follow the
site's series counter, so a site that already has documents will start higher) and
**batch/serial names** (series-driven, e.g. `CUP-1001`).

---

## 3. The demo company

Everything in this course is keyed into one company. Build it exactly like this.

| Setting | Value |
|---|---|
| Company name | **Little Oven Supply** |
| Country | **Malaysia** |
| Currency | **MYR** (RM) |
| Chart of accounts | **Standard Chart of Accounts** (Books ships no Malaysian chart — see Module 4) |
| Bank name | **Maybank Current** |
| Fiscal year | **01/01/2026 – 31/12/2026** |
| Login / password | `Administrator` (course default) |
| First document numbers | `SINV-1001`, `PAY-1001`, `JV-1001` … (series seeded with `start=1001`, `pad_zeros=4`) |
| Date format in the UI | `dd/mm/yyyy` (set by the wizard from the country) |

### Masters

| Item code | Name | Type | Stock | Rate | Tracking |
|---|---|---|---|---|---|
| `LT-CUP50` | Paper Cup 8oz (Pack of 50) | Product | Yes, UOM **Pack** | 24.00 | **Batch** (`CUP-.####`), 1 Box = 12 Pack |
| `LT-BEAN1KG` | Arabica Beans 1 kg | Product | Yes, UOM **Kg** | 78.00 | none (FIFO demo) |
| `LT-GRINDX1` | Grinder X1 | Product | Yes, UOM **Unit** | 640.00 | **Serial** (`GRND-.####`) |
| `LT-SVC-INST` | Installation & Setup | Service | No | 120.00 | — |

| Party | Type |
|---|---|
| `Kopi Hub` | Customer |
| `Sunrise Cafe` | Customer — invoiced on the **Wholesale** price list |
| `Walk-in Customer` | Customer (POS default) |
| `Nusantara Supplies` | Supplier |

Tax: **`SST 8%`** — Sales tax template, one row, *On Net Total*, 8 %, account **`SST Payable`**
(a new leaf under *Duties and Taxes*). Applied to every sales invoice and POS sale.
Purchases are entered **without** tax in this course so that stock value stays clean.

### The transactions you will enter

| # | Created in | Date | Document | Party | Amount |
|---|---|---|---|---|---|
| 1 | M4 | 01/09/2026 | `JV-1001` | — | 20,000.00 |
| 2 | M6 | 02/09/2026 | `PREC-1001` | Nusantara Supplies | 5,520.00 |
| 3 | M6 | 03/09/2026 | `PINV-1001` | Nusantara Supplies | 5,520.00 |
| 4 | M6 | 10/09/2026 | `PAY-1001` | Nusantara Supplies | 5,520.00 |
| 5 | M6 | 12/10/2026 | `PREC-1002` | Nusantara Supplies | 2,080.00 |
| 6 | M6 | 13/10/2026 | `PINV-1002` | Nusantara Supplies | 2,080.00 |
| 7 | M6 | 14/10/2026 | `PAY-1002` | Nusantara Supplies | 2,080.00 |
| 8 | M7 | 15/09/2026 | `SINV-1001` + `SHPM-1001` | Kopi Hub | 2,052.00 |
| 9 | M7 | 20/10/2026 | `SINV-1002` + `SHPM-1002` | Sunrise Cafe (Wholesale list) | 3,058.56 |
| 10 | M8 | 25/09/2026 | `PAY-1003` | Kopi Hub | 2,052.00 |
| 11 | M8 | 22/10/2026 | `PAY-1004` | Sunrise Cafe | 3,058.56 |
| 12 | M9 | 25/10/2026 | `SINV-1003` + `SHPM-1003` | Kopi Hub — return | −691.20 |
| 13 | M9 | 28/10/2026 | `PAY-1005` | Kopi Hub — refund | 691.20 |
| 14 | M10 | 30/10/2026 | `SMOV-1001` | — (damaged stock) | 30.00 |
| 15 | M12 | 05/10/2026 | `SINV-1004` + `SHPM-1004` + `PAY-1006` | Walk-in (POS) | 77.76 |

Document numbers follow the **order you create** documents, not their posting dates — which
is why the 05/10 POS sale is the last invoice you enter. Do the modules in order and your
numbers will match this table.

The headline result of the whole course, checked in Module 14:

```
Sales (net of returns)      4,164.00
Cost of Goods Sold          2,729.00
Stock Adjustment               30.00
Net profit                  1,405.00

Assets                     21,738.12   (Bank 16,819.36 · Cash 77.76 · Stock 4,841.00)
SST Payable                   333.12
Capital Stock              20,000.00
Current year earnings       1,405.00
Assets = Liabilities + Equity   21,738.12 ✔
```

---

## 4. Conventions used in every module

* **Key in** tables give field values in the order the form shows them. Leave every
  field not listed at its default.
* **Expect** tables give the result. *Assert* rows are checkpoints — if one fails,
  stop and fix it before moving on; every later module depends on it.
* **🔁 Side lab** — a lab that changes the ledger. Do it on a second site, or after
  you have captured the Module 14 checkpoint, or the headline figures above will no
  longer match. Each side lab tells you its own expected delta.
* **✎ Draft-only lab** — leave the document in **Draft**, or delete it afterwards.
  Drafts never reach the ledger, so the checkpoint stays valid.
* Money is always **MYR, 2 dp**. A negative amount means a credit note / return.
* Dates are shown `dd/mm/yyyy` because that is what the UI will show for a
  Malaysian company; the API and JSON fixtures use `yyyy-mm-dd`.
* "Submit" is the confirmation dialog you get from the header button **Save →
  Submit**; `…` opens **Cancel** / **Delete** (Module 7 revisits this).

---

## 5. Course map

| Module | File | Role | Time |
|---|---|---|---|
| 1 | `01-installation-and-roles.md` | both | 60 min |
| 2 | `02-setup-wizard.md` | both | 45 min |
| 3 | `03-settings-and-defaults.md` | both | 45 min |
| 4 | `04-chart-of-accounts.md` | both | 60 min |
| 5 | `05-masters-items-taxes-parties.md` | both | 75 min |
| 6 | `06-purchases.md` | both | 75 min |
| 7 | `07-sales.md` | both | 90 min |
| 8 | `08-payments-and-outstanding.md` | both | 60 min |
| 9 | `09-returns.md` | both | 60 min |
| 10 | `10-inventory.md` | both | 75 min |
| 11 | `11-pricing-and-discounts.md` | both | 60 min |
| 12 | `12-point-of-sale.md` | both | 75 min |
| 13 | `13-multi-currency.md` | both | 45 min |
| 14 | `14-reports-and-checkpoint.md` | both | 90 min |
| 15 | `15-technical-doctypes-and-api.md` | technical | 90 min |
| 16 | `16-technical-ledger-and-stock.md` | technical | 90 min |
| 17 | `17-technical-extending-and-operations.md` | technical | 75 min |
| 18 | `18-exam.md` | both | 75 min |

Data:
* `training/data/demo-dataset.json` — the whole course dataset (settings, masters,
  documents) as fixtures you can replay through the API or `bench execute`.
* `training/data/expected-results.json` — every expected figure: per-document ledger rows,
  stock ledger, stock balance, trial balance, P&L, balance sheet, POS shift.
* `training/data/build_expected.py` — the generator. It models the posting rules of
  `invoice.py`, `taxes.py`, `payment.py`, `stock_posting.py`, `valuation.py` and `status.py`,
  asserts that every voucher balances, and rewrites both JSON files:

  ```bash
  python3 training/data/build_expected.py
  ```

### How this course relates to the official Getting Started page

| Official section | Covered in | Taken further by |
|---|---|---|
| Open Frappe Books (`/books`, Books role) | Module 1 | roles matrix read from the doctype JSON |
| Set Up Your Organization | Module 2 | every record the wizard writes, and the ones it leaves empty |
| Get Started page | Modules 2–3 | which task cards clear when, and why inventory features are hidden |
| Save and Submit Documents | Module 7.5 | what cancel actually posts, on a quotation so the checkpoint survives |
| Next Steps (chart of accounts, taxes, items, opening balances) | Modules 4–6 | exact accounts, tax template, opening entry with party rows |
| *(not in the docs)* | Modules 7–18 | the full purchase→sale→pay→return→POS cycle with ledger, FIFO valuation, reports, API, internals, exam |

---

## 6. Getting a site to practise on

Three supported routes — pick one and confirm you can open `https://<your-site>/books`
before Module 2:

1. **This repository's scripts** (fastest, self-hosted, zero licence cost):
   `deploy/README.md` → `deploy/install-books.sh` (Linux/macOS/WSL2) or
   `deploy/install-books.ps1` (Windows, which provisions WSL2 for you). They install
   `frappe-bench`, Frappe `version-16`, Books **v16.1.0**, and create the site
   `books.localhost` with `/books` enabled.
2. **Docker** — the Frappe Docker images, if your laptop already has Docker Desktop.
3. **Frappe Cloud** — fastest to start, but it is a paid subscription.

> **Windows note.** `bench` itself does not support Windows natively; use WSL2 (what
> `install-books.ps1` does), Docker Desktop, or a Linux VM. Do **not** use the archived
> Electron desktop app (`frappe/books`, last release 0.36.0, archived October 2026) —
> it is a different product and its screens do not match this course.

**Sizing:** 8 GB RAM minimum, 16 GB comfortable (MariaDB + Redis + 2 gunicorn workers).

---

## 7. Grading

| Component | Weight |
|---|---|
| Module checkpoint assertions (Modules 2–14) | 40 % |
| Module exercises (marked ✍) | 20 % |
| Exam, part A — functional scenarios | 20 % |
| Exam, part B — technical | 20 % |

A pass requires **every** Module 14 checkpoint to hold: the Trial Balance's closing
columns must balance at **24,497.12 / 24,497.12** (its period columns total
**58,158.04** each), net profit must be **1,405.00**, and stock must value at **4,841.00**. Those three numbers are the proof that the whole chain —
setup, masters, tax, FIFO, posting, returns — is correct.
