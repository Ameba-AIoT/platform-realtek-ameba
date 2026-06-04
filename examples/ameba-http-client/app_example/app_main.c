/*
 * app_example/app_main.c
 *
 * SDK entry point: the Ameba SDK's main() calls app_example() during
 * bring-up (the equivalent of app_main() in ESP-IDF). We delegate to
 * user_main() in src/ so all user code lives in the PIO-standard place.
 */

extern void user_main(void);

void app_example(void)
{
    user_main();
}
