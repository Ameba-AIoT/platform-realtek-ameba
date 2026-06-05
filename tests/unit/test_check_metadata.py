"""tests/unit/test_check_metadata.py  (U04)

_inject_check_metadata() makes `pio check` (cppcheck/clang-tidy) see the
SDK's include paths and macros by parsing compile_commands.json. It samples
the longest-command entry (cmake emits short bootstrap entries with
abbreviated flags) and injects -I/-isystem/-D into env via AppendUnique.

This pins: longest-entry sampling, -I/-isystem/-D parsing, FOO=bar ->
(FOO, bar) translation, the PROJECT_DIR fallback, and the no-op paths.

Same AST-isolation approach as the other unit tests.
"""
import ast
import json
import os
import textwrap
from unittest.mock import MagicMock

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


def _inject(build_dir, project_dir, env):
    return _load_func(
        "_inject_check_metadata",
        {
            "PROJECT_BUILD_DIR": str(build_dir),
            "PROJECT_DIR": str(project_dir),
            "env": env,
            "json": json,
            "isfile": os.path.isfile,
            "join": os.path.join,
            "print": lambda *a, **k: None,
        },
    )


# A short bootstrap entry + a full TU entry. The function must sample the
# longest (the TU one) to get the complete -I/-D set.
CC = [
    {
        "directory": "/x",
        "command": "arm-none-eabi-gcc -DFOO -I/inc/a -c bootstrap.c",
        "file": "bootstrap.c",
    },
    {
        "directory": "/x",
        "command": (
            "arm-none-eabi-gcc -DFOO -DBAR=42 -I/inc/a -I/inc/b "
            "-isystem /inc/c -c real.c -o real.o"
        ),
        "file": "real.c",
    },
]


def test_parses_longest_entry(tmp_path):
    build = tmp_path / "build"
    build.mkdir()
    (build / "compile_commands.json").write_text(json.dumps(CC))
    env = MagicMock()

    _inject(build, tmp_path / "proj", env)()

    env.AppendUnique.assert_called_once()
    kw = env.AppendUnique.call_args.kwargs
    assert kw["CPPPATH"] == ["/inc/a", "/inc/b", "/inc/c"]  # deduped, ordered
    assert "FOO" in kw["CPPDEFINES"]
    assert ("BAR", "42") in kw["CPPDEFINES"]  # FOO=bar -> (FOO, bar)


def test_fallback_to_project_dir(tmp_path):
    """No compile_commands in build dir, but the PROJECT_DIR copy exists."""
    build = tmp_path / "build"
    build.mkdir()
    proj = tmp_path / "proj"
    proj.mkdir()
    (proj / "compile_commands.json").write_text(json.dumps(CC))
    env = MagicMock()

    _inject(build, proj, env)()

    env.AppendUnique.assert_called_once()


def test_noop_when_missing(tmp_path):
    """First-ever pio check (no build yet) must be a silent no-op."""
    env = MagicMock()
    _inject(tmp_path / "nobuild", tmp_path / "noproj", env)()
    env.AppendUnique.assert_not_called()


def test_empty_entries_noop(tmp_path):
    build = tmp_path / "build"
    build.mkdir()
    (build / "compile_commands.json").write_text("[]")
    env = MagicMock()
    _inject(build, tmp_path / "proj", env)()
    env.AppendUnique.assert_not_called()
