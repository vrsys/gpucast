#extension GL_NV_gpu_shader5 : enable

#include "./resources/glsl/trimmed_surface/parametrization_uniforms.glsl"

///////////////////////////////////////////////////////////////////////////////
// input
///////////////////////////////////////////////////////////////////////////////                                                            
flat in vec3  vertex_position[];                        
flat in uint  vertex_index[];                           
flat in vec2  vertex_tessCoord[];  
flat in vec3  vertex_final_tesselation[];           

///////////////////////////////////////////////////////////////////////////////
// output
///////////////////////////////////////////////////////////////////////////////         
#if GPUCAST_SECOND_PASS_TRIANGLE_TESSELATION
  layout(vertices = 3) out;      
#else                                                      
  layout(vertices = 4) out;               
#endif

flat out uint tcIndex[];                          
flat out vec2 tcTessCoord[];   

///////////////////////////////////////////////////////////////////////////////
// uniforms
///////////////////////////////////////////////////////////////////////////////                                                             
uniform samplerBuffer gpucast_control_point_buffer; 
           
#include "./resources/glsl/common/camera_uniforms.glsl"   
            
///////////////////////////////////////////////////////////////////////////////
// functions
///////////////////////////////////////////////////////////////////////////////  
#include "./resources/glsl/trimmed_surface/ssbo_per_patch_data.glsl"  
#include "./resources/glsl/common/conversion.glsl"        
#include "./resources/glsl/common/obb_area.glsl"                   
#include "./resources/glsl/math/horner_surface.glsl.frag"
#include "./resources/glsl/math/to_screen_space.glsl"
#include "./resources/glsl/trimmed_surface/edge_length.glsl"
#include "./resources/glsl/trimmed_surface/control_polygon_length.glsl"
#include "./resources/glsl/trimmed_surface/edge_tess_level.glsl"
#include "./resources/glsl/trimmed_surface/inner_tess_level.glsl"
#include "./resources/glsl/trimmed_surface/is_inside.glsl"
#include "./resources/glsl/trimmed_surface/frustum_cull.glsl"

///////////////////////////////////////////////////////////////////////////////
void adjust_tesselation_by_edge_length_estimate(in float final_tesselation_estimate,
                                                in uvec2 edge_length_u, 
                                                in uvec2 edge_length_v, 
                                                out vec2 inner_tessel_level,
                                                out vec4 outer_tessel_level) 
{
  float umax = float(max(edge_length_u.x, edge_length_u.y));
  float vmax = float(max(edge_length_v.x, edge_length_v.y));

  float tess_umax = umax / gpucast_tesselation_max_pixel_error;
  float tess_vmax = vmax / gpucast_tesselation_max_pixel_error;
  float tess_edge = max(tess_umax, tess_vmax);

  final_tesselation_estimate = max(tess_edge, final_tesselation_estimate);

  // clamp to max tesselation
  inner_tessel_level      = vec2(clamp(final_tesselation_estimate, 1.0, 64.0));
  outer_tessel_level      = vec4(clamp(final_tesselation_estimate, 1.0, 64.0));
}

#if 1
///////////////////////////////////////////////////////////////////////////////
void compute_screenspace_vertices(out vec4 umin_vmin,
                                  out vec4 umax_vmin,
                                  out vec4 umax_vmax,
                                  out vec4 umin_vmax)
{
  vec4 vertices[4];

  int surface_index   = 0;
  int surface_order_u = 0;
  int surface_order_v = 0;
  retrieve_patch_data (int(vertex_index[0]), surface_index, surface_order_u, surface_order_v);

  bool umax = vertex_tessCoord[gl_InvocationID].x > vertex_tessCoord[0].x || 
              vertex_tessCoord[gl_InvocationID].x > vertex_tessCoord[1].x || 
              vertex_tessCoord[gl_InvocationID].x > vertex_tessCoord[2].x ||
              vertex_tessCoord[gl_InvocationID].x > vertex_tessCoord[3].x;

  bool vmax = vertex_tessCoord[gl_InvocationID].y > vertex_tessCoord[0].y || 
              vertex_tessCoord[gl_InvocationID].y > vertex_tessCoord[1].y || 
              vertex_tessCoord[gl_InvocationID].y > vertex_tessCoord[2].y ||
              vertex_tessCoord[gl_InvocationID].y > vertex_tessCoord[3].y;

  evaluateSurface(gpucast_control_point_buffer,                                   
                  surface_index,                                  
                  surface_order_u,                                
                  surface_order_v,                                
                  vertex_tessCoord[gl_InvocationID], vertices[int(umax) + 2*int(vmax)]);
  
  //barrier();

  umin_vmin = vertices[0];
  umax_vmin = vertices[1];
  umax_vmax = vertices[3];
  umin_vmax = vertices[2];
}

