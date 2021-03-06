#ifndef GPUCAST_TRIMMING_LOOP_LIST
#define GPUCAST_TRIMMING_LOOP_LIST

#include "resources/glsl/common/config.glsl"
#include "resources/glsl/common/conversion.glsl"

#include "resources/glsl/trimming/trimming_uniforms.glsl"
#include "resources/glsl/trimming/binary_search.glsl"
#include "resources/glsl/trimming/bisect_curve.glsl"
#include "resources/glsl/trimming/classification_to_coverage.glsl"
#include "resources/glsl/trimming/pre_classification.glsl"

struct bbox_t {
  float umin;
  float umax;
  float vmin;
  float vmax;
};

struct point_t {
  float wx;
  float wy;
  float wz;
  float pad;
};

struct curve_t {
  unsigned int order;
  unsigned int point_index;
  unsigned int uincreasing;
  unsigned int pad;
  bbox_t       bbox;
};

struct loop_t {
  unsigned int nchildren;
  unsigned int child_index;
  unsigned int ncontours;
  unsigned int contour_index;

  unsigned int pre_class_id;
  unsigned int pre_class_width;
  unsigned int pre_class_height;
  unsigned int pad;

  vec4 domainsize;

  bbox_t       bbox;
};

struct contour_t {
  unsigned int ncurves;
  unsigned int curve_index;
  unsigned int uincreasing;
  unsigned int parity_priority;
  bbox_t       bbox;
};

layout(std430) buffer gpucast_loop_buffer {
  loop_t loops[];
};

layout(std430) buffer gpucast_contour_buffer {
  contour_t contours[];
};

layout(std430) buffer gpucast_curve_buffer {
  curve_t curves[];
};

layout(std430) buffer gpucast_point_buffer {
  vec4 points[];
};

/////////////////////////////////////////////////////////////////////////////////////////////
void
evaluateCurve(in unsigned int index,
              in unsigned int order,
              in float t,
              out vec4 p)
{
  unsigned int deg = order - 1;
  float u = 1.0 - t;

  float bc = 1.0;
  float tn = 1.0;

  p = points[index];
  gpucast_count_texel_fetch();

  p *= u;


  if (order > 2) {
    for (unsigned int i = 1; i <= deg - 1; ++i) {
      tn *= t;
      bc *= (float(deg - i + 1) / float(i));
      p = (p + tn * bc * points[index + i]) * u;
      gpucast_count_texel_fetch();
    }

    p += tn * t * points[index+deg];
    gpucast_count_texel_fetch();
  }
  else {
    /* linear piece*/
    p = mix(points[index], points[index + 1], t);
    gpucast_count_texel_fetch();
    gpucast_count_texel_fetch();
  }

  /* project into euclidian coordinates */
  p[0] = p[0] / p[2];
  p[1] = p[1] / p[2];
}


