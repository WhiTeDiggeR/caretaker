class_name ScriptErrorLogger
extends Logger

## Collects GDScript runtime errors while the opening checks run (issue #163). A script
## error inside a case aborts the rest of that case silently; the runner turns every
## collected error into a failure so it cannot pass with `failures=0`. Errors of the engine
## (not of scripts) are left to the log. Loggers may be called from other threads.

var _mutex := Mutex.new()
var _errors := PackedStringArray()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_mutex.lock()
	_errors.append("script error: %s (%s:%d in %s)" % [rationale if not rationale.is_empty() else code, file, line, function])
	_mutex.unlock()


## Errors collected since the last call; clears the list.
func take() -> PackedStringArray:
	_mutex.lock()
	var taken := _errors
	_errors = PackedStringArray()
	_mutex.unlock()
	return taken
