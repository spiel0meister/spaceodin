package spaceodin

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_FACTOR :: 70

PLAYER_SIZE :: 30
PLAYER_SPEED :: 100
PLAYER_ROT_SPEED :: math.PI / 2

BULLET_SIZE :: 10
BULLET_SPEED :: 200

ENEMY_SIZE :: 20
ENEMY_SPEED :: 50

Entity :: struct {
	pos: rl.Vector2,
	vec: rl.Vector2,
}

GameState :: struct {
	player_pos: rl.Vector2,
	player_rot: f32,
	bullets:    [dynamic]Entity,
	enemies:    [dynamic]rl.Vector2,
}

draw_player :: proc(state: ^GameState) {
	camera := rl.Camera2D {
		offset = state.player_pos,
		zoom   = 1,
	}

	rl.BeginMode2D(camera)
	v1 := rl.Vector2Rotate({0, -PLAYER_SIZE}, state.player_rot)
	v2 := rl.Vector2Rotate({-PLAYER_SIZE / 2, PLAYER_SIZE / 2}, state.player_rot)
	v3 := rl.Vector2Rotate({PLAYER_SIZE / 2, PLAYER_SIZE / 2}, state.player_rot)

	rl.DrawTriangle(v1, v2, v3, rl.GRAY)
	rl.EndMode2D()
}

player_controls :: proc(state: ^GameState, dt: f32) {
	vec := rl.Vector2{0, 0}
	if (rl.IsKeyDown(rl.KeyboardKey.W)) {
		vec.y = -1
	} else if (rl.IsKeyDown(rl.KeyboardKey.S)) {
		vec.y = 1
	}

	if (rl.IsKeyDown(rl.KeyboardKey.A)) {
		vec.x = -1
	} else if (rl.IsKeyDown(rl.KeyboardKey.D)) {
		vec.x = 1
	}

	if (rl.IsKeyDown(rl.KeyboardKey.Q)) {
		state.player_rot -= PLAYER_ROT_SPEED * dt
	} else if (rl.IsKeyDown(rl.KeyboardKey.E)) {
		state.player_rot += PLAYER_ROT_SPEED * dt
	}

	if (rl.IsKeyPressed(rl.KeyboardKey.SPACE)) {
		vec := rl.Vector2 {
			math.cos(state.player_rot - math.PI / 2),
			math.sin(state.player_rot - math.PI / 2),
		}
		append(&state.bullets, Entity{state.player_pos, vec})
	}

	state.player_pos += vec * PLAYER_SPEED * dt
}

main :: proc() {
	state := GameState{{SCREEN_FACTOR * 8, SCREEN_FACTOR * 4}, 0, {}, {}}
	defer delete_dynamic_array(state.bullets)
	defer delete_dynamic_array(state.enemies)

	rl.InitWindow(SCREEN_FACTOR * 16, SCREEN_FACTOR * 9, "SpaceOdin")
	defer rl.CloseWindow()

	score := 0
	enemy_spawn_timer := 0
	lost := false

	rl.SetTargetFPS(60)
	game_loop: for (!rl.WindowShouldClose()) {
		if (!lost) {
			dt := rl.GetFrameTime()

			if (enemy_spawn_timer % 30 == 0) {
				enemy_pos := rl.Vector2{rand.float32(), rand.float32()}
				caze := rand.int63() % 4
				switch (caze) {
				case 0:
					enemy_pos.x = -ENEMY_SIZE
					enemy_pos.y *= SCREEN_FACTOR * 9
				case 1:
					enemy_pos.x = SCREEN_FACTOR * 16 + ENEMY_SIZE
					enemy_pos.y *= SCREEN_FACTOR * 9
				case 2:
					enemy_pos.x *= SCREEN_FACTOR * 9
					enemy_pos.y = -ENEMY_SIZE
				case 3:
					enemy_pos.x *= SCREEN_FACTOR * 9
					enemy_pos.y = SCREEN_FACTOR * 16 + ENEMY_SIZE
				}
				append(&state.enemies, enemy_pos)
			}

			player_controls(&state, dt)

			outer_for: for i := 0; i < len(state.bullets); i += 1 {
				bullet := &state.bullets[i]
				rec :: rl.Rectangle{0, 0, SCREEN_FACTOR * 16, SCREEN_FACTOR * 9}
				if (!rl.CheckCollisionCircleRec(bullet.pos, BULLET_SIZE, rec)) {
					unordered_remove(&state.bullets, i)
					i -= 1
					continue
				}

				for j := 0; j < len(state.enemies); j += 1 {
					enmey_rec := rl.Rectangle {
						state.enemies[j].x,
						state.enemies[j].y,
						ENEMY_SIZE,
						ENEMY_SIZE,
					}

					if (rl.CheckCollisionCircleRec(bullet.pos, BULLET_SIZE, enmey_rec)) {
						unordered_remove(&state.bullets, i)
						i -= 1
						unordered_remove(&state.enemies, j)
						j -= 1
						score += 1
						continue outer_for
					}
				}

				bullet.pos += bullet.vec * BULLET_SPEED * dt
			}

			for j := 0; j < len(state.enemies); j += 1 {
				enemy := &state.enemies[j]

				if (rl.CheckCollisionPointRec(
						   state.player_pos,
						   rl.Rectangle{enemy.x, enemy.y, ENEMY_SIZE * 1.9, ENEMY_SIZE * 1.9},
					   )) {
					rl.TraceLog(.INFO, "DEATH")
					lost = true
					continue game_loop
				}

				dir := rl.Vector2Normalize(state.player_pos - enemy^)
				enemy^ += dir * dt * ENEMY_SPEED
			}

		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.GetColor(0x171717FF))

		if (!lost) {
			FONT_SIZE :: 30
			for bullet in state.bullets {
				rl.DrawCircleV(bullet.pos, BULLET_SIZE + 0.5, rl.BLACK)
				rl.DrawCircleV(bullet.pos, BULLET_SIZE, rl.RED)
			}

			draw_player(&state)

			for enemy in state.enemies {
				rl.DrawRectangleV(enemy, ENEMY_SIZE + 1, rl.BLACK)
				rl.DrawRectangleV(enemy, ENEMY_SIZE, rl.RED)
			}

			score_text := rl.TextFormat("Score: %d", score)
			width := rl.MeasureText(score_text, FONT_SIZE)

			rl.DrawText(score_text, 5, 5, FONT_SIZE, rl.WHITE)
		} else {
			FONT_SIZE :: 80
			end_text := rl.TextFormat("Hah, you lost! Score: %d", score)
			width := rl.MeasureText(end_text, FONT_SIZE)
			rl.DrawText(
				end_text,
				SCREEN_FACTOR * 16 / 2 - width / 2,
				SCREEN_FACTOR * 9 / 2 - FONT_SIZE / 2,
				FONT_SIZE,
				rl.WHITE,
			)
		}

		rl.EndDrawing()

		enemy_spawn_timer += 1
	}

}
