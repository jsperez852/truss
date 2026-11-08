class_name TrAppEvents
extends RefCounted
## Application lifecycle events, published by the Truss autoload on the container's [TrEventBus] (when one is
## registered) and emitted as [signal Truss.app_event] (always).
## [codeblock]
## bus.subscribe(TrAppEvents.FocusLost, func(_e: TrAppEvents.FocusLost) -> void: autosave())
## bus.subscribe(TrAppEvents.QuitRequested, _save_before_quit)
## [/codeblock]
## Desktop sends focus events; Android and iOS send [code]Paused[/code]/[code]Resumed[/code] too. The base
## class [code]TrAppEvents.AppEvent[/code] receives every one of them.


## Base class of every lifecycle event.
class AppEvent:
	extends TrEvent


## The game window lost focus ([constant Node.NOTIFICATION_APPLICATION_FOCUS_OUT]).
class FocusLost:
	extends AppEvent


## The game window got focus back ([constant Node.NOTIFICATION_APPLICATION_FOCUS_IN]).
class FocusGained:
	extends AppEvent


## The OS paused the app, typically sent to the background on mobile ([constant Node.NOTIFICATION_APPLICATION_PAUSED]).
class Paused:
	extends AppEvent


## The OS resumed the app ([constant Node.NOTIFICATION_APPLICATION_RESUMED]).
class Resumed:
	extends AppEvent


## The window's close button or the OS asked the game to quit ([constant Node.NOTIFICATION_WM_CLOSE_REQUEST]).
class QuitRequested:
	extends AppEvent


## The event for a [Node] notification, or [code]null[/code] for notifications that aren't lifecycle events.
static func from_notification(what: int) -> AppEvent:
	match what:
		Node.NOTIFICATION_APPLICATION_FOCUS_OUT:
			return FocusLost.new()
		Node.NOTIFICATION_APPLICATION_FOCUS_IN:
			return FocusGained.new()
		Node.NOTIFICATION_APPLICATION_PAUSED:
			return Paused.new()
		Node.NOTIFICATION_APPLICATION_RESUMED:
			return Resumed.new()
		Node.NOTIFICATION_WM_CLOSE_REQUEST:
			return QuitRequested.new()
	return null
