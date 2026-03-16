shader_type canvas_item;

uniform float amplitude = 0.003;
uniform float speed = 1.0;
uniform float frequency = 10.0;

void fragment() {
    vec2 uv = UV;
    uv.y += sin(uv.x * frequency + TIME * speed) * amplitude;
    COLOR = texture(TEXTURE, uv);
}
