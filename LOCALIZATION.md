# Manual localization from the Roblox profile

The game selects its language exclusively from `Players.LocalPlayer.LocaleId`:

| Profile locale | Game text |
| --- | --- |
| `uk`, `uk-UA` | Ukrainian manual translation |
| `ru`, `ru-RU` | Russian manual translation |
| `en`, `en-US`, other unsupported locales | Existing English source |

There is no in-game switch, override attribute, language RemoteEvent or language
DataStore. Change the language in the Roblox profile and rejoin to test it.
`LocaleId` is the account's in-experience language, rather than the operating
system language or `LocalizationService.RobloxLocaleId` used by CoreGui.
Reference: https://create.roblox.com/docs/reference/engine/classes/Player#LocaleId

`LocaleController` disables `AutoLocalize` on the game's PlayerGui descendants
and applies only the repository's hand-authored dictionary. It never requests a
cloud/machine translator. Roblox's own protected CoreGui is untouched.

## Translation scope and terminology

`src/shared/Locales` contains 898 English source entries with both Ukrainian and
Russian translations: interface, controls, all four help pages, items and their
variants, recipes, attributes, skills, perks, medical actions, farming, towns,
diplomacy, markets, administration and notifications. Existing English item names,
IDs, commands, balance values and network action arguments remain stable.

Examples of consistent terminology:

| English | Ukrainian | Russian |
| --- | --- | --- |
| Attributes | Атрибути | Атрибуты |
| Skills | Навички | Навыки |
| Perks | Здібності | Способности |
| First aid | Перша допомога | Первая помощь |
| Doctor | Лікар | Врач |
| Damage absorption | Поглинання шкоди | Поглощение урона |
| Damage resistance | Опір шкоді | Сопротивление урону |
| Armor class | Клас захисту | Класс защиты |
| HP / AC | ОЗ / КЗ | ОЗ / КЗ |

The help pages preserve the author's informal tone. Combat reports use a compact
actor → target format, avoiding incorrect gender or case changes to player names.

The binder retains each object's original English source. New labels, late server
messages, placeholders and changed text translate when their events fire. It does
not scan the UI every frame. `UIUpdates.Set` and progression counters compare
original sources so unchanged values do not cause repeated translation writes.
Formatted templates preserve captured numbers, hotkeys and ammunition codes;
unknown future strings fall back to English. Caches are limited to 512 strings
per translated language.

Help scroll height and progression tooltips measure the localized text. Item
descriptions can grow vertically to accommodate longer translations. Actual
font/layout appearance still needs a Studio/client check; mock tests are not
visual verification.

## Adding text safely

1. Keep English as the source. Add `{English, Ukrainian, Russian}` to the relevant
   locale module; `LocalizationCatalog` loads every group.
2. For formatted text, use the existing English printf source and `{1}`, `{2}`,
   etc. in translations. Every argument must be retained. A fourth entry such as
   `{[2]=true}` marks argument 2 as opaque (a name), so it is not translated.
3. Wrap dynamic player/town names and filtered user reasons with `Locale.Raw`
   on the client or `LocalizationRules.Protect` on the server. Internal markers
   are removed when rendering, including in English. Do not use them in IDs or
   player input. Player names, arbitrary chat, reasons and TextBox.Text stay intact.
4. For a purely user-authored label, set `LocalizationIgnore = true`. TextBox.Text
   is never bound; only PlaceholderText is. Chat rows explicitly opt out.
5. Use `Locale.Set(object, "Text", englishSource)` or `UIUpdates.Set` for frequently
   refreshed fields. Computed combat rows use `Locale.Computed`.

Stable manual fragments support existing concatenated UI strings; full-sentence
and structured templates take priority. New complex sentences should receive a
complete entry rather than relying on fragments. Developer diagnostics and
unknown future authored content may remain English.

## Validation

`tests/run_localization.py` checks complete Name/Description coverage for every
current item, recipe and perk, all template variables in both languages, preserved
numbers, opaque names, English fallback and bounded caches.
`tests/run_locale_controller.py` runs the actual controller against eventful mock
instances: profile-only selection, existing/new text, placeholders, profile
changes, unchanged-source writes, user input/name protection, combat history and
cleanup. The help, inventory/crafting, town and progression regression suites
remain applicable. No live Studio or published-client locale test is implied.
