class_name FxAsyncHandler
extends TrRequestHandler
## Waits one frame before answering, like a handler doing file or network I/O.

var finished: int = 0


func handles() -> Script:
	return FxAsyncRequest


func handle(request: TrRequest) -> TrResult:
	await (Engine.get_main_loop() as SceneTree).process_frame
	finished += 1
	return TrResult.success((request as FxAsyncRequest).value * 10)
