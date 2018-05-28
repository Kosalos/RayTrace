#pragma once

#include <simd/simd.h>

#define KIND_SPHERE   0
#define KIND_PLANE    1
#define KIND_TRIANGLE 2
#define MAX_OBJECTS   12

typedef struct {
    int kind;
    vector_float3 p1;   // sphere: center;  plane: position;  triangle: vertex #1
    vector_float3 p2;   // sphere: p2.x = radius; plane: normal;  triangle: vertex #2
    vector_float3 p3;   // sphere: unused; plane: unused  triangle: vertex #3
    vector_float3 color;
} Object;

typedef struct {
    vector_float3 light;
    int count;
    Object object[MAX_OBJECTS];
} Param;

// Swift access to arrays in Param
#ifndef __METAL_VERSION__

Object* objectPointer(Param *p,int index);
void setObject(Param *p,int index, Object v);
Object getObject(Param *p,int index);

#endif


