# Tredig – Localization / Translations

Tredig uses **gettext .po** files as the source of truth for translations,
loaded at runtime by the `Localization` autoload (`res://scripts/localization.gd`).

- `tredig.pot` – translation **template** listing every translation key. The
  English source text for each key is shown in the `#.` comment above it.
- `en.po` – English (the source language). Keys are symbolic IDs, so English is
  an explicit translation just like any other language.
- `sk.po` – Slovak translation.
- `en` is the default/fallback language.

At startup the `Localization` autoload scans `res://locale/*.po`, parses each one
into a `Translation`, and registers it with the `TranslationServer`. There is **no
editor import step and no `.translation` binaries** – edit the `.po` files and the
game picks them up on the next run. UI text is translated automatically
(Godot auto-translate); dynamic/formatted strings in scripts use `tr("...")`.

## Adding a new language

1. **Copy** `tredig.pot` to `<code>.po` (e.g. `de.po`, `pl.po`, `cs.po`, `uk.po`)
   using the correct locale code (see Godot's supported locales).
2. Set the header `"Language: <code>\n"` and fill in every `msgstr`.
   Keep format placeholders (`%d`, `%s`, `%d%%`) intact and preserve BBCode
   tags (`[b]`, `[url]`) in the credits string. Edit in a plain text editor,
   or use **Poedit** / **Weblate** / **Crowdin**.
3. Add the language to the in-game picker: append
   `{"code": "<code>", "name": "<native name>"}` to `SUPPORTED_LOCALES`
   in `scripts/user_settings.gd`.

That's it – the runtime loader auto-discovers the new `.po`; no `project.godot`
change is required. (Exports already include `*.po` via each preset's
`include_filter` in `export_presets.cfg`.)

## Regenerating the template

After adding/changing UI text in scenes or scripts, regenerate `tredig.pot` from
the Godot editor: **Project → Project Settings → Localization → POT Generation →
Generate**. The scanned files are listed under `internationalization/locale/translations_pot_files`
in `project.godot`. Then merge the new strings into each `.po` (Poedit's
"Update from POT file", or `msgmerge`).

## Notes

- Translation keys are **symbolic IDs** (e.g. `MenuPlay`, `SkillPickConfirm`),
  not the English text. This means editing the English wording only touches
  `en.po` – other languages keep their key and are unaffected. Scenes and scripts
  reference the key; the visible text comes from the `.po` files at runtime.
- **Fonts:** the UI font `PressStart2P` is a pixel font that may not include all
  diacritics (e.g. Slovak č/ď/ľ/š/ž) or non-Latin scripts (Cyrillic, CJK…).
  Languages needing those glyphs may require a font swap / fallback in `ui_theme.tres`.
- **Plurals:** the runtime loader handles simple `msgid`/`msgstr` pairs only.
  Languages with complex plural forms (e.g. Slovak "1 dynamit / 2-4 dynamity /
  5+ dynamitov") would need `tr_n()` support to be added if grammatically correct
  counted strings are desired.