///////////////////////////////////////////////////////////////////////////////
void adjust_tesselation_by_edge_lengths(in float final_tesselation_estimate,
                                        out vec2 inner_tessel_level,
                                        out vec4 outer_tessel_level)
{
  vec4 umin_vmin, umin_vmax, umax_vmin, umax_vmax;
  compute_screenspace_vertices(umin_vmin, umax_vmin, umax_vmax, umin_vmax);

  umin_vmin.w = 1.0;
  umin_vmax.w = 1.0;
  umax_vmin.w = 1.0;
  umax_vmax.w = 1.0;

  umin_vmin = gpucast_model_view_projection_matrix * umin_vmin;
  umin_vmax = gpucast_model_view_projection_matrix * umin_vmax;
  umax_vmin = gpucast_model_view_projection_matrix * umax_vmin;
  umax_vmax = gpucast_model_view_projection_matrix * umax_vmax;

  umin_vmin /= umin_vmin.w;
  umin_vmax /= umin_vmin.w;
  umax_vmin /= umin_vmin.w;
  umax_vmax /= umin_vmin.w;

  //     (0,1)   OL3   (1,1)          (0,1,0)         (0,1)          (1,1)
  //      +--------------+              +             ^  +  <no edge>   +  
  //      |              |             / \            |                
  //      |  +--------+  |            /   \           |  +--------------+  
  //      |  |   IL0  |  |       OL0 /  +  \ OL2      |                  
  //   OL0|  |IL1     |  |OL2       /  / \  \         |  +--------------+  
  //      |  |        |  |         /  /IL0\  \       OL0                  
  //      |  +--------+  |        /  +-----+  \       |  +--------------+  
  //      |              |       /             \      |                 
  //      +--------------+      +---------------+     v  +--------------+  
  //     (0,0)   OL1   (1,0) (0,0,1)   OL1   (1,0,0)   (0,0)   OL1   (1,0)

  inner_tessel_level[0] = final_tesselation_estimate;
  inner_tessel_level[1] = final_tesselation_estimate;

  outer_tessel_level[0] = clamp(length(vec2(gpucast_resolution) * umin_vmin.xy)/gpucast_tesselation_max_pixel_error, 1.0, 64.0);
  outer_tessel_level[1] = clamp(length(vec2(gpucast_resolution) * umin_vmax.xy)/gpucast_tesselation_max_pixel_error, 1.0, 64.0);
  outer_tessel_level[2] = clamp(length(vec2(gpucast_resolution) * umax_vmin.xy)/gpucast_tesselation_max_pixel_error, 1.0, 64.0);
  outer_tessel_level[3] = clamp(length(vec2(gpucast_resolution) * umax_vmax.xy)/gpucast_tesselation_max_pixel_error, 1.0, 64.0);

}
 #endif          


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
void main()                                                                                                               
{                                                                                                                         
  tcIndex[gl_InvocationID]     = vertex_index[gl_InvocationID];                                                                                           
  tcTessCoord[gl_InvocationID] = vertex_tessCoord[gl_InvocationID];                                                                                       

  // retrieve tesselation data
  float final_tess_level       = vertex_final_tesselation[gl_InvocationID].x;

  barrier();

  uvec2 u_edge_lengths = intToUInt2(floatBitsToUint(vertex_final_tesselation[gl_InvocationID].y)); 
  uvec2 v_edge_lengths = intToUInt2(floatBitsToUint(vertex_final_tesselation[gl_InvocationID].z));

  vec2 inner_tessel_level = vec2(final_tess_level);
  vec4 outer_tessel_level = vec4(final_tess_level);

  //adjust_tesselation_by_edge_length_estimate(final_tess_level, u_edge_lengths, v_edge_lengths, inner_tessel_level, outer_tessel_level);
  adjust_tesselation_by_edge_lengths(final_tess_level, inner_tessel_level, outer_tessel_level);

  // adjust by patch ratio 
#if GPUCAST_USE_PATCH_RATIO_TO_SCALE_TESSELATION_FACTORS

  float ratio = retrieve_patch_ratio_uv(int(vertex_index[gl_InvocationID]));

  inner_tessel_level[0] *= ratio;  // u
  inner_tessel_level[1] /= ratio;  // v

  outer_tessel_level[0] /= ratio;  // v
  outer_tessel_level[1] *= ratio;  // u
  outer_tessel_level[2] /= ratio;  // v                                                                                                           
  outer_tessel_level[3] *= ratio;  // u

  clamp(outer_tessel_level, 1, 64);
  clamp(inner_tessel_level, 1, 64);

#endif

// DEBUG ONLY -> SIMPLE TESSELLATION
#if 0
  inner_tessel_level[0] = 4.0;
  inner_tessel_level[1] = 4.0;
  outer_tessel_level[0] = 4.0;
  outer_tessel_level[1] = 4.0;
  outer_tessel_level[2] = 4.0;
  outer_tessel_level[3] = 4.0;
#endif

#if GPUCAST_SECOND_PASS_TRIANGLE_TESSELATION
  gl_TessLevelInner[0] = inner_tessel_level[0];
  gl_TessLevelOuter[0] = outer_tessel_level[0];
  gl_TessLevelOuter[1] = outer_tessel_level[1];
  gl_TessLevelOuter[2] = outer_tessel_level[2]; 
#else
  // apply tesselation
  gl_TessLevelInner[0] = inner_tessel_level[0];
  gl_TessLevelInner[1] = inner_tessel_level[1];

  gl_TessLevelOuter[0] = outer_tessel_level[0];
  gl_TessLevelOuter[1] = outer_tessel_level[1];
  gl_TessLevelOuter[2] = outer_tessel_level[2];                                                                                                                
  gl_TessLevelOuter[3] = outer_tessel_level[3];
#endif
}           