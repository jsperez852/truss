class_name FxPauseTarget
extends RefCounted
## Stands in for the SceneTree in pause tests, so the test runner itself is never paused.

var paused: bool = false
