"""tests/unit/test_upload_endaddr.py  (U03)

The SDK's flash layout reports partition ends INCLUSIVE, but `ameba.py
flash -i` wants an EXCLUSIVE end — so uploadfs passes ``end_addr + 1``
(builder/main.py: upload_fs_image). This pins both halves of that contract:

  * _resolve_vfs_region computes size as an inclusive span (end-start+1)
  * the exclusive end (end_addr+1) minus start equals that size — i.e. an
    image exactly filling the partition is NOT off-by-one rejected.

Same AST-isolation approach as test_erase_fail.py / test_uploadfs_argv.py.
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


def _resolve_vfs_region(layout):
    """Load _resolve_vfs_region with _resolve_default_layout stubbed."""
    return _load_func(
        "_resolve_vfs_region", {"_resolve_default_layout": lambda: layout}
    )


# 8713E VFS1 partition: 0x08703000–0x08722FFF inclusive == 0x20000 (128 KiB).
VFS1 = {
    "type": "VFS1",
    "label": "vfs1",
    "start_addr": 0x08703000,
    "end_addr": 0x08722FFF,
}


def test_size_is_inclusive_span():
    region = _resolve_vfs_region([VFS1])()
    assert region["size"] == 0x08722FFF - 0x08703000 + 1
    assert region["size"] == 0x20000


def test_exclusive_end_preserves_size():
    """uploadfs passes end_addr+1; SDK then derives region = end - start,
    which must equal the inclusive size (no off-by-one)."""
    region = _resolve_vfs_region([VFS1])()
    exclusive_end = region["end_addr"] + 1  # what upload_fs_image emits
    assert exclusive_end - region["start_addr"] == region["size"]


def test_picks_vfs1_among_others():
    layout = [
        {"type": "KM4_IMG2", "label": "img2", "start_addr": 0x0, "end_addr": 0x10},
        VFS1,
        {"type": "FFS", "label": "ffs", "start_addr": 0x9000000, "end_addr": 0x9000010},
    ]
    region = _resolve_vfs_region(layout)()
    assert region["label"] == "vfs1"
    assert region["start_addr"] == 0x08703000


def test_no_vfs1_returns_none():
    layout = [{"type": "KM4_IMG2", "label": "x", "start_addr": 0, "end_addr": 1}]
    assert _resolve_vfs_region(layout)() is None


def test_no_layout_returns_none():
    assert _resolve_vfs_region(None)() is None
