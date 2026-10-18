# KeyLootMaster: Overall, Farming-Reiter, Katalysator, Tier-Set

Stand: 2026-10-18

## Warum

keystoneloot.io zeigt pro Spec eine Liste „Overall / Mythic+ / Raid“ mit Katalysator-Tabelle,
Tier-Set-Text und Hinweisen zur Beute-Spezialisierung. KeyLootMaster hat die tieferen Daten (was die
Top-Spieler wirklich tragen, mit Anteilen), aber diese Teile fehlen. Ziel: alles, was dort steht, auch
im Addon-Fenster, plus ein Reiter, der sagt, **wo man farmen soll**. Es gibt keine Website; alles
passiert im Addon.

## Ziele

1. **Overall** als dritte Auswahl neben Mythic+ und Raid auf der Items-Seite.
2. **Neuer Reiter „Farming“**: welche Dungeons (bzw. Raidbosse) die meisten gefragten Items droppen.
3. **Katalysator**: pro Tier-Slot, aus welchen Dungeons/Bossen ein umwandelbares Teil kommt.
4. **Tier-Set**: Name und 2er/4er-Bonustext der eigenen Klasse.
5. **Hinweis zur Beute-Spezialisierung**: „droppt nicht für deine Beute-Spec, stell auf X um“.
6. **Handwerk** mit Berufsname statt nur „Crafted“.

## Nicht-Ziele

- Website, Import-Strings, Tier-Liste der Specs, Raidbots-Import, Guide-Daten.
- Neue Stat-Priorität: gibt es schon (Stats-Seite, `StatRanking` in `Logic.lua:229`).
- „Equipped“-Markierung neu bauen: gibt es schon (`ns.EquippedItems` `Core.lua:92`, Markierung `UI.lua:594`)
  und wird auf dem Farming-Reiter wiederverwendet.

## Anti-Ziele

- Bestehende Mythic+- und Raid-Listen verlieren nichts: alles, was heute darin steht, bleibt (Tier- und
  Handwerksteile kommen nur dazu, siehe „Items-Seite: Filter“).
- Kein Netzwerkzugriff im Addon; alles Neue kommt entweder aus den generierten Data-Dateien oder aus der
  Spiel-API.

## Zwei Repos

- **Addon:** `C:\Users\jok\Desktop\dev\KeyStoneMaster` (`KeyLootMaster/`, Tests in `tests/`,
  `python -m unittest discover -s tests -v`, braucht `lupa`).
- **DataMiner:** `C:\Users\jok\Desktop\dev\KeyLootMaster` (Repo KeyLootDataMiner, `pipeline/`, Tests
  `python -m unittest discover -s pipeline/tests -v`). Schreibt die Lua-Dateien in `KeyLootMaster/Data/`
  des Addons. Der leere Ordner `KeystoneLoot/` dort ist ungenutzt und bleibt unberührt.

Reihenfolge: zuerst die Teile, die ohne neue Daten gehen (1, 2), dann DataMiner-Erweiterungen (3, 4, 6),
dann deren Anzeige. 5 läuft rein im Addon.

## Items-Seite: Filter (entschieden vom Nutzer: Tier- und Handwerksteile sollen in der Liste stehen)

Heute setzt `ns.Filters()` (`Core.lua:171`) immer `farmable = "dungeon"` bzw. `"raid"`, wodurch
Katalysator-, Handwerks- und sonstige Teile aus den Listen fallen (`ns.Passes`, `Logic.lua:334`). Neu:

- **Mythic+-Ansicht:** Dungeon-Teile **plus** Katalysator- und Handwerksteile. Raid-Teile bleiben wie
  heute draußen (meine Entscheidung).
- **Raid-Ansicht:** Raid-Teile plus Katalysator- und Handwerksteile (meine Entscheidung, gleiche Regel).
- **Overall:** kein Quellenfilter, alles, was in den zusammengeführten Listen steht (meine Entscheidung).
- Quellen `other` (kein Journal-Eintrag, kein Rezept, kein Set) bleiben in M+/Raid draußen, in Overall
  stehen sie mit der Zeile „Sonstige Quelle“ (meine Entscheidung).
