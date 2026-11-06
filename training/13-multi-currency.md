# Module 13 — Multi-Currency

**Roles:** 👤 + 🔧 · **Time:** 45 min
**Prerequisite:** Module 12

## 13.1 Objectives

1. Sell in a foreign currency and read both the document currency and the base amounts.
2. Know where Books gets its exchange rate, and what happens when it cannot.
3. Predict the ledger when the invoice and the payment use different rates.

## 13.2 How Books handles currency

* Every document has `currency` (document currency) and `conversion_rate` (to the
  company currency). `base_grand_total = round(grand_total × conversion_rate)`.
* **Ledger rows are always in the company currency** — `InvoicePosting` multiplies every
  amount by `conversion_rate` before posting. The party ledger, the control accounts and
  therefore every report are MYR.
* The rate comes from `get_exchange_rate(currency, company_currency, date)` in
  `frappe_books/currency.py`, which calls **`https://api.vatcomply.com/rates`**, caches the
  answer for 24 h and retries a failed lookup after 10 min. Only the currency codes and
  the date leave the server.
* If the lookup fails the rate is 0 and the invoice refuses to save:
  *Set an exchange rate from SGD to MYR above zero.* — type the rate by hand. There is no
  exchange-rate table to maintain, so an **air-gapped site must key rates manually**.
* A price list has its own currency; a document can only use a list in its own currency
  (`validate_price_list` → *Price List … is not for …* / currency mismatch errors).

## 13.3 Lab 13.1 — prepare SGD

| Step | Key in | Expect |
|---|---|---|
| 1 | Desk → Currency → open **SGD** → **Enabled ✔** → Save | SGD appears in currency pickers (`enable_currency` is enforced on the wizard path; doing it by hand needs the same flag) |
| 2 | Settings → Price List → *Add*: `Singapore (SGD)`, currency **SGD**, Selling ✔ | saved |
| 3 | Item Price → *Add*: `LT-BEAN1KG`, list `Singapore (SGD)`, price `30.00` | saved |
| 4 | Customer → *Add*: `Brew Co (SG)`, Default Accounts `Debtors`, **Default Currency `SGD`** | saved |

## 13.4 🔁 Lab 13.2 — an SGD invoice (after the Module 14 checkpoint)

New Sales Invoice, `Brew Co (SG)`, date `29/10/2026`:

| Field | Value |
|---|---|
| Currency | **SGD** |
| Conversion Rate | **3.5000** (type it; do not accept a fetched rate for a reproducible demo) |
| Selling Price List | `Singapore (SGD)` |
| Taxes and Charges Template | `SST 8%` |
| Row | `LT-BEAN1KG` qty `1`, rate **30.00** |

### Expect

| Field | Expect |
|---|---|
| `net_total` | 30.00 SGD |
| `total_taxes_and_charges` | 2.40 SGD |
| `grand_total` | **32.40 SGD** |
| `base_grand_total` | **113.40** MYR (32.40 × 3.5) |
| `outstanding_amount` | 32.40 (document currency) |
| COGS | 52.00 MYR (the FIFO layer) — stock is always valued in company currency |

**Ledger (company currency):**

| Account | Debit | Credit |
|---|---|---|
| `Debtors` | 113.40 | |
| `Sales` | | 105.00 |
| `SST Payable` | | 8.40 |

Now receive 32.40 SGD into a bank account with the **same** rate 3.5000:

| Account | Debit | Credit |
|---|---|---|
| `Maybank Current` (or an SGD bank account) | 113.40 | |
| `Debtors` | | 113.40 |

`Debtors` is clean again — in base currency.

## 13.5 The exchange-difference question

If the customer pays when the rate is **3.6000**, the money received is worth more:

| Account | Debit | Credit |
|---|---|---|
| Bank | 116.64 | |
| `Debtors` | | 113.40 |
| `Exchange Gain/Loss` | | **3.24** |

Books stores the payment's own `conversion_rate` and its `realised_taxes`; the party
account must clear at the **invoice's** base amount, so the balance lands on
`Exchange Gain/Loss` (an Indirect Expense account, so a credit there is income). Verify the
figure on your build: enter the payment with `conversion_rate` 3.6000 and read the resulting
ledger rows before you quote this line to a client — exchange handling is the one place
where the exact posting depends on how the payment was created (mapped from the invoice vs
typed from scratch).

## 13.6 Common failures

| Message | Cause |
|---|---|
| *Set an exchange rate from SGD to MYR above zero.* | rate 0 — the online lookup failed, or you cleared it |
| *Price List … is not for Selling.* | the list is flagged buying only |
| Currency mismatch on the price list | list currency ≠ document currency |
| `Debtors` never clears | the payment was posted in a different currency without a rate |
| Amounts 100× too big | rate typed as 0.035 instead of 3.5 (SGD→MYR) |

## 13.7 🔧 Technical notes

* `invoice.py:435-437` sets `conversion_rate = 1` for a company-currency document, else
  fetches via `get_exchange_rate`. `base_grand_total` is rounded once, from the rounded
  `grand_total`.
* `LedgerPosting.exchange_rate` multiplies each row's amount; tax rows too
  (`payment.py:366` uses `abs(tax.tax_amount) * conversion_rate`).
* Currency precision comes from Babel CLDR (`currency.py:currency_precision`), written to
  `System Settings.currency_precision` by the wizard — a 3-decimal currency (KWD) changes
  every rounding boundary in this course.
* The rate cache key is `books_exchange_rate:<date>:<from>:<to>`; to force a refetch,
  `bench --site <site> clear-cache`.

## 13.8 Exercises ✍

1. A 1,000.00 USD invoice at 4.20, paid at 4.35. Give every ledger amount, including the
   exchange difference, and say which report shows it.
2. Why is a price list tied to a currency, and what would break if Books allowed a MYR list
   on an SGD invoice?
3. Your client's site has no outbound internet. List every step needed to invoice in SGD.

---

**Next:** Module 14 — the reports, and the checkpoint that proves the whole course.
