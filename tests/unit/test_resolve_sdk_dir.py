"""tests/unit/test_resolve_sdk_dir.py  (U07)

_find_sdk_dir() resolves which ameba-rtos checkout to build against, in
priority order:
  1. $AMEBA_SDK_DIR (developer override / local fork)
  2. PIO-managed package dir (PioPlatform().get_package_dir(...))
  3. ~/.platformio/packages/framework-ameba-rtos (last-resort default)
A candidate only counts if it's a dir containing ameba.py; otherwise it's
skipped. Nothing found -> FileNotFoundError.

In the unit env `platformio` isn't installed, so the PioPlatform branch
raises ImportError and is skipped (exactly the "outside PIO context" path
the function guards). We drive dir/file existence via injected stubs so the
result doesn't depend on the host's real ~/.platformio.
"""
import ast
import os
import textwrap

import pytest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _load_find_sdk(present):
    """Load _find_sdk_dir with isdir/isfile answering True only for paths in
    `present` (a set of absolute paths, dirs and the ameba.py files)."""
    with open(os.path.join(REPO_ROOT, "builder", "main.py"), encoding="utf-8") as fh:
        src = fh.read()
    for node in ast.parse(src).body:
        if isinstance(node, ast.FunctionDef) and node.name == "_find_sdk_dir":
            namespace = {
                "os": os,
                "isdir": lambda p: p in present,
                "isfile": lambda p: p in present,
                "join": os.path.join,
            }
            exec(textwrap.dedent(ast.get_source_segment(src, node)), namespace)
            return namespace["_find_sdk_dir"]
    raise AssertionError("_find_sdk_dir not found in builder/main.py")


DEFAULT = os.path.expanduser("~/.platformio/packages/framework-ameba-rtos")


def test_env_override_wins(monkeypatch):
    sdk = os.path.join(os.sep, "fork", "ameba-rtos")
    monkeypatch.setenv("AMEBA_SDK_DIR", sdk)
    fn = _load_find_sdk({sdk, os.path.join(sdk, "ameba.py")})
    assert fn() == sdk


def test_env_dir_without_ameba_py_is_skipped(monkeypatch):
    """A set-but-bogus $AMEBA_SDK_DIR (no ameba.py) must not be returned."""
    sdk = os.path.join(os.sep, "fork", "ameba-rtos")
    monkeypatch.setenv("AMEBA_SDK_DIR", sdk)
    # sdk dir "exists" but has no ameba.py; default does have one.
    fn = _load_find_sdk({sdk, DEFAULT, os.path.join(DEFAULT, "ameba.py")})
    assert fn() == DEFAULT


def test_falls_back_to_default(monkeypatch):
    monkeypatch.delenv("AMEBA_SDK_DIR", raising=False)
    fn = _load_find_sdk({DEFAULT, os.path.join(DEFAULT, "ameba.py")})
    assert fn() == DEFAULT


def test_nothing_found_raises(monkeypatch):
    monkeypatch.delenv("AMEBA_SDK_DIR", raising=False)
    fn = _load_find_sdk(set())  # no path exists anywhere
    with pytest.raises(FileNotFoundError):
        fn()
