#include<metal_stdlib>
#include"Scene.h"

using namespace metal;

//MARK: -

#define sPosition obj.p1
#define sRadius   obj.p2.x

float sphereDistance
(
 constant Object &obj,
 float3 const direction,
 float3 const origin
 ) {
    float result = INFINITY;
    float3 const d = origin - obj.p1;
    float const c = fma(sRadius, -sRadius, length_squared(d));
    
    if ( 0 < c ) {
        float const b = dot(d, direction);
        float const e = fma(b, b, -c);
        result = select(result, -b-sqrt(e), 0 < e);
    }
    
    return result;
}

float3 sphereNormal(constant Object &obj, float3 const p) {
    return normalize( p - obj.p1 );
}

//MARK: -

#define pPosition obj.p1
#define pNormal   obj.p2

float planeDistance
(
 constant Object &obj,
 float3 const direction,
 float3 const origin
 ) {
    
    float result = INFINITY;
    float const a = dot(pNormal, direction);
    
    if ( isnormal(a) ) {
        float const distant = - dot(pNormal, origin - pPosition) / a;
        result = select(result, distant, 0 < distant);
    }
    
    return result;
}

float3 planeNormal(constant Object &obj) {
    return pNormal;
}

//MARK: -

#define triA obj.p1
#define triB obj.p2
#define triC obj.p3

float triangleDistance
(
 constant Object &obj,
 float3 const direction,
 float3 const origin
 ) {
    float result = INFINITY;
    float3 const n = normalize(cross(triB - triA, triC - triA));
    float const z = dot(n, direction);
    
    if ( isnormal(z) ) {
        float const distant = - dot(n, origin - triA) / z;
        
        if ( 0 < distant ) {
            float3 const p = fma(distant, direction, origin);
            if ( 0 < dot(n, cross(triC - p, triA - p)) && 0 < dot(n, cross(triA - p, triB - p)) && 0 < dot(n, cross(triB - p, triC - p))) result = distant;
        }
    }
    
    return result;
}

float3 triangleNormal(constant Object &obj) {
    return normalize(cross(triB - triA, triC - triA));
}

//MARK: -

struct PairIF {
    int first;
    float second;
};

inline PairIF
intersect
(
 float3 const direction,
 float3 const origin,
 Param constant &param,
 int const self
 ) {
    PairIF result = {-1, INFINITY};
    
    for ( int k = 0, K = param.count ; k < K ; ++ k ) {
        if ( k != self ) {
            float distant = INFINITY;
            
            switch ( param.object[k].kind ) {
                case KIND_SPHERE   : distant = sphereDistance(param.object[k], direction, origin); break;
                case KIND_PLANE    : distant = planeDistance(param.object[k], direction, origin); break;
                case KIND_TRIANGLE : distant = triangleDistance(param.object[k], direction, origin); break;
            }
            if ( distant < result.second ) result = {k, distant};
        }
    }
    return result;
}

//MARK: -

template<uint depth>
float4 trace
(
 float3 const direction,
 float3 const origin,
 Param constant &param,
 int const self
 ) {
    auto const hit = intersect(direction, origin, param, self);
    float4 color = 0;
    float4 mask = 1;
    float4 objColor = float4(1,1,1,1);
    
    if ( -1 < hit.first ) {
        float3 const object_p = fma(hit.second, direction, origin);
        float3 object_n = 0;
        
        switch ( param.object[hit.first].kind ) {
            case KIND_SPHERE :
            {
                object_n = sphereNormal(param.object[hit.first], object_p);
            }
                break;
                
            case KIND_PLANE :
            {
                object_n = planeNormal(param.object[hit.first]);
                bool2 const flag = fmod(fmod(object_p.xz, 2)+2, 2) < 1;     // checkerboard pattern
                if ( flag.x ^ flag.y ) mask = 0.5;
            }
                break;
                
            case 2 :
            {
                object_n = triangleNormal(param.object[hit.first]);
            }
                break;
        }
        
        if ( 0 < length_squared(object_n) ) {
            float3 const light_v = normalize(param.light - object_p);
            if ( intersect(light_v, object_p, param, hit.first).first < 0 )
                color += max(0.0, dot(direction, reflect(light_v, object_n)));
            
            objColor.xyz = param.object[hit.first].color;
            
            color += objColor * trace<depth-1>(reflect(direction, object_n), object_p, param, hit.first);
        }
    }
    return color * mask;
}

template<>float4 trace<0>
(
 float3 const direction,
 float3 const origin,
 Param constant &param,
 int const self
 ) {
    return 0;
}

//MARK: -

kernel void trace
(
 texture2d<float, access::write> texture [[ texture(0) ]],
 Param constant &param [[ buffer(0) ]],
 uint2 const k [[ thread_position_in_grid ]],
 uint2 const K [[ threads_per_grid ]])
{
    float3 const origin = float3(0, 0, -3);
    float3 const direction = normalize(float3(2*float2(k)/float2(K)-1, 2));
    
    texture.write( trace<2>(direction, origin, param, -1), k);        // trace<6>
};
