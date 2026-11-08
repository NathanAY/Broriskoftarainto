shader_type canvas_item;
render_mode unshaded;

// The swirling gate surface behind the portal ring.
//
// The quad covers the sprite's whole canvas, and every length below is in UV
// units measured from the quad centre. `hole_radius` must reach the farthest
// point of the transparent hole in `src/Assets/portal.png` *plus a tuck*, so the
// disc passes under the stone rim and no seam shows. That hole is not centred on
// the canvas — it sits 6.5px above the middle of the 500px source, so its top
// edge is 146px (0.292) from the quad centre while its bottom edge is 133px.
// 0.34 gives 24px of tuck at the top and stays well inside the ring's ~86px
// stone band, so the disc's own edge is always hidden. Keep it in sync when the
// art changes; `test/Systems/test_portal_vortex.gd` measures the PNG and fails
// if this number stops covering the hole or starts emerging from the stone.
//
// The disc is drawn *behind* the ring Sprite2D, so anything past the hole is
// hidden by the stone. The final COLOR is multiplied by the incoming modulate,
// which is what lets a LoopChoicePortal's `tint` (red for the final boss, pale
// blue for one more loop) colour the vortex along with the ring.

uniform float hole_radius = 0.34;
uniform float arms = 3.0;
uniform float twist = 9.0;
uniform float spin_speed = 1.1;
uniform float band_sharpness = 2.0;
uniform float rim_width = 0.10;
uniform vec4 void_color : source_color = vec4(0.05, 0.06, 0.09, 1.0);
uniform vec4 swirl_color : source_color = vec4(0.80, 0.87, 0.95, 1.0);
uniform vec4 rim_color : source_color = vec4(0.45, 0.55, 0.68, 1.0);

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	float aa = max(fwidth(r), 0.001);

	float mask = 1.0 - smoothstep(hole_radius - aa * 2.0, hole_radius, r);
	if (mask <= 0.0) {
		discard;
	}

	float angle = atan(p.y, p.x);
	float t = TIME * spin_speed;
	float r01 = clamp(r / hole_radius, 0.0, 1.0);

	// Two logarithmic spirals drifting against each other, so the core churns
	// instead of reading as a rotating flat pattern.
	float s1 = sin(angle * arms + log(r + 0.015) * twist - t * 2.0);
	float s2 = sin(angle * (arms + 2.0) - log(r + 0.015) * twist * 0.6 + t * 1.3);
	float band = 0.5 + 0.5 * (s1 * 0.7 + s2 * 0.3);
	band = pow(clamp(band, 0.0, 1.0), band_sharpness);

	// Brightness gathers at the rim, leaving the centre dark and deep.
	float depth = smoothstep(0.08, 0.85, r01);
	float rim = smoothstep(1.0 - rim_width, 1.0, r01);
	float pulse = 0.9 + 0.1 * sin(t * 2.5);

	vec3 rgb = mix(void_color.rgb, swirl_color.rgb, band * (0.25 + 0.75 * depth) * pulse);
	rgb = mix(rgb, rim_color.rgb, rim * 0.8);

	COLOR *= vec4(rgb, mask);
}
