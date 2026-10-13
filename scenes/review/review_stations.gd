class_name ReviewStations
extends RefCounted

## Stations of the review hall (#192): what the author checks by hand, where it is and what
## to expect. A station is a moment of data/debug/moments.json (`moment`) with optional
## overrides, or its own moment-shaped entry (`scene`, `spawn`, `state`, `dream`); the hall
## loads it through Debug.go_to. The list matches docs/review/manual_checklist.md.

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"
const MAIN_MENU := "res://scenes/shell/main_menu.tscn"
const CHECKLIST := "res://docs/review/manual_checklist.md"

const STATIONS: Array[Dictionary] = [
	{
		"id": "doors", "issue": 174, "title": "Двери: штурвал и ручка",
		"scene": SANDBOX,
		"spawn": {"node": "Stations/DoorStation", "offset": [5, 1, 0], "yaw": 90},
		"check": "Удерживайте взаимодействие на штурвале гермодвери, отпустите на середине; подёргайте служебную дверь.",
		"expect": "Штурвал крутится только пока держите и откатывается назад при отпускании; у служебной двери ручка на полотне.",
	},
	{
		"id": "breach", "issue": 178, "title": "Пролом из релейной",
		"moment": "before_breach",
		"check": "Возьмите лом, проломите стену у трещины; попробуйте дверь ЦУ ↔ комната старшего.",
		"expect": "Стена ломается ломом, проход в комнату открыт; дверь открывается только с допуском старшего.",
	},
	{
		"id": "gas", "issue": 123, "title": "Газ и контрольная точка",
		"scene": SANDBOX,
		"spawn": {"node": "Stations/Checkpoint", "offset": [3, 1, 0], "yaw": -90},
		"check": "Коснитесь контрольной точки, встаньте на зелёный пол камеры модуля 4 и нажмите F6.",
		"expect": "После предупреждения камеру заполняет газ, смотритель засыпает и приходит в себя у контрольной точки.",
	},
	{
		"id": "seal", "issue": 183, "title": "Сон Боузера: печать",
		"moment": "dream_seal",
		"check": "Поверните кольца печати рычагами до совпадения.",
		"expect": "Каждое кольцо встаёт в своё положение; когда совпали все три, печать восстановлена.",
	},
	{
		"id": "ambush", "issue": 184, "title": "Сон Боузера: засада",
		"moment": "bowser_terrace",
		"check": "Спуститесь во двор и пересеките линию у входа; отбейтесь от стражей.",
		"expect": "Стражи появляются из ниш и нападают; бой можно выиграть и проиграть.",
	},
	{
		"id": "dash", "issue": 185, "title": "Сон Боузера: рывок",
		"moment": "bowser_terrace",
		"check": "В бою нажмите клавишу рывка с направлением движения под удар стража.",
		"expect": "Смотритель делает короткий рывок, удар во время рывка не наносит урона, у рывка есть перезарядка.",
	},
	{
		"id": "remains", "issue": 186, "title": "Сон Боузера: останки героя",
		"moment": "bowser_terrace",
		"dream_spawn": {"node": "Yard/Remains", "offset": [0, 1, 3], "yaw": 0},
		"check": "Осмотрите останки героя мира и записку, возьмите оружие; найдите след оператора за линией засады.",
		"expect": "Тексты осмотра и записки на русском, оружие берётся и работает в бою, цепь у останков спит до засады.",
	},
	{
		"id": "cycle", "issue": 190, "title": "Сквозной цикл сна",
		"moment": "before_module_4",
		"check": "Сядьте в кресло модуля 4, пройдите сон до печати и выйдите через врата.",
		"expect": "Вход в сон, печать, выход через врата — смотритель возвращается к креслу в реальность без ошибок.",
	},
	{
		"id": "keys", "issue": 189, "title": "Клавиши сна в настройках",
		"scene": MAIN_MENU,
		"check": "Настройки → управление: переназначьте удар, второй удар и рывок, затем проверьте их во сне (станции засады).",
		"expect": "Новые клавиши сохраняются, подсказки во сне показывают их, конфликт клавиш не допускается.",
	},
]


## The moment-shaped entry the hall loads for `station` (empty when its moment is missing).
static func entry(station: Dictionary, moments: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if station.has("moment"):
		result = (moments.get(StringName(str(station["moment"])), {}) as Dictionary).duplicate(true)
		if result.is_empty():
			return {}
	for key: String in ["scene", "spawn", "state", "dream"]:
		if station.has(key):
			result[key] = station[key]
	if station.has("dream_spawn"):
		var dream: Dictionary = result.get("dream", {})
		dream["spawn"] = station["dream_spawn"]
		result["dream"] = dream
	result["title"] = station["title"]
	return result


## Moments of data/debug/moments.json by id.
static func moment_index() -> Dictionary:
	var index: Dictionary = {}
	for moment: Dictionary in DebugMoments.read().get("moments", []):
		index[StringName(str(moment.get("id", "")))] = moment
	return index
