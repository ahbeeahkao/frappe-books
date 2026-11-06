#!/usr/bin/env python3
"""Regenerate expected-results.json and demo-dataset.json for the Books training course.

This is a *reference model* of Frappe Books v16.1.0's posting rules, written so the
course's expected figures can be audited without a database:

  row maths          -> frappe_books/accounting/invoice.py  (_calculate_row, _calculate_totals)
  tax                -> frappe_books/accounting/taxes.py    (On Net Total)
  ledger sides       -> accounting/invoice.py InvoicePosting, accounting/payment.py
  stock value / FIFO -> inventory/stock_posting.py, inventory/valuation.py
  statuses           -> frappe_books/status.py
  numbering          -> frappe_books/series.py + setup.py (start 1001, 4 digits)

Run:  python3 training/data/build_expected.py
"""
import json
from collections import defaultdict, deque
from decimal import Decimal as D, ROUND_HALF_UP
from pathlib import Path

HERE = Path(__file__).parent
TAX_RATE = D("0.08")
COMPANY = "Little Oven Supply"
CURRENCY = "MYR"
BANK = "Maybank Current"
SST = "SST Payable"


def money(x) -> str:
    return str(D(x).quantize(D("0.01"), rounding=ROUND_HALF_UP))


def r(x) -> D:
    return D(x).quantize(D("0.01"), rounding=ROUND_HALF_UP)


class Books:
    def __init__(self):
        self.ledger = []          # (date, voucher, account, debit, credit)
        self.stock_ledger = []    # dict rows
        self.layers = defaultdict(deque)   # item -> deque[[qty, rate]]
        self.balances = defaultdict(lambda: [D(0), D(0)])
        self.docs = {}

    # ---------------------------------------------------------------- postings
    def post(self, date, voucher, account, debit=0, credit=0):
        self.ledger.append(
            {"date": date, "voucher": voucher, "account": account,
             "debit": money(debit), "credit": money(credit)}
        )

    def receive(self, date, voucher, item, qty, rate):
        qty, rate = D(qty), D(rate)
        self.layers[item].append([qty, rate])
        self.balances[item][0] += qty
        self.balances[item][1] += qty * rate
        self._stock_row(date, voucher, item, qty, rate, qty * rate)
        self.post(date, voucher, "Stock In Hand", debit=qty * rate)

    def issue(self, date, voucher, item, qty):
        need, cost, out = D(qty), D(0), D(qty)
        used = []
        while need > 0:
            layer = self.layers[item][0]
            take = min(need, layer[0])
            cost += take * layer[1]
            used.append(f"{take.normalize()}@{money(layer[1])}")
            layer[0] -= take
            need -= take
            if layer[0] == 0:
                self.layers[item].popleft()
        self.balances[item][0] -= out
        self.balances[item][1] -= cost
        self._stock_row(date, voucher, item, -out, cost / out, -cost)
        self.post(date, voucher, "Stock In Hand", credit=cost)
        return cost, " + ".join(used)

    def _stock_row(self, date, voucher, item, qty, rate, value):
        self.stock_ledger.append({
            "date": date, "voucher": voucher, "item": item, "qty": money(qty),
            "rate": money(rate), "value": money(value),
            "balance_qty": money(self.balances[item][0]),
            "balance_value": money(self.balances[item][1]),
        })

    # ---------------------------------------------------------------- documents
    def sale(self, date, invoice, transfer, party, rows, price_list, cash=False,
             payment=None, payment_date=None):
        net, cogs, lines = D(0), D(0), []
        for item, qty, rate in rows:
            amount = r(D(qty) * D(rate))
            net += amount
            cost, how = self.issue(date, transfer, item, qty)
            cogs += cost
            lines.append({"item_code": item, "qty": qty, "rate": money(rate),
                          "amount": money(amount), "cost": money(cost), "fifo_layers": how})
        tax = r(net * TAX_RATE)
        total = r(net + tax)
        self.post(date, transfer, "Cost of Goods Sold", debit=cogs)
        self.post(date, invoice, "Debtors", debit=total)
        self.post(date, invoice, "Sales", credit=net)
        self.post(date, invoice, SST, credit=tax)
        status = "Unpaid"
        if payment:
            account = "Cash" if cash else BANK
            self.post(payment_date, payment, account, debit=total)
            self.post(payment_date, payment, "Debtors", credit=total)
            status = "Paid"
        self.docs[invoice] = {
            "doctype": "Books Sales Invoice", "posting_date": date, "party": party,
            "party_type": "Customer", "price_list": price_list, "items": lines,
            "net_total": money(net), "total_taxes_and_charges": money(tax),
            "grand_total": money(total), "status_after_submit": status,
            "delivery_note": transfer, "cogs": money(cogs),
            "payment": payment or "",
        }
        self.docs[transfer] = {
            "doctype": "Books Delivery Note", "posting_date": date,
            "against_sales_invoice": invoice, "value": money(cogs), "status": "Completed",
        }


