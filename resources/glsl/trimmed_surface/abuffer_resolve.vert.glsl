///////////////////////////////////////////////////////////////////////////////
// input attributes
///////////////////////////////////////////////////////////////////////////////
layout (location = 0) in vec4 in_vertex;

out vec4 frag_texcoord;

void main(void) {
  gl_Position = in_vertex;
}
