class_name GameConfig
extends RefCounted

const VIEW_SIZE := Vector2(1280.0, 720.0)
const ARENA_RECT := Rect2(36.0, 76.0, 1208.0, 598.0)
const RUN_DURATION := 180.0

const PLAYER_MAX_HP := 5
const PLAYER_SPEED := 280.0
const PLAYER_RADIUS := 15.0
const PLAYER_IFRAME := 0.7
const BLINK_DISTANCE := 150.0
const BLINK_DURATION := 0.12
const BLINK_COOLDOWN := 2.0

const UNIT_MAX := 30
const UNIT_FOLLOW_SPEED := 8.0
const UNIT_ORBIT_RADIUS := 60.0
const UNIT_DAMAGE := 10.0
const UNIT_ATTACK_INTERVAL := 0.8
const UNIT_RANGE := 650.0

const PROJECTILE_SPEED := 620.0
const PROJECTILE_RADIUS := 4.0
const PROJECTILE_POOL_SIZE := 180

const ENEMY_HP := 20.0
const ENEMY_SPEED := 76.0
const ENEMY_RADIUS := 13.0
const ENEMY_POOL_SIZE := 100
const ENEMY_ACTIVE_MAX := 82
const SPAWN_RATE_START := 0.70
const SPAWN_GROWTH_PER_30 := 1.18

const ORB_POOL_SIZE := 100
const ORB_ATTRACT_RANGE := 150.0
const ORB_COLLECT_RANGE := 22.0
const ORB_SPEED := 360.0

const FIRST_LEVEL_XP := 20
const XP_GROWTH := 10
const MAX_LEVEL_CHOICES := 7

const COLOR_BG := Color("07101f")
const COLOR_GRID := Color("16304b")
const COLOR_GRID_MAJOR := Color("224661")
const COLOR_CYAN := Color("51f6d2")
const COLOR_CYAN_DIM := Color("1b8e89")
const COLOR_WHITE := Color("f3fbff")
const COLOR_RED := Color("ff4f70")
const COLOR_RED_DIM := Color("8f2949")
const COLOR_YELLOW := Color("ffd166")
const COLOR_PURPLE := Color("a88bff")

