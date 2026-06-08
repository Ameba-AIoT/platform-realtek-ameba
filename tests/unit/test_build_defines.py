"""tests/unit/test_build_defines.py  (U08)

_parse_build_defines() extracts -D macros from a platformio.ini build_flags
string so the bridge can forward them onto the app_example library (the SDK
ignores EXTRA_CFLAGS, so this is how build_flags actually reach user code).

Pins: -DFOO / -D FOO forms, FOO=val, ignoring non-define flags (-I/-O/-W),
quoted values, and empty input.
"""
import ast
import os
import textwrap

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _load_func(name):
    with open(os.path.join(REPO_ROOT, "builder", "main.py"), encoding="utf-8") as fh:
        src = fh.read()
    for node in ast.parse(src).body:
        if isinstance(node, ast.FunctionDef) and node.name == name:
            namespace = {}
            exec(textwrap.dedent(ast.get_source_segment(src, node)), namespace)
            return namespace[name]
    raise AssertionError(f"{name} not found in builder/main.py")


_parse = _load_func("_parse_build_defines")


def test_basic_attached_form():
    assert _parse("-DDEBUG -DFOO=1") == ["DEBUG", "FOO=1"]


def test_spaced_form():
    assert _parse("-D BAR -D BAZ=2") == ["BAR", "BAZ=2"]


def test_ignores_non_define_flags():
    assert _parse("-O2 -Wall -DFOO -I/some/inc -DBAR") == ["FOO", "BAR"]


def test_quoted_value_unwrapped_by_shlex():
    assert _parse('-DVERSION="1.0"') == ["VERSION=1.0"]


def test_empty_and_blank():
    assert _parse("") == []
    assert _parse("   ") == []
    assert _parse(None) == []


def test_no_defines_present():
    assert _parse("-O2 -Wall -Werror") == []
