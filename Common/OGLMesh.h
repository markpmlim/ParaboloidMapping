//
//  NSObject+Mesh.h
//  OpenGLDemos
//
//  Created by mark lim pak mun on 30/03/2017.
//  Copyright © 2017 Incremental Innovation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OGLSubMesh : NSObject

@property (readonly) MDLSubmesh *mdlSubmesh;
@property (readonly, nonnull) NSMutableArray *textures;

@end

// This class should be the base class of 2 or more other classes.
// For example, one sub-class could handle model loading from files (obj/dea).
// Another sub-class could instantiate a Mesh object from C/C++ struct/arrays.
// Problem: indexing may not be provided
// Lastly, another sub-class could instantiate a Mesh with data generated
// using parametric surface equations.
@interface OGLMesh: NSObject

@property (nonatomic, readonly, nonnull) MDLMesh *mdlMesh;
@property (nonatomic, readonly, nonnull) NSArray<OGLSubMesh*> *submeshes;

// extension of GLKTextureLoader to load .hdr files.
+ (nullable NSArray<OGLMesh*> *) newMeshesFromObject:(nonnull MDLObject*)object
                             modelIOVertexDescriptor:(nonnull MDLVertexDescriptor*)vertexDescriptor
                               metalKitTextureLoader:(MTKTextureLoader*_Nullable)textureLoader
                                               error:(NSError * __nullable * __nullable)error;

// Constructs an array of meshes from the provided file URL, which indicate the location of a model
//  file in a format supported by Model I/O, such as OBJ, ABC, or USD.  mdlVertexDescriptor defines
//  the layout Model I/O will use to arrange the vertex data while the bufferAllocator supplies
//  allocations of Metal buffers to store vertex and index data
+ (nullable NSArray<OGLMesh*> *) newMeshesFromUrl:(nonnull NSURL *)url
                          modelIOVertexDescriptor:(nonnull MDLVertexDescriptor *)vertexDescriptor
                                            error:(NSError * __nullable * __nullable)error
                                             aabb:(MDLAxisAlignedBoundingBox&)aabb;

- (void) render;

// These two methods could in a sub-class that deals with model loading.
- (void) addVertexBufferObjectsWithVertexAttributes:(NSDictionary *)vertAttrs
                            andVertexAttributesData:(NSDictionary *)vertAttrsData
                                     andVertexCount:(NSUInteger)vertCount;

- (void) addIndexBufferObjectsWithIndexBuffers:(NSArray *)indexBufs
                                andIndexCounts:(uint *)count
                                 andIndexTypes:(GLenum *)indexTypes;
@end
