# Datenmodell

Beschreibt die heutigen Datenstrukturen der bestehenden App und wie sie auf ein Backend abzubilden sind. Feldnamen sind die tatsächlichen aus `legacy/CCP_App.html`.

## Entität: Patient

Schlüssel heute: `ccp_pat_<id>`.

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | string | eindeutige ID (gerätegeneriert) |
| `num` | number | laufende Nummer **pro CCP** |
| `ccp` | string | CCP-Kennung (Default `"A"`) – siehe ID-Schema |
| `cat` | string | Kategorie: `T1` / `T2` / `T3` / `T5` |
| `status` | string | `active` oder `gpa` (ausgecheckt) |
| `prio` | bool | Prio-Transport |
| `ready` | bool | transportfertig |
| `tqStart` | number\|null | Startzeit Tourniquet (ms) oder null |
| `created` | number | Anlagezeit (ms) |
| `lastTriage` | number | Zeit der letzten Sichtung/Änderung (ms) |
| `updated` | number | letzte Speicherung (ms) |
| `name`,`age`,`gender`,`allergies` | string | optionale Stammdaten |
| `pupRe`,`pupLi` | string | Pupillen rechts/links |
| `vit` | object | `{af,spo2,hf,rr,avpu,pain}` Vitalwerte |
| `tx` | object | gesetzte Maßnahmen (Schalter) |
| `inj` | array | Verletzungen `[{r:Region, a:Art}]` |
| `moi`,`injury` | string | Verletzungsmechanismus / Beschreibung |
| `fr`,`by` | string | erfassendes Bediener-Kürzel |
| `notes` | string | Freitext |
| `photo` | string (optional) | verkleinertes JPEG als Data-URL |
| `demo` | bool (optional) | **nur Vorschau**: markiert Beispiel-Patienten des Demo-CCP B; in der echten App entfernen |

## Entität: Checkliste

Schlüssel: `ccp_checklist`.

```
{
  hdr:   { ort, mm, door, ass },          // Kopfdaten
  items: { <punktId>: { done:bool, note:string } }
}
```

Die Punkte-Definition (`CHK`) und der tacSTART-Entscheidungsbaum (`FLOW`) sind im Code als Konstanten hinterlegt.

## Meta / CCP-Status

| Schlüssel | Inhalt |
|---|---|
| `ccp_operator` | aktuelles Bediener-Kürzel (Gerät) |
| `ccp_mastermedic` | Kürzel des aktuellen MasterMedic |
| `ccp_merged` | bool – ist eine Zusammenführung aktiv (steuert die Präfix-Anzeige) |

## ID- und Nummern-Schema (wichtig)

- Jeder CCP hat eine kurze **Kennung** (`A`, `B`, …). Sie liegt **immer** im Patientensatz (`ccp`).
- Die **laufende Nummer** ist **pro CCP** eindeutig (Funktion `nextNum()` zählt nur Patienten des lokalen CCP, der hier immer `A` ist).
- **Anzeige:** Solange nur ein CCP läuft (`ccp_merged=false`), wird nur die nackte Nummer gezeigt (`7`). Erst nach einer Zusammenführung erscheint die Kennung als Präfix (`A-07`, `B-07`). Helfer-Funktion: `pno(p)`.
- Dieses Schema verhindert Nummern-Kollisionen, sobald mehrere Geräte/CCPs getrennt erfassen, und macht das Zusammenführen kollisionsfrei.

## Abbildung auf das Backend (Empfehlung)

- Tabelle `ccps` (id/Kennung, Einsatzort, MasterMedic, Status, erstellt).
- Tabelle `patients` (Felder wie oben, Fremdschlüssel auf `ccps`, plus Sperr-Felder `lockedBy`, `lockedAt` – siehe `docs/FEATURES_MULTIUSER.md`).
- Tabelle `checklists` (pro CCP).
- Echtzeit-Abonnement auf `patients` (und `ccps`) des aktiven CCP.
- Zugriffskontrolle: nur authentifizierte Geräte; Schreibrecht über die Sperr-Logik gesteuert.
- `demo`-Felder und der Demo-CCP-B-Mechanismus aus der Vorschau **entfallen** in der echten App.

---

## Aktualisierung (Stand v0.16.1, 2026-06-05)

> Der obige Abschnitt beschreibt das **frühe** Modell. **Maßgeblich** für das echte
> DB-Schema ist jetzt `supabase/migrations/0000_base_schema.sql` (+ `0001_…`).

**DB-Spaltennamen** (Tabelle `patients`) weichen von den JS-Feldern ab: `ccp_id`,
`tq_start`, `last_triage`, `pup_re`/`pup_li`, `locked_by`/`locked_at`. Mapping:
`patFromRow()`/`patToRow()` in `index.html`.

**Neu/ergänzt seit der Erstfassung:**
- `vit.avpu` enthält jetzt **WASB** (W/A/S/B = Wach/Ansprechbar/Schmerzreiz/Bewusstlos),
  nicht mehr AVPU (v0.16.0, inkl. Datenmigration).
- Optionaler **Vitalwerte-Verlauf** `vit.log` = `[{t,af,spo2,hf,rr,avpu,pain,by}]`.
- **Nur lokale** Patient-Felder (NICHT in der DB, von `patToRow` ignoriert):
  `_dirty` (offline noch nicht synchronisiert) und `ccpId` (Ziel-CCP für den Upload).
- `locked_by`/`locked_at` = Soft-Lock (45 s TTL, Heartbeat, Auto-Übernahme).
- Demo-/Schulungs-Patienten haben **id-Präfix `seed`** (echte: `p…`); das frühere
  `demo`-Flag betrifft nur die lokale Vorschau-Zusammenführung.

**Weitere Tabellen:** `ccps` (praesidium_id, kennung, merged/merge_group_id/
merge_request_from/merge_request_at, closed_at, join_token), `checklists` (ccp_id,
data jsonb), `access_tokens` (token PK, short_code unique, is_master, temporary,
ttl_hours, single_use, **used_at = bigint/ms**), `praesidien` (id, name).
Zugriff serverseitig per **RLS** (siehe `0001_phase4_jwt_rls.sql`).
