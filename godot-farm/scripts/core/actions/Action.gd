class_name Action
extends RefCounted

## Base class for all game actions
## Actions encapsulate game logic and support undo/redo

enum Status {
	PENDING,
	EXECUTED,
	FAILED,
	UNDONE
}

var status: Status = Status.PENDING
var timestamp: int = 0

func _init():
	timestamp = Time.get_unix_time_from_system()

## Execute the action - MUST be overridden by subclasses
## Returns true if successful
func execute() -> bool:
	push_error("Action.execute() must be overridden")
	return false

## Undo the action - optional, returns true if successful
func undo() -> bool:
	return false

## Check if action can be executed
func can_execute() -> bool:
	return true

## Get action description for logging/debugging
func get_description() -> String:
	return "Action"

## Serialize action for save games
func serialize() -> Dictionary:
	return {
		"type": get_class_name(),
		"timestamp": timestamp,
		"status": status
	}

## Deserialize action from save data
func deserialize(data: Dictionary) -> void:
	timestamp = data.get("timestamp", Time.get_unix_time_from_system())
	status = data.get("status", Status.PENDING)

## Get class name for serialization
func get_class_name() -> String:
	return "Action"