- Der Quellenfilter im Fenster (`filters.source`) und der Kommentar `Core.lua:168` werden angepasst.
- Die Quellzeilen „Katalysator · <Dungeons>“ und „Handwerk · <Beruf>“ (Abschnitte 3 und 6) erscheinen
  damit auf der Items-Seite in allen drei Ansichten.
- Der Farming-Reiter ist davon unabhängig; er hat seine eigene Gruppierung (Abschnitt 2).

## 1. Overall

- Dritter Knopf neben Mythic+ / Raid, Reihenfolge **Overall · Mythic+ · Raid**. `Settings().content`
  bekommt den Wert `overall` (heute nur `mplus`/`raid`, `Core.lua:31`).
- Liste pro Slot aus `mplus` und `raid` zusammengeführt. **Meine Entscheidung:** Anteil gewichtet nach
  Stichprobe, `share = (s1·n1 + s2·n2) / (n1 + n2)`; fehlt ein Item in einer Liste, zählt es dort als 0.
  Die Quellen (Blizzard-Leaderboards für M+, Warcraft Logs für Raid) sind verschiedene Spieler, doppelte
  Zählung ist deshalb kein Thema.
- Bei Overall gibt es keine „Dungeon players / All top players“-Auswahl; verwendet wird `mplus`.
- Itemlevel/Keylevel-Zeile: jedes Item zeigt die Angabe seiner eigenen Quelle, so wie es heute in der
  jeweiligen Ansicht erscheint (Dungeon-Item mit Keylevel, Raid-Item mit Raid-Angabe). Wie die Keylevel-
  und Vault-Auswahl bei Overall aussieht, entscheidet der Builder; sie darf nur auf Dungeon-Items wirken.
- Betroffene Stellen laut Recon: `Core.lua:31`, `Core.lua:171` (`Filters`, `farmable`), Knöpfe
  `UI.lua:492-497` und `627-631`, `sourceText` `UI.lua:103`, `holdTextOf` `UI.lua:550`,
  `DungeonLevel` `Logic.lua:71`, `ns.Rows` `Logic.lua:341`, `ContentKey` `Logic.lua:153`.

## 2. Reiter „Farming“

Aufbau wie im abgenommenen Entwurf (`.superpowers/brainstorm/.../farming.html`):

- Sechster Reiter nach Players. Achtung: kollidiert evtl. mit `widgets.stamp` (`UI.lua:482`); Abstände
  der Reiter anpassen.
- Auswahl **Mythic+ / Raid** (ohne Overall).
- **Mythic+:** Dungeons absteigend nach Punkten; unter jedem Dungeon die Items mit Boss, Slot und Anteil.
  Getrennt darunter: **Handwerk** (Items mit Beruf), **Katalysator** (siehe 3), **Raid-Items, die
  M+-Spieler tragen** (nur Hinweis, nicht in der Rangfolge).
- **Raid:** dieselbe Darstellung, gruppiert nach Raidboss.
- **Welche Items zählen** (meine Entscheidung): pro Slot das beliebteste Item, das in der gewählten
  Ansicht farmbar ist (Dungeon bzw. Raidboss), plus alle farmbaren Items mit mindestens 20 % Anteil, aus
  der Liste `mplus` bzw. `raid` der gewählten Spec. Ist Platz 1 ein Tier- oder Handwerksteil, rückt also
  das beste Dungeon-Item des Slots nach.
- **Punkte** = Summe der Anteile dieser Items. **Meine Entscheidung:** Items, die der Spieler schon trägt,
  bleiben sichtbar mit „Equipped“ markiert, zählen aber nicht zu den Punkten – die Route soll zeigen,
  wo noch etwas zu holen ist.
- Ringe und Trinkets: beide Plätze zählen; ein getragenes Exemplar markiert nur dieses Item.
- Klick auf ein Item öffnet wie auf der Items-Seite den Dungeon-Guide.
- Spec-Wechsel und „Compare with“ verhalten sich wie auf den anderen Seiten; was der Builder bei
  Compare zeigt (gemeinsame Items oder nur die erste Spec), ist seine Entscheidung.

