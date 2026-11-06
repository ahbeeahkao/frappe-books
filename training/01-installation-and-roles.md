# Module 1 — Installation, Site and Roles

**Roles:** 👤 functional + 🔧 technical · **Time:** 60 min
**Prerequisite:** none

## 1.1 Objectives

By the end of this module you can

1. get a working Frappe Books v16 site and open `/books`;
2. explain what `/books` is (a single-page app served by the Frappe site, not a
   separate server);
3. create the four user types this course uses and predict what each may do;
4. explain *why* a Cashier cannot open a Journal Entry — from the doctype JSON,
   not from opinion.

---

## 1.2 What you are actually installing

Frappe Books v16 is a **Frappe Framework app** (`frappe_books`) served by the same
bench/gunicorn/nginx that serves the Desk. It is *not* the archived Electron desktop
application (`frappe/books`, last release 0.36.0, archived 2 October 2026) — that
product has different screens and does not match this course.

| Fact | Value (verify with `cat pyproject.toml`) |
|---|---|
| App version | `16.1.0` |
| Requires | `frappe >=16.36.0,<17.0.0` |
| Python | `>=3.14,<3.15` |
| Database | **MariaDB only** (there is no Postgres support in v16) |
| SPA entry point | `https://<site>/books` |
| Desk entry point | `https://<site>/app` |

> **Why Python 3.14?** Frappe 16 and Books 16 use 3.14-only syntax (generic
> `class LocalProxy[T]`, `type X = …`). On 3.13 or older the app will not even
> import. If your installer says "installed fine" but `bench start` explodes at
> import time, check `python3 --version` first.

---

## 1.3 Lab 1.1 — Bring up the site

Pick **one** route.

### Route A — this repository's installer (recommended, free)

| Key in (shell) | Expect |
|---|---|
| `bash deploy/install-books.sh` | Installs `mariaDb`, `redis`, `bench`, Frappe `version-16`, Books `v16.1.0`; ends with the site URL |
| `cd ~/frappe-bench && bench start` | Gunicorn + socketio + watch start; `bench` prints the site URL |
| open `https://books.localhost/books` (or `http://books.localhost:8000/books` on a bench dev server) | Books **Setup Wizard** opens (first run), or the Dashboard on a configured site |

### Route B — Docker

| Key in | Expect |
|---|---|
| `git clone https://github.com/frappe/frappe_docker && cd frappe_docker` | repo present |
| follow its "Frappe Books" app list, adding `https://github.com/frappe/frappe-books` at tag `v16.1.0` | site up with Books installed |
| `docker compose exec backend bench --site <site> install-app frappe_books` | `Installing frappe_books…` then success |

### Route C — Frappe Cloud

Create a site, install **Frappe Books**, open `https://<site>/books`.

### Assert (all routes)

| Check | Expect |
|---|---|
| `bench --site <site> list-apps` | `frappe` and `frappe_books` |
| `bench --site <site> execute frappe_books.permissions.has_app_permission` | `True` for Administrator |
| Log in as `Administrator` and open `/books` | the Books SPA loads, with the "Get Started" or Dashboard screen |
| Open `/app` | the standard Frappe Desk — the *same* database, a different UI |

**Failure guide**

| Symptom | Cause |
|---|---|
| `SyntaxError` / `TypeError` at import | wrong Python (needs 3.14) |
| 404 at `/books` | `frappe_books` not installed on that site, or assets not built (`bench build --app frappe_books`) |
| 403 / blank page for a non-admin user | that user cannot read any Books doctype — see 1.4 |

---

## 1.4 Lab 1.2 — Create the users and roles this course uses

Books ships **three** application roles plus Frappe's `System Manager`:

| Role | Intended for |
|---|---|
| `Books Manager` | the consultant / finance lead — full control including journals, accounts and settings |
| `Books User` | accounts clerk — sales and purchase documents, no journals, no deletes |
| `Books Cashier` | till operator — POS shifts and sales invoices only |
| `System Manager` | Frappe administrator (same rights as Books Manager, plus Desk) |

Create three users in **Desk → User** (`/app/user/new`):

| User | First name | Roles to tick |
|---|---|---|
| `manager@littleoven.test` | Siti (Manager) | `Books Manager` |
| `clerk@littleoven.test` | Aiman (Clerk) | `Books User` |
| `cashier@littleoven.test` | Devi (Cashier) | `Books Cashier` |

