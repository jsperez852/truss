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