def build():
    b = Books()
    # 1 — opening capital
    b.post("2026-09-01", "JV-1001", BANK, debit=20000)
    b.post("2026-09-01", "JV-1001", "Capital Stock", credit=20000)
    b.docs["JV-1001"] = {"doctype": "Books Journal Entry", "posting_date": "2026-09-01",
                         "voucher_type": "Journal Entry", "total_debit": "20000.00",
                         "status_after_submit": "Submitted"}

    # 2-4 — first purchase cycle
    for item, qty, rate in (("LT-CUP50", 100, 15), ("LT-BEAN1KG", 40, 48), ("LT-GRINDX1", 5, 420)):
        b.receive("2026-09-02", "PREC-1001", item, qty, rate)
    b.post("2026-09-02", "PREC-1001", "Stock Received But Not Billed", credit=5520)
    b.docs["PREC-1001"] = {"doctype": "Books Purchase Receipt", "posting_date": "2026-09-02",
                           "supplier": "Nusantara Supplies", "grand_total": "5520.00",
                           "status_after_submit": "Completed"}
    b.post("2026-09-03", "PINV-1001", "Stock Received But Not Billed", debit=5520)
    b.post("2026-09-03", "PINV-1001", "Creditors", credit=5520)
    b.docs["PINV-1001"] = {"doctype": "Books Purchase Invoice", "posting_date": "2026-09-03",
                           "supplier": "Nusantara Supplies", "grand_total": "5520.00",
                           "status_after_submit": "Paid"}
    b.post("2026-09-10", "PAY-1001", "Creditors", debit=5520)
    b.post("2026-09-10", "PAY-1001", BANK, credit=5520)
    b.docs["PAY-1001"] = {"doctype": "Books Payment Entry", "posting_date": "2026-09-10",
                          "payment_type": "Pay", "party": "Nusantara Supplies",
                          "paid_amount": "5520.00", "status_after_submit": "Submitted"}

    # 5 — sales invoice 1001 with automatic delivery note
    b.sale("2026-09-15", "SINV-1001", "SHPM-1001", "Kopi Hub",
           [("LT-CUP50", 20, 24), ("LT-BEAN1KG", 10, 78), ("LT-GRINDX1", 1, 640)], None)

    # 6 — payment from Kopi Hub
    b.post("2026-09-25", "PAY-1003", BANK, debit="2052")
    b.post("2026-09-25", "PAY-1003", "Debtors", credit="2052")
    b.docs["PAY-1003"] = {"doctype": "Books Payment Entry", "posting_date": "2026-09-25",
                          "payment_type": "Receive", "party": "Kopi Hub",
                          "paid_amount": "2052.00", "allocated_to": "SINV-1001",
                          "status_after_submit": "Submitted"}

    # 7-8 — second purchase cycle at a higher cost (new FIFO layer)
    b.receive("2026-10-12", "PREC-1002", "LT-BEAN1KG", 40, 52)
    b.post("2026-10-12", "PREC-1002", "Stock Received But Not Billed", credit=2080)
    b.docs["PREC-1002"] = {"doctype": "Books Purchase Receipt", "posting_date": "2026-10-12",
                           "supplier": "Nusantara Supplies", "grand_total": "2080.00",
                           "status_after_submit": "Completed"}
    b.post("2026-10-13", "PINV-1002", "Stock Received But Not Billed", debit=2080)
    b.post("2026-10-13", "PINV-1002", "Creditors", credit=2080)
    b.docs["PINV-1002"] = {"doctype": "Books Purchase Invoice", "posting_date": "2026-10-13",
                           "supplier": "Nusantara Supplies", "grand_total": "2080.00",
                           "status_after_submit": "Paid"}
    b.post("2026-10-14", "PAY-1002", "Creditors", debit=2080)
    b.post("2026-10-14", "PAY-1002", BANK, credit=2080)
    b.docs["PAY-1002"] = {"doctype": "Books Payment Entry", "posting_date": "2026-10-14",
                          "payment_type": "Pay", "party": "Nusantara Supplies",
                          "paid_amount": "2080.00", "status_after_submit": "Submitted"}

    # 9 — wholesale invoice (FIFO straddle on beans)
    b.sale("2026-10-20", "SINV-1002", "SHPM-1002", "Sunrise Cafe",
           [("LT-CUP50", 24, 22), ("LT-BEAN1KG", 32, 72)], "Wholesale")

    # 10 — Sunrise Cafe pays
    b.post("2026-10-22", "PAY-1004", BANK, debit="3058.56")
    b.post("2026-10-22", "PAY-1004", "Debtors", credit="3058.56")
    b.docs["PAY-1004"] = {"doctype": "Books Payment Entry", "posting_date": "2026-10-22",
                          "payment_type": "Receive", "party": "Sunrise Cafe",
                          "paid_amount": "3058.56", "allocated_to": "SINV-1002",
                          "status_after_submit": "Submitted"}

    # 11 — credit note + return delivery note
    b.receive("2026-10-25", "SHPM-1003", "LT-GRINDX1", 1, 420)
    b.post("2026-10-25", "SHPM-1003", "Cost of Goods Sold", credit=420)
    net, tax, total = D(640), r(D(640) * TAX_RATE), r(D(640) * (1 + TAX_RATE))
    b.post("2026-10-25", "SINV-1003", "Sales", debit=net)
    b.post("2026-10-25", "SINV-1003", SST, debit=tax)
    b.post("2026-10-25", "SINV-1003", "Debtors", credit=total)
    b.docs["SINV-1003"] = {"doctype": "Books Sales Invoice", "posting_date": "2026-10-25",
                          "party": "Kopi Hub", "is_return": True, "return_against": "SINV-1001",
                          "items": [{"item_code": "LT-GRINDX1", "qty": -1, "rate": "640.00",
                                     "amount": "-640.00", "cost": "-420.00"}],
                          "net_total": "-640.00", "total_taxes_and_charges": money(-tax),
                          "grand_total": money(-total), "status_after_submit": "Return",
                          "delivery_note": "SHPM-1003", "cogs": "-420.00"}
    b.docs["SHPM-1003"] = {"doctype": "Books Delivery Note", "posting_date": "2026-10-25",
                           "return_against": "SHPM-1001", "value": "-420.00",
                           "status": "Return"}

    # 12 — refund the customer
    b.post("2026-10-28", "PAY-1005", "Debtors", debit=total)
    b.post("2026-10-28", "PAY-1005", BANK, credit=total)
    b.docs["PAY-1005"] = {"doctype": "Books Payment Entry", "posting_date": "2026-10-28",
                          "payment_type": "Pay", "party": "Kopi Hub",
                          "paid_amount": money(total), "allocated_to": "SINV-1003",
                          "status_after_submit": "Submitted"}

    # 13 — damaged stock issued out
    cost, how = b.issue("2026-10-30", "SMOV-1001", "LT-CUP50", 2)
    b.post("2026-10-30", "SMOV-1001", "Stock Adjustment", debit=cost)
    b.docs["SMOV-1001"] = {"doctype": "Books Stock Entry", "posting_date": "2026-10-30",
                           "purpose": "Material Issue", "value": money(cost),
                           "fifo_layers": how, "status_after_submit": "Submitted"}

    # 14 — point of sale
    b.sale("2026-10-05", "SINV-1004", "SHPM-1004", "Walk-in Customer",
           [("LT-CUP50", 3, 24)], None, cash=True, payment="PAY-1006",
           payment_date="2026-10-05")
    b.docs["SINV-1004"]["is_pos"] = True
    b.docs["PAY-1006"] = {"doctype": "Books Payment Entry", "posting_date": "2026-10-05",
                          "payment_type": "Receive", "party": "Walk-in Customer",
                          "mode_of_payment": "Cash", "paid_amount": "77.76",
                          "allocated_to": "SINV-1004", "status_after_submit": "Submitted"}

    return b


