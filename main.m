#include "metal.h"
#include <AppKit/AppKit.h>

int
main(void)
{
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];

    R_View view = r_view_alloc();
    R_Renderer renderer = r_renderer_alloc(view);

    [NSTimer scheduledTimerWithTimeInterval:(1.0 / 100.0)
                                    repeats:true
                                      block:^(NSTimer *_Nonnull timer) {
                                        r_render(renderer, view);
                                      }];

    r_renderer_release(renderer);
    r_view_release(view);

    [app activateIgnoringOtherApps:true];
    [app run];
}
