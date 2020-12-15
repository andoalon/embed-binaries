#version 330

layout(location = 0) in vec2 vertex_position;
layout(location = 1) in vec2 tex_coordinates;

uniform mat3 render_mtx;

out vec2 texture_coordinates;

void main ()
{
	texture_coordinates = tex_coordinates;
	gl_Position = vec4(render_mtx * vec3(vertex_position, 1.0), 1.0);
}