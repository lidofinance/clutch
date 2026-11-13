#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Convert a Sepolia CoW sell quote to feeAmount=0 order fields."""
import json
import sys


def sell_order(quote):
    if quote["kind"] != "sell":
        raise ValueError("A sell quote is required")
    fields = ("sellToken", "buyToken", "receiver", "sellAmount", "buyAmount", "validTo",
              "appData", "kind", "partiallyFillable", "sellTokenBalance", "buyTokenBalance")
    order = {key: quote[key] for key in fields}
    order["sellAmount"] = str(int(quote["sellAmount"]) + int(quote["feeAmount"]))
    order["feeAmount"] = "0"
    return order


if __name__ == "__main__":
    print(json.dumps(sell_order(json.load(sys.stdin)["quote"])))
