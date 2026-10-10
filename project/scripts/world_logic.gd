extends RefCounted
class_name WorldLogic
## WorldLogic — вспомогательные функции мира: эффекты из JSON, условные реплики.

class EffectResult:
	var text := ""
	var applied := false

static func resolve_effect(entry: Dictionary, _ctx_id: String = "") -> EffectResult:
	## entry может содержать: {"flag": "..."}, {"item": "id"}, {"effect": "atk+5"|"max_hp+10"|"def+3"|...},
	## {"if_flag": "...", "then": [...], "else": [...]}, {"gold": N}
	var res := EffectResult.new()
	if entry.has("flag"):
		GameState.set_flag(str(entry.flag))
		res.applied = true
		return res
	if entry.has("item"):
		var iid := str(entry.item)
		GameState.add_item(iid)
		var it: Dictionary = DataLoader.get_item(iid)
		res.text = "* Получен предмет: %s" % (it.get("name", iid))
		AudioManager.pickup()
		res.applied = true
		return res
	if entry.has("gold"):
		GameState.gold += int(entry.gold)
		res.text = "* Найдено %d GOLD." % int(entry.gold)
		res.applied = true
		return res
	if entry.has("effect"):
		var e := str(entry.effect)
		if "+" in e:
			var parts := e.split("+")
			var stat := parts[0]
			var val := int(parts[1])
			match stat:
				"atk": GameState.atk += val
				"def": GameState.dfs += val
				"max_hp":
					GameState.max_hp += val
					GameState.hp += val
				"gold": GameState.gold += val
				_: pass
			res.applied = true
			AudioManager.level_up_jingle()
		return res
	if entry.has("if_flag"):
		var cond := GameState.get_flag(str(entry.if_flag))
		var branch: Array = entry.then if cond else entry.get("else", [])
		for sub in branch:
			if typeof(sub) == TYPE_DICTIONARY:
				var r := resolve_effect(sub, _ctx_id)
				if r.text != "":
					res.text += (("\n" if res.text != "" else "") + r.text)
				res.applied = res.applied or r.applied
			else:
				res.text += (("\n" if res.text != "" else "") + str(sub))
		return res
	return res

static func dialogue_condition_ok(entry: Dictionary) -> bool:
	## для записей вида {"if_flag"/"if_item"/...} в массивах диалогов
	if entry.has("if_flag"):
		return GameState.get_flag(str(entry.if_flag))
	if entry.has("if_item"):
		return GameState.has_item(str(entry.if_item))
	if entry.has("if_not_flag"):
		return not GameState.get_flag(str(entry.if_not_flag))
	return true

static func expand_dialogue(lines: Array) -> Array:
	## разворачивает условные блоки в плоский список строк
	var out: Array = []
	for l in lines:
		if typeof(l) == TYPE_DICTIONARY:
			var d: Dictionary = l
			if d.has("then") or d.has("else"):
				if dialogue_condition_ok(d):
					out.append_array(expand_dialogue(d.get("then", [])))
				else:
					out.append_array(expand_dialogue(d.get("else", [])))
			elif d.has("text"):
				out.append(str(d.text))
			else:
				# эффект без текста — применяем сразу
				pass
		else:
			out.append(str(l))
	return out

static func apply_pending_effects(lines: Array) -> void:
	for l in lines:
		if typeof(l) == TYPE_DICTIONARY and not l.has("then"):
			resolve_effect(l)
