# PIO project root cmake entry for Ameba external project mode.
# The SDK (invoked with -DEXTERN_DIR=<this dir>) reads this as the project's
# top-level cmake. Keep it minimal — sources are registered in app_example/.

ameba_add_subdirectory(app_example)