Then set **Role Permissions** only if you need to loosen something — for this course
the shipped set is enough.

### Expect — the permission matrix you must memorise

Read straight from the doctype JSON (`permissions` array). `read/write/create/submit/cancel/delete/amend`:

| Document | System Manager | Books Manager | Books User | Books Cashier |
|---|---|---|---|---|
| Sales Invoice | all | all | r/w/c/s/cancel/amend | r/w/c/s |
| Purchase Invoice | all | all | r/w/c/s/cancel/amend | — |
| Payment Entry | all | all | r/w/c/s/cancel/amend | **read only** |
| **Journal Entry** | all | all | **—** | **—** |
| Delivery Note / Stock Entry | all | all | r/w/c/s/cancel/amend | — |
| Item | r/w/c/**delete** | r/w/c/delete | r/w/c/delete | read |
| Customer | r/w/c/delete | r/w/c/delete | r/w/c/delete | r/w/c (**no delete**) |
| Account (chart) | r/w/c/delete | r/w/c/delete | — | — |
| Company / Accounting Settings | r/w/c/delete | r/w/c/delete | **read** | read |
| POS Opening / Closing Entry | all | all | r/w/c/s/cancel/amend | r/w/c/s |

Two rows matter most in practice:

* **Only a Books Manager can post a Journal Entry.** Opening balances, payroll
  accruals, depreciation — all journals — are therefore a manager's job. This is the
  single most common "why can't I see it?" support ticket after go-live.
* **A Books Cashier cannot cancel anything and cannot touch purchases.** A wrong POS
  sale has to be returned by a User/Manager, or voided through a credit note.

---

## 1.5 Lab 1.3 — Prove the boundaries

Log in as each user in a private window and try the following. (Frappe answers a
denied action with a generic *Insufficient Permission* / *Not permitted* error — the
exact wording is Frappe's, not Books'.)

| Log in as | Do this | Expect |
|---|---|---|
| `cashier@…` | open `/books` | loads |
| `cashier@…` | Sales → Journal Entry | the doctype is not in the sidebar and `/list/JournalEntry` refuses to render |
| `cashier@…` | open a submitted Sales Invoice → `…` | **Cancel** is absent |
| `clerk@…` | open a submitted Sales Invoice → `…` → Cancel | allowed (Books User has `cancel`) |
| `clerk@…` | Items → open `LT-CUP50` → `…` → Delete | delete is available to Books User too — but a submitted document cannot be deleted, only cancelled |
| `manager@…` | Accounting Settings | editable (others get read-only) |

### Assert

| Check | Expect |
|---|---|
| `bench --site <site> roles` or Desk → Role list | `Books Manager`, `Books User`, `Books Cashier` exist (created as fixtures) |
| Cashier's sidebar | Sales, Purchases (read), Items, Parties, POS — **no** Accounting/Journal |

---

## 1.6 🔧 Technical notes

* `frappe_books/permissions.py:has_app_permission()` returns `True` when the user can
  read **any** doctype whose module is `Frappe Books`. That is what makes the Books
  icon appear in the Frappe app switcher — there is no separate "Books user" flag.
* Rights are ordinary Frappe Role Permissions shipped as doctype fixtures; there is no
  parallel permission model. Changing them means editing role permissions, and the
  change is upgrade-safe only if you do it through **Role Permission Manager** or a
  custom fixture, not by editing the JSON in `apps/`.
* `check_preview_permission(doc)` (same file) is why the form's `preview()` buttons
  (which compute totals without saving) still enforce *create*/*write* rights.
* The SPA talks to the site through `/api/method/…` and `/api/resource/…` (Module 15).
  Anything you can do in `/books` you can do with a REST call using the same user's
  credentials — the role matrix above therefore applies to your integrations too.

## 1.7 Exercises ✍

1. A customer-facing pricing rule must be approved by finance before it goes live.
   Which role must the approver hold, and why can it not be `Books User`?
2. Your client wants "read-only auditors". Which shipped role is closest, and what
   two extra restrictions would you apply with Role Permission Manager?
3. The client's server has Python 3.13. Can you deploy Books 16 to it? Justify in one
   sentence with a code reference.

---

**Next:** Module 2 — the Setup Wizard, and exactly what it writes to the database.
