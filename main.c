#include "metal.h"

int
main(void)
{
    R_View view = r_view_alloc();
    R_Renderer renderer = r_renderer_alloc(view);

    while (1)
    {
        r_render(renderer, view);
    }

    r_renderer_release(renderer);
    r_view_release(view);

    return 0;
}
