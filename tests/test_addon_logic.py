"""Runs the addon's Logic.lua in a Lua runtime (lupa) against small made-up tables.

Skipped when lupa is not installed (`pip install lupa`); CI installs it.
"""

import unittest
from pathlib import Path

try:
    import lupa
except ImportError:  # pragma: no cover
    lupa = None

ADDON = Path(__file__).resolve().parents[1] / "KeyLootMaster"

TABLES = r"""
KeyLootMasterData = {
  ["paladin"] = { ["protection"] = {
    ["mplus"] = {
      ["head"] = { {100, 0.9, 50}, {101, 0.06, 50}, {102, 0.04, 50} },
      ["trinket"] = { {200, 0.7, 50}, {201, 0.5, 50} },
      ["neck"] = { {300, 0.4, 50} },
    },
    ["raid"] = { ["head"] = { {100, 0.8, 100}, {103, 0.1, 100} } },
  } },
  ["mage"] = { ["fire"] = { ["mplus"] = { ["head"] = { {500, 1.0, 10} } } } },
}
KeyLootMasterDrops = {
  [100] = { {kind = "catalyst", instance = 0, instanceName = "Catalyst / tier", encounter = 0, encounterName = ""} },
  [101] = { {kind = "dungeon", instance = 1, instanceName = "Keep", encounter = 2, encounterName = "Boss"},
            {kind = "raid", instance = 3, instanceName = "Abyss", encounter = 4, encounterName = "Eel"} },
  [200] = { {kind = "raid", instance = 3, instanceName = "Abyss", encounter = 4, encounterName = "Eel"} },
  [201] = { {kind = "crafted", instance = 0, instanceName = "Crafted", encounter = 0, encounterName = ""} },
}
KeyLootMasterItems = {
  [100] = { s = "ch", l = 219, t = true },
  [101] = { s = "mv", l = 219 },
  [200] = { s = "chm", l = 230 },
}
KeyLootMasterSpecs = { [66] = {"paladin", "protection"}, [63] = {"mage", "fire"}, [999] = {"ghost", "none"} }
KeyLootMasterCatalyst = {
  head = { plate = { {1001, 10, "Keep", 1, "Boss A"}, {1002, 10, "Keep", 1, "Boss A"}, {1003, 20, "Temple", 2, "Boss B"} },
           cloth = { {1004, 30, "Vale", 3, "Boss C"} } },
  chest = { plate = { {1005, 20, "Temple", 2, "Boss B"}, {1006, 20, "Temple", 4, "Boss D"} } },
}
KeyLootMasterTierSet = {
  paladin = { name = {"Flame", "Flamme"}, bonus = { [4] = {"Big four.", ""}, [2] = {"Big two.", "Groß zwei."} } },
}
"""


