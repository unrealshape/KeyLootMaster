# KeyLootMaster

A World of Warcraft addon (Retail 12.x) that shows where the best gear of your class and specialization
drops, for Mythic+ dungeons and the current raid. The data comes from what the best players actually wear.

> Screenshots will follow.

## What it can do

`/klm` (or the button in the addon list next to the minimap) opens the window.

- **Items:** the best items per slot for your specialization (or any other). The **Overall**, **Mythic+** and
  **Raid** buttons choose the list: both together, what drops in the dungeons, or what drops in the raid (the
  Catalyst and crafted pieces are listed in each). Each item names the dungeon and boss (or the raid boss) and
  opens in the Adventure Guide.
- **Farming:** where to farm. The dungeons (or raid bosses) in the order they are worth running, with the
  items that drop there and how many of the top players wear them; the crafted and Catalyst pieces beside it.
  What you wear already is marked **Equipped** and does not count.
- **Key level and Great Vault:** item levels at the key level you pick, or the Vault reward of that level.
- **Two specializations at once:** pick "Compare with" in the specialization menu, and the lists show only
  the items both specializations want (for example Retribution and Holy).
- **Gear:** the enchantments, gems and gem combinations the top players use, compared with yours.
- **Talents:** the builds of the top players. "Apply build" adds one as a new loadout in the talent window,
  and overwrites nothing; "Copy" gives the import string.
- **Players:** the best players of the specialization with realm, race, item level and rating.
- **Tooltips:** a line in every item tooltip with the share of top players who wear it (`/klm tooltip`
  switches it off).

## Install

Download the zip of the newest [release](../../releases/latest) and unzip it into
`World of Warcraft/_retail_/Interface/AddOns`. The folder inside is called `KeyLootMaster`.

## Where the data comes from

The data is not collected by the addon. [KeyLootDataMiner](https://github.com/unrealshape/KeyLootDataMiner)
reads the Blizzard API and Warcraft Logs twice a week and writes the Lua files in `KeyLootMaster/Data/`
into this repository.

## Releases

Every change of the addon on `main` (a data update from the DataMiner or a code change) runs the tests and
then publishes a new version, `vYYYY.MM.DD.<run>`, with `KeyLootMaster-<version>.zip` attached
(`.github/workflows/release.yml`).

## Develop

```
pip install lupa
python -m unittest discover -s tests -v
```

The tests run the addon's Lua in a runtime against a stub of the game API, with the real data. The addon has
not been verified in the game client itself yet.

## License

MIT, see [LICENSE](LICENSE).
