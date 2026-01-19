#include "metal.h"
#include <AppKit/AppKit.h>
#include <Foundation/Foundation.h>
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include <ModelIO/ModelIO.h>

R_View
r_view_alloc(void)
{
    // The Metal View
    R_View result;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil)
    {
        fprintf(stderr, "GPU not supported\n");
        exit(1);
    }
    CGRect frame = {.origin = {0, 0}, .size = {600, 600}};
    MTKView *view = [[MTKView alloc] initWithFrame:frame device:device];
    view.clearColor = (MTLClearColor){1.0, 1.0, 0.8, 1.0};

    // ~ create window and attach view
    NSWindowStyleMask mask = (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:mask backing:NSBackingStoreBuffered defer:false];
    [window setContentView:view];
    [window makeKeyAndOrderFront:nil];
    [device release];
    result.u64[0] = (U64)view;

    return result;
}

void
r_view_release(R_View handle)
{
    MTKView *view = (MTKView *)handle.u64[0];
    [view release];
}

R_Renderer
r_renderer_alloc(R_View handle)
{
    R_Renderer result;
    MTKView *view = (MTKView *)handle.u64[0];

    R_Buffer triangle_vertex_buffers_handle[MAX_FRAMES_IN_FLIGHT];
    R_Buffer viewport_size_buffer_handle;
    for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++)
    {
        id<MTLBuffer> buffer = [view.device newBufferWithLength:sizeof(TriangleData) options:MTLResourceStorageModeShared];
        triangle_vertex_buffers_handle[i].u64[0] = (U64)buffer;
    }
    viewport_size_buffer_handle.u64[0] = (U64)[view.device newBufferWithLength:sizeof(VertexData) options:MTLResourceStorageModeShared];

    // Queues, Buffers and Encoders
    R_CommandQueue command_queue_handle;
    id<MTLCommandQueue> command_queue = view.device.newCommandQueue;
    if (command_queue == nil)
    {
        fprintf(stderr, "Could not create a command queue\n");
        exit(1);
    }
    command_queue_handle.u64[0] = (U64)command_queue;

    // Shader Functions
    NSString *source = [NSString stringWithContentsOfFile:@"shaders.metal" encoding:NSUTF8StringEncoding error:nil];
    id<MTLLibrary> library = [view.device newLibraryWithSource:source options:nil error:nil];
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];

    // The Model
    R_Mesh mesh_handle;
    MTKMeshBufferAllocator *allocator = [[MTKMeshBufferAllocator alloc] initWithDevice:view.device];
    MDLMesh *mdlMesh = [[MDLMesh alloc] initSphereWithExtent:(vector_float3){0.75, 0.75, 0.75}
                                                    segments:(vector_uint2){100, 100}
                                               inwardNormals:false
                                                geometryType:MDLGeometryTypeTriangles
                                                   allocator:allocator];
    MTKMesh *mesh = [[MTKMesh alloc] initWithMesh:mdlMesh device:view.device error:nil];
    mesh_handle.u64[0] = (U64)mesh;

    // The Pipeline State
    R_RenderPipelineState pipeline_state_handle;
    NSError *err;
    MTLRenderPipelineDescriptor *pipeline_descriptor = [MTLRenderPipelineDescriptor new];
    pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipeline_descriptor.vertexFunction = vertexFunction;
    pipeline_descriptor.fragmentFunction = fragmentFunction;
    pipeline_descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor);
    id<MTLRenderPipelineState> pipeline_state = [view.device newRenderPipelineStateWithDescriptor:pipeline_descriptor error:&err];
    if (pipeline_state == nil)
    {
        fprintf(stderr, "%s\n", err.localizedDescription.UTF8String);
        exit(1);
    }
    pipeline_state_handle.u64[0] = (U64)pipeline_state;

    result.command_queue = command_queue_handle;
    result.frame_number = 0;
    result.viewport_size = (SIMD2U64){600LL, 600LL};
    result.viewport_size_buffer = viewport_size_buffer_handle;
    *result.triangle_vertex_buffers = *triangle_vertex_buffers_handle;
    result.render_pipeline_state = pipeline_state_handle;
    result.mesh = mesh_handle;

    return result;
}

void
r_renderer_release(R_Renderer handle)
{
}

void
r_render(R_Renderer renderer, R_View view_handle)
{
    id<MTLCommandQueue> command_queue = (id<MTLCommandQueue>)renderer.command_queue.u64[0];
    id<MTLRenderPipelineState> pipeline_state = (id<MTLRenderPipelineState>)renderer.render_pipeline_state.u64[0];
    MTKMesh *mesh = (MTKMesh *)renderer.mesh.u64[0];
    MTKView *view = (MTKView *)view_handle.u64[0];

    id<MTLCommandBuffer> command_buffer = command_queue.commandBuffer;
    MTLRenderPassDescriptor *render_pass_descriptor = view.currentRenderPassDescriptor;
    id<MTLRenderCommandEncoder> render_encoder = [command_buffer renderCommandEncoderWithDescriptor:render_pass_descriptor];
    [render_encoder setRenderPipelineState:pipeline_state];
    [render_encoder setVertexBuffer:mesh.vertexBuffers[0].buffer offset:0 atIndex:0];

    // Submeshes
    MTKSubmesh *submesh = [mesh.submeshes firstObject];
    [render_encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:submesh.indexCount
                                indexType:submesh.indexType
                              indexBuffer:submesh.indexBuffer.buffer
                        indexBufferOffset:0
                            instanceCount:1];
    [render_encoder endEncoding];
    id<CAMetalDrawable> drawable = [view currentDrawable];
    [command_buffer presentDrawable:drawable];
    [command_buffer commit];
}
