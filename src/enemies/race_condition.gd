class_name RaceConditionEnemy
extends EnemyBase

## Two independent processes share a proximity buff. The relationship is
## presentation-visible, but health, damage and rewards remain per process.

const LINK_RADIUS := 170.0
const LINK_SPEED_MULTIPLIER := 1.18
const LINK_CABLE_MAX_DISTANCE := 300.0
const LINK_CABLE_SEGMENTS := 7

var link_radius := LINK_RADIUS
var link_buff_multiplier := LINK_SPEED_MULTIPLIER
var partner: RaceConditionEnemy
var pair_linked := false
var pair_distance := INF
var pair_id := ""
var _v := Vector2.ZERO

func _init() -> void:
	display_name = "RACE_CONDITION"
	hp = 3
	speed = 112.0
	pts = 120
	radius = 15.0
	col = Balance.COL_RACE
	mote_count = 2

static func link_pair(first: EnemyBase, second: EnemyBase, id: String = "") -> void:
	var left := first as RaceConditionEnemy
	var right := second as RaceConditionEnemy
	if left == null or right == null or left == right:
		return
	left.partner = right
	right.partner = left
	left.pair_id = id
	right.pair_id = id
	left.update_pair_state()
	right.update_pair_state()

func connect_partner(other: EnemyBase, id: String = "") -> void:
	link_pair(self, other, id)

func update_pair_state() -> void:
	if partner == null or not is_instance_valid(partner) or partner == self:
		partner = null
		pair_distance = INF
		pair_linked = false
		return
	pair_distance = global_position.distance_to(partner.global_position)
	pair_linked = pair_distance <= link_radius

func current_speed() -> float:
	return speed * (link_buff_multiplier if pair_linked else 1.0)

func _move(delta: float) -> void:
	update_pair_state()
	var desired := steer_approach(aim_at_player(), 1.0, 0.3)
	desired += steer_separation(2.4) * 0.7
	_v = _v.move_toward(desired.limit_length(1.0) * current_speed(), 520.0 * delta)

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _v.length_squared() > 400.0:
		rotation = lerp_angle(rotation, _v.angle(), 8.0 * delta)

func presentation_snapshot() -> Dictionary:
	var snapshot := super.presentation_snapshot()
	snapshot["timer_marker"] = "linked-pair"
	snapshot["nested"] = {
		"pair_id": pair_id,
		"pair_linked": pair_linked,
		"pair_distance": pair_distance,
		"link_radius": link_radius,
		"link_buff_multiplier": link_buff_multiplier,
		"link_telegraph": "broken-cable-and-brackets",
	}
	return snapshot

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	VNextEntityRenderer.draw_enemy(self, "race_condition", presentation_facing(), presentation_state(), elite, r, t, _glyph_color(c))
	update_pair_state()
	if partner != null and is_instance_valid(partner) and get_instance_id() < partner.get_instance_id():
		_draw_broken_cable(to_local(partner.global_position), c)
	if pair_linked:
		# Shape and cadence carry the warning even when color is disabled.
		draw_arc(Vector2.ZERO, r + 7.0, -PI * 0.78, -PI * 0.22, 10, Balance.COL_TEXT, 1.8, true)
		draw_arc(Vector2.ZERO, r + 7.0, PI * 0.22, PI * 0.78, 10, Balance.COL_TEXT, 1.8, true)
		for i in 4:
			var marker_angle := TAU * i / 4.0 + t * 0.5
			var marker := Vector2.from_angle(marker_angle)
			draw_line(marker * (r + 9.0), marker * (r + 13.0), Balance.COL_TEXT, 1.6, true)

func _draw_broken_cable(to_partner: Vector2, c: Color) -> void:
	var distance := to_partner.length()
	if distance <= 0.1 or distance > LINK_CABLE_MAX_DISTANCE:
		return
	var direction := to_partner / distance
	var cable_color := Color(c.r, c.g, c.b, 0.46)
	for i in LINK_CABLE_SEGMENTS:
		if i % 3 == 2:
			continue
		var start: Vector2 = to_partner * (float(i) / LINK_CABLE_SEGMENTS)
		var end: Vector2 = to_partner * (float(i + 1) / LINK_CABLE_SEGMENTS)
		draw_line(start, end, cable_color, 2.0, true)
	# The two open brackets are a second, non-color-readable link indicator.
	var midpoint := to_partner * 0.5
	var normal := direction.orthogonal()
	for sign in [-1.0, 1.0]:
		var mark: Vector2 = midpoint + normal * sign * 5.0
		draw_line(mark - direction * 5.0, mark + normal * sign * 3.0, Balance.COL_TEXT, 1.2, true)
