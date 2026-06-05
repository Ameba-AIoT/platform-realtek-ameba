"""tests/unit/test_uploadfs_argv.py  (U02)

Verifies _ameba_py_args() builds the right `ameba.py` argv — in particular
that an ``image`` triple list expands into repeated ``-i NAME START END``
groups (the shape `uploadfs` and multi-image `upload` depend on), and that
boolean / None upload options are handled correctly.

builder/main.py executes a lot at module top (it expects a live SCons env),
so we don't import it. We extract just the target function via AST and exec
it in an isolated namespace with its module-level globals stubbed — the same
isolation approach used by test_erase_fail.py (U01).
"""
import ast
import os
import textwrap

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _load_func(name, extra_globals):
    """Extract a single top-level function from builder/main.py and exec it
    in isolation, returning the callable."""
    with open(os.path.join(REPO_ROOT, "builder", "main.py"), encoding="utf-8") as fh:
        src = fh.read()
    tree = ast.parse(src)
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == name:
            fn_src = textwrap.dedent(ast.get_source_segment(src, node))
            namespace = dict(extra_globals)
            exec(fn_src, namespace)
            return namespace[name]
    raise AssertionError(f"{name} not found in builder/main.py")


def _ameba_py_args():
    """Load _ameba_py_args with its module globals stubbed."""
    return _load_func(
        "_ameba_py_args",
        {
            "SOC": "RTL8721Dx",
            "SDK_DIR": os.path.join(os.sep, "fake", "sdk"),
            "join": os.path.join,
            "_ameba_python": lambda: "python3",
        },
    )


def test_image_triples_become_repeated_i_groups():
    """Each [name, start, end] triple -> its own `-i name start end`."""
    fn = _ameba_py_args()
    cmds = fn(
        "flash",
        upload_opts={
            "image": [
                ["km0_image2", "0x08006000", "0x08008000"],
                ["km4_image2", "0x08008000", "0x0800a000"],
            ]
        },
    )
    assert len(cmds) == 1
    argv = cmds[0]
    assert argv.count("-i") == 2, f"expected two -i groups, got argv: {argv}"
    first = argv.index("-i")
    assert argv[first : first + 4] == [
        "-i",
        "km0_image2",
        "0x08006000",
        "0x08008000",
    ]


def test_bool_and_none_opts():
    """True -> bare flag; None/False -> dropped; value -> `--opt value`."""
    fn = _ameba_py_args()
    argv = fn(
        "flash",
        upload_opts={"chip_erase": True, "port": None, "baud": 1500000},
    )[0]
    assert "--chip-erase" in argv          # True -> flag only
    idx = argv.index("--chip-erase")
    assert idx == len(argv) - 1 or argv[idx + 1].startswith("--"), (
        "a bare flag must not be followed by a value"
    )
    assert "--port" not in argv             # None -> dropped entirely
    assert "--baud" in argv and "1500000" in argv  # value passed through


def test_underscores_become_dashes():
    """opt keys use snake_case in Python but --kebab-case on the CLI."""
    fn = _ameba_py_args()
    argv = fn("flash", upload_opts={"memory_type": "nor"})[0]
    assert "--memory-type" in argv
    assert "nor" in argv


def test_build_argv_is_positional_soc():
    """`build` passes the SoC positionally, no opts."""
    fn = _ameba_py_args()
    cmds = fn("build")
    assert cmds == [
        [
            "python3",
            os.path.join(os.sep, "fake", "sdk", "ameba.py"),
            "build",
            "RTL8721Dx",
        ]
    ]


def test_clean_flag():
    """build with clean=True appends -c."""
    fn = _ameba_py_args()
    argv = fn("build", clean=True)[0]
    assert argv[-1] == "-c"
