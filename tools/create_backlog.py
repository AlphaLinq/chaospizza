#!/usr/bin/env python3
"""Labelek, mérföldkövek és issue-k létrehozása a GitHub-repóban a `gh` CLI-vel.

Használat:
    python3 tools/create_backlog.py --repo OWNER/REPO            # létrehozás + állapot
    python3 tools/create_backlog.py --repo OWNER/REPO --dry-run  # csak kiírja
    python3 tools/create_backlog.py --markdown docs/BACKLOG.md   # áttekintő generálása

Többször is futtatható: a meglévő labeleket/mérföldköveket/issue-kat (azonos cím) kihagyja.
Az állapotot (kész → lezárva + komment, részleges → komment) a tools/backlog_status.py adja;
a kommentet és a lezárást csak az újonnan létrehozott issue-knál végzi el.
"""
import argparse
import json
import subprocess
import time
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from backlog import ISSUES, LABELS, MILESTONES  # noqa: E402
from backlog_status import NEW_ISSUES, OWNER_LABELS, STATUS  # noqa: E402

STATE_TEXT = {"done": "✅ Kész", "partial": "🟡 Részben kész", "open": "⬜ Nyitott"}


def all_issues():
    """(issue, status, owner, note) a régi 60 + az új ticketekhez."""
    out = []
    for n, i in enumerate(ISSUES, 1):
        status, owner, note = STATUS.get(n, ("open", None, None))
        labels = list(i["labels"]) + ([f"owner:{owner}"] if owner else [])
        out.append(({**i, "labels": labels}, status, owner, note))
    for i in NEW_ISSUES:
        owner = next((l.split(":", 1)[1] for l in i["labels"] if l.startswith("owner:")), None)
        out.append((i, "open", owner, None))
    return out


def gh(*args, input_=None):
    r = subprocess.run(["gh", *args], input=input_, text=True, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:3])}… hiba: {r.stderr.strip()}")
    return r.stdout


def write_markdown(path):
    lines = ["# Pizza Chaos 2.0 — Backlog", "",
             "Generálva a `tools/backlog.py` + `tools/backlog_status.py` fájlokból. A GitHub issue-k az irányadók.", ""]
    items_all = all_issues()
    for name, desc in MILESTONES:
        items = [x for x in items_all if x[0]["milestone"] == name]
        lines += [f"## {name}", "", desc, "", "| Ticket | Állapot | Felelős |", "|---|---|---|"]
        for i, status, owner, _ in items:
            lines.append(f"| {i['title']} | {STATE_TEXT[status]} | {owner or '-'} |")
        lines.append("")
    done = sum(1 for x in items_all if x[1] == "done")
    lines.append(f"**Összesen:** {len(items_all)} ticket ({done} kész), {len(MILESTONES)} mérföldkő.")
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Írva: {path}")


def create(repo, dry):
    items = all_issues()
    labels = {**LABELS, **OWNER_LABELS}
    if dry:
        for i, status, owner, _ in items:
            print(f"[{i['milestone'][:2]}] {status:7} {owner or '-':6} {i['title']}")
        print(f"\n{len(labels)} label, {len(MILESTONES)} mérföldkő, {len(items)} issue")
        return

    # REST only (works where GraphQL is unavailable, e.g. Claude Code sessions).
    def api(method, path, payload=None):
        args = ["api", "-X", method, path]
        if payload is not None:
            args += ["--input", "-"]
        out = gh(*args, input_=json.dumps(payload) if payload is not None else None)
        return json.loads(out) if out.strip() else None

    def paged(path):
        items, page = [], 1
        while True:
            sep = "&" if "?" in path else "?"
            batch = api("GET", f"{path}{sep}per_page=100&page={page}")
            items += batch
            if len(batch) < 100:
                return items
            page += 1

    existing_labels = {l["name"] for l in paged(f"repos/{repo}/labels")}
    for name, (color, desc) in labels.items():
        if name not in existing_labels:
            api("POST", f"repos/{repo}/labels", {"name": name, "color": color, "description": desc})
            print(f"label: {name}")

    milestones = {m["title"]: m["number"] for m in paged(f"repos/{repo}/milestones?state=all")}
    for title, desc in MILESTONES:
        if title not in milestones:
            m = api("POST", f"repos/{repo}/milestones", {"title": title, "description": desc})
            milestones[title] = m["number"]
            print(f"milestone: {title}")

    existing_issues = {i["title"] for i in paged(f"repos/{repo}/issues?state=all") if "pull_request" not in i}
    for i, status, _owner, note in items:
        if i["title"] in existing_issues:
            print(f"kihagyva (már van): {i['title']}")
            continue
        created = api("POST", f"repos/{repo}/issues", {
            "title": i["title"], "body": i["body"],
            "milestone": milestones[i["milestone"]], "labels": i["labels"]})
        number = created["number"]
        print(f"issue #{number}: {i['title']}")
        if note:
            api("POST", f"repos/{repo}/issues/{number}/comments",
                {"body": f"**Állapot:** {STATE_TEXT[status]}\n\n{note}"})
        if status == "done":
            api("PATCH", f"repos/{repo}/issues/{number}", {"state": "closed", "state_reason": "completed"})
        time.sleep(1)  # stay under GitHub's secondary rate limit for content creation


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
