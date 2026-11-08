class_name FxAddHandler
extends TrRequestHandler

var calls: int = 0

func handles() -> Script:
	return FxAdd

func handle(request: TrRequest) -> TrResult:
	calls += 1
	var r := request as FxAdd
	if r.a < 0:
		return TrResult.failure(&"negative", "a must be >= 0")
	return TrResult.success(r.a + r.b)
