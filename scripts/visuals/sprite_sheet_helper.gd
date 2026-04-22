extends RefCounted


static func add_row_animation(
	frames: SpriteFrames,
	animation_name: String,
	texture: Texture2D,
	frame_size: Vector2i,
	row: int,
	frame_count: int,
	fps: float,
	loop: bool = true
) -> void:
	if frames.has_animation(animation_name):
		frames.remove_animation(animation_name)
	frames.add_animation(animation_name)

	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)

	for frame_index in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			frame_index * frame_size.x,
			row * frame_size.y,
			frame_size.x,
			frame_size.y
		)
		frames.add_frame(animation_name, atlas)
