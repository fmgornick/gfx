#include "metal.h"
#include <AppKit/AppKit.h>
#include <Foundation/Foundation.h>
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include <ModelIO/ModelIO.h>

void
metal_render(void)
{
    @autoreleasepool
    {
        // ~ initialize application
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        // The Metal View
        NSError *err;
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

        // The Model
        MTKMeshBufferAllocator *allocator = [[MTKMeshBufferAllocator alloc] initWithDevice:device];
        MDLMesh *mdlMesh = [[MDLMesh alloc] initSphereWithExtent:(vector_float3){0.75, 0.75, 0.75}
                                                        segments:(vector_uint2){100, 100}
                                                   inwardNormals:false
                                                    geometryType:MDLGeometryTypeTriangles
                                                       allocator:allocator];
        MTKMesh *mesh = [[MTKMesh alloc] initWithMesh:mdlMesh device:device error:nil];

        // Queues, Buffers and Encoders
        id<MTLCommandQueue> commandQueue = device.newCommandQueue;
        if (commandQueue == nil)
        {
            fprintf(stderr, "Could not create a command queue\n");
            exit(1);
        }

        // Shader Functions
        id<MTLLibrary> library = [device newLibraryWithURL:[NSURL fileURLWithPath:@"shaders.metallib"] error:nil];
        id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
        id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];

        // The Pipeline State
        MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipelineDescriptor.vertexFunction = vertexFunction;
        pipelineDescriptor.fragmentFunction = fragmentFunction;
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor);
        id<MTLRenderPipelineState> pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&err];
        if (pipelineState == nil)
        {
            fprintf(stderr, "%s\n", err.localizedDescription.UTF8String);
            exit(1);
        }

        // Rendering
        [NSTimer scheduledTimerWithTimeInterval:(1.0 / 100.0)
                                        repeats:true
                                          block:^(NSTimer *_Nonnull timer) {
                                            id<MTLCommandBuffer> commandBuffer = commandQueue.commandBuffer;
                                            MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
                                            id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
                                            [renderEncoder setRenderPipelineState:pipelineState];
                                            [renderEncoder setVertexBuffer:mesh.vertexBuffers[0].buffer offset:0 atIndex:0];

                                            // Submeshes
                                            MTKSubmesh *submesh = [mesh.submeshes firstObject];
                                            [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                                                      indexCount:submesh.indexCount
                                                                       indexType:submesh.indexType
                                                                     indexBuffer:submesh.indexBuffer.buffer
                                                               indexBufferOffset:0
                                                                   instanceCount:1];
                                            [renderEncoder endEncoding];
                                            id<CAMetalDrawable> drawable = [view currentDrawable];
                                            [commandBuffer presentDrawable:drawable];
                                            [commandBuffer commit];
                                          }];

        // ~ run application
        [app activateIgnoringOtherApps:true];
        [app run];
    }
}
