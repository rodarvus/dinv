#!/usr/bin/env python3
"""
build.py - Builds dinv_single.xml by embedding all Lua modules into the XML script block.

Usage:
    python3 build.py

Output:
    dinv_single.xml  (same directory as this script)

The single-file XML can be installed by dropping it alone into the MUSHclient
plugin directory - no separate .lua files needed.

Output is always LF line endings, iso-8859-1 encoded, with Unicode comment
characters replaced by ASCII equivalents and XML 1.0 forbidden control
characters stripped.
"""

import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


ENCODING = "iso-8859-1"

# Unicode characters found in comments - not valid in iso-8859-1 XML 1.0
UNICODE_REPLACEMENTS = [
    ("→", "->"),   # right arrow
    ("↔", "<->"),  # left-right arrow
    ("—", "--"),   # em dash
    ("–", "-"),    # en dash
    ("‘", "'"),    # left single quote
    ("’", "'"),    # right single quote
    ("“", '"'),    # left double quote
    ("”", '"'),    # right double quote
    ("…", "..."),  # ellipsis
]

# XML 1.0 forbidden control characters (everything below 0x20 except tab, LF, CR)
XML_FORBIDDEN = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")

DOFILE_PATTERN = re.compile(
    r'^dofile\(dinv_plugin_dir \.\. "([^"]+\.lua)"\)\n',
    re.MULTILINE,
)

FIRST_SCRIPT_PATTERN = re.compile(
    r"<script>\s*<!\[CDATA\[.*?\]\]>\s*</script>",
    re.DOTALL,
)


def read_file(path, error_if_contains_cdata=True):
    """Read a file and return a clean, normalized string ready for embedding in XML.

    - Normalizes line endings to LF
    - Replaces known Unicode characters with ASCII equivalents
    - Strips XML 1.0 forbidden control characters (with warnings)
    - Errors on any remaining non-ASCII characters
    """
    fname = os.path.basename(path)

    with open(path, "rb") as f:
        raw = f.read()

    # Normalize line endings to LF
    raw = raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n")

    # Decode - try UTF-8 first (handles Unicode arrows/dashes in comments), fall back to iso-8859-1
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        text = raw.decode(ENCODING)

    # Replace known Unicode characters with ASCII equivalents
    for char, replacement in UNICODE_REPLACEMENTS:
        text = text.replace(char, replacement)

    # Strip XML 1.0 forbidden control characters
    forbidden = XML_FORBIDDEN.findall(text)
    if forbidden:
        counts = {}
        for c in forbidden:
            counts[c] = counts.get(c, 0) + 1
        detail = ", ".join(f"U+{ord(c):04X} x{n}" for c, n in sorted(counts.items()))
        print(f"WARNING [{fname}]: stripped {len(forbidden)} forbidden control char(s): {detail}",
              file=sys.stderr)
        text = XML_FORBIDDEN.sub("", text)

    # Abort on any remaining non-ASCII — they can't be encoded in iso-8859-1.
    non_ascii = [(i, c) for i, c in enumerate(text) if ord(c) > 127]
    if non_ascii:
        print(f"ERROR [{fname}] has {len(non_ascii)} non-ASCII character(s) which cannot be encoded in {ENCODING}:",
              file=sys.stderr)
        for i, c in non_ascii[:10]:
            line = text[:i].count("\n") + 1
            print(f"  {fname} line {line}: U+{ord(c):04X} {repr(c)}", file=sys.stderr)
        if len(non_ascii) > 10:
            print(f"  ... and {len(non_ascii) - 10} more", file=sys.stderr)
        print(f"Teach build.py how to replace this char by adding it to UNICODE_REPLACEMENTS.", file=sys.stderr)
        sys.exit(1)

    if error_if_contains_cdata and "]]>" in text:
        print(f"ERROR [{fname}]: content contains ']]>' which would break a CDATA block.",
              file=sys.stderr)
        sys.exit(1)

    return text


def build():
    xml_path = os.path.join(SCRIPT_DIR, "dinv.xml")
    out_path = os.path.join(SCRIPT_DIR, "dinv_single.xml")

    xml = read_file(xml_path, error_if_contains_cdata=False)

    # Read dinv_init.lua, extract module load order from dofile() calls, then strip them
    init_content = read_file(os.path.join(SCRIPT_DIR, "dinv_init.lua"))
    lua_modules = DOFILE_PATTERN.findall(init_content)
    init_content = DOFILE_PATTERN.sub("", init_content)

    if not lua_modules:
        print("ERROR: No dofile() module calls found in dinv_init.lua", file=sys.stderr)
        sys.exit(1)

    # Assemble all Lua: modified init + each module in the order found in init
    lua_parts = [init_content]
    for module in lua_modules:
        path = os.path.join(SCRIPT_DIR, module)
        if not os.path.exists(path):
            print(f"ERROR: missing module {module}", file=sys.stderr)
            sys.exit(1)
        bar = "=" * 80
        label     = module.center(78)
        end_label = f"end of {module}".center(78)
        lua_parts.append(f"\n\n-- {bar}\n--{label}\n-- {bar}\n\n")
        lua_parts.append(read_file(path))
        lua_parts.append(f"\n\n-- {bar}\n--{end_label}\n-- {bar}\n\n")

    all_lua = "".join(lua_parts)

    new_script = "<script>\n<![CDATA[\n" + all_lua + "]]>\n</script>"

    # Replace the first <script> block with the full embedded Lua
    match = FIRST_SCRIPT_PATTERN.search(xml)
    if not match:
        print("ERROR: Could not find first <script> block in dinv.xml", file=sys.stderr)
        sys.exit(1)
    xml = xml[:match.start()] + new_script + xml[match.end():]

    with open(out_path, "w", encoding=ENCODING, newline="\n") as f:
        f.write(xml)

    lua_lines = all_lua.count("\n")
    print(f"Built {out_path}")
    print(f"  Embedded {len(lua_modules)} modules, {lua_lines:,} Lua lines total")


if __name__ == "__main__":
    build()
