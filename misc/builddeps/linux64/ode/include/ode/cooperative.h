/*************************************************************************
 *                                                                       *
 * Open Dynamics Engine, Copyright (C) 2001-2003 Russell L. Smith.       *
 * All rights reserved.  Email: russ@q12.org   Web: www.q12.org          *
 *                                                                       *
 * This library is free software; you can redistribute it and/or         *
 * modify it under the terms of EITHER:                                  *
 *   (1) The GNU Lesser General Public License as published by the Free  *
 *       Software Foundation; either version 2.1 of the License, or (at  *
 *       your option) any later version. The text of the GNU Lesser      *
 *       General Public License is included with this library in the     *
 *       file LICENSE.TXT.                                               *
 *   (2) The BSD-style license that is included with this library in     *
 *       the file LICENSE-BSD.TXT.                                       *
 *                                                                       *
 * This library is distributed in the hope that it will be useful,       *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the files    *
 * LICENSE.TXT and LICENSE-BSD.TXT for more details.                     *
 *                                                                       *
 *************************************************************************/

#ifndef _ODE_COOPERATIVE_H_
#define _ODE_COOPERATIVE_H_


#include <ode/common.h>
#include <ode/threading.h>


#ifdef __cplusplus
extern "C" {
#endif

/**
 * @defgroup coop Cooperative Algorithms
 *
 * Algorithms implemented as multiple threads doing work cooperatively.
 */


struct dxCooperative;
struct dxResourceRequirements;
struct dxResourceContainer;

/**
 * @brief A container for cooperative algorithms shared context
 *
 * The Cooperative is a container for cooperative algorithms shared context.
 * At present it contains threading object (either a real one or a defaulted 
 * self-threading).
 *
 * Cooperative use in functions performing computations must be serialized. That is,
 * functions referring to a single instance of Cooperative object must not be called in
 * parallel.
 */
typedef struct dxCooperative *dCooperativeID;


/**
 * @brief A container for resource requirements information
 *
 * The ResourceRequirements object is a container for descriptive information
 * regarding what resources (memory, synchronization objects, etc.) need to be
 * allocated for particular computations. The object can be used for accumulating 
 * resource requirement maxima over multiple functions and then allocating resources
 * that would suffice for any of those function calls.
 *
 * ResourceRequirements objects maintain relations to Cooperative objects since
 * amounts of resources that could be required can depend on characteristics of 
 * shared context, e.g. on maximal number of threads in the threading object.
 *
 * @ingroup coop
 * @see dCooperativeID
 * @see dResourceContainerID
 */
typedef struct dxResourceRequirements *dResourceRequirementsID;

/**
 * @brief A container for algorithm allocated resources
 * 
 * The ResourceContainer object can contain resources allocated according to information
 * in a ResourceRequirements. The resources inherit link to the threading object 
 * from the requirements they are allocated according to.
 *
 * @ingroup coop
 * @see dResourceRequirementsID
 * @see dCooperativeID
 */
typedef struct dxResourceContainer *dResourceContainerID;


 /**
 * @brief Creates a Cooperative object related to the specified threading.
 *
 * NULL's are allowed for the threading. In this case the default (global) self-threading
 * object will be used.
 *
 * Use @c dCooperativeDestroy to destroy the object. The Cooperative object must exist 
 * until after all the objects referencing it are destroyed.
 *
 * @param functionInfo The threading functions to use
 * @param threadingImpl The threading implementation object to use
 * @returns The Cooperative object instance or NULL if allocation fails.
 * @ingroup coop
 * @see dCooperativeDestroy
 */
ODE_API dCooperativeID dCooperativeCreate(const dThreadingFunctionsInfo *functionInfo/*=NULL*/, dThreadingImplementationID threadingImpl/*=NULL*/);

 /**
 * @brief Destroys Cooperative object.
 *
 * The Cooperative object can only be destroyed after all the objects referencing it.
 *
 * @param cooperative A Cooperative object to be deleted (NULL is allowed)
 * @ingroup coop
 * @see dCooperativeCreate
 */
ODE_API void dCooperativeDestroy(dCooperativeID cooperative);


 /**
 * @brief Creates a ResourceRequirements object related to a Cooperative.
 *
 * The object is purely descriptive and does not contain any resources by itself.
 * The actual resources are allocated by means of ResourceContainer object.
 *
 * The object is created with empty requirements. It can be then used to accumulate 
 * requirements for one or more function calls and can be cloned or merged with others.
 * The actual requirements information is added to the object by computation related
 * functions.
 *
 * Use @c dResourceRequirementsDestroy to delete the object when it is no longer needed.
 *
 * @param cooperative A Cooperative object to be used
 * @returns The ResourceRequirements object instance or NULL if allocation fails
 * @ingroup coop
 * @see dResourceRequirementsDestroy
 * @see dResourceRequirementsClone
 * @see dResourceRequirementsMergeIn
 * @see dCooperativeCreate
 * @see dResourceContainerAcquire
 */
ODE_API dResourceRequirementsID dResourceRequirementsCreate(dCooperativeID cooperative);

 /**
 * @brief Destroys ResourceRequirements object.
 *
 * The ResourceRequirements object can be destroyed at any time with no regards 
 * to other objects' lifetime.
 *
 * @param requirements A ResourceRequirements object to be deleted (NULL is allowed)
 * @ingroup coop
 * @see dResourceRequirementsCreate
 */
ODE_API void dResourceRequirementsDestroy(dResourceRequirementsID requirements);

 /**
 * @brief Clones ResourceRequirements object.
 *
 * The function creates a copy of the ResourceRequirements object with all the 
 * contents and the relation to Cooperative matching. The object passed in 
 * the parameter is not changed.
 *
 * The object created with the function must later be destroyed with @c dResourceRequirementsDestroy.
 *
 * @param requirements A ResourceRequirements object to be cloned
 * @returns A handle to the new object or NULL if allocation fails
 * @ingroup coop
 * @see dResourceRequirementsCreate
 * @see dResourceRequirementsDestroy
 * @see dResourceRequirementsMergeIn
 */
ODE_API dResourceRequirementsID dResourceRequirementsClone(/*const */dResourceRequirementsID requirements);

 /**
 * @brief Merges one ResourceRequirements object into another ResourceRequirements object.
 *
 * The function updates @a summaryRequirements requirements to be also sufficient
 * for the purposes @a extraRequirements could be used for. The @a extraRequirements
 * object is not changed. The both objects should normally have had been created 
 * with the same Cooperative object.
 *
 * @param summaryRequirements A ResourceRequirements object to be changed
 * @param extraRequirements A ResourceRequirements the requirements to be taken from
 * @ingroup coop
 * @see dResourceRequirementsCreate
 * @see dResourceRequirementsDestroy
 * @see dResourceRequirementsClone
 */
ODE_API void dResourceRequirementsMergeIn(dResourceRequirementsID summaryRequirements, /*const */dResourceRequirementsID extraRequirements);


 /**
 * @brief Allocates resources as specified in ResourceRequirements object.
 *
 * The ResourceContainer object can be used in cooperative computation algorithms.
 *
 * The same @a requirements object can be passed to many resource allocations 
 * (with or without modifications) and can be deleted immediately, without waiting
 * for the ResourceContainer object destruction.
 *
 * Use @c dResourceContainerDestroy to delete the object and release the resources 
 * when they are no longer needed.
 *
 * @param requirements The ResourceRequirements object to allocate resources according to
 * @returns A ResourceContainer object instance with the resources allocated or NULL if allocation fails
 * @ingroup coop
 * @see dResourceContainerDestroy
 * @see dResourceRequirementsCreate
 */
ODE_API dResourceContainerID dResourceContainerAcquire(/*const */dResourceRequirementsID requirements);

 /**
 * @brief Destroys ResourceContainer object and releases resources allocated in it.
 *
 * @param resources A ResourceContainer object to be deleted (NULL is allowed)
 * @ingroup coop
 * @see dResourceContainerAcquire
 */
ODE_API void dResourceContainerDestroy(dResourceContainerID resources);


#ifdef __cplusplus
} // extern "C"
#endif


#endif // #ifndef _ODE_COOPERATIVE_H_
