class_name FxAsyncRecorder
extends TrBehavior

var label: String
var log: Array[String]


func _init(p_label: String, p_log: Array[String]) -> void:
	label = p_label
	log = p_log


func process(_request: TrRequest, next: Callable) -> TrResult:
	log.append("sync " + label)
	var result: TrResult = next.call()
	return result


func process_async(_request: TrRequest, next: Callable) -> TrResult:
	log.append(label + ">")
	var result: TrResult = await next.call()
	log.append("<" + label)
	return result
