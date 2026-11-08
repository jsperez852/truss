class_name FxBlocker
extends TrBehavior

func process(_request: TrRequest, _next: Callable) -> TrResult:
	return TrResult.failure(&"blocked", "stopped by FxBlocker")
