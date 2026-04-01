class_name PhaseModel
extends RefCounted

# Model layer — data for a single phase.
# Serializes to/from the phase-config.json format.
# folder_path, photo_count, and notes are computed at load time and excluded from to_dict().


var phase_name: String = ""
var color: String = "#6495ed"
var folder_path: String = ""
var photo_count: int = 0
var start_date: String = ""
var end_date: String = ""
var archived: bool = false
var connections: Array[String] = []
var playlist_link: String = ""
var photos: Array = []
var note_positions: Array = []
var video_positions: Array = []
var notes: Array[NoteModel] = []


static func from_dict(d: Dictionary) -> PhaseModel:
	var p := PhaseModel.new()
	p.phase_name = d.get("phase_name", "")
	p.color = d.get("color", "#6495ed")
	p.start_date = d.get("start_date", "")
	p.end_date = d.get("end_date", "")
	p.archived = d.get("archived", false)
	p.playlist_link = d.get("playlist_link", "")
	for c: Variant in (d.get("connections", []) as Array):
		p.connections.append(str(c))
	for entry: Variant in (d.get("photos", []) as Array):
		if entry is Dictionary:
			p.photos.append(entry)
	for entry: Variant in (d.get("note_positions", []) as Array):
		if entry is Dictionary:
			p.note_positions.append(entry)
	for entry: Variant in (d.get("video_positions", []) as Array):
		if entry is Dictionary:
			p.video_positions.append(entry)
	return p


func to_dict() -> Dictionary:
	return {
		"phase_name": phase_name,
		"color": color,
		"playlist_link": playlist_link,
		"start_date": start_date,
		"end_date": end_date,
		"archived": archived,
		"connections": connections,
		"photos": photos,
		"note_positions": note_positions,
		"video_positions": video_positions,
	}
