## ModalHub — 全局访问辅助（非 autoload，避免超出 10 个配额）
##
## 用途：业务代码通过 `ModalHubRef.open(...)` 静态方法访问全局 Modal 管理器，
## 无需关心节点路径。内部通过 SceneTree 根节点索引到 main.gd 下挂载的 ModalLayer。
##
## 使用示例（调用方用 preload 获取脚本引用）：
##   const ModalHubRef := preload("res://common/ui/modal_hub.gd")
##   ModalHubRef.open(my_content, "标题", {"size": Vector2(640, 800)})
##   ModalHubRef.close()
##   ModalHubRef.close_all()

extends Object

# ============================================================
# 常量：ModalLayer 在主场景下的节点路径
# ============================================================
const MODAL_NODE_PATH := "/root/Main/ModalLayer"


## 静态获取 ModalManager 实例（CanvasLayer with modal_manager.gd 挂载）
## 若未挂载或场景未就绪返回 null
## 查找策略：优先 group "modal_layer"（主 Main 节点重命名后仍可用），回退到硬路径
static func get_instance() -> CanvasLayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var from_group := tree.get_nodes_in_group("modal_layer")
	if not from_group.is_empty():
		var n: Node = from_group[0]
		if n is CanvasLayer:
			return n as CanvasLayer
	return tree.root.get_node_or_null(MODAL_NODE_PATH) as CanvasLayer


## 打开 Modal（代理到 ModalManager.open）
static func open(content: Variant, title: String = "", options: Dictionary = {}) -> int:
	var hub := get_instance()
	if hub == null:
		push_warning("[ModalHub] ModalLayer 未就绪，open 被忽略")
		return -1
	return hub.open(content, title, options)


## 关闭最上层（或指定 id）
static func close(modal_id: int = -1) -> void:
	var hub := get_instance()
	if hub:
		hub.close(modal_id)


## 关闭所有
static func close_all() -> void:
	var hub := get_instance()
	if hub:
		hub.close_all()


## 是否有 Modal 打开
static func is_open() -> bool:
	var hub := get_instance()
	return hub != null and hub.is_open()
