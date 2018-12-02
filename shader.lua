local pixelcode = [[
	uniform vec4 light_sources[100];
	uniform int light_source_count;
	uniform Image shadow_map;

	vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
	{
		// trace a path towards each light source
		float light_level = 0.2;

		for (int i = 0; i < light_source_count; i++) {
			vec4 light_source = light_sources[i];
			float dist = distance(screen_coords, light_source.xy);
			if (dist < light_source[2]) {
				light_level += (1.0 - dist/light_source[2]) * light_source[3] / 10.0;
			}
		}

		light_level = min(light_level, 1.0);

		// calculate position in shadow map
		vec2 shadow_pos = screen_coords / love_ScreenSize.xy;
		vec4 shadow_data = Texel(shadow_map, shadow_pos);
		vec4 texcolor = Texel(texture, texture_coords);
		return texcolor * shadow_data * light_level;
	}
]]

local vertexcode = [[
	vec4 position( mat4 transform_projection, vec4 vertex_position)
	{
		return transform_projection * vertex_position;
	}
]]

local shader = love.graphics.newShader(pixelcode, vertexcode)
return shader