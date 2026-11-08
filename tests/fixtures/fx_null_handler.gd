class_name FxNullHandler
extends TrRequestHandler

func handles() -> Script:
	return FxUnhandled

func handle(_request: TrRequest) -> TrResult:
	return null
