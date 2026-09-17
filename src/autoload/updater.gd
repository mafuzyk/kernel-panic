extends Node

## Verificação de atualização para as versões de desktop.
##
## O jogo promete, no README e nas notas de versão, que NÃO faz requisição de
## rede por conta própria. Um updater que consulta a internet ao abrir quebra
## essa promessa em silêncio — então aqui nada acontece sozinho: a checagem só
## sai quando alguém aperta o botão, ou quando a pessoa liga explicitamente a
## checagem ao iniciar, que nasce DESLIGADA.
##
## Ele também não troca o binário em execução. Substituir o próprio executável
## é específico de cada sistema, precisa de permissão que o jogo pode não ter,
## e briga com quem instalou por gerenciador de pacotes — onde quem manda é o
## `paru`, o `xbps-install` ou o `nix`. O updater baixa, CONFERE o checksum
## publicado no release e diz onde o arquivo ficou. A troca é da pessoa.

signal check_finished(status: String, version: String, notes: String)
signal download_finished(ok: bool, path_or_error: String)

const SECTION := "update"
const RELEASE_API := "https://api.github.com/repos/mafuzyk/kernel-panic/releases/latest"
const RELEASE_PAGE := "https://github.com/mafuzyk/kernel-panic/releases/latest"
const REQUEST_TIMEOUT := 15.0

## Situações que a UI precisa distinguir. Erro de rede não é "está atualizado".
const STATUS_CURRENT := "current"
const STATUS_AVAILABLE := "available"
const STATUS_MANAGED := "managed"
const STATUS_UNSUPPORTED := "unsupported"
const STATUS_ERROR := "error"

var check_on_launch := false
var last_status := ""
var last_version := ""

var _request: HTTPRequest
var _download: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_request = _make_request()
	_download = _make_request()
	load_settings()
	if check_on_launch and supported():
		check_now()


func _make_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT
	add_child(request)
	return request


## A versão que este build declara, sem o "v".
static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## Só desktop. No Android quem atualiza é a loja ou o APK que a pessoa baixa,
## e um updater dentro do jogo não tem como instalar nada.
static func supported() -> bool:
	return OS.get_name() in ["Linux", "Windows", "macOS"]


## Instalado por gerenciador de pacotes?
##
## Se o executável mora num prefixo do sistema, quem manda na atualização é o
## gerenciador. Baixar por fora deixaria duas cópias e a próxima atualização
## do pacote sobrescreveria a de dentro do jogo sem avisar.
static func package_managed() -> bool:
	var exe := OS.get_executable_path()
	for prefix in ["/usr/", "/nix/store/", "/opt/", "/var/lib/flatpak/", "/snap/"]:
		if exe.begins_with(prefix):
			return true
	return false


## Compara duas versões "x.y.z". Devolve 1 se `a` é mais nova que `b`, -1 se é
## mais antiga, 0 se iguais. Sufixos como "-rc1" são ignorados na comparação
## numérica e desempatam como MENORES que a versão limpa.
static func compare_versions(a: String, b: String) -> int:
	var pa := _version_parts(a)
	var pb := _version_parts(b)
	for i in 3:
		if pa["nums"][i] != pb["nums"][i]:
			return 1 if pa["nums"][i] > pb["nums"][i] else -1
	var sa := str(pa["suffix"])
	var sb := str(pb["suffix"])
	if sa == sb:
		return 0
	# Versão limpa é mais nova que qualquer pré-lançamento do mesmo número.
	if sa == "":
		return 1
	if sb == "":
		return -1
	return 1 if sa > sb else -1


static func _version_parts(v: String) -> Dictionary:
	var clean := v.strip_edges()
	if clean.begins_with("v"):
		clean = clean.substr(1)
	var suffix := ""
	var dash := clean.find("-")
	if dash >= 0:
		suffix = clean.substr(dash + 1)
		clean = clean.substr(0, dash)
	var nums := [0, 0, 0]
	var bits := clean.split(".")
	for i in mini(bits.size(), 3):
		nums[i] = int(str(bits[i]).to_int())
	return {"nums": nums, "suffix": suffix}


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(Sfx.SAVE_PATH) != OK:
		return
	check_on_launch = bool(cf.get_value(SECTION, "check_on_launch", false))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value(SECTION, "check_on_launch", check_on_launch)
	cf.save(Sfx.SAVE_PATH)


func set_check_on_launch(on: bool) -> void:
	check_on_launch = on
	save_settings()


## Dispara a consulta. Nada aqui roda sem alguém ter pedido.
func check_now() -> void:
	if not supported():
		_finish(STATUS_UNSUPPORTED, "", "")
		return
	if package_managed():
		_finish(STATUS_MANAGED, "", "")
		return
	if _request == null or not is_instance_valid(_request):
		_finish(STATUS_ERROR, "", "no request node")
		return
	_request.request_completed.connect(_on_check_completed, CONNECT_ONE_SHOT)
	var err := _request.request(RELEASE_API, ["Accept: application/vnd.github+json"])
	if err != OK:
		if _request.request_completed.is_connected(_on_check_completed):
			_request.request_completed.disconnect(_on_check_completed)
		_finish(STATUS_ERROR, "", "request failed: %d" % err)


func _on_check_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_finish(STATUS_ERROR, "", "http %d" % code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("tag_name"):
		_finish(STATUS_ERROR, "", "unexpected payload")
		return
	var tag := str(parsed["tag_name"])
	var notes := str(parsed.get("body", ""))
	if compare_versions(tag, current_version()) > 0:
		_finish(STATUS_AVAILABLE, tag, notes)
	else:
		_finish(STATUS_CURRENT, tag, "")


func _finish(status: String, version: String, notes: String) -> void:
	last_status = status
	last_version = version
	check_finished.emit(status, version, notes)
