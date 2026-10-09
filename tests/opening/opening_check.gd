class_name OpeningCheck
extends RefCounted

## Assertion context shared by the opening-systems check cases.

var checks := 0
var failures := PackedStringArray()
var tree: SceneTree
var root: Node
var _case := ""


func _init(scene_tree: SceneTree, case_root: Node) -> void:
	tree = scene_tree
	root = case_root


func begin_case(case_name: String) -> void:
	_case = case_name


func is_true(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [_case, message])


func equal(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: %s (got %s, expected %s)" % [_case, message, var_to_str(actual), var_to_str(expected)])


func near(actual: float, expected: float, tolerance: float, message: String) -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		failures.append("%s: %s (got %.4f, expected %.4f)" % [_case, message, actual, expected])


## Adds a node under the case root; the runner frees it after the case.
func add(node: Node) -> Node:
	root.add_child(node)
	return node


func physics_frames(count: int) -> void:
	for _i in count:
		await tree.physics_frame
