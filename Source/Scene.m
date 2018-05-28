#import "Scene.h"

Object* objectPointer(Param *p,int index) { return &(p->object[index]); }

void setObject(Param *p,int index, Object v) { p->object[index] = v; }
Object getObject(Param *p,int index) { return p->object[index]; }
