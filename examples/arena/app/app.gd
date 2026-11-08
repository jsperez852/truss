extends Node
## Composition root (autoload "App", after "Truss"). Run with -- --autoplay to let a bot play and quit.


func _ready() -> void:
	var options := GameOptions.new()
	options.autoplay = OS.get_cmdline_user_args().has("--autoplay")
	var result: TrResult = Truss.boot([
		CoreModule.new(),
		GameModule.new(options),
		CombatModule.new(),
		WavesModule.new(),
		ScoreModule.new(),
	])
	if result.is_err():
		printerr("BOOT FAILED [%s]\n%s" % [result.error, result.message])
		get_tree().quit(1)
