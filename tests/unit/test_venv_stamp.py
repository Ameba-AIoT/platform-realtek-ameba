"""tests/unit/test_venv_stamp.py  (U05)

_setup_sdk_venv() keeps the SDK's Python venv in sync with
tools/requirements.txt using a SHA-256 stamp: if the stamp matches the
current requirements hash it skips pip entirely; if it differs (or is
missing) it runs `pip install --upgrade`. This pins that idempotency so a
no-op `pio run` doesn't reinstall, and a changed requirements.txt does.

_setup_sdk_venv lives inside the PlatformBase subclass and platform.py's
module top imports `platformio` (absent in unit CI). So we don't import the
module — we AST-extract just this method and exec it with os/subprocess/...
stubbed (subprocess.check_call is mocked so nothing is actually installed).
"""
import ast
import hashlib
import os
import shutil
import subprocess
import sys
import textwrap
from unittest.mock import MagicMock

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _load_setup_venv(subprocess_mock):
    src = open(os.path.join(REPO_ROOT, "platform.py"), encoding="utf-8").read()
    for node in ast.walk(ast.parse(src)):  # walk: the method is inside a class
        if isinstance(node, ast.FunctionDef) and node.name == "_setup_sdk_venv":
            fn_src = textwrap.dedent(ast.get_source_segment(src, node))
            namespace = {
                "os": os,
                "sys": sys,
                "subprocess": subprocess_mock,
                "shutil": shutil,
                "IS_WINDOWS": False,
            }
            exec(fn_src, namespace)
            return namespace["_setup_sdk_venv"]
    raise AssertionError("_setup_sdk_venv not found in platform.py")


def _mock_subprocess():
    """A mock subprocess whose check_call is a spy but whose
    CalledProcessError / DEVNULL stay real (the method references both)."""
    sub = MagicMock()
    sub.CalledProcessError = subprocess.CalledProcessError
    sub.DEVNULL = subprocess.DEVNULL
    return sub


def _sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def _make_sdk(tmp_path, reqs="json5\npyelftools\n", venv_python=True, stamp=None):
    """Lay out a fake SDK dir: tools/requirements.txt, optional .venv python,
    optional stamp file. Returns the sdk dir path (str)."""
    (tmp_path / "tools").mkdir(parents=True, exist_ok=True)
    # write_bytes (not write_text): on Windows write_text translates \n -> \r\n,
    # which would change the file's sha256 vs _sha(reqs) and break the stamp
    # comparison. The real requirements.txt and its stamp hash the same bytes,
    # so this just keeps the fixture faithful cross-platform.
    (tmp_path / "tools" / "requirements.txt").write_bytes(reqs.encode())
    if venv_python:
        bindir = tmp_path / ".venv" / "bin"
        bindir.mkdir(parents=True, exist_ok=True)
        (bindir / "python3").write_text("")
    if stamp is not None:
        (tmp_path / ".venv").mkdir(parents=True, exist_ok=True)
        (tmp_path / ".venv" / ".pio_requirements_sha256").write_text(stamp)
    return str(tmp_path)


def test_stamp_match_skips_install(tmp_path):
    reqs = "json5\npyelftools\n"
    sdk = _make_sdk(tmp_path, reqs=reqs, venv_python=True, stamp=_sha(reqs))
    sub = _mock_subprocess()

    _load_setup_venv(sub)(MagicMock(), sdk)

    sub.check_call.assert_not_called()  # hash matches -> no pip


def test_stamp_mismatch_runs_install(tmp_path):
    reqs = "json5\npyelftools\n"
    sdk = _make_sdk(tmp_path, reqs=reqs, venv_python=True, stamp="deadbeef")
    sub = _mock_subprocess()

    _load_setup_venv(sub)(MagicMock(), sdk)

    sub.check_call.assert_called()
    # one of the calls must be a `pip install ... --upgrade -r requirements.txt`
    assert any(
        "install" in " ".join(map(str, c.args[0])) and "--upgrade" in c.args[0]
        for c in sub.check_call.call_args_list
    ), f"expected a pip --upgrade install; calls were {sub.check_call.call_args_list}"


def test_missing_stamp_runs_install(tmp_path):
    sdk = _make_sdk(tmp_path, venv_python=True, stamp=None)
    sub = _mock_subprocess()

    _load_setup_venv(sub)(MagicMock(), sdk)

    sub.check_call.assert_called()


def test_no_requirements_is_noop(tmp_path):
    # SDK dir with a .venv but no tools/requirements.txt
    (tmp_path / ".venv" / "bin").mkdir(parents=True)
    (tmp_path / ".venv" / "bin" / "python3").write_text("")
    sub = _mock_subprocess()

    _load_setup_venv(sub)(MagicMock(), str(tmp_path))

    sub.check_call.assert_not_called()
