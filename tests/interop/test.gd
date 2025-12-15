extends SceneTree

var test_passed := true
var test_messages: Array[String] = []

func _init() -> void:
	run_tests()

	for msg in test_messages:
		print(msg)

	if test_passed:
		print("All interop tests passed!")
		quit(0)
	else:
		print("Some interop tests failed!")
		quit(1)

func run_tests() -> void:
	test_zig_method_call()
	test_zig_object_passing()
	test_zig_signal_emission()
	test_zig_object_extension()
	test_godot_object_to_zig()
	test_gdscript_signal_to_zig()

## Test 1: Call a method on ZigObject from GDScript
func test_zig_method_call() -> void:
	var zig_obj: ZigObject = ZigObject.new()
	root.add_child(zig_obj)

	var result: int = zig_obj.zig_method(15, 25)

	if result == 40:
		log_pass("test_zig_method_call: ZigObject.zig_method(15, 25) returned 40")
	else:
		log_fail("test_zig_method_call: Expected 40, got %d" % result)

	zig_obj.queue_free()

## Test 2: Pass a ZigObject to another ZigObject's method
func test_zig_object_passing() -> void:
	var zig_obj1: ZigObject = ZigObject.new()
	var zig_obj2: ZigObject = ZigObject.new()
	root.add_child(zig_obj1)
	root.add_child(zig_obj2)

	# Call method on zig_obj2 to set its call_count
	zig_obj2.zig_method(100, 200)

	# Pass zig_obj2 to zig_obj1 - receiveZigObject copies call_count to last_received_value
	zig_obj1.receive_zig_object(zig_obj2)

	# Verify the interaction worked - should receive call_count of 1
	var received: int = zig_obj1.get_last_received_value()
	if received == 1:
		log_pass("test_zig_object_passing: ZigObject successfully received another ZigObject (call_count: %d)" % received)
	else:
		log_fail("test_zig_object_passing: Failed to pass ZigObject, expected call_count 1, got: %d" % received)

	zig_obj1.queue_free()
	zig_obj2.queue_free()

## Test 3: Receive a signal emitted from Zig
func test_zig_signal_emission() -> void:
	var zig_obj: ZigObject = ZigObject.new()
	root.add_child(zig_obj)

	var signal_received := false
	var signal_value := 0

	zig_obj.zig.connect(func(value: int) -> void:
		signal_received = true
		signal_value = value
	)

	zig_obj.emit_zig_signal(999)

	if signal_received and signal_value == 999:
		log_pass("test_zig_signal_emission: Received zig signal with value 999")
	else:
		log_fail("test_zig_signal_emission: Signal not received or wrong value (received: %s, value: %d)" % [signal_received, signal_value])

	zig_obj.queue_free()

## Test 4: Extend ZigObject in GDScript and override virtual method
func test_zig_object_extension() -> void:
	var ext: ZigObjectExtension = ZigObjectExtension.new()
	root.add_child(ext)

	# Manually notify ready since we're not running the main loop
	ext.notification(Node.NOTIFICATION_READY)

	if ext.extension_ready_called:
		log_pass("test_zig_object_extension: ZigObjectExtension._ready was called")
	else:
		log_fail("test_zig_object_extension: ZigObjectExtension._ready was NOT called")

	var result: int = ext.zig_method(7, 8)
	if result == 15:
		log_pass("test_zig_object_extension: Base zig_method still works (7 + 8 = 15)")
	else:
		log_fail("test_zig_object_extension: Base zig_method failed, expected 15, got %d" % result)

	ext.queue_free()

## Test 5: Create a GodotObject and pass it to Zig
func test_godot_object_to_zig() -> void:
	var godot_obj: GodotObject = GodotObject.new()
	var zig_obj: ZigObject = ZigObject.new()
	root.add_child(godot_obj)
	root.add_child(zig_obj)

	var gd_value: int = godot_obj.godot_method(50)

	if gd_value == 100:
		log_pass("test_godot_object_to_zig: GodotObject.godot_method(50) returned 100")
	else:
		log_fail("test_godot_object_to_zig: Expected 100, got %d" % gd_value)

	godot_obj.queue_free()
	zig_obj.queue_free()

## Test 6: GDScript signal received by Zig
func test_gdscript_signal_to_zig() -> void:
	var godot_obj: GodotObject = GodotObject.new()
	var zig_obj: ZigObject = ZigObject.new()
	root.add_child(godot_obj)
	root.add_child(zig_obj)

	godot_obj.godot_signal.connect(zig_obj.on_godot_signal)
	godot_obj.emit_godot_signal(777)

	var received: int = zig_obj.get_signal_received_value()
	if received == 777:
		log_pass("test_gdscript_signal_to_zig: ZigObject received godot_signal with value 777")
	else:
		log_fail("test_gdscript_signal_to_zig: Expected signal value 777, got %d" % received)

	godot_obj.queue_free()
	zig_obj.queue_free()

func log_pass(msg: String) -> void:
	test_messages.append("[PASS] " + msg)

func log_fail(msg: String) -> void:
	test_passed = false
	test_messages.append("[FAIL] " + msg)


## GodotObject: A pure GDScript class with methods and signals
class GodotObject extends Node:
	signal godot_signal(value: int)

	var call_count := 0

	func godot_method(x: int) -> int:
		call_count += 1
		return x * 2

	func emit_godot_signal(value: int) -> void:
		godot_signal.emit(value)


## ZigObjectExtension: A GDScript class that extends ZigObject
class ZigObjectExtension extends ZigObject:
	var extension_ready_called: bool = false
	var extension_custom_value: int = 0

	func _ready() -> void:
		extension_ready_called = true
		extension_custom_value = 123
