@abstract class_name TrRequest
extends RefCounted
## Base class for commands ("do this") and queries ("tell me this") sent through a [TrMediator].
## Subclass it, add typed fields, and register one [TrRequestHandler] for it.
## [codeblock]
## class_name AddItemRequest
## extends TrRequest
##
## var item: ItemDef
## var amount: int
## [/codeblock]
