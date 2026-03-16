shader_type canvas_item;

uniform float strength = 0.01;
uniform float speed = 1.0;
uniform sampler2D noise_texture : repeat_enable;

void fragment() {
    vec2 uv = UV;
    
    // Sample noise for distortion
    vec2 noise_uv = uv + TIME * speed * 0.1;
    float noise = texture(noise_texture, noise_uv).r;
    
    // Apply distortion based on noise
    uv.x += (noise - 0.5) * strength;
    uv.y += (noise - 0.5) * strength * 0.5;
    
    COLOR = texture(TEXTURE, uv);
}
