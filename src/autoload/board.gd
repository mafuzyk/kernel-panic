extends Node

## Cliente do placar semanal.
##
## Enviar uma pontuação manda a run inteira para um servidor — o que a jogadora
## fez, quadro a quadro, com o nome que ela escolher. Isso sai da máquina dela,
## então nada aqui acontece sozinho: o envio é DESLIGADO por padrão, sem
## endereço configurado, e a partida só viaja quando alguém aperta o botão.
##
## Sem servidor configurado o jogo não muda em nada. Um placar fora do ar não
## pode tornar um jogo single-player menos jogável.

signal submit_finished(ok: bool, message: String)
signal board_loaded(week: int, entries: Array)

const SECTION := "board"
const REQUEST_TIMEOUT := 20.0
## O nome aparece para outras pessoas, então segue a mesma regra do servidor.
const NAME_PATTERN := "^[A-Za-z0-9 _.\\-]{1,24}$"

var enabled := false
var url := ""
var player_name := ""

var _submit_request: HTTPRequest
var _board_request: HTTPRequest
var _name_re: RegEx


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_name_re = RegEx.new()
	_name_re.compile(NAME_PATTERN)
	_submit_request = _make_request()
	_board_request = _make_request()
	load_settings()

func _make_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT
	add_child(request)
	return request

## Configurado = tem endereço válido, nome válido e a jogadora ligou.
func is_configured() -> bool:
	return enabled and is_valid_url(url) and is_valid_name(player_name)

func is_valid_name(candidate: String) -> bool:
	return _name_re != null and _name_re.search(candidate.strip_edges()) != null

## Só `http` e `https`. Sem isto um endereço colado errado viraria uma chamada
## para um esquema qualquer.
static func is_valid_url(candidate: String) -> bool:
	var clean := candidate.strip_edges()
	return clean.begins_with("http://") or clean.begins_with("https://")

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(Sfx.SAVE_PATH) != OK:
		return
	enabled = bool(cf.get_value(SECTION, "enabled", false))
	url = str(cf.get_value(SECTION, "url", ""))
	player_name = str(cf.get_value(SECTION, "name", ""))

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value(SECTION, "enabled", enabled)
	cf.set_value(SECTION, "url", url)
	cf.set_value(SECTION, "name", player_name)
	cf.save(Sfx.SAVE_PATH)

func set_enabled(value: bool) -> void:
	enabled = value
	save_settings()

func set_url(value: String) -> void:
	url = value.strip_edges().rstrip("/")
	save_settings()

func set_player_name(value: String) -> void:
	player_name = value.strip_edges()
	save_settings()

## Envia a run. Devolve falso quando nem chegou a sair — sem endereço, sem run
## gravada, ou com um envio já em voo.
func submit_run(packet: Dictionary) -> bool:
	if not is_configured():
		submit_finished.emit(false, tr("BOARD_NOT_CONFIGURED"))
		return false
	if packet.is_empty():
		submit_finished.emit(false, tr("BOARD_NO_RUN"))
		return false
	if _submit_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		submit_finished.emit(false, tr("BOARD_BUSY"))
		return false
	var body := JSON.stringify({"name": player_name, "run": packet})
	if not _submit_request.request_completed.is_connected(_on_submit_completed):
		_submit_request.request_completed.connect(_on_submit_completed)
	var error := _submit_request.request(url + "/v1/submit", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		submit_finished.emit(false, tr("BOARD_UNREACHABLE"))
		return false
	return true

func _on_submit_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		submit_finished.emit(false, tr("BOARD_UNREACHABLE"))
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if code >= 400:
		var reason := str(parsed.get("error", "")) if parsed is Dictionary else ""
		submit_finished.emit(false, reason if reason != "" else tr("BOARD_REFUSED"))
		return
	# 202: aceito para conferência. A pontuação ainda não está no placar — o
	# servidor precisa re-simular a run antes, e isso leva minutos.
	submit_finished.emit(true, tr("BOARD_QUEUED"))

func fetch_board(week: int) -> bool:
	if not is_valid_url(url):
		board_loaded.emit(week, [])
		return false
	if _board_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return false
	if not _board_request.request_completed.is_connected(_on_board_completed):
		_board_request.request_completed.connect(_on_board_completed)
	var error := _board_request.request("%s/v1/board?week=%d&limit=20" % [url, week])
	if error != OK:
		board_loaded.emit(week, [])
		return false
	return true

func _on_board_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		board_loaded.emit(Game.week_number(), [])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		board_loaded.emit(Game.week_number(), [])
		return
	var payload: Dictionary = parsed
	var raw_entries = payload.get("entries", [])
	board_loaded.emit(int(payload.get("week", Game.week_number())), raw_entries if raw_entries is Array else [])