def reports(b):
    accounts = sorted({row["account"] for row in b.ledger})
    tb, total_dr, total_cr = [], D(0), D(0)
    for account in accounts:
        dr = sum((D(x["debit"]) for x in b.ledger if x["account"] == account), D(0))
        cr = sum((D(x["credit"]) for x in b.ledger if x["account"] == account), D(0))
        net = r(dr - cr)
        tb.append({"account": account, "total_debit": money(dr), "total_credit": money(cr),
                   "closing_debit": money(max(net, 0)), "closing_credit": money(max(-net, 0))})
        total_dr += dr
        total_cr += cr

    def closing(account):
        dr = sum((D(x["debit"]) for x in b.ledger if x["account"] == account), D(0))
        cr = sum((D(x["credit"]) for x in b.ledger if x["account"] == account), D(0))
        return r(dr - cr)

    sales, cogs = closing("Sales"), closing("Cost of Goods Sold")
    adjustment = closing("Stock Adjustment")
    profit = -sales - cogs - adjustment
    stock = r(sum((v[1] for v in b.balances.values()), D(0)))
    pnl = {"from_date": "2026-01-01", "to_date": "2026-10-31",
           "income": {"Sales": money(-sales)}, "income_total": money(-sales),
           "expenses": {"Cost of Goods Sold": money(cogs), "Stock Adjustment": money(adjustment)},
           "expenses_total": money(cogs + adjustment),
           "gross_profit": money(-sales - cogs), "net_profit": money(profit)}
    bs = {"as_on": "2026-10-31",
          "assets": {"Bank Accounts": money(closing(BANK)), "Cash": money(closing("Cash")),
                     "Stock In Hand": money(closing("Stock In Hand"))},
          "assets_total": money(closing(BANK) + closing("Cash") + closing("Stock In Hand")),
          "liabilities": {SST: money(-closing(SST))},
          "liabilities_total": money(-closing(SST)),
          "equity": {"Capital Stock": money(-closing("Capital Stock")),
                     "Current Year Earnings": money(profit)},
          "equity_total": money(-closing("Capital Stock") + profit)}
    bs["liabilities_and_equity_total"] = money(
        -closing(SST) - closing("Capital Stock") + profit)
    return tb, pnl, bs


