@abstract class_name TrRequestHandler
extends RefCounted
## Handles exactly one [TrRequest] class. Register it with [method TrMediator.register].
## [codeblock]
## class_name AddItemHandler
## extends TrRequestHandler
##
## var _inventory: Inventory
##
## func _init(inventory: Inventory) -> void:
##     _inventory = inventory
##
## func handles() -> Script:
##     return AddItemRequest
##
## func handle(request: TrRequest) -> TrResult:
##     var r := request as AddItemRequest
##     return _inventory.add(r.item, r.amount)
## [/codeblock]


## The [TrRequest] subclass this handler accepts.
@abstract func handles() -> Script


## Processes [param request] and returns its outcome.
@abstract func handle(request: TrRequest) -> TrResult
