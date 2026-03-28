class_name NoteDisplay
extends Control


@onready var _label: RichTextLabel = $RichTextLabel


func display(note: NoteModel) -> void:
	_label.text = note.content
