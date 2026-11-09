#!/usr/bin/env python3
"""Compare an existing Studio's read-only script inventory with a Rojo build."""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOTS = [
    ["ReplicatedStorage", "Shared"],
    ["ServerScriptService", "Server"],
    ["StarterPlayer", "StarterPlayerScripts", "Client"],
]
CLASSES = {"Script", "LocalScript", "ModuleScript"}
ALGORITHM = "djb2-utf8-32"


def digest(source: str) -> tuple[int, int]:
    data = source.encode("utf-8")
    value = 5381
    for byte in data:
        value = (value * 33 + byte) % 2**32
    return value, len(data)


def manifest(build: Path) -> dict:
    scripts = []

    def walk(item: ET.Element, parent: list[str]) -> None:
        properties = item.find("Properties")
        name = None if properties is None else properties.find("*[@name='Name']")
        if name is None or name.text is None:
            raise ValueError("Build contains an Item without a Name property")
        path = parent + [name.text]
        class_name = item.attrib.get("class")
        if class_name in CLASSES:
            source = properties.find("*[@name='Source']")
            if source is None:
                raise ValueError(f"Missing Source property: {path}")
            if not any(path[:len(root)] == root for root in ROOTS):
                raise ValueError(f"Script outside this project's managed roots: {path}")
            value, length = digest(source.text or "")
            scripts.append(dict(path=path, className=class_name, hash=value, length=length))
        for child in item.findall("Item"):
            walk(child, path)

    for item in ET.parse(build).getroot().findall("Item"):
        walk(item, [])
    if not scripts:
        raise ValueError("Build contains no managed scripts")
    scripts.sort(key=lambda row: row["path"])
    result = dict(schema=1, algorithm=ALGORITHM, roots=ROOTS, scripts=scripts)
    validate(result, unique=True)
    return result


def validate(data: dict, *, unique: bool = False) -> None:
    if not isinstance(data, dict) or data.get("schema") != 1 or data.get("algorithm") != ALGORITHM:
        raise ValueError("Expected a schema 1 djb2-utf8-32 inventory")
    if data.get("roots") != ROOTS or not isinstance(data.get("scripts"), list):
        raise ValueError("Inventory roots do not match this project's managed roots")
    seen = set()
    for row in data["scripts"]:
        if not isinstance(row, dict) or set(row) != {"path", "className", "hash", "length"}:
            raise ValueError("Invalid script metadata")
        path = row.get("path")
        if not isinstance(path, list) or not path or not all(isinstance(x, str) and x for x in path):
            raise ValueError("Script paths must be nonempty arrays of names")
        if not any(path[:len(root)] == root for root in ROOTS):
            raise ValueError("Script outside managed roots in inventory")
        if row.get("className") not in CLASSES:
            raise ValueError(f"Invalid script class: {path}")
        if type(row.get("hash")) is not int or not 0 <= row["hash"] < 2**32:
            raise ValueError(f"Invalid script hash: {path}")
        if type(row.get("length")) is not int or row["length"] < 0:
            raise ValueError(f"Invalid byte length: {path}")
        key = tuple(path)
        if unique and key in seen:
            raise ValueError(f"Duplicate path in expected build: {path}")
        seen.add(key)


def snippet(expected: dict) -> str:
    # Encode only root names. No game source, file paths or executable content
    # from the build is injected into the inspector.
    roots = json.dumps(json.dumps(expected["roots"], ensure_ascii=True))
    return '''-- Generated read-only inventory. Use the existing Studio, Edit mode.
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play and run the source audit in Edit mode")
local HttpService = game:GetService("HttpService")
local roots = HttpService:JSONDecode(ROOTS_JSON)
local scripts = {}
local visited = 0
local function inspect(object, path)
    visited += 1
    if visited % 32 == 0 then task.wait() end
    if object:IsA("LuaSourceContainer") then
        local source, hash = object.Source, 5381
        for i = 1, #source do
            hash = (hash * 33 + string.byte(source, i)) % 4294967296
            if i % 32768 == 0 then task.wait() end
        end
        table.insert(scripts, {path=path, className=object.ClassName, hash=hash, length=#source})
    end
    for _, child in object:GetChildren() do
        local nextPath = table.clone(path)
        table.insert(nextPath, child.Name)
        inspect(child, nextPath)
    end
end
for _, path in roots do
    local matches = {game}
    for _, name in path do
        local nextMatches = {}
        for _, parent in matches do
            for _, child in parent:GetChildren() do
                if child.Name == name then table.insert(nextMatches, child) end
            end
        end
        matches = nextMatches
    end
    -- Traverse every match, including duplicate folders with the same name.
    for _, object in matches do inspect(object, table.clone(path)) end
end
return HttpService:JSONEncode({schema=1, algorithm="djb2-utf8-32", roots=roots, scripts=scripts})
'''.replace("ROOTS_JSON", roots)


def compare(expected: dict, actual: dict) -> dict:
    validate(expected, unique=True)
    validate(actual)
    wanted = {tuple(row["path"]): row for row in expected["scripts"]}
    found = defaultdict(list)
    for row in actual["scripts"]:
        found[tuple(row["path"])].append(row)
    missing, changed, extra, duplicates = [], [], [], []
    matched = 0
    for path in sorted(set(wanted) | set(found)):
        rows = found[path]
        if len(rows) > 1:
            duplicates.append(dict(path=list(path), instances=len(rows)))
        if path not in wanted:
            extra.extend(sorted(rows, key=lambda row: (row["className"], row["hash"], row["length"])))
        elif not rows:
            missing.append(wanted[path])
        elif len(rows) == 1:
            keys = ("className", "hash", "length")
            if all(wanted[path][key] == rows[0][key] for key in keys):
                matched += 1
            else:
                changed.append(dict(path=list(path), expected=wanted[path], actual=rows[0]))
    return dict(ok=not (missing or changed or extra or duplicates), matched=matched,
                missing=missing, changed=changed, extra=extra, duplicates=duplicates)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    prepare = commands.add_parser("prepare", help="Read a Rojo build; emit manifest and read-only Edit snippet")
    prepare.add_argument("build", type=Path)
    prepare.add_argument("--manifest", type=Path, required=True)
    prepare.add_argument("--script", type=Path, required=True)
    check = commands.add_parser("compare", help="Compare a saved Studio JSON inventory against the manifest")
    check.add_argument("manifest", type=Path)
    check.add_argument("snapshot", type=Path)
    check.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            if len({args.build.resolve(), args.manifest.resolve(), args.script.resolve()}) != 3:
                raise ValueError("Build, manifest and inspector paths must be distinct")
            expected = manifest(args.build)
            args.manifest.write_text(json.dumps(expected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            args.script.write_text(snippet(expected), encoding="utf-8")
            print(f"Prepared read-only audit for {len(expected['scripts'])} scripts")
            return 0
        result = compare(json.loads(args.manifest.read_text(encoding="utf-8")),
                         json.loads(args.snapshot.read_text(encoding="utf-8")))
    except (ValueError, OSError, ET.ParseError) as error:
        print(f"Source audit: {error}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"Studio source audit: {result['matched']} matched; " + "; ".join(
            f"{len(result[key])} {key}" for key in ("missing", "changed", "extra", "duplicates")))
        for category in ("missing", "changed", "extra", "duplicates"):
            for row in result[category]:
                print(f"  {category}: {'/'.join(row['path'])}")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
