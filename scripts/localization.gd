extends Node
## Runtime gettext .po loader (autoload "Localization").
##
## Parses every res://locale/*.po file into a Translation and registers it with
## the TranslationServer at startup, so translations work without depending on
## Godot's editor import step. This keeps the .po/.pot files as the single,
## hand/Poedit/Weblate-editable source of truth.
##
## The locale of each file is taken from its filename ("sk.po" -> "sk").
## Empty msgstr entries are skipped so untranslated strings fall back to the
## English source msgid.

const LOCALE_DIR := "res://locale/"


func _ready() -> void:
	load_all_translations()


## Loads and registers every .po file found in LOCALE_DIR. Safe to call again.
func load_all_translations() -> void:
	var dir := DirAccess.open(LOCALE_DIR)
	if dir == null:
		push_warning("Localization: cannot open %s" % LOCALE_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "po":
			_load_po_file(LOCALE_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_po_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Localization: cannot read %s" % path)
		return

	var translation := Translation.new()
	translation.locale = path.get_file().get_basename()  # "sk.po" -> "sk"

	var current_msgid := ""
	var current_msgstr := ""
	var state := ""  # "msgid" | "msgstr" | "" (ignored)
	var added := 0

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("msgid "):
			# A new entry begins: flush the previous one.
			added += _add_if_valid(translation, current_msgid, current_msgstr)
			current_msgid = _unquote_po(line.substr(6))
			current_msgstr = ""
			state = "msgid"
		elif line.begins_with("msgstr "):
			current_msgstr = _unquote_po(line.substr(7))
			state = "msgstr"
		elif line.begins_with("msgid_plural ") or line.begins_with("msgctxt "):
			# Plural / context forms are not handled by this simple loader.
			state = ""
		elif line.begins_with("\""):
			var chunk := _unquote_po(line)
			if state == "msgid":
				current_msgid += chunk
			elif state == "msgstr":
				current_msgstr += chunk

	added += _add_if_valid(translation, current_msgid, current_msgstr)
	file.close()

	if added > 0:
		TranslationServer.add_translation(translation)


func _add_if_valid(translation: Translation, msgid: String, msgstr: String) -> int:
	# Skip the PO header (empty msgid) and untranslated entries (empty msgstr).
	if msgid.is_empty() or msgstr.is_empty():
		return 0
	translation.add_message(msgid, msgstr)
	return 1


## Strips the surrounding quotes of a PO string literal and unescapes it.
func _unquote_po(raw: String) -> String:
	var s := raw.strip_edges()
	var first := s.find("\"")
	var last := s.rfind("\"")
	if first < 0 or last <= first:
		return ""
	s = s.substr(first + 1, last - first - 1)
	# Unescape. Protect literal backslashes with an unlikely token first so the
	# later single-backslash unescapes don't disturb them.
	var sentinel := "BSLASH_TOKEN"
	s = s.replace("\\\\", sentinel)
	s = s.replace("\\n", "\n")
	s = s.replace("\\t", "\t")
	s = s.replace("\\\"", "\"")
	s = s.replace(sentinel, "\\")
	return s
