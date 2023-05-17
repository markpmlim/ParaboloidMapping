//
//  NSObject+Mesh.m
//  OpenGLDemos
//
//  Created by mark lim pak mun on 30/03/2017.
//  Copyright © 2017 Incremental Innovation. All rights reserved.
//

#import <OpenGL/gl3.h>
#import <SceneKit/ModelIO.h>
#import "Mesh.h"
#import "OGLShader.h"
#include <malloc/malloc.h>

@implementation OGLSubMesh {
    MDLSubmesh *_mdlSubmesh;
    // KIV - texture info for each submesh?
    NSMutableArray *_textures;
}

@end

@interface OGLMesh() {
    GLuint vao;
    GLuint *vbos;       // separate vertex buffer objects for each vertex attribute
    GLuint *ebos;       // separate element buffer objects for each submesh
    uint vertAttrsCount;
    uint *indexCounts;
    GLenum *indexTypes;
    NSArray<id<MDLMeshBuffer>> *indexBuffers;
}


@end

@implementation Mesh
- (instancetype) init {
    self = [super init];
    if (self) {
        glGenVertexArrays(1, &vao);
    }
    return self;
}

- (void) dealloc {
    free(vbos);
    free(ebos);
    free(indexCounts);
}

-(void) render {
    glBindVertexArray(vao);
    for (int i=0; i<vertAttrsCount; i++) {
        // The statement below may not be required.
        glEnableVertexAttribArray(i);
    }

    // Render the sub meshes.
    // The code is not fully tested if the model has more than 1 submesh
    for (int i=0; i<indexBuffers.count; i++) {
        // The statement below may not be required.
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebos[i]);
        glDrawElements(GL_TRIANGLES,
                       (GLsizei)indexCounts[i],
                       indexTypes[i],           //GL_UNSIGNED_INT,
                       0);
    }
    glBindVertexArray(0);
}

// Create one or more vertex buffer objects (VBOs) for this mesh.
// The vertex data of the mesh will be uploaded to the GPU.
// No assumptions are made on whether the MDLMesh consists of inter-leaved data.
-(void) addVertexBufferObjectsWithVertexAttributes:(NSDictionary *)vertAttrs
                           andVertexAttributesData:(NSDictionary *)vertAttrsData
                                    andVertexCount:(NSUInteger)vertCount {
    glBindVertexArray(vao);
    vertAttrsCount = (uint)vertAttrs.count;
    vbos = malloc(vertAttrs.count * sizeof(GLuint));
    glGenBuffers((GLsizei)vertAttrs.count, vbos);
    //printf("vbo names:%u %u %u\n", vbos[0], vbos[1], vbos[2]);
    // Allocate space for the VBO & copy data from arrays into it
    MDLVertexAttribute *vertAttr = vertAttrs[MDLVertexAttributePosition];
    MDLVertexAttributeData *vertAttrData = vertAttrsData[MDLVertexAttributePosition];
    void *dataBufPtr = vertAttrData.map.bytes;
    glBindBuffer(GL_ARRAY_BUFFER, vbos[0]);
    glBufferData(GL_ARRAY_BUFFER,
                 vertAttrData.stride*vertCount,
                 dataBufPtr,
                 GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0,                            // position attribute
                          3,                            // size
                          GL_FLOAT,                     // type
                          GL_FALSE,                     // don't normalize
                          (GLsizei)vertAttrData.stride, // stride
                          (const GLvoid *)vertAttr.offset);     // array buffer offset

    vertAttr = vertAttrs[MDLVertexAttributeNormal];
    vertAttrData = vertAttrsData[MDLVertexAttributeNormal];
    if (vertAttr != nil) {
        dataBufPtr = vertAttrData.map.bytes;
        glBindBuffer(GL_ARRAY_BUFFER, vbos[1]);
        glBufferData(GL_ARRAY_BUFFER,
                     vertAttrData.stride*vertCount,
                     dataBufPtr,
                     GL_STATIC_DRAW);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1,                            // normal attribute
                              3,                            // size
                              GL_FLOAT,                     // type
                              GL_FALSE,                     // don't normalize
                              (GLsizei)vertAttrData.stride, // stride
                              (const GLvoid *)vertAttr.offset);     // array buffer offset
    }

    vertAttr = vertAttrs[MDLVertexAttributeTextureCoordinate];
    vertAttrData = vertAttrsData[MDLVertexAttributeTextureCoordinate];
    if (vertAttr != nil) {
        dataBufPtr = vertAttrData.map.bytes;
        glBindBuffer(GL_ARRAY_BUFFER, vbos[2]);
        glBufferData(GL_ARRAY_BUFFER,
                     vertAttrData.stride*vertCount,
                     dataBufPtr,
                     GL_STATIC_DRAW);
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2,                            // texcoor attribute
                              2,                            // size
                              GL_FLOAT,                     // type
                              GL_FALSE,                     // don't normalize
                              (GLsizei)vertAttrData.stride, // stride
                              (const GLvoid *)vertAttr.offset);     // array buffer offset
    }
    // KIV. tangents, bitangent, binormal
    glBindVertexArray(0);
}

// We are assuming the geometry is triangle for all submeshes.
// For each submesh, an index buffer object is instantiated.
- (void) addIndexBufferObjectsWithIndexBuffers:(NSArray *)indexBufs
                                andIndexCounts:(uint *)counts
                                 andIndexTypes:(GLenum *)types {
    indexBuffers = indexBufs;
    indexCounts = malloc(indexBuffers.count * sizeof(uint));
    indexTypes = malloc(indexBuffers.count * sizeof(GLenum));
    //printf("size of index count memory block: %lu\n", malloc_size(vbos));
    for (int i=0; i<indexBuffers.count; i++) {
        indexCounts[i] = counts[i];
        indexTypes[i] = types[i];
    }
    glBindVertexArray(vao);
    //printf("vao name:%u\n", vao);
    ebos = malloc(indexBuffers.count * sizeof(GLuint));
    //printf("size of EBO memory block: %lu\n", malloc_size(vbos));
    glGenBuffers((GLsizei)indexBuffers.count, ebos);
    for (int i=0; i<indexBuffers.count; i++) {
        GLsizeiptr indexSize = sizeof(GLuint);      // default
        int count = indexCounts[i];
        id<MDLMeshBuffer> indexBuffer = indexBuffers[i];
        MDLMeshBufferMap *indexMap = indexBuffer.map;
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebos[i]);
        if (types[i] == GL_UNSIGNED_BYTE) {
            indexSize = sizeof(GLubyte);
        }
        else if (types[i] == GL_UNSIGNED_SHORT) {
            indexSize = sizeof(GLushort);
        }
        // Upload the index data to the GPU.
        void *indices = indexMap.bytes;
        glBufferData(GL_ELEMENT_ARRAY_BUFFER,
                     indexSize*count,
                     indices,
                     GL_STATIC_DRAW);
        
    }
    glBindVertexArray(0);
}

@end
