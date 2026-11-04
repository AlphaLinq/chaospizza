#!/usr/bin/env python3
"""Labelek, mérföldkövek és issue-k létrehozása a GitHub-repóban a `gh` CLI-vel.

Használat:
    python3 tools/create_backlog.py --repo OWNER/REPO            # létrehozás
    python3 tools/create_backlog.py --repo OWNER/REPO --dry-run  # csak kiírja
    python3 tools/create_backlog.py --markdown docs/BACKLOG.md   # áttekintő generálása

Többször is futtatható: a meglévő labeleket/mérföldköveket/issue-kat (azonos cím) kihagyja.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from backlog import ISSUES, LABELS, MILESTONES  # noqa: E402


def gh(*args, input_=None):
    r = subprocess.run(["gh", *args], input=input_, text=True, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:3])}… hiba: {r.stderr.strip()}")
    return r.stdout


def write_markdown(path):
    lines = ["# Pizza Chaos 2.0 — Backlog", "",
             "Generálva a `tools/backlog.py`-ból. A GitHub issue-k az irányadók.", ""]
    for name, desc in MILESTONES:
        items = [i for i in ISSUES if i["milestone"] == name]
        lines += [f"## {name}", "", desc, "", "| # | Ticket | Labelek |", "|---|---|---|"]
        for n, i in enumerate(items, 1):
            lines.append(f"| {n} | {i['title']} | {', '.join(i['labels'])} |")
        lines.append("")
    lines.append(f"**Összesen:** {len(ISSUES)} ticket, {len(MILESTONES)} mérföldkő.")
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Írva: {path}")


def create(repo, dry):
    if dry:
        for i in ISSUES:
            print(f"[{i['milestone']}] {i['title']}  {i['labels']}")
        print(f"\n{len(LABELS)} label, {len(MILESTONES)} mérföldkő, {len(ISSUES)} issue")
        return

    existing_labels = {l["name"] for l in json.loads(gh("label", "list", "-R", repo, "--limit", "200", "--json", "name"))}
    for name, (color, desc) in LABELS.items():
        if name not in existing_labels:
            gh("label", "create", name, "-R", repo, "--color", color, "--description", desc)
            print(f"label: {name}")

    existing_ms = {m["title"] for m in json.loads(gh("api", f"repos/{repo}/milestones?state=all&per_page=100"))}
    for title, desc in MILESTONES:
        if title not in existing_ms:
            gh("api", f"repos/{repo}/milestones", "-f", f"title={title}", "-f", f"description={desc}")
            print(f"milestone: {title}")

    existing_issues = {i["title"] for i in json.loads(
        gh("issue", "list", "-R", repo, "--state", "all", "--limit", "500", "--json", "title"))}
    for i in ISSUES:
        if i["title"] in existing_issues:
            print(f"kihagyva (már van): {i['title']}")
            continue
        args = ["issue", "create", "-R", repo, "--title", i["title"], "--body-file", "-",
                "--milestone", i["milestone"]]
        for l in i["labels"]:
            args += ["--label", l]
        url = gh(*args, input_=i["body"]).strip()
        print(f"issue: {url}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--repo")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--markdown")
    a = p.parse_args()
    if a.markdown:
        write_markdown(a.markdown)
    if a.repo or a.dry_run:
        create(a.repo, a.dry_run)
