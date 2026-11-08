@abstract class_name TrBehavior
extends RefCounted
## A step in the [TrMediator] pipeline that wraps every request: logging, validation, timing, undo history.
##
## Call [param next] to continue the pipeline (it returns the handler's [TrResult]), or return early to stop it.
## [codeblock]
## class_name LogRequests
## extends TrBehavior
##
## func process(request: TrRequest, next: Callable) -> TrResult:
##     var result: TrResult = next.call()
##     print(TrContracts.describe_value(request), " -> ", result)
##     return result
## [/codeblock]


@abstract func process(request: TrRequest, next: Callable) -> TrResult
