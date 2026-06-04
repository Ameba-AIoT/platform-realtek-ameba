/*
 * app_example/app_main.c
 *
 * SDK entry point. app_example() runs in the bare main() context BEFORE the
 * RTOS scheduler starts (the SDK calls rtos_sched_start() right after this
 * returns), so it must NOT block. We spawn a task to run user_main() and
 * return immediately -- user_main() then runs in a normal task context where
 * an infinite loop is perfectly fine. All user code lives in src/.
 */

#include "os_wrapper.h"

extern void user_main(void);

static void user_main_task(void *param)
{
    (void)param;
    user_main();
    rtos_task_delete(NULL);  /* user_main() returned -> end this task */
}

void app_example(void)
{
    /* Stack size is in BYTES. */
    rtos_task_create(NULL, "user_main", user_main_task, NULL, 4096, 1);
}
