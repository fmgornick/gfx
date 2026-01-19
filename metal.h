#ifndef METAL_H
#define METAL_H

#include <stdint.h>

#define MAX_FRAMES_IN_FLIGHT 3

typedef int8_t S8;
typedef int16_t S16;
typedef int32_t S32;
typedef int64_t S64;
typedef uint8_t U8;
typedef uint16_t U16;
typedef uint32_t U32;
typedef uint64_t U64;
typedef S8 B8;
typedef S16 B16;
typedef S32 B32;
typedef S64 B64;
typedef float F32;
typedef double F64;

typedef __attribute__((__ext_vector_type__(2))) F32 SIMD2F32;
typedef __attribute__((__ext_vector_type__(4))) F32 SIMD4F32;
typedef __attribute__((__ext_vector_type__(2))) U64 SIMD2U64;

typedef struct VertexData {
    SIMD2F32 position;
    SIMD4F32 color;
} VertexData;

typedef struct TriangleData {
    VertexData v1;
    VertexData v2;
    VertexData v3;
} TriangleData;

/// id<MTLCommandQueue> handle
typedef struct R_CommandQueue {
    U64 u64[1];
} R_CommandQueue;

/// id<MTLSharedEvent> handle
typedef struct R_SharedEvent {
    U64 u64[1];
} R_SharedEvent;

/// id<MTLBuffer> handle
typedef struct R_Buffer {
    U64 u64[1];
} R_Buffer;

/// MTKView * handle
typedef struct R_View {
    U64 u64[1];
} R_View;

// MTKMesh * handle
typedef struct R_Mesh {
    U64 u64[1];
} R_Mesh;

/// id<MTLRenderPipelineState> handle
typedef struct R_RenderPipelineState {
    U64 u64[1];
} R_RenderPipelineState;

typedef struct R_Renderer {
    /// A command queue the app uses to send command buffers to the Metal device.
    R_CommandQueue command_queue;

    /// A shared event that synchronizes work that runs on the CPU and GPU.
    ///
    /// The app instructs the GPU to signal the main code on the CPU when it
    /// finishes rendering a frame.
    R_SharedEvent shared_event[1];

    /// An integer that tracks the current frame number.
    U64 frame_number;

    /// The current size of the view.
    SIMD2U64 viewport_size;

    /// A buffer that stores the viewport's size data.
    ///
    /// The renderer sends this buffer as an input to the vertex shader.
    R_Buffer viewport_size_buffer;

    /// An array of buffers, each of which stores the geometric position and color
    /// data of a triangle's three vertices for one frame.
    ///
    /// The renderer sends one of these buffers, per frame, as an input to the vertex shader.
    R_Buffer triangle_vertex_buffers[MAX_FRAMES_IN_FLIGHT];

    /// A render pipeline the app creates at runtime.
    ///
    /// The app creates the pipeline with the vertex and fragment shaders in the
    /// `Shaders.metal` source code file.
    R_RenderPipelineState render_pipeline_state;

    R_Mesh mesh;
} R_Renderer;

R_View r_view_alloc(void);
void r_view_release(R_View view);

R_Renderer r_renderer_alloc(R_View view);
void r_renderer_release(R_Renderer renderer);

void r_launch_app(void);
void r_render(R_Renderer renderer, R_View view);

#endif // METAL_H
