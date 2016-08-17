#extension GL_NV_gpu_shader5 : enable

///////////////////////////////////////////////////////////////////////////////
// input
///////////////////////////////////////////////////////////////////////////////                                                            
flat in vec3  vertex_position[];                        
flat in uint  vertex_index[];                           
flat in vec2  vertex_tessCoord[];  
flat in float vertex_final_tesselation[];           

///////////////////////////////////////////////////////////////////////////////
// output
///////////////////////////////////////////////////////////////////////////////                                                               
layout(vertices = 4) out;               

flat out uint tcIndex[];                          
flat out vec2 tcTessCoord[];   

///////////////////////////////////////////////////////////////////////////////
// uniforms
///////////////////////////////////////////////////////////////////////////////                                                            
uniform samplerBuffer parameter_texture;    
uniform samplerBuffer attribute_texture;    
uniform samplerBuffer obb_texture;       

uniform float gua_tesselation_max_error;   
uniform float gua_max_pre_tesselation;
                                                          
uniform float gua_texel_width;                    
uniform float gua_texel_height;                   

#define GPUCAST_HULLVERTEXMAP_SSBO_BINDING 1
#define GPUCAST_ATTRIBUTE_SSBO_BINDING 2

#include "./resources/glsl/common/obb_area.glsl"   
#include "./resources/glsl/trimmed_surface/ssbo_per_patch_data.glsl"                          
#include "./resources/glsl/common/camera_uniforms.glsl"   
            
///////////////////////////////////////////////////////////////////////////////
// functions
///////////////////////////////////////////////////////////////////////////////                        
#include "./resources/glsl/math/horner_surface.glsl.frag"
#include "./resources/glsl/math/to_screen_space.glsl"
#include "./resources/glsl/trimmed_surface/edge_length.glsl"
#include "./resources/glsl/trimmed_surface/control_polygon_length.glsl"
#include "./resources/glsl/trimmed_surface/edge_tess_level.glsl"
#include "./resources/glsl/trimmed_surface/inner_tess_level.glsl"
#include "./resources/glsl/trimmed_surface/is_inside.glsl"
#include "./resources/glsl/trimmed_surface/frustum_cull.glsl"

           

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
void main()                                                                                                               
{                                                                                                                         
  tcIndex[gl_InvocationID]     = vertex_index[gl_InvocationID];                                                                                           
  tcTessCoord[gl_InvocationID] = vertex_tessCoord[gl_InvocationID];                                                                                       
                                                                                                                                  
  mat4 mvp_matrix = gpucast_projection_matrix * gpucast_model_view_matrix;                                           
                        
  int surface_index   = 0;
  int surface_order_u = 0;
  int surface_order_v = 0;
  retrieve_patch_data(int(vertex_index[gl_InvocationID]), surface_index, surface_order_u, surface_order_v);

  //vec4 curve_factor = clamp(retrieve_patch_distance(int(vertex_index[gl_InvocationID])), 1, 4);

  vec4 bboxmin, bboxmax;
  retrieve_patch_bbox(int(vertex_index[gl_InvocationID]), bboxmin, bboxmax);

  float final_tess_level = vertex_final_tesselation[0];

  gl_TessLevelInner[0] = clamp(final_tess_level, 1.0, 64.0);
  gl_TessLevelOuter[1] = clamp(final_tess_level, 1.0, 64.0);
  gl_TessLevelOuter[3] = clamp(final_tess_level, 1.0, 64.0);
  gl_TessLevelInner[1] = clamp(final_tess_level, 1.0, 64.0);
  gl_TessLevelOuter[0] = clamp(final_tess_level, 1.0, 64.0);
  gl_TessLevelOuter[2] = clamp(final_tess_level, 1.0, 64.0);                                                                                                                
}           