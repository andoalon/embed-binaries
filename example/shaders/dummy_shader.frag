#version 330

in vec2 texture_coordinates;

uniform vec4 modulation_color;
uniform sampler2D texture;

out vec4 frag_color;

void main()
{
	frag_color = texture(texture, texture_coordinates) * modulation_color;
}