@unittest.skipIf(lupa is None, "lupa is not installed")
class LogicTest(unittest.TestCase):
    def setUp(self):
        self.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(TABLES)
        loader = self.lua.eval("function(source, name, ns) return load(source, name)('KeyLootMaster', ns) end")
        self.ns = self.lua.eval("{}")
        loader((ADDON / "Logic.lua").read_text(encoding="utf-8"), "Logic.lua", self.ns)

    def call(self, name, *args):
        return self.ns[name](*args)

    def table(self, **fields):
        table = self.lua.table()
        for key, value in fields.items():
            table[key] = value
        return table

    def items_of(self, rows, slot):
        for row in rows.values():
            if row["slot"] == slot:
                return [item["item"] for item in row["items"].values()]
        raise AssertionError(slot)

    def test_spec_key_and_list_skip_specs_without_data(self):
        self.assertEqual(tuple(self.call("SpecKeyOf", 66)), ("paladin", "protection"))
        self.assertIsNone(self.call("SpecKeyOf", 12345))
        labels = [row["label"] for row in self.call("SpecList").values()]
        self.assertEqual(labels, ["Mage - Fire", "Paladin - Protection"])

    def test_rows_follow_the_slot_order_and_keep_every_slot(self):
        rows = self.call("Rows", "paladin", "protection", "mplus", None, None)
        self.assertEqual([row["slot"] for row in rows.values()], list(self.ns["SLOT_ORDER"].values()))
        self.assertEqual(self.items_of(rows, "head"), [100, 101, 102])
        self.assertEqual(self.items_of(rows, "feet"), [])

    def test_unknown_spec_gives_empty_rows(self):
        rows = self.call("Rows", "ghost", "none", "mplus", None, None)
        self.assertEqual(self.items_of(rows, "head"), [])

    def test_source_filter(self):
        filters = self.table(source="crafted")
        rows = self.call("Rows", "paladin", "protection", "mplus", filters, None)
        self.assertEqual(self.items_of(rows, "trinket"), [201])
        self.assertEqual(self.items_of(rows, "head"), [])
        # an item with two sources passes either filter
        for kind in ("dungeon", "raid"):
            rows = self.call("Rows", "paladin", "protection", "mplus", self.table(source=kind), None)
            self.assertIn(101, self.items_of(rows, "head"))
        # an item the data has no source for counts as "other"
        rows = self.call("Rows", "paladin", "protection", "mplus", self.table(source="other"), None)
        self.assertEqual(self.items_of(rows, "head"), [102])

    def test_stat_filter_needs_all_letters_and_unknown_items_fail(self):
        rows = self.call("Rows", "paladin", "protection", "mplus", self.table(stats="ch"), None)
        self.assertEqual(self.items_of(rows, "head"), [100])
        self.assertEqual(self.items_of(rows, "trinket"), [200])  # "chm" has c and h
        rows = self.call("Rows", "paladin", "protection", "mplus", self.table(stats="m"), None)
        self.assertEqual(self.items_of(rows, "head"), [101])
        self.assertEqual(self.items_of(rows, "neck"), [])  # 300 has no facts: unknown fails a stat filter

    def test_only_missing_hides_what_is_worn(self):
        worn = self.lua.eval("{[100] = true}")
        rows = self.call("Rows", "paladin", "protection", "mplus", self.table(missing=True), worn)
        self.assertEqual(self.items_of(rows, "head"), [101, 102])
        rows = self.call("Rows", "paladin", "protection", "mplus", self.table(missing=False), worn)
        self.assertEqual(self.items_of(rows, "head"), [100, 101, 102])

    def test_source_label_prefers_the_most_specific_and_counts_the_rest(self):
        text, more = self.call("SourceLabel", 101)
        self.assertEqual((text, more), ("Keep - Boss", 1))
        text, more = self.call("SourceLabel", 100)
        self.assertEqual((text, more), ("Catalyst / tier", 0))
        self.assertEqual(tuple(self.call("SourceLabel", 102)), (None, 0))

    def test_the_view_kinds_keep_what_can_be_got_in_that_view(self):
        mplus = self.call("ViewKinds", "mplus")
        self.assertTrue(mplus["dungeon"] and mplus["catalyst"] and mplus["crafted"])
        self.assertIsNone(mplus["raid"])
        raid = self.call("ViewKinds", "raid")
        self.assertTrue(raid["raid"] and raid["catalyst"] and raid["crafted"])
        self.assertIsNone(self.call("ViewKinds", "overall"))
        rows = self.call("Rows", "paladin", "protection", "mplus", self.table(kinds=mplus), None)
        # 100 is a tier piece, 101 drops in a dungeon: both stay; 102 has no known source: gone
        self.assertEqual(self.items_of(rows, "head"), [100, 101])
        # the raid-only trinket goes, the crafted one stays
        self.assertEqual(self.items_of(rows, "trinket"), [201])
        rows = self.call("Rows", "paladin", "protection", "raid", self.table(kinds=raid), None)
        self.assertEqual(self.items_of(rows, "head"), [100])

    def test_overall_merges_both_lists_weighted_by_their_players(self):
        rows = self.call("Rows", "paladin", "protection", "overall", None, None)
        head = next(r for r in rows.values() if r["slot"] == "head")["items"]
        merged = {e["item"]: e for e in head.values()}
        # 100: 45 of 50 dungeon players and 80 of 100 raiders = 125 of 150
        self.assertAlmostEqual(merged[100]["share"], 125 / 150)
        self.assertEqual(merged[100]["sample"], 150)
        self.assertAlmostEqual(merged[103]["share"], 10 / 150)
        self.assertEqual(self.items_of(rows, "head"), [100, 103, 101, 102])
        # a slot only one list knows: the other list counts as 0 players there
        self.assertAlmostEqual(
            next(e for r in rows.values() if r["slot"] == "trinket" for e in r["items"].values() if e["item"] == 200)["share"],
            35 / 150)
        # a filter applies to the merged list as to any other
        rows = self.call("Rows", "paladin", "protection", "overall", self.table(kinds=self.call("ViewKinds", "raid")), None)
        self.assertEqual(self.items_of(rows, "head"), [100, 101])

    def test_overall_with_one_list_only_uses_that_list(self):
        rows = self.call("Rows", "mage", "fire", "overall", None, None)
        self.assertEqual(self.items_of(rows, "head"), [500])

    def test_the_farming_route_groups_by_dungeon_and_sets_the_rest_aside(self):
        route = self.call("FarmingRoute", "paladin", "protection", "mplus", None)
        self.assertEqual(route["kind"], "dungeon")
        groups = list(route["groups"].values())
        self.assertEqual([g["name"] for g in groups], ["Keep"])
        item = list(groups[0]["items"].values())[0]
        self.assertEqual((item["item"], item["slot"], item["boss"], item["worn"]), (101, "head", "Boss", False))
        self.assertAlmostEqual(groups[0]["score"], 0.06)
        # the tier piece, the crafted piece and the raid piece M+ players wear are listed apart
        self.assertEqual([e["item"] for e in route["catalyst"].values()], [100])
        self.assertEqual([e["item"] for e in route["crafted"].values()], [201])
        self.assertEqual([e["item"] for e in route["other"].values()], [200])

    def test_the_farming_route_keeps_what_is_worn_but_does_not_count_it(self):
        worn = self.lua.eval("{[101] = true, [100] = true}")
        route = self.call("FarmingRoute", "paladin", "protection", "mplus", worn)
        group = list(route["groups"].values())[0]
        self.assertTrue(list(group["items"].values())[0]["worn"])
        self.assertEqual(group["score"], 0)
        self.assertTrue(list(route["catalyst"].values())[0]["worn"])

    def test_the_farming_route_of_the_raid_groups_by_boss(self):
        route = self.call("FarmingRoute", "paladin", "protection", "raid", None)
        self.assertEqual(route["kind"], "raid")
        # the raid list holds 100 (tier) and 103 (no source): no raid drop, so no group
        self.assertEqual(len(list(route["groups"].values())), 0)
        self.assertEqual([e["item"] for e in route["catalyst"].values()], [100])

    def test_the_catalyst_dungeons_are_ranked_by_how_many_raw_pieces_drop_there(self):
        both = self.call("CatalystDungeons", "paladin", self.lua.table_from(["head", "chest"]))
        self.assertEqual([(d["name"], d["count"]) for d in both.values()], [("Temple", 3), ("Keep", 2)])
        head = self.call("CatalystDungeons", "paladin", self.lua.table_from(["head"]))
        self.assertEqual([(d["name"], d["count"]) for d in head.values()], [("Keep", 2), ("Temple", 1)])
        # the armor type decides: a mage (cloth) is not offered plate pieces
        cloth = self.call("CatalystDungeons", "mage", self.lua.table_from(["head"]))
        self.assertEqual([d["name"] for d in cloth.values()], ["Vale"])
        # unknown class, unknown slot, no data at all
        self.assertEqual(len(list(self.call("CatalystDungeons", "ghost", self.lua.table_from(["head"])).values())), 0)
        self.assertEqual(len(list(self.call("CatalystDungeons", "paladin", self.lua.table_from(["legs"])).values())), 0)
        self.lua.execute("KeyLootMasterCatalyst = nil")
        self.assertEqual(len(list(self.call("CatalystDungeons", "paladin", self.lua.table_from(["head"])).values())), 0)

    def test_the_tier_set_comes_in_the_players_language_with_english_as_the_fallback(self):
        english = self.call("TierSetOf", "paladin", "en")
        self.assertEqual(english["name"], "Flame")
        self.assertEqual([(b["count"], b["text"]) for b in english["bonuses"].values()], [(2, "Big two."), (4, "Big four.")])
        german = self.call("TierSetOf", "paladin", "de")
        self.assertEqual(german["name"], "Flamme")
        self.assertEqual([b["text"] for b in german["bonuses"].values()], ["Groß zwei.", "Big four."])
        self.assertIsNone(self.call("TierSetOf", "mage", "en"))
        self.lua.execute("KeyLootMasterTierSet = nil")
        self.assertIsNone(self.call("TierSetOf", "paladin", "en"))

    def test_the_best_drop_names_the_kind_for_the_window(self):
        drop, more = self.call("BestDrop", 100)
        self.assertEqual((drop["kind"], drop["instance"], more), ("catalyst", 0, 0))
        drop, more = self.call("BestDrop", 101, "raid")
        self.assertEqual((drop["kind"], drop["encounterName"], more), ("raid", "Eel", 0))
        self.assertEqual(tuple(self.call("BestDrop", 102)), (None, 0))

    def test_share_index_takes_the_best_share_per_content(self):
        index = self.call("ShareIndex", "paladin", "protection")
        self.assertAlmostEqual(index[100]["mplus"], 0.9)
        self.assertAlmostEqual(index[100]["raid"], 0.8)
        self.assertIsNone(index[200]["raid"])
        self.assertEqual(len(list(self.call("ShareIndex", "ghost", "none").keys())), 0)

    def test_small_helpers(self):
        self.assertEqual(self.call("Percent", 0.625), "63%")
        self.assertEqual(self.call("Percent", 0.9), "90%")
        self.assertEqual(self.call("StatText", "hc"), "crit, haste")
        self.assertEqual(self.call("Title", "death-knight"), "Death Knight")
        self.assertEqual(self.call("Title", "beast-mastery"), "Beast Mastery")

    def test_the_generated_data_loads_and_the_logic_runs_on_it(self):
        data = ADDON / "Data"
        if not (data / "Specs.lua").exists():
            self.skipTest("no generated data yet")
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        for name in ("Specs.lua", "Drops.lua", "Items.lua", "paladin.lua"):
            lua.execute((data / name).read_text(encoding="utf-8"))
        loader = lua.eval("function(source, name, ns) return load(source, name)('KeyLootMaster', ns) end")
        ns = lua.eval("{}")
        loader((ADDON / "Logic.lua").read_text(encoding="utf-8"), "Logic.lua", ns)
        rows = ns["Rows"]("paladin", "protection", "mplus", None, None)
        head = next(row for row in rows.values() if row["slot"] == "head")
        self.assertGreaterEqual(len(list(head["items"].values())), 1)
        self.assertEqual(tuple(ns["SpecKeyOf"](66)), ("paladin", "protection"))


if __name__ == "__main__":
    unittest.main()
