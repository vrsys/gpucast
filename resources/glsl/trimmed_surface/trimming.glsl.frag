/*****************************************************************************
 * evaluate for parameter pair uv if it is trimmed or not
 ****************************************************************************/
bool
trim ( in samplerBuffer partition_buffer,
       in samplerBuffer cell_buffer, 
       in samplerBuffer curvelist_buffer,
       in samplerBuffer curvedata_buffer,
       in vec2    uv, 
       in int     id, 
       in int     trim_outer, 
       inout int  iters,
       in float   tolerance,
       in int     max_iterations)
{
  vec4 debug = vec4(0.2);
  vec4 domaininfo1 = texelFetch ( partition_buffer, id );

  int total_intersections  = 0;
  int v_intervals = int ( floatBitsToUint ( domaininfo1[0] ) );

  // if there is no partition in vertical(v) direction -> return
  if ( v_intervals == 0) 
  {
    return false;
  } 

  vec4 domaininfo2 = texelFetch ( partition_buffer, id + 1 );

  // classify against whole domain
  if ( uv[0] > domaininfo2[1] || uv[0] < domaininfo2[0] ||
       uv[1] > domaininfo2[3] || uv[1] < domaininfo2[2] ) 
  {
    return bool(trim_outer);
  }

  vec4 vinterval = vec4(0.0, 0.0, 0.0, 0.0);
  bool vinterval_found = binary_search ( partition_buffer, uv[1], id + 2, v_intervals, vinterval );

  if ( !vinterval_found ) {
    return bool(trim_outer);
  }

  int celllist_id = int(floatBitsToUint(vinterval[2]));
  int ncells      = int(floatBitsToUint(vinterval[3]));

  vec4 celllist_info  = texelFetch(cell_buffer, int(celllist_id));
  vec4 cell           = vec4(0.0);

  bool cellfound      = binary_search   (cell_buffer, uv[0], celllist_id + 1, int(ncells), cell);
  if (!cellfound) 
  {
    return bool(trim_outer);
  }

  vec4 clist                       = texelFetch(curvelist_buffer, int(floatBitsToUint(cell[3])));
  total_intersections              = int(floatBitsToUint(cell[2]));
  unsigned int curves_to_intersect = floatBitsToUint(clist[0]);

  for (int i = 1; i <= curves_to_intersect; ++i) 
  {
    vec4 curveinfo = texelFetch(curvelist_buffer, int(floatBitsToUint(cell[3])) + i );

    int index                    = int(floatBitsToUint(curveinfo[0]));
    int order                    = abs(floatBitsToInt(curveinfo[1]));
    bool horizontally_increasing = floatBitsToInt(curveinfo[1]) > 0;
    float tmin                   = curveinfo[2];
	  float tmax                   = curveinfo[3];

    bisect_curve ( curvedata_buffer, 
                   uv, 
                   index, 
                   order,
                   horizontally_increasing,
                   tmin,
                   tmax,
                   total_intersections, 
                   iters, 
                   tolerance, 
                   max_iterations );
  }

  if ( mod(total_intersections, 2) == 1 ) 
  {
    return !bool(trim_outer);
  } else {
    return bool(trim_outer);
  }
}
