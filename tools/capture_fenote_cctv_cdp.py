#!/usr/bin/env python3
"""Capture Fenote CCTV shots via Chrome DevTools after Flutter has painted."""

from __future__ import annotations

import base64
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import websocket

ROOT = Path(__file__).resolve().parents[1]
SCREENS = ROOT / "web/fenote-raey-academy/screens"
CDP = "http://127.0.0.1:9333"
BASE = "http://127.0.0.1:8101"


class Cdp:
    def __init__(self, url: str) -> None:
        self._id = 0
        self.ws = websocket.create_connection(url, timeout=60)

    def send(self, method: str, params: dict | None = None, timeout: float = 60) -> dict:
        self._id += 1
        self.ws.settimeout(timeout)
        self.ws.send(json.dumps({"id": self._id, "method": method, "params": params or {}}))
        while True:
            msg = json.loads(self.ws.recv())
            if msg.get("id") == self._id:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result") or {}

    def close(self) -> None:
        try:
            self.ws.close()
        except Exception:
            pass


def open_tab(url: str) -> dict:
    encoded = urllib.parse.quote(url, safe="")
    req = urllib.request.Request(
        f"{CDP}/json/new?{encoded}",
        method="PUT",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.load(resp)
    except urllib.error.HTTPError:
        tabs = json.load(urllib.request.urlopen(f"{CDP}/json/list", timeout=10))
        page = next((t for t in tabs if t.get("type") == "page"), None)
        if not page:
            raise
        return page


def wait_cdp(retries: int = 30) -> None:
    for i in range(retries):
        try:
            urllib.request.urlopen(f"{CDP}/json/version", timeout=2).read()
            return
        except Exception:
            time.sleep(1)
    raise SystemExit("Chrome CDP on :9333 did not come up")


def capture(shot: str, dest: Path, wait_s: float = 18) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    page_url = f"{BASE}/?shot={shot}"
    tab = open_tab(page_url)
    ws_url = tab["webSocketDebuggerUrl"]
    cdp = Cdp(ws_url)
    try:
        cdp.send("Page.enable")
        cdp.send("Page.navigate", {"url": page_url})
        cdp.send("Emulation.setDeviceMetricsOverride", {
            "width": 1600,
            "height": 900,
            "deviceScaleFactor": 1,
            "mobile": False,
        })
        # First Flutter DDC compile can take a while.
        time.sleep(wait_s)
        result = cdp.send("Page.captureScreenshot", {
            "format": "png",
            "fromSurface": True,
            "captureBeyondViewport": False,
        }, timeout=30)
        raw = base64.b64decode(result["data"])
        if len(raw) < 40_000:
            raise SystemExit(f"{dest.name} too small ({len(raw)} bytes) — Flutter likely still on splash")
        dest.write_bytes(raw)
        print(f"Wrote {dest} ({len(raw)} bytes)", flush=True)
    finally:
        cdp.close()


def main() -> None:
    wait_cdp()
    capture("admin", SCREENS / "screen-cctv.png", wait_s=22)
    capture("overview", SCREENS / "screen-cctv-dashboard.png", wait_s=12)


if __name__ == "__main__":
    main()
