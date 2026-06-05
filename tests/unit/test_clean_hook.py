"""tests/unit/test_clean_hook.py  (U06)

`pio run -t clean` runs SCons in --clean mode, which removes the default
target's outputs plus everything registered via env.Clean(). builder/main.py
registers _clean_artifact_paths() — the platform-generated build artifacts
PIO's built-in clean doesn't know about.

The dangerous failure mode here is clean nuking the user's source, so this
pins both directions: the artifact list MUST include the build dir +
sidecar files, and MUST NOT include any user source / generated skeleton.
(Actual deletion is exercised by I04 04_clean.sh.)
"""
import ast
import os
import textwrap

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _load_func(name, extra_globals):
    with open(os.path.join(REPO_ROOT, "builder", "main.py"), encoding="utf-8") as fh:
        src = fh.read()
    for node in ast.parse(src).body:
        if isinstance(node, ast.FunctionDef) and node.name == name:
            namespace = dict(extra_globals)
            exec(textwrap.dedent(ast.get_source_segment(src, node)), namespace)
            return namespace[name]
    raise AssertionError(f"{name} not found in builder/main.py")


PROJ = os.path.join(os.sep, "proj")


def _clean_paths(soc="RTL8721Dx"):
    fn = _load_func(
        "_clean_artifact_paths",
        {
            "EXTERN_BUILD_DIR": os.path.join(PROJ, f"build_{soc}"),
            "PROJECT_DIR": PROJ,
            "join": os.path.join,
        },
    )
    return fn()


def test_includes_build_artifacts():
    paths = _clean_paths()
    assert os.path.join(PROJ, "build_RTL8721Dx") in paths
    assert os.path.join(PROJ, "compile_commands.json") in paths
    assert os.path.join(PROJ, "soc_info.json") in paths
    assert os.path.join(PROJ, "app_example", "_pio_src_fragment.cmake") in paths


def test_excludes_user_source_and_skeleton():
    paths = _clean_paths()
    must_keep = [
        os.path.join(PROJ, "src"),
        os.path.join(PROJ, "src", "main.c"),
        os.path.join(PROJ, "CMakeLists.txt"),
        os.path.join(PROJ, "platformio.ini"),
        os.path.join(PROJ, "app_example"),
        os.path.join(PROJ, "app_example", "app_main.c"),
        os.path.join(PROJ, "app_example", "CMakeLists.txt"),
    ]
    for keep in must_keep:
        assert keep not in paths, f"clean must NOT delete user file: {keep}"


def test_build_dir_is_soc_specific():
    """The build dir entry tracks the active SoC (build_<SOC>/)."""
    assert os.path.join(PROJ, "build_RTL8713E") in _clean_paths(soc="RTL8713E")
