#!/usr/bin/env python3
# © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
"""
ARGUS — Daten-Backup (Sofort-Sicherheitsnetz bis Supabase Pro-Tier, Phase 5).

Was es tut:
  Lädt alle Tabellen der ARGUS-Datenbank (praesidien, ccps, checklists,
  access_tokens, patients) read-only herunter und schreibt sie als eine
  JSON-Datei nach  ~/ARGUS-Backups/argus-backup-<zeitstempel>.json
  Zusätzlich werden die Kurs-Evaluationen über die Master-RPC argus_eval_list()
  gesichert (course_evaluations ist per RLS für direktes SELECT gesperrt).

Authentifizierung:
  Über den MasterToken-CODE (kein Management-PAT nötig). Der Code wird NICHT
  gespeichert — er wird abgefragt oder aus der Umgebungsvariable ARGUS_MASTER_CODE
  gelesen. Der MasterToken darf serverseitig alle Daten lesen.

WICHTIG / Datenschutz:
  Die Backup-Datei enthält sensible Daten (Zugangscodes, ggf. Patientendaten).
  -> Niemals ins (öffentliche) Git-Repo legen oder unverschlüsselt teilen.
  -> Sicher ablegen (Time Machine / verschlüsseltes Volume).

Aufruf:
  python3 scripts/argus_backup.py
  (oder)  ARGUS_MASTER_CODE=XXXX-YYYY python3 scripts/argus_backup.py
"""

import os, sys, json, time, getpass, urllib.request, urllib.error

SUPA_URL = "https://sehuosjyjmrpzcqrelej.supabase.co"
# Öffentlicher Anon-Key (steckt ohnehin im App-Quelltext) — kein Geheimnis.
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6"
        "InNlaHVvc2p5am1ycHpjcXJlbGVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0Mjk1"
        "MzksImV4cCI6MjA5NjAwNTUzOX0.G0DuJmeJBQwTLK8n4m4PVFSf2eNStZy_F0gIouMxIuo")
TABLES = ["praesidien", "ccps", "checklists", "access_tokens", "patients"]
PAGE = 1000  # PostgREST-Seitengröße

def _post(path, body, jwt):
    req = urllib.request.Request(
        SUPA_URL + path,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json", "apikey": ANON,
                 "Authorization": "Bearer " + jwt},
        method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))

def _get_page(table, jwt, frm, to):
    req = urllib.request.Request(
        SUPA_URL + "/rest/v1/" + table + "?select=*",
        headers={"apikey": ANON, "Authorization": "Bearer " + jwt,
                 "Range-Unit": "items", "Range": "%d-%d" % (frm, to)},
        method="GET")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))

def exchange(code):
    """MasterToken-Code -> JWT (über den DB-RPC)."""
    clean = "".join(ch for ch in code.upper() if ch.isalnum())
    data = _post("/rest/v1/rpc/argus_exchange_code", {"code": clean}, ANON)
    if not isinstance(data, dict) or not data.get("jwt"):
        raise SystemExit("FEHLER: Code ungültig / kein JWT erhalten (%s)" % data)
    if not data.get("is_master"):
        print("⚠  Hinweis: Dieser Code ist KEIN MasterToken — es werden evtl. nur "
              "Teildaten gesichert (nur das eigene Präsidium).")
    return data["jwt"]

def dump_table(table, jwt):
    rows, frm = [], 0
    while True:
        page = _get_page(table, jwt, frm, frm + PAGE - 1)
        if not isinstance(page, list):
            raise SystemExit("FEHLER bei Tabelle %s: %s" % (table, page))
        rows.extend(page)
        if len(page) < PAGE:
            break
        frm += PAGE
    return rows

def main():
    code = os.environ.get("ARGUS_MASTER_CODE") or getpass.getpass("MasterToken-Code (XXXX-YYYY): ")
    if not code.strip():
        raise SystemExit("Kein Code angegeben.")
    print("· Tausche Code gegen Lesezugriff …")
    jwt = exchange(code)
    out = {"exported_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
           "project_ref": "sehuosjyjmrpzcqrelej", "tables": {}, "counts": {}}
    for t in TABLES:
        print("· Sichere %s …" % t, end=" ", flush=True)
        rows = dump_table(t, jwt)
        out["tables"][t] = rows
        out["counts"][t] = len(rows)
        print("%d Zeilen" % len(rows))
    # Kurs-Evaluationen separat über die Master-RPC (RLS sperrt direktes SELECT).
    print("· Sichere course_evaluations (via argus_eval_list) …", end=" ", flush=True)
    try:
        evals = _post("/rest/v1/rpc/argus_eval_list", {}, jwt)
        if not isinstance(evals, list):
            evals = []
        out["tables"]["course_evaluations"] = evals
        out["counts"]["course_evaluations"] = len(evals)
        print("%d Zeilen" % len(evals))
    except Exception as e:
        out["tables"]["course_evaluations"] = []
        out["counts"]["course_evaluations"] = 0
        print("übersprungen (%s)" % e)
    outdir = os.path.expanduser("~/ARGUS-Backups")
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(outdir, "argus-backup-" + time.strftime("%Y%m%d-%H%M%S") + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    os.chmod(path, 0o600)  # nur für den Eigentümer lesbar
    print("\n✓ Backup gespeichert: %s" % path)
    print("  Zeilen gesamt:", sum(out["counts"].values()), "·", out["counts"])
    print("  ⚠ Enthält sensible Daten — sicher aufbewahren, NICHT ins Repo legen.")

if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as e:
        raise SystemExit("HTTP-Fehler %s: %s" % (e.code, e.read().decode("utf-8", "ignore")[:300]))
    except urllib.error.URLError as e:
        raise SystemExit("Netzwerkfehler: %s (online?)" % e.reason)
