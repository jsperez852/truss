@abstract class_name TrEvent
extends RefCounted
## Base class for events: facts that already happened, named in the past tense ([code]EnemyDied[/code],
## [code]LevelCompleted[/code]). Subclass it and add typed fields; publish instances with [TrEventBus].
## [codeblock]
## class_name EnemyDied
## extends TrEvent
##
## var enemy_type: StringName
##
## func _init(type: StringName) -> void:
##     enemy_type = type
## [/codeblock]

## Who published the event, when it was published with [code]bus.publish(event, source)[/code]. Handlers
## subscribed with a [code]source[/code] option only receive events whose source is that same object.
var source: Object
