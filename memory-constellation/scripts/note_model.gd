class_name NoteModel
extends RefCounted

# Model layer — data for a single markdown note inside a phase folder.
# Loaded from disk at scan time; not serialized into phase-config.json.
# file_path is computed at load time.


var file_name: String = ""
var title: String = ""
var content: String = ""
var file_path: String = ""


static func from_file(path: String) -> NoteModel:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var n := NoteModel.new()
	n.file_path = path
	n.file_name = path.get_file()
	n.content = text
	n.title = _parse_title(text, n.file_name)
	return n


static func _parse_title(text: String, fallback_file_name: String) -> String:
	for line: String in text.split("\n", false, 5):
		var stripped := line.strip_edges()
		if stripped.begins_with("# "):
			return stripped.trim_prefix("# ").strip_edges()
	return fallback_file_name.get_basename().replace("_", " ")
