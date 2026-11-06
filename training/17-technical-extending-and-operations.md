# Module 17 — Technical: Extending and Operating

**Roles:** 🔧 technical · **Time:** 75 min
**Prerequisite:** Module 16

## 17.1 Objectives

1. Add fields, print formats and validation without forking the app.
2. Move data in and out safely.
3. Run, back up and upgrade a Books site — and know the deployment facts that break projects.

## 17.2 Adding a field (the upgrade-safe way)

Module 6 noted that a purchase invoice has no supplier-bill-number field. Add one:

| Step | Do |
|---|---|
| 1 | Desk → **Customize Form** → DocType `Books Purchase Invoice` |
| 2 | Add field: Label `Supplier Invoice No`, fieldname `custom_supplier_invoice_no`, type `Data`, insert after `supplier` |
| 3 | Save (writes a `Custom Field` + a Property Setter; stored in the database, not in `apps/`) |
| 4 | It now appears in `/books` too — the SPA reads its schema from `get_books_meta`, which includes custom fields |

**Never** edit `frappe_books/frappe_books/doctype/*/*.json` under `apps/`: `bench update`
overwrites it. Export customisations as fixtures if you need them reproducible:

```bash
bench --site <site> export-fixtures --app frappe_books   # writes hooks-configured fixtures
```

## 17.3 Print formats

`Books Print Settings` holds the branding; the Jinja templates ship as
`Business - Sales Invoice`, `Business - Payment`, `Business-POS - Sales Invoice`, etc., and
are assigned per doctype in `Books Defaults` (`sales_invoice_print_template`, …).

```bash
# render a format without printing, to test it
curl -s -H "$AUTH" "$SITE/api/method/frappe_books.printing.preview_print_format?doctype=Books%20Sales%20Invoice&name=SINV-1001"
```

A custom format is a normal Frappe Print Format; put the company logo, the tax breakdown and
`amount_in_words` (Books Print Settings) in it. Test with a **return** invoice — negative
amounts and `is_return` are where custom templates break.

## 17.4 Validation without forking

Three levels, in order of preference:

| Level | Tool | Survives upgrade |
|---|---|---|
| Mandatory / uniqueness / defaults | Customize Form (property setters) | yes |
| Server-side rules | **Server Script** (`DocType Event`, `before_save`) or a small custom app importing `frappe_books` helpers | yes (custom app) |
| Code change | patch to `apps/frappe_books` | **no** — forks the product |

Example server script on `Books Sales Invoice` (`before_save`):

```python
if doc.get("custom_po_reference") is None and doc.docstatus == 0:
    frappe.throw("Enter the customer's PO reference before submitting.")
```

Do **not** validate accounting numbers in a script: `calculate()` already ran, and
re-implementing it is how double-taxation bugs get shipped.

## 17.5 Data in and out

| Direction | Method |
|---|---|
| Out — documents | `GET /api/resource/<Doctype>?fields=[...]&limit_page_length=0` (mind the limit, page it) |
| Out — ledger | query `Books Ledger Entry` (never scrape reports) |
| Out — stock | `Books Stock Ledger Entry` + `stock_queue` for the layers |
| In — masters | `Data Import` (Desk) or `POST /api/resource/Books Item` per record |
| In — opening balances | one Journal Entry with party rows (Module 4.6) |
| In — historic invoices | **do not**. Import a trial balance as one journal, dated the day before go-live, and keep history in the old system |

Idempotency for imports: match on `item_code` / party name first (`GET`), then create only
what is missing. Books will happily create `Kopi Hub-1` if you post a duplicate name.

## 17.6 Backup, restore, upgrade

```bash
bench --site books.localhost backup --with-files     # or: deploy/backup-books.sh
bench --site books.localhost restore /path/to/db.sql.gz --with-public-files ...
bench update --reset                                 # upgrade bench, frappe and all apps
bench --site books.localhost migrate                 # runs patches.txt
```

| Fact | Consequence |
|---|---|
| `pyproject.toml`: `frappe >=16.36.0,<17.0.0`, `requires-python >=3.14,<3.15` | pin both; a Python 3.13 host cannot run this app |
| MariaDB only | do not promise Postgres |
| Single company per site | multi-entity = multiple sites, multiple databases |
| `patches.txt` runs on `migrate` | schedule a maintenance window; back up first |
| Number series live in `tabSeries` | after a restore, new documents continue from the restored counter |
| Exchange rates call `api.vatcomply.com` | an air-gapped site must key rates (Module 13) |
| Archived desktop app (`frappe/books`, 0.36.0) | **no migration path** — different product, different schema |

## 17.7 Operating a live site

| Concern | Practice |
|---|---|
| Roles | integrations get their own user with an API key and the smallest role (Module 1 matrix) |
| Journal Entries | Books Manager only — enforce separation of duties at the role level |
| Month-end | export Trial Balance + Stock Balance, sign, archive; Books has no period lock |
| Monitoring | `bench doctor`, `/api/method/ping`, MariaDB slow log, Redis memory |
| Capacity | 8 GB RAM / 2 vCPU for a small business; gunicorn `cpu_count()*2+1`, `background_workers 1` |
| Upgrades | staging site first, run the Module 14 checkpoint there, then production |
| Support archaeology | every rule in this course cites a file and a function — quote those in tickets, not screenshots |

## 17.8 Exercises ✍

1. Add `custom_supplier_invoice_no` and prove it survives `bench update` (where is it stored?).
2. Write the export script that produces a monthly ledger extract, including party and
   against fields.
3. The client wants approval before any invoice above 10,000 is submitted, without changing
   the code. Design it with Frappe roles + workflow, and say where the status will show.

---

**Next:** Module 18 — the exam.
