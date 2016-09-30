#extension GL_NV_gpu_shader5 : enable

///////////////////////////////////////////////////////////////////////////////
// input
///////////////////////////////////////////////////////////////////////////////
layout (location = 0) in vec3  in_position;   
layout (location = 1) in uint  in_index;      
layout (location = 2) in vec4  in_tesscoord;  

///////////////////////////////////////////////////////////////////////////////                                         
// output
///////////////////////////////////////////////////////////////////////////////                      
out vec3  vertex_position;                  
out uint  vertex_index;                    
out vec2  vertex_tesscoord;             

///////////////////////////////////////////////////////////////////////////////                                         
// uniforms
///////////////////////////////////////////////////////////////////////////////   


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////                                                   
void main()                                
{                   
  vertex_position  = in_position;                   
  vertex_index     = in_index;                      
  vertex_tesscoord = in_tesscoord.xy;           
} 