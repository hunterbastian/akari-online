extends RefCounted

## Mina keeps a limb shell, and the sky can fade from space to air.


static func run() -> int:
	var failed := 0
	var shells: Array = Engine.get_main_loop().get_nodes_in_group("planet_atmo")
	if shells.size() < 2 or shells.size() % 2 != 0:
		push_error("expected a pair of atmosphere shells per planet, got %d" % shells.size())
		failed += 1
	var env_node := Engine.get_main_loop().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if env_node == null or env_node.environment == null or env_node.environment.sky == null:
		push_error("sky missing")
		return failed + 1
	var mat: ShaderMaterial = env_node.environment.sky.sky_material as ShaderMaterial
	if mat == null or mat.get_shader_parameter("ground_mix") == null:
		push_error("sky has no ground_mix")
		failed += 1
	else:
		mat.set_shader_parameter("ground_mix", 0.4)
		var back: float = mat.get_shader_parameter("ground_mix")
		if absf(back - 0.4) > 0.001:
			push_error("ground_mix did not stick")
			failed += 1
		mat.set_shader_parameter("ground_mix", 0.0)
	if failed == 0:
		print("Atmosphere tests passed.")
	return failed
