/*******************************************************************************
**  Mesh-based Monte Carlo (MMC)
**
**  Author: Qianqian Fang <fangq at nmr.mgh.harvard.edu>
**
**  Reference:
**  (Fang2010) Qianqian Fang, "Mesh-based Monte Carlo Method Using Fast Ray-Tracing 
**          in Pl�cker Coordinates," Biomed. Opt. Express, 1(1) 165-175 (2010)
**
**  (Fang2009) Qianqian Fang and David A. Boas, "Monte Carlo Simulation of Photon 
**          Migration in 3D Turbid Media Accelerated by Graphics Processing 
**          Units," Optics Express, 17(22) 20178-20190 (2009)
**
**  License: GPL v3, see LICENSE.txt for details
**
*******************************************************************************/

/***************************************************************************//**
\file    tettracing.h

\brief   Definition of the core ray-tracing functions
*******************************************************************************/

#ifndef _MMC_RAY_TRACING_H
#define _MMC_RAY_TRACING_H

#include "simpmesh.h"
#include "mcx_utils.h"

#define MAX_TRIAL          3
#define FIX_PHOTON         1e-3f


/***************************************************************************//**
\struct MMC_ray tettracing.h
\brief  Data structure associated with the current photon

*******************************************************************************/   

typedef struct MMC_ray{
	float3 p0;
	float3 vec;
	float3 pout;
	float4 bary0;
	int eid;
	int faceid;
	int isend;
	int nexteid;
	float weight;
	float photontimer;
	float slen;
	float Lmove;
	double Eabsorb;
	float *partialpath;
} ray;

/***************************************************************************//**
\struct MMC_visitor tettracing.h
\brief  A structure that accumulates the statistics about the simulation

*******************************************************************************/  

typedef struct MMC_visitor{
	float raytet;
	float rtstep;
	int   detcount;
	int   bufpos;
	float *partialpath;
} visitor;

void interppos(float3 *w,float3 *p1,float3 *p2,float3 *p3,float3 *pout);
void getinterp(float w1,float w2,float w3,float3 *p1,float3 *p2,float3 *p3,float3 *pout);
void fixphoton(float3 *p,float3 *nodes, int *ee);
float onephoton(int id,raytracer *tracer,tetmesh *mesh,mcconfig *cfg,RandType *ran,RandType *ran0, visitor *visit);
float reflectray(mcconfig *cfg,float3 *c0,raytracer *tracer,int *oldeid,int *eid,int faceid,RandType *ran);

#endif