def main():
    b = build()
    tb, pnl, bs = reports(b)

    documents = {}
    for name, doc in b.docs.items():
        documents[name] = {**doc,
                           "ledger": [row for row in b.ledger if row["voucher"] == name]}
    for name in documents:
        dr = sum((D(x["debit"]) for x in documents[name]["ledger"]), D(0))
        cr = sum((D(x["credit"]) for x in documents[name]["ledger"]), D(0))
        documents[name]["ledger_balanced"] = money(dr) == money(cr)

    expected = {
        "meta": {
            "generated_by": "training/data/build_expected.py",
            "app_version": "16.1.0",
            "note": "Reference model of the posting rules; not captured from a running site.",
            "company": COMPANY, "currency": CURRENCY,
            "period": {"from": "2026-01-01", "to": "2026-10-31"},
        },
        "documents": documents,
        "stock_ledger": b.stock_ledger,
        "stock_balance": {
            "as_on": "2026-10-31",
            "items": [{"item_code": item, "qty": money(qty),
                       "value": money(value), "average_rate": money(value / qty)}
                      for item, (qty, value) in sorted(b.balances.items())],
            "total_value": money(sum((v[1] for v in b.balances.values()), D(0))),
        },
        "trial_balance": {
            "as_on": "2026-10-31", "rows": tb,
            "total_debit": money(sum((D(x["total_debit"]) for x in tb), D(0))),
            "total_credit": money(sum((D(x["total_credit"]) for x in tb), D(0))),
            "closing_debit": money(sum((D(x["closing_debit"]) for x in tb), D(0))),
            "closing_credit": money(sum((D(x["closing_credit"]) for x in tb), D(0))),
        },
        "profit_and_loss": pnl,
        "balance_sheet": bs,
        "pos_shift": {
            "opening_amount": "0.00", "sales_cash": "77.76", "expected_closing": "77.76",
            "denominations": {"50": 1, "20": 1, "5": 1, "2": 1,
                              "0.5": 1, "0.2": 1, "0.05": 1, "0.01": 1},
            "difference": "0.00",
        },
        "checkpoint": {
            "documents_created": 20,
            "trial_balance_closing_debit": "24497.12",
            "trial_balance_closing_credit": "24497.12",
            "trial_balance_period_debit": "58158.04",
            "trial_balance_period_credit": "58158.04",
            "net_profit": money(pnl["net_profit"]),
            "stock_value": money(bs["assets"]["Stock In Hand"]),
            "bank_balance": money(bs["assets"]["Bank Accounts"]),
            "cash_balance": money(bs["assets"]["Cash"]),
            "sst_payable": money(bs["liabilities"][SST]),
            "assets_total": money(bs["assets_total"]),
            "liabilities_and_equity_total": money(bs["liabilities_and_equity_total"]),
        },
    }
    (HERE / "expected-results.json").write_text(json.dumps(expected, indent=2) + "\n")

    dataset = {
        "meta": {"company": COMPANY, "currency": CURRENCY, "country": "Malaysia",
                 "chart_of_accounts": "Standard Chart of Accounts",
                 "fiscal_year": ["2026-01-01", "2026-12-31"],
                 "bank_name": BANK, "first_document_number": "1001"},
        "settings": {
            "Books Accounting Settings": {
                "enable_inventory": 1, "enable_invoice_returns": 1,
                "enable_discounts_and_margin": 1, "enable_price_list": 1,
                "year_start_date": "2026-01-01", "year_end_date": "2026-12-31"},
            "Books Inventory Settings": {
                "enable_batches": 1, "enable_serial_number": 1,
                "enable_uom_conversions": 1, "enable_point_of_sale": 1},
            "Books Defaults": {
                "delivery_note_location": "Stores", "purchase_receipt_location": "Stores",
                "pos_customer": "Walk-in Customer",
                "sales_invoice_terms": "Goods once sold are not returnable.",
                "delivery_note_terms": "Received in good order."},
        },
        "accounts": [
            {"name": "SST Payable", "parent_account": "Duties and Taxes",
             "root_type": "Liability", "account_type": "Tax", "is_group": 0},
        ],
        "uoms": [{"uom_name": "Pack", "must_be_whole_number": 1},
                 {"uom_name": "Box", "must_be_whole_number": 1}],
        "items": [
            {"item_code": "LT-CUP50", "item_name": "Paper Cup 8oz (Pack of 50)",
             "item_type": "Product", "is_stock_item": 1, "stock_uom": "Pack",
             "standard_rate": "24.00", "has_batch_no": 1, "batch_number_series": "CUP-.####",
             "uoms": [{"uom": "Box", "conversion_factor": 12}],
             "barcodes": [{"barcode": "9551234500017", "barcode_type": "EAN"}],
             "item_defaults": [{"company": COMPANY, "default_warehouse": "Stores",
                                "income_account": "Sales",
                                "expense_account": "Stock Received But Not Billed"}]},
            {"item_code": "LT-BEAN1KG", "item_name": "Arabica Beans 1 kg",
             "item_type": "Product", "is_stock_item": 1, "stock_uom": "Kg",
             "standard_rate": "78.00",
             "item_defaults": [{"company": COMPANY, "default_warehouse": "Stores",
                                "income_account": "Sales",
                                "expense_account": "Stock Received But Not Billed"}]},
            {"item_code": "LT-GRINDX1", "item_name": "Grinder X1", "item_type": "Product",
             "is_stock_item": 1, "stock_uom": "Unit", "standard_rate": "640.00",
             "has_serial_no": 1, "serial_no_series": "GRND-.####",
             "item_defaults": [{"company": COMPANY, "default_warehouse": "Stores",
                                "income_account": "Sales",
                                "expense_account": "Stock Received But Not Billed"}]},
            {"item_code": "LT-SVC-INST", "item_name": "Installation & Setup",
             "item_type": "Service", "is_stock_item": 0, "stock_uom": "Hour",
             "standard_rate": "120.00",
             "item_defaults": [{"company": COMPANY, "income_account": "Service",
                                "expense_account": "Cost of Goods Sold"}]},
        ],
        "parties": [
            {"doctype": "Books Customer", "name": "Kopi Hub",
             "accounts": [{"company": COMPANY, "account": "Debtors"}]},
            {"doctype": "Books Customer", "name": "Sunrise Cafe",
             "accounts": [{"company": COMPANY, "account": "Debtors"}]},
            {"doctype": "Books Customer", "name": "Walk-in Customer",
             "accounts": [{"company": COMPANY, "account": "Debtors"}]},
            {"doctype": "Books Supplier", "name": "Nusantara Supplies",
             "accounts": [{"company": COMPANY, "account": "Creditors"}]},
        ],
        "tax_template": {
            "doctype": "Books Sales Taxes and Charges Template", "title": "SST 8%",
            "company": COMPANY, "is_default": 1,
            "taxes": [{"charge_type": "On Net Total", "account_head": SST, "rate": 8,
                       "description": "Sales and Service Tax 8%"}]},
        "price_list": {"doctype": "Books Price List", "price_list_name": "Wholesale",
                       "currency": CURRENCY, "selling": 1, "enabled": 1,
                       "item_prices": [
                           {"item_code": "LT-CUP50", "uom": "Pack", "price_list_rate": "22.00"},
                           {"item_code": "LT-BEAN1KG", "uom": "Kg", "price_list_rate": "72.00"}]},
        "documents": [
            {"name": name, **{k: v for k, v in doc.items()
                              if k not in ("ledger", "ledger_balanced")}}
            for name, doc in documents.items()
        ],
    }
    (HERE / "demo-dataset.json").write_text(json.dumps(dataset, indent=2) + "\n")
    print("wrote expected-results.json and demo-dataset.json")
    print(json.dumps(expected["checkpoint"], indent=2))


if __name__ == "__main__":
    main()
