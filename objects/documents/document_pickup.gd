class_name DocumentPickup
extends StaticBody3D

## A document lying in the world. Using it opens the reader and adds it to the journal.

const PROMPT := "ПРОЧИТАТЬ"

@export var document_id := ""

@onready var _interactable: Interactable = $Interactable

var reader: DocumentReader


func _ready() -> void:
	if not DocumentLibrary.has(document_id):
		push_error("DocumentPickup %s: unknown document '%s'" % [name, document_id])
	_interactable.prompt = PROMPT
	_interactable.interacted.connect(read)


func read() -> void:
	if reader or not DocumentLibrary.has(document_id):
		return
	DocumentLibrary.mark_read(document_id)
	reader = DocumentReader.open_document_scene(get_tree(), document_id)
	reader.closed.connect(func() -> void: reader = null)
