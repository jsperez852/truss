class_name FxBadHandler
extends TrRequestHandler

func handles() -> Script:
	return FxStore

func handle(_request: TrRequest) -> TrResult:
	return TrResult.success()
