"""Build reproducible, unpublished Studio scheduling fixtures (#172, #286).

Production source files remain unchanged. Only cloned timing/enable config
is overridden in the generated Rojo project; the actual event code is used.
"""

import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--combo", choices=["bubbles-tornado", "blackout-horses"])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output == root or root in output.parents:
        parser.error("Fixture output must be outside the repository; production config must stay untouched.")
    output.mkdir(parents=True, exist_ok=True)
    project = json.loads((root / "default.project.json").read_text())

    def absolute_paths(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key == "$path":
                    value[key] = str(root / child)
                else:
                    absolute_paths(child)

    absolute_paths(project)
    # An explicit child beside an implicit $path can create same-named folders.
    # Enumerate this boundary so there is exactly one Config and one Tuning.
    shared = {"$className": "Folder"}
    for source in sorted((root / "src/shared").iterdir()):
        name = source.stem if source.is_file() else source.name
        shared[name] = {"$path": str(source)}
    project["tree"]["ReplicatedStorage"]["Shared"] = shared
    config = {"$className": "Folder"}
    for source in sorted((root / "src/shared/Config").glob("*.luau")):
        config[source.stem] = {"$path": str(source)}
    shared["Config"] = config
    config["PerfProductionTuning"] = {"$path": str(root / "src/shared/Config/Tuning.luau")}
    tuning = output / "Tuning.luau"
    tuning.write_text('''--!strict
local production = require(script.Parent.PerfProductionTuning)
local result = table.clone(production)
local events = table.clone(production.Events)
-- Two consecutive 30-second captures with time for quality switching.
events.activeMinSeconds, events.activeMaxSeconds = 90, 90
result.Events = table.freeze(events)
return table.freeze(result)
''')
    config["Tuning"] = {"$path": str(tuning)}
    if args.combo:
        pair = ["BubbleStorm", "Tornado"] if args.combo == "bubbles-tornado" else ["Blackout", "HorseRace"]
        config["PerfProductionEvents"] = {"$path": str(root / "src/shared/Config/Events.luau")}
        events = output / "Events.luau"
        allowed = ", ".join(f'["{event}"] = true' for event in pair)
        events.write_text('''--!strict
local production = require(script.Parent.PerfProductionEvents)
local allowed: { [string]: boolean } = { ''' + allowed + ''' }
local result = {}
for _, event in production do
    local copy = table.clone(event)
    copy.enabled = allowed[event.id] == true
    table.insert(result, table.freeze(copy))
end
return table.freeze(result)
''')
        config["Events"] = {"$path": str(events)}
    project["name"] = "PizzaPerfFixture"
    path = output / "fixture.project.json"
    path.write_text(json.dumps(project, indent=2) + "\n")
    print(path)


if __name__ == "__main__":
    main()