## 3. Katalysator

- **Meine Entscheidung:** Als Tier-Teil gelten nur die 5 Set-Plätze (Kopf, Schultern, Brust, Hände,
  Beine), keine thematisch passenden Teile anderer Plätze. Der Katalysator-Block erscheint nur in der
  Mythic+-Ansicht, als Quellen zählen nur Dungeons. Im Raid kommen Tier-Teile über Marken, deren
  Zuordnung in keinen Daten steht; das bleibt außen vor.
- **DataMiner:** `inventory_type` und `item_subclass` (Rüstungstyp) aus `/data/wow/item/{id}` beim
  Item-Lesen mit cachen (`blizzard_items.py:65-71`), nur für Dungeon-Drops der Saison (mit Cache
  vertretbar). Für jedes Tier-Teil die Dungeon-Drops mit gleichem Slot und Rüstungstyp suchen und als Liste von Quellen
  (Instanz, Boss) ausgeben. Format der neuen Daten entscheidet der Builder (z. B. eigene Datei
  `Catalyst.lua` oder Feld in `Drops.lua`).
- **Addon:** Auf dem Farming-Reiter ein Block „Katalysator“: pro Tier-Slot das Tier-Teil, darunter die
  Dungeons/Bosse, aus denen ein umwandelbares Teil kommt. Katalysator-Slots fließen **nicht** in die
  Dungeon-Punkte ein (jeder passende Drop geht, das würde die Rangfolge verzerren).
- Auf der Items-Seite zeigt die Quellzeile eines Tier-Teils statt „Catalyst / tier“ künftig
  „Katalysator · <Dungeons>“ (gekürzt, wenn es viele sind).

## 4. Tier-Set

- **DataMiner:** `/data/wow/item-set/{id}` abfragen (die Set-ID liegt über `preview_item.set` schon vor),
  Set-Name und Bonustexte für 2 und 4 Teile in **en_US und de_DE** ausgeben.
- **Addon:** Abschnitt „Tier-Set“ auf der Gear-Seite mit Name und den beiden Boni in der Spielsprache
  (fällt auf Englisch zurück).

## 5. Beute-Spezialisierung

- Im Spiel über den Dungeon-Guide prüfen (Loot-Filter je Klasse/Spec), ob ein Item für die aktuelle
  Beute-Spec droppt. Wenn nicht: Hinweis am Item (Items- und Farming-Reiter), mit einer Spec der Klasse,
  für die es droppt.
- Der Builder muss vorher klären, ob die Journal-API das zuverlässig liefert. Wenn nicht, entfällt
  Punkt 5 und wird gemeldet, statt geraten.

## 6. Handwerk

- **DataMiner:** beim Erkennen von `kind="crafted"` den Berufsnamen (aus dem Rezept-Abgleich, der schon
  existiert) mit ausgeben.
- **Addon:** Quellzeile „Handwerk · Schmiedekunst“ statt „Crafted“.

## Sprache

Alle neuen Texte über `L["..."]` mit deutschem Eintrag in `Locales.lua` (`overrides.deDE`).

## Tests

- Addon: neue Logik (Overall-Zusammenführung, Farming-Rangfolge inkl. Equipped) in
  `tests/test_addon_logic.py`; neuer Reiter und Overall-Knopf als UI-Tests in `tests/test_addon_smoke.py`
  nach dem Muster von `test_the_gear_talent_and_player_pages_show_their_data`.
- DataMiner: Katalysator-Zuordnung, Item-Set-Texte und Berufsname in `pipeline/tests`.
- Bestehende Tests bleiben grün; wo ein Test die alte Filterung (nur Dungeon bzw. Raid) festschreibt,
  wird er an die neue Regel angepasst und das im Bericht genannt.

## Dem Builder überlassen

Datenformat der neuen Lua-Dateien, genaue Platzierung und Optik innerhalb des bestehenden Skins,
Kürzung langer Quellenlisten, Overall-Verhalten von Keylevel/Vault (nur auf Dungeon-Items).
