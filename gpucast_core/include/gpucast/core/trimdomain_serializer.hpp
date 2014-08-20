/********************************************************************************
*
* Copyright (C) 2013 Bauhaus-Universitaet Weimar
*
*********************************************************************************
*
*  module     : trimdomain_serializer.hpp
*  project    : gpucast
*  description:
*
********************************************************************************/
#ifndef GPUCAST_CORE_TRIMDOMAIN_SERIALIZER_HPP
#define GPUCAST_CORE_TRIMDOMAIN_SERIALIZER_HPP

// header, system
#include <unordered_map>

#include <gpucast/math/halffloat.hpp>
#include <gpucast/gl/math/vec4.hpp>

// header, project
#include <gpucast/core/gpucast.hpp>
#include <gpucast/core/beziersurface.hpp>
#include <gpucast/core/hyperspace_adapter.hpp>

namespace gpucast {

class GPUCAST_CORE trimdomain_serializer
{
  public : // enums/typedefs

    typedef unsigned                                            address_type;
    typedef float                                               float_type;

    typedef beziersurface::curve_point_type                     point_type;
    typedef gpucast::math::axis_aligned_boundingbox<point_type> bbox_type;
    typedef beziersurface::curve_type                           curve_type;
    typedef std::shared_ptr<curve_type>                         curve_ptr;

    typedef beziersurface::trimdomain_ptr                       trimdomain_ptr;

  public : // c'tor/d'tor

    trimdomain_serializer();
    virtual ~trimdomain_serializer();

  public : // methods

    template <typename float3_type>
    address_type    serialize ( curve_ptr const&                             input_curve, 
                                std::unordered_map<curve_ptr, address_type>& referenced_curves,
                                std::vector<float3_type>&                    output_container ) const;

    float_type      unsigned_bits_as_float  ( address_type i ) const;

    address_type    float_bits_as_unsigned  ( float_type f ) const;

    address_type uint4ToUInt ( unsigned char a, unsigned char b, unsigned char c, unsigned char d ) const
    {
      assert ( sizeof ( address_type ) == 4 );

      address_type result = 0U;
      result |= (d & 0x000000FF) << 24U;
      result |= (c & 0x000000FF) << 16U;
      result |= (b & 0x000000FF) << 8U;
      result |= (a & 0x000000FF);

      return result;
    }

    address_type uint8_24ToUInt ( unsigned char a, unsigned int b ) const
    {
      assert ( sizeof ( address_type ) == 4 );

      address_type result = 0U;
      result |= (b & 0x00FFFFFF) << 8U;
      result |= (a & 0x000000FF);

      return result;
    }

    void intToUint8_24 ( address_type input,
                         unsigned char& a, 
                         unsigned int& b ) const
    {
      b = (input & 0xFFFFFF00) >> 8U;
      a = (input & 0x000000FF);
    }

    address_type float2_to_unsigned ( float a, float b ) const
    {
      gpucast::math::halffloat_t ah = gpucast::math::floatToHalf ( a );
      gpucast::math::halffloat_t bh = gpucast::math::floatToHalf ( b );

      address_type result = 0U;
      result |= (bh & 0x0000FFFF) << 16U;
      result |= (ah & 0x0000FFFF);

      return result;
    }

  private : // member



  };

/////////////////////////////////////////////////////////////////////////////
template <typename float3_type>
trimdomain_serializer::address_type
trimdomain_serializer::serialize ( curve_ptr const&                               input_curve, 
                                   std::unordered_map<curve_ptr, address_type>& referenced_curves,
                                   std::vector<float3_type>&                      output_container ) const
{
  // find curve index, if already referenced
  std::unordered_map<curve_ptr, address_type>::const_iterator curve_index = referenced_curves.find(input_curve);

  if (curve_index != referenced_curves.end())
  {
    return curve_index->second;
  }
  else
  {
    // save current index
    address_type index = address_type ( output_container.size() );

    // copy curve data into buffer
    std::transform ( input_curve->begin(), 
                     input_curve->end(), 
                     std::back_inserter(output_container), 
                     hyperspace_adapter_2D_to_3D<gpucast::math::point2d, float3_type>() );

    // insert curve pointer and according index into map
    referenced_curves.insert ( std::make_pair ( input_curve, index ));

    if ( output_container.size() >= std::numeric_limits<address_type>::max() )
    {
      throw std::runtime_error ("Address exceeds maximum of addressable memory");
    }

    // return index the curve was written to
    return index;
  }
}

} // namespace gpucast

#endif // GPUCAST_CORE_TRIMDOMAIN_SERIALIZER_HPP