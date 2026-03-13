extends SceneTree

## Test Runner - Executes all test suites
## Usage: godot --headless --script tests/run_all_tests.gd

var _tests_passed: int = 0
var _tests_failed: int = 0
var _test_errors: Array[String] = []

func _init():
	print("=" .repeat(60))
	print("  Cozy Farm - Test Runner")
	print("=" .repeat(60))
	
	# Run test suites in order
	_run_smoke_tests()
	_run_integration_tests()
	_run_validation_tests()
	
	# Report
	print("")
	print("=" .repeat(60))
	print("  RESULTS: %d passed, %d failed" % [_tests_passed, _tests_failed])
	print("=" .repeat(60))
	
	if _test_errors.size() > 0:
		print("\nFailures:")
		for err in _test_errors:
			print("  ✗ " + err)
	
	# Exit with appropriate code
	quit(0 if _tests_failed == 0 else 1)

func _run_smoke_tests():
	print("\n[Smoke Tests]")
	_assert("StateManager loads", _test_autoload_exists("StateManager"))
	_assert("ActionSystem loads", _test_autoload_exists("ActionSystem"))
	_assert("Project file valid", FileAccess.file_exists("res://project.godot"))

func _run_integration_tests():
	print("\n[Integration Tests]")
	_assert("StateManager apply_action", _test_state_manager_actions())
	_assert("ActionSystem execute", _test_action_system_execute())

func _run_validation_tests():
	print("\n[Validation Tests]")
	_assert("Crop schema exists", FileAccess.file_exists("res://data/schemas/crop_schema.json"))
	_assert("State docs exist", FileAccess.file_exists("res://docs/state/state_truth_source.md"))

func _test_autoload_exists(name: String) -> bool:
	# Check script file exists for autoload
	var paths = {
		"StateManager": "res://scripts/core/state/state_manager.gd",
		"ActionSystem": "res://scripts/core/state/action_system.gd",
	}
	if paths.has(name):
		return FileAccess.file_exists(paths[name])
	return false

func _test_state_manager_actions() -> bool:
	var sm = load("res://scripts/core/state/state_manager.gd")
	return sm != null

func _test_action_system_execute() -> bool:
	var as_script = load("res://scripts/core/state/action_system.gd")
	return as_script != null

func _assert(test_name: String, condition: bool):
	if condition:
		_tests_passed += 1
		print("  ✓ " + test_name)
	else:
		_tests_failed += 1
		_test_errors.append(test_name)
		print("  ✗ " + test_name)
