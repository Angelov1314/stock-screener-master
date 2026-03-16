extends Node

## 修复测试脚本 - 验证所有修复是否正常工作

func _ready():
	print("=== Godot Farm 修复测试 ===")
	
	# 等待一帧确保所有自动加载完成
	await get_tree().process_frame
	
	_test_initial_gold()
	_test_user_data_manager()
	_test_planting_cost()
	
	print("\n=== 测试完成 ===")

func _test_initial_gold():
	print("\n[测试1] 初始金币检查...")
	var state_mgr = get_node_or_null("/root/StateManager")
	var eco_mgr = get_node_or_null("/root/EconomyManager")
	
	if state_mgr and eco_mgr:
		var state_gold = state_mgr.get_gold()
		var eco_gold = eco_mgr.get_gold()
		print("  StateManager 金币: %d" % state_gold)
		print("  EconomyManager 金币: %d" % eco_gold)
		
		if state_gold == 100:
			print("  ✓ 初始金币设置正确: 100")
		else:
			print("  ✗ 初始金币错误，期望 100，实际 %d" % state_gold)
		
		if state_gold == eco_gold:
			print("  ✓ StateManager 和 EconomyManager 金币同步")
		else:
			print("  ✗ 金币不同步!")
	else:
		print("  ✗ StateManager 或 EconomyManager 未找到")

func _test_user_data_manager():
	print("\n[测试2] UserDataManager 检查...")
	var user_mgr = get_node_or_null("/root/UserDataManager")
	
	if user_mgr:
		print("  ✓ UserDataManager 已加载")
		print("  用户名: %s" % user_mgr.get_username())
		print("  等级: %d" % user_mgr.get_level())
		print("  金币: %d" % user_mgr.get_gold())
		
		# 测试数据修改
		user_mgr.set_username("TestFarmer")
		if user_mgr.get_username() == "TestFarmer":
			print("  ✓ 用户名修改成功")
		else:
			print("  ✗ 用户名修改失败")
		
		# 恢复默认
		user_mgr.set_username("Farmer")
	else:
		print("  ✗ UserDataManager 未找到")

func _test_planting_cost():
	print("\n[测试3] 种植成本检查...")
	
	# 检查 ActionSystem 是否正确读取 seed_cost
	var crop_data = _get_crop_data("carrot")
	var seed_cost = crop_data.get("seed_cost", 0)
	print("  胡萝卜种子成本: %d" % seed_cost)
	
	if seed_cost > 0:
		print("  ✓ 种植成本已配置")
	else:
		print("  ! 种植成本为0或不存在")

func _get_crop_data(crop_id: String) -> Dictionary:
	var file_path = "res://data/crops/%s.json" % crop_id
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			return json.data
	return {}