/////////////////////////////////////////////////////////////////////////////////////////////
void
bisect_curve(in vec2          uv,
             in unsigned int  index,
             in unsigned int  order,
             in bool          horizontally_increasing,
             in float         tmin,
             in float         tmax,
             inout unsigned int intersections,
             in float         tolerance,
             in unsigned int  max_iterations)
{
  // initialize search
  float t = 0.0;
  vec4 p = vec4(0.0);

  // evaluate curve to determine if uv is on left or right of curve
  for (unsigned int i = 0; i < max_iterations; ++i)
  {
    t = (tmax + tmin) / 2.0;
    evaluateCurve(index, order, t, p);

    // stop if point on curve is very close to uv

    //if ( abs ( uv[1] - p[1] ) < tolerance )
    //if (length(uv - p.xy) < tolerance)
    if (abs(uv.x - p.x) + abs(uv.y - p.y) < tolerance)
    {
      break;
    }

    // classify: no classification of uv is possible -> continue search
    if (uv[1] > p[1]) {
      tmin = t;
    }
    else {
      tmax = t;
    }

    // classify: uv is on left -> stop search
    if ((!horizontally_increasing && uv[0] > p[0] && uv[1] > p[1]) ||
      (horizontally_increasing && uv[0] > p[0] && uv[1] < p[1]))
    {
      break;
    }

    // classify: uv is on right -> stop search
    if ((!horizontally_increasing && uv[0] < p[0] && uv[1] < p[1]) ||
      (horizontally_increasing && uv[0] < p[0] && uv[1] > p[1]))
    {
      ++intersections;
      break;
    }
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////
void
bisect_curve_coverage(in vec2            uv,
                      in unsigned int    index,
                      in unsigned int    order,
                      in bool            horizontally_increasing,
                      in float           tmin,
                      in float           tmax,
                      in float           tolerance,
                      in unsigned int    max_iterations,
                      in vec4            curve_bbox,
                      inout unsigned int intersections,
                      inout vec2         closest_point,
                      inout vec2         gradient)
{
  // initialize search
  float t = 0.0;
  vec4 p = vec4(0.0);

  // evaluate curve to determine if uv is on left or right of curve
  for (unsigned int i = 0; i < max_iterations; ++i)
  {
    t = (tmax + tmin) / 2.0;
    evaluateCurve(index, order, t, p);

    // stop if point on curve is very close to uv

    //if ( abs ( uv[1] - p[1] ) < tolerance )
    //if (length(uv - p.xy) < tolerance)
    if (abs(uv.x - p.x) + abs(uv.y - p.y) < tolerance)
    {
      break;
    }

    // classify: no classification of uv is possible -> continue search
    if (uv[1] > p[1]) {
      tmin = t;
    }
    else {
      tmax = t;
    }

    // classify: uv is on right -> no intersection -> stop search
    //   ____________________
    //  | \            xxxxxx|
    //  |   ---____    xxxxxx|
    //  |          \   xxxxxx|
    //  |           --oxxxxxx|
    //  |                --_ |
    //  | __________________\|
    if (!horizontally_increasing && uv[0] > p[0] && uv[1] > p[1]) {
      vec2 sekant = curve_bbox.xw - curve_bbox.zy;
      gradient = normalize(vec2(-sekant.y, sekant.x));
      closest_point = p.xy;
      break;
    }

    // classify: uv is on right -> no intersection -> stop search
    //  __________________ 
    // |                 /|
    // |                / |
    // |          __----  |
    // |  ____---oxxxxxxxx|
    // | /        xxxxxxxx|
    // |__________xxxxxxxx|
    if (horizontally_increasing && uv[0] > p[0] && uv[1] < p[1]) {
      vec2 sekant = curve_bbox.zw - curve_bbox.xy;
      gradient = normalize(vec2(-sekant.y, sekant.x));
      closest_point = p.xy;
      break;
    }

    // classify: uv is on left  -> intersection -> stop search
    //  __________________ 
    // |xxxxxxxxx        /|
    // |xxxxxxxxx       / |
    // |xxxxxxxxx __----  |
    // |  ____---o        |
    // | /                |
    // |__________________|
    if (horizontally_increasing && uv[0] < p[0] && uv[1] > p[1]) {
      ++intersections;
      vec2 sekant = curve_bbox.zw - curve_bbox.xy;
      gradient = normalize(vec2(-sekant.y, sekant.x));
      closest_point = p.xy;
      break;
    }

    // classify: uv is on left  -> intersection -> stop search
    //   __________________
    //  | \                |
    //  |   ---__          |
    //  |         \        |
    //  |xxxxxxxxxxo__     |
    //  |xxxxxxxxxx   --__ |
    //  |xxxxxxxxxx_______\|  
    if (!horizontally_increasing && uv[0] < p[0] && uv[1] < p[1]) {
      ++intersections;
      vec2 sekant = curve_bbox.xw - curve_bbox.zy;
      gradient = normalize(vec2(-sekant.y, sekant.x));
      closest_point = p.xy;
      break;
    }
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////
bool
bisect_contour(in vec2            uv,
               in unsigned int    id,
               in unsigned int    intervals,
               in bool            uincreasing,
               inout unsigned int intersections,
               inout unsigned int curveindex)
{
  unsigned int id_min = id;
  unsigned int id_max = id + intervals - 1;

  bool needs_curve_evaluation = false;

  while (id_min <= id_max) {

    unsigned int id = id_min + (id_max - id_min) / unsigned int(2);
    bbox_t curve_bbox = curves[id].bbox;
    gpucast_count_texel_fetch();

    if (uv[1] >= curve_bbox.vmin && uv[1] <= curve_bbox.vmax) {
      if (uv[0] >= curve_bbox.umin && uv[0] <= curve_bbox.umax) {
        curveindex = id;
        needs_curve_evaluation = true;
        return needs_curve_evaluation;
      }
      else {
        if (uv[0] < curve_bbox.umin) {
          ++intersections;
        }
      }
      break;
    }
    else {

      if ((uv[1] < curve_bbox.vmax && uv[0] > curve_bbox.umax && uincreasing) ||
          (uv[1] < curve_bbox.vmin && uv[0] > curve_bbox.umin && uincreasing) ||
          (uv[1] > curve_bbox.vmin && uv[0] > curve_bbox.umax && !uincreasing) ||
          (uv[1] > curve_bbox.vmax && uv[0] > curve_bbox.umin && !uincreasing)) {
        break;
      }

      if ((uv[1] > curve_bbox.vmin && uv[0] < curve_bbox.umin && uincreasing) ||
          (uv[1] > curve_bbox.vmax && uv[0] < curve_bbox.umax && uincreasing) ||
          (uv[1] < curve_bbox.vmax && uv[0] < curve_bbox.umin && !uincreasing) ||
          (uv[1] < curve_bbox.vmin && uv[0] < curve_bbox.umax && !uincreasing)) {

        ++intersections;
        break;
      }

      if (uv[1] < curve_bbox.vmin) {
        id_max = id - 1;
      }
      else {
        id_min = id + 1;
      }
    }
  }

  return needs_curve_evaluation;
}


/////////////////////////////////////////////////////////////////////////////////////////////
bool
bisect_contour_coverage(in vec2            uv,
                        in unsigned int    id,
                        in unsigned int    intervals,
                        in bool            uincreasing,
                        inout unsigned int intersections,
                        inout unsigned int curveindex,
                        inout vec4         bbox,
                        out vec2           classification_point,
                        out vec2           classification_gradient)
{
  unsigned int id_min = id;
  unsigned int id_max = id + intervals - 1;

  bool needs_curve_evaluation = false;
  vec4 remaining_bbox = bbox;

  classification_point = vec2(-1000000.0);
  classification_gradient = vec2(0.0);

  while (id_min <= id_max) {

    unsigned int id = id_min + (id_max - id_min) / unsigned int(2);
    bbox_t curve_bbox = curves[id].bbox;
    gpucast_count_texel_fetch();

    if (uv[1] >= curve_bbox.vmin && uv[1] <= curve_bbox.vmax) {
      if (uv[0] >= curve_bbox.umin && uv[0] <= curve_bbox.umax) {
        curveindex = id;
        needs_curve_evaluation = true;
        bbox = vec4(curve_bbox.umin, curve_bbox.vmin, curve_bbox.umax, curve_bbox.vmax);
        return needs_curve_evaluation;
      }
      else {

        //debug_out = vec4(1.0, 0.0, 0.0, 1.0);
        // is in curve's v-interval, left of bbox -> found intersection
        if (uv[0] <= curve_bbox.umin) {
          //  __________________ 
          // |                _/|
          // |          ____ /  |
          // |xxxxxxxxx|    |   |
          // |xxxxxxxxx|____|   |
          // | ____----         |
          // |/_________________|
          //classification_point = vec2((curve_bbox.umin + curve_bbox.umax) / 2.0, (curve_bbox.vmin + curve_bbox.vmax) / 2.0); // use center of curve bbox            
          ++intersections;
        }
        else { // is in curve's v-interval, but right -> no intersection
          //  __________________ 
          // |                _/|
          // |          ____ /  |
          // |         |    |xxx|
          // |         |____|xxx|
          // | ____----         |
          // |/_________________|
          //classification_point = vec2((curve_bbox.umin + curve_bbox.umax) / 2.0, (curve_bbox.vmin + curve_bbox.vmax) / 2.0); // use center of curve bbox            
        }

        if (uincreasing) {
          vec2 sekant = remaining_bbox.zw - remaining_bbox.xy;
          classification_gradient = normalize(vec2(-sekant.y, sekant.x));
        }
        else {
          vec2 sekant = remaining_bbox.xw - remaining_bbox.zy;
          classification_gradient = normalize(vec2(-sekant.y, sekant.x));
        }

      }
      break;
    }
    else {

      // classify: uv is on right -> no intersection -> stop search
      //  __________________ 
      // |                 /|
      // |                / |
      // |          __----  |
      // |  ____---o        |
      // | /        xxxxxxxx|
      // |__________xxxxxxxx|
      if ( uv[1] < curve_bbox.vmin && uv[0] > curve_bbox.umin && uincreasing )
      {
        //classification_point = vec2((curve_bbox.umin + curve_bbox.umax) / 2.0, (curve_bbox.vmin + curve_bbox.vmax) / 2.0); // use center of curve bbox
        //classification_point = vec2(curve_bbox.umin, curve_bbox.vmin);
        vec2 sekant = remaining_bbox.zw - remaining_bbox.xy;
        classification_gradient = normalize(vec2(-sekant.y, sekant.x));
        break;
      }

      // classify: uv is on right -> no intersection -> stop search
      //   ____________________
      //  | \            xxxxxx|
      //  |   ---____    xxxxxx|
      //  |          \   xxxxxx|
      //  |           --o      |
      //  |                --_ |
      //  | __________________\|
      if ( uv[1] > curve_bbox.vmax && uv[0] > curve_bbox.umin && !uincreasing ) {
        //classification_point = vec2((curve_bbox.umin + curve_bbox.umax) / 2.0, (curve_bbox.vmin + curve_bbox.vmax) / 2.0); // use center of curve bbox
       // classification_point = vec2(curve_bbox.umax, curve_bbox.vmin);
        vec2 sekant = remaining_bbox.xw - remaining_bbox.zy;
        classification_gradient = normalize(vec2(-sekant.y, sekant.x));
        break;
      }

      // classify: uv is on left  -> intersection -> stop search
      //  __________________ 
      // |xxxxxxxxx        /|
      // |xxxxxxxxx       / |
      // |xxxxxxxxx __----  |
      // |  ____---o        |
      // | /                |
      // |__________________|
      if ( uv[1] > curve_bbox.vmax && uv[0] < curve_bbox.umax && uincreasing ) {
        //classification_point = vec2((curve_bbox.umin + curve_bbox.umax) / 2.0, (curve_bbox.vmin + curve_bbox.vmax) / 2.0); // use center of curve bbox
        //classification_point = vec2(curve_bbox.umin, curve_bbox.vmin);
        vec2 sekant = remaining_bbox.zw - remaining_bbox.xy;
        classification_gradient = normalize(vec2(-sekant.y, sekant.x));
        ++intersections;
        break;
      }

      // classify: uv is on left  -> intersection -> stop search
      //   __________________
      //  | \                |
      //  |   ---__          |
      //  |         \        |
      //  |          o__     |
      //  |xxxxxxxxxx   --__ |
      //  |xxxxxxxxxx_______\| 
      if ( uv[1] < curve_bbox.vmin && uv[0] < curve_bbox.umax && !uincreasing ) {
        //classification_point = vec2((curve_bbox.umin + curve_bbox.umax) / 2.0, (curve_bbox.vmin + curve_bbox.vmax) / 2.0); // use center of curve bbox
        //classification_point = remaining_bbox.xy;
        vec2 sekant = remaining_bbox.xw - remaining_bbox.zy;
        classification_gradient = normalize(vec2(-sekant.y, sekant.x));
        ++intersections;
        break;
      }

      // keep lower contour segment
      if (uv[1] < curve_bbox.vmin)
      {
        if (uincreasing) {
          remaining_bbox = vec4(remaining_bbox.x, remaining_bbox.y, curve_bbox.vmin, curve_bbox.vmax);
        }
        else {
          remaining_bbox = vec4(curve_bbox.umin, remaining_bbox[1], remaining_bbox[2], curve_bbox.vmax);
        }
        id_max = id - 1;
      }
      else { // keep upper contour segment
        if (uincreasing) {
          remaining_bbox = vec4(curve_bbox.vmin, curve_bbox.vmax, remaining_bbox.z, remaining_bbox.w);
        }
        else {
          remaining_bbox = vec4(remaining_bbox.x, curve_bbox.umax, curve_bbox.vmin, remaining_bbox.w);
        }
        id_min = id + 1;
      }
    }
  }

  return needs_curve_evaluation;
}



/////////////////////////////////////////////////////////////////////////////////////////////
bool is_inside(in bbox_t bbox, in vec2 point) 
{
  return point.x >= bbox.umin && point.x <= bbox.umax &&
         point.y >= bbox.vmin && point.y <= bbox.vmax;
}

/////////////////////////////////////////////////////////////////////////////////////////////
bool is_inside(in bbox_t outer, in bbox_t inner)
{
  return is_inside(outer, vec2(inner.umin, inner.vmin)) && 
         is_inside(outer, vec2(inner.umax, inner.vmax));
}

/////////////////////////////////////////////////////////////////////////////////////////////
bool classify_loop(in vec2 uv, in int index)
{
  bbox_t loop_bbox = loops[index].bbox;
  gpucast_count_texel_fetch();

  if (uv.x >= loop_bbox.umin && uv.x <= loop_bbox.umax && uv.y >= loop_bbox.vmin && uv.y <= loop_bbox.vmax)
  {
    unsigned int intersections = 0;

    unsigned int ci = loops[index].contour_index;
    gpucast_count_texel_fetch();

    for (unsigned int i = 0; i != loops[index].ncontours; ++i)
    {
      bbox_t       contour_bbox = contours[ci + i].bbox;
      gpucast_count_texel_fetch();

      // is inside monotonic contour segment
      if (uv[1] >= contour_bbox.vmin && uv[1] <= contour_bbox.vmax)
      {
        if (uv[0] >= contour_bbox.umin && uv[0] <= contour_bbox.umax)
        {
          // curve segment
          unsigned int contour_intersection = 0;
          unsigned int curve_index = 0;

          bool classify_by_curve = bisect_contour(uv,
            contours[ci + i].curve_index,
            contours[ci + i].ncurves,
            contours[ci + i].uincreasing != 0,
            contour_intersection,
            curve_index);

          // classification necessary
          if (classify_by_curve)
          {
            contour_intersection = 0;

            bisect_curve(uv,
              curves[curve_index].point_index,
              curves[curve_index].order,
              curves[curve_index].uincreasing != 0,
              0.0, 1.0,
              contour_intersection,
              0.00001,
              16U);
          }
          intersections += contour_intersection;
        }
        intersections += unsigned int(uv.x < contour_bbox.umin);
      }
    }

    return mod(intersections, 2) == 0;
  }
  else {
    return true;
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////
bool classify_loop_coverage(in vec2 uv, in int index, out vec2 closest_point, out vec2 closest_gradient)
{
  bbox_t loop_bbox = loops[index].bbox;
  gpucast_count_texel_fetch();

  closest_point = vec2(-10000.0); // TODO: improve initialization
  closest_gradient = vec2(1.0, 0.0);

  if (uv.x >= loop_bbox.umin && uv.x <= loop_bbox.umax && uv.y >= loop_bbox.vmin && uv.y <= loop_bbox.vmax)
  {
    unsigned int intersections = 0;

    unsigned int ci = loops[index].contour_index;
    gpucast_count_texel_fetch();
    bool curve_found = false;

    for (unsigned int i = 0; i != loops[index].ncontours; ++i)
    {
      bbox_t       contour_bbox = contours[ci + i].bbox;
      gpucast_count_texel_fetch();

      // is inside monotonic contour segment
      if (uv[1] >= contour_bbox.vmin && uv[1] <= contour_bbox.vmax)
      {
        if (uv[0] >= contour_bbox.umin && uv[0] <= contour_bbox.umax)
        {
          // curve segment
          unsigned int contour_intersection = 0;
          unsigned int curve_index = 0;
          vec4 remaining_bbox = vec4(contour_bbox.umin, contour_bbox.vmin, contour_bbox.umax, contour_bbox.vmax);

          vec2 point, gradient;
          bool classify_by_curve = bisect_contour_coverage(uv,
                                                           contours[ci + i].curve_index,
                                                           contours[ci + i].ncurves,
                                                           contours[ci + i].uincreasing != 0,
                                                           contour_intersection,
                                                           curve_index,
                                                           remaining_bbox,
                                                           point,
                                                           gradient);

          // classification necessary
          if (classify_by_curve)
          {
            contour_intersection = 0;

            bisect_curve_coverage(uv,
                                  curves[curve_index].point_index,
                                  curves[curve_index].order,
                                  curves[curve_index].uincreasing != 0,
                                  0.0, 1.0,
                                  0.000001,
                                  16U,
                                  remaining_bbox,
                                  contour_intersection,
                                  closest_point,
                                  closest_gradient);
          }
          else {
            if (length(uv - point) < length(uv - closest_point)) {
              closest_point = point;
              closest_gradient = gradient;
            }
          }

          intersections += contour_intersection;
        }
        intersections += unsigned int(uv.x < contour_bbox.umin);
      }
    }

    return mod(intersections, 2) == 0;
  }
  else {
    return true;
  }
}



/////////////////////////////////////////////////////////////////////////////////////////////
bool
trimming_loop_list (in vec2 uv, in int index, in usamplerBuffer preclassification)
{
  bool is_trimmed = false;

  /////////////////////////////////////////////////////////////////////////////
  // 1. texture-based pre-classification 
  /////////////////////////////////////////////////////////////////////////////
  int classification_base_id = int(loops[index].pre_class_id);
  if ( classification_base_id != 0 )
  {
    int preclasstex_width  = int(loops[index].pre_class_width);
    int preclasstex_height = int(loops[index].pre_class_height);
    int pre_class = pre_classify(preclassification,
                                 classification_base_id,
                                 uv,
                                 loops[index].domainsize,
                                 preclasstex_width, 
                                 preclasstex_height);
  
    if (pre_class != 0) {
      return mod(pre_class, 2) == 0;
    }  
  }
  is_trimmed = classify_loop(uv, index);

  /////////////////////////////////////////////////////////////////////////////
  // 2. magnification - exact classification
  /////////////////////////////////////////////////////////////////////////////
  vec4 kdnode = vec4(0.0);
  for (unsigned int i = 0; i < loops[index].nchildren; ++i) {
    //is_trimmed = is_trimmed && classify_loop(uv, int(loops[index].child_index + i));
    is_trimmed = is_trimmed == classify_loop(uv, int(loops[index].child_index + i));
  }

  return is_trimmed;
}

/////////////////////////////////////////////////////////////////////////////////////////////
float
trimming_loop_list_coverage(in vec2 uv, 
                            in vec2 duvdx, 
                            in vec2 duvdy, 
                            in usamplerBuffer preclassification,
                            in sampler2D prefilter,
                            in int index,
                            in int coverage_estimation_type)
{
  /////////////////////////////////////////////////////////////////////////////
  // 1. texture-based pre-classification 
  /////////////////////////////////////////////////////////////////////////////
  int classification_base_id = int(loops[index].pre_class_id);
  if ( classification_base_id != 0 )
  { 
    int preclasstex_width  = int(loops[index].pre_class_width);
    int preclasstex_height = int(loops[index].pre_class_height);

    int pre_class = pre_classify(preclassification,
                                 classification_base_id,
                                 uv,
                                 loops[index].domainsize,
                                 preclasstex_width, 
                                 preclasstex_height);
    if (pre_class != 0) {
      return float(mod(pre_class, 2) == 1);
    } 
  }


  /////////////////////////////////////////////////////////////////////////////
  // 2. magnification - exact classification
  /////////////////////////////////////////////////////////////////////////////
  vec2 closest_point_on_curve;
  vec2 closest_bounds;

  bool is_trimmed = classify_loop_coverage(uv, index, closest_point_on_curve, closest_bounds);

  for (unsigned int i = 0; i < loops[index].nchildren; ++i) {
    vec2 point_on_curve;
    vec2 bounds_on_curve;
    bool loop_trimmed = classify_loop_coverage(uv, int(loops[index].child_index + i), point_on_curve, bounds_on_curve);
    is_trimmed = is_trimmed == loop_trimmed;

    if (length(point_on_curve - uv) < length(closest_point_on_curve - uv)) {
      closest_point_on_curve = point_on_curve;
      closest_bounds = bounds_on_curve;
    }
  }

  /////////////////////////////////////////////////////////////////////////////
  // coverage estimation
  /////////////////////////////////////////////////////////////////////////////
  return classification_to_coverage(uv, duvdx, duvdy, !is_trimmed, closest_point_on_curve, closest_bounds, prefilter);
}


#endif