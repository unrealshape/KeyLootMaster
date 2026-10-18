# Overall, Farming, Katalysator, Tier-Set Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (this session implements it inline).

**Goal:** Das Addon bekommt die Auswahl Overall, den Reiter Farming, Tier-/Handwerksteile in den Listen und (über den DataMiner) Katalysator-Quellen, Tier-Set-Text und Berufsnamen.

**Architecture:** Reine Logik in `Logic.lua` (testbar ohne Spiel), Anzeige in `UI.lua`/`Pages.lua`. Neue Daten aus dem DataMiner kommen als zusätzliche Lua-Tabellen; das Addon läuft auch ohne sie (Phase B ist optional zur Laufzeit).

**Tech Stack:** Lua (WoW Retail 12.x), Python + lupa für Tests, DataMiner in Python.

**Spec:** `docs/superpowers/specs/2026-10-18-overall-farming-catalyst-design.md`

## Global Constraints

- Neue Texte nur über `L["..."]`; deutsche Einträge in `Locales.lua` (`overrides.deDE`).
- Kein Netzwerkzugriff im Addon.
- Tests: `python -m unittest discover -s tests -v` im Addon-Repo; `python -m unittest discover -s pipeline/tests -v` im DataMiner. Alle bleiben grün.
- Release entsteht durch Push auf `main` des Addon-Repos (`.github/workflows/release.yml`).

## Review Focus

- Spec ohne Daten für Raid/M+ (leere Listen): Overall und Farming zeigen eine Meldung, keinen Fehler.
- Item mit mehreren Quellen (Dungeon und Raid): erscheint in M+ und Raid, in Overall mit Dungeon zuerst.
- Spec mit nur `mplus` oder nur `raid` in den Daten: Overall nutzt die vorhandene Liste.
- Getragenes Item in beiden Ring-/Trinketplätzen: einmal „Equipped“, zählt nicht zu den Punkten.
- Alte gespeicherte Einstellungen (`content` unbekannt): fällt auf `mplus` zurück.

---

### Task 1: Logic – Overall, Quellenfilter, Farming-Route

**Files:** Modify `KeyLootMaster/Logic.lua`; Test `tests/test_addon_logic.py`

**Interfaces:**
- Produces: `ns.ViewKinds(content) -> set|nil` (`mplus`: dungeon+catalyst+crafted, `raid`: raid+catalyst+crafted, `overall`: nil); `filters.kinds` in `ns.Passes`; `ns.Rows(class, spec, content, filters, equipped)` versteht `content == "overall"`; `ns.FarmingRoute(class, spec, contentKey, equipped) -> { kind, groups = {{name, sub, score, items}}, crafted, catalyst, other }` mit Item `{item, share, slot, boss, worn}`; `ns.SourceLabel` liefert zusätzlich `kind` und `instance` des gewählten Eintrags.

- [ ] Tests schreiben (Overall-Mischung nach Gewichtung, Filter `kinds`, FarmingRoute-Auswahl/Punkte/Equipped/Gruppierung)
- [ ] Tests laufen lassen: schlagen fehl
- [ ] Implementieren, Tests grün
- [ ] Commit

### Task 2: Core + UI – Overall-Knopf, Filter, Quellzeilen

**Files:** Modify `KeyLootMaster/Core.lua`, `KeyLootMaster/UI.lua`, `KeyLootMaster/Locales.lua`; Test `tests/test_addon_smoke.py`

- [ ] `Settings()` erlaubt `overall`; `ns.Filters()` liefert `{ kinds = ns.ViewKinds(content) }`
- [ ] Knopf Overall vor Mythic+; `sourceText` lokalisiert Quellen ohne Instanz (Katalysator/Handwerk); Keylevel-Zeile nur für Dungeon-Items (auch in Overall)
- [ ] Bestehenden Test `test_the_two_buttons_list_the_dungeon_drops_and_the_raid_drops` an die neue Regel anpassen, neue Tests für Overall und Tier-/Handwerksteile in der Liste
- [ ] Tests grün, Commit

### Task 3: Farming-Reiter

**Files:** Modify `KeyLootMaster/UI.lua` (`PAGE_ORDER`, Reiter-Abstände, Knöpfe auf Farming sichtbar), `KeyLootMaster/Pages.lua` (`buildFarming`, `refreshFarming`, `UI.RegisterPage("farming", ...)`), `KeyLootMaster/Locales.lua`; Test `tests/test_addon_smoke.py`

- [ ] Smoke-Test: Reiter „Farming“ zeigt Dungeon-Namen, Boss, Item, „Equipped“; Meldung ohne Daten
- [ ] Implementieren (zwei Spalten: Route links, Handwerk/Katalysator/Raid-Hinweis rechts; feste Zeilen-Pools, Überlauf als „+N more“)
- [ ] Tests grün, Commit, **Push** (Release 1)

### Task 4: DataMiner – Katalysator-Quellen, Tier-Set-Text, Beruf

**Files:** `C:\Users\jok\Desktop\dev\KeyLootMaster\pipeline\klm\sources\blizzard_items.py`, `pipeline\klm\lua.py`, `pipeline\klm\model.py`, Tests in `pipeline\tests`

- [ ] Item-Lesen cached zusätzlich `inventory_type` und `item_subclass`; Tier-Set-Daten (`preview_item.set` -> `/data/wow/item-set`) mit Bonustexten en_US/de_DE; Berufsname beim Rezept-Abgleich
- [ ] Ausgabe: `Catalyst.lua` (`KeyLootMasterCatalyst[slot] = { {instance, instanceName, encounter, encounterName}, ... }`), `TierSet.lua` (`KeyLootMasterTierSet[class] = { name = {en, de}, bonus = {[2] = {en, de}, [4] = {...}} }`), Beruf als Feld `profession` in den Crafted-Drops
- [ ] Tests (ohne Netz, mit eingespielten Antworten) grün, Commit, Push

### Task 5: Addon zeigt die neuen Daten

**Files:** `KeyLootMaster/Data/Data.xml` (neue Dateien optional), `Logic.lua`, `UI.lua`, `Pages.lua`

- [ ] Katalysator-Quellen im Farming-Block und in der Quellzeile; Tier-Set auf der Gear-Seite; „Handwerk · Beruf“; alles still ausgeblendet, wenn die Daten fehlen
- [ ] Beute-Spezialisierung: nur wenn die Journal-API es zuverlässig liefert, sonst melden und weglassen
- [ ] Tests grün, Commit, **Push** (Release 2)
