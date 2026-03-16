extends AudioStreamPlayer

## Level 2 Background Music - Auto-looping

func _ready():
	# Ensure the stream loops
	if stream:
		stream.loop = true
	print("[Level2Music] Background music ready, looping: %s" % stream.loop if stream else "no stream")
