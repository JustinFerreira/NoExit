## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Note Data
## - One readable note. Make one per note in res://Assets/Notes/
##   (right-click the folder > New > Resource... > NoteData), fill in the
##   fields, and every note in the game lives in that one folder.
## - Put a NoteItem in the level and drag the note onto its `note` slot.
## - Scripts check if the player found it with GameState.has_note("id").

extends Resource
class_name NoteData

## Unique name scripts use, e.g. "janitor_schedule". Don't change it once
## other scripts reference it.
@export var id: String = ""
## Shown in the journal list and at the top of the note.
@export var title: String = "Untitled Note"
## The note itself.
@export_multiline var text: String = ""
