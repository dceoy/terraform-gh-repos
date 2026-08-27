#!/usr/bin/env python3
"""Synchronize a Terraform repository inventory with repositories owned on GitHub."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ENTRY_RE = re.compile(r'^  "([^"]+)"\s*=\s*(.*)$')
OWNER_RE = re.compile(r'^github_owner\s*=\s*"([^"]+)"\s*$')
CORE_RESOURCES = [
    ("github_repository", "repo"),
    ("github_repository_vulnerability_alerts", "alerts"),
    ("github_repository_dependabot_security_updates", "dependabot"),
    ("github_workflow_repository_permissions", "actions"),
]


def parse_inventory(path: Path) -> tuple[list[str], str, dict[str, list[str]], list[str]]:
    lines = path.read_text().splitlines()
    owner = next(
        (match.group(1) for line in lines if (match := OWNER_RE.match(line))),
        None,
    )
    if not owner:
        raise SystemExit(f"Could not find github_owner in {path}")

    try:
        start = next(i for i, line in enumerate(lines) if line.strip() == "repositories = {")
    except StopIteration:
        raise SystemExit(f"Could not find repositories map in {path}")

    end = next((i for i in range(start + 1, len(lines)) if lines[i] == "}"), None)
    if end is None:
        raise SystemExit(f"Could not find end of repositories map in {path}")

    entries: dict[str, list[str]] = {}
    current_name: str | None = None
    for line in lines[start + 1 : end]:
        match = ENTRY_RE.match(line)
        if match:
            current_name = match.group(1)
            if current_name in entries:
                raise SystemExit(f"Duplicate repository entry: {current_name}")
            entries[current_name] = [line]
        elif current_name is not None:
            entries[current_name].append(line)
        elif line.strip():
            raise SystemExit(f"Unexpected content before first repository entry: {line}")

    return lines[: start + 1], owner, entries, lines[end:]


def format_inventory(
    prefix: list[str], entries: dict[str, list[str]], suffix: list[str]
) -> str:
    width = max((len(name) for name in entries), default=0)
    body: list[str] = []
    for name in sorted(entries):
        block = entries[name]
        match = ENTRY_RE.match(block[0])
        if not match:
            raise SystemExit(f"Malformed repository entry: {block[0]}")
        body.append(f'  "{name}"{" " * (width - len(name))} = {match.group(2)}')
        body.extend(block[1:])
    return "\n".join([*prefix, *body, *suffix]) + "\n"


def load_tracking(path: Path) -> dict[str, dict[str, object]]:
    if not path.exists():
        return {}
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")
    return data


def write_tracking(path: Path, tracking: dict[str, dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(tracking, indent=2, sort_keys=True) + "\n")


def state_blocks(kind: str, old: str, new: str | None, public: bool) -> str:
    resources = [*CORE_RESOURCES]
    if public:
        resources.append(("github_repository_ruleset", "branch"))

    blocks = []
    for resource_type, resource_name in resources:
        source = f'{resource_type}.{resource_name}["{old}"]'
        if kind == "moved":
            target = f'{resource_type}.{resource_name}["{new}"]'
            blocks.append(f"moved {{\n  from = {source}\n  to   = {target}\n}}")
        else:
            blocks.append(
                "removed {\n"
                f"  from = {source}\n\n"
                "  lifecycle {\n"
                "    destroy = false\n"
                "  }\n"
                "}"
            )
    return "\n\n".join(blocks)


def append_sections(path: Path, header: str, sections: list[str]) -> None:
    if not sections:
        return
    existing = path.read_text().rstrip() if path.exists() else header.rstrip()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(existing + "\n\n" + "\n\n".join(sections) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tfvars", type=Path, required=True)
    parser.add_argument("--repositories-json", type=Path, required=True)
    parser.add_argument("--tracking-file", type=Path, required=True)
    parser.add_argument("--moved-file", type=Path, required=True)
    parser.add_argument("--removed-file", type=Path, required=True)
    args = parser.parse_args()

    prefix, owner, entries, suffix = parse_inventory(args.tfvars)
    repositories = json.loads(args.repositories_json.read_text())
    if not isinstance(repositories, list):
        raise SystemExit("Repository API payload must be a JSON array")

    repos = [
        repo
        for repo in repositories
        if repo.get("owner", {}).get("login") == owner and "id" in repo
    ]
    if not repos:
        raise SystemExit(f"No repositories owned by {owner} were returned")
    by_id = {str(repo["id"]): repo for repo in repos}
    by_name = {repo["name"]: repo for repo in repos}

    tracking = load_tracking(args.tracking_file)
    if not tracking:
        missing = sorted(set(entries) - set(by_name))
        if missing:
            raise SystemExit(
                "Cannot initialize repository IDs because inventory names are missing "
                "from the API response: " + ", ".join(missing)
            )
        tracking = {
            str(by_name[name]["id"]): {
                "archived": False,
                "name": name,
                "visibility": by_name[name].get("visibility", "public"),
            }
            for name in entries
        }

    missing_ids = sorted(set(tracking) - set(by_id))
    if missing_ids:
        names = [str(tracking[repo_id].get("name", repo_id)) for repo_id in missing_ids]
        raise SystemExit(
            "Refusing to modify repositories missing from the API response: "
            + ", ".join(names)
        )

    moved_sections: list[str] = []
    removed_sections: list[str] = []
    renames: list[str] = []
    retirements: list[str] = []

    for repo_id, tracked in list(tracking.items()):
        repo = by_id[repo_id]
        old = str(tracked["name"])
        new = repo["name"]
        was_archived = bool(tracked.get("archived", False))
        now_archived = bool(repo.get("archived", False))
        old_public = tracked.get("visibility", repo.get("visibility")) == "public"
        new_public = repo.get("visibility") == "public"

        if was_archived:
            if not now_archived:
                raise SystemExit(
                    f"Previously retired repository {new} became active; restore its "
                    "inventory settings manually before removing its removed blocks"
                )
            tracking[repo_id] = {
                "archived": True,
                "name": new,
                "visibility": repo.get("visibility", "public"),
            }
            continue

        if old not in entries:
            raise SystemExit(f"Tracked active repository is missing from inventory: {old}")

        if now_archived:
            entries.pop(old)
            removed_sections.append(
                f"# BEGIN archived repository: {old}\n"
                + state_blocks("removed", old, None, old_public)
                + f"\n# END archived repository: {old}"
            )
            retirements.append(old)
            tracking[repo_id] = {
                "archived": True,
                "name": new,
                "visibility": repo.get("visibility", "public"),
            }
            continue

        if old != new:
            if new in entries:
                raise SystemExit(f"Repository rename target already exists in inventory: {new}")
            if old_public != new_public:
                raise SystemExit(
                    f"Repository {old} was renamed to {new} while visibility changed; "
                    "handle that transition manually"
                )
            entries[new] = entries.pop(old)
            moved_sections.append(
                f"# BEGIN repository rename: {repo_id}: {old} -> {new}\n"
                + state_blocks("moved", old, new, old_public)
                + f"\n# END repository rename: {repo_id}: {old} -> {new}"
            )
            renames.append(f"{old} -> {new}")

        tracking[repo_id] = {
            "archived": False,
            "name": new,
            "visibility": repo.get("visibility", "public"),
        }

    tracked_active_names = {
        str(item["name"])
        for item in tracking.values()
        if not bool(item.get("archived", False))
    }
    untracked_inventory = sorted(set(entries) - tracked_active_names)
    for name in untracked_inventory:
        repo = by_name.get(name)
        if not repo or repo.get("archived", False):
            raise SystemExit(f"Untracked inventory repository is not active on GitHub: {name}")
        tracking[str(repo["id"])] = {
            "archived": False,
            "name": name,
            "visibility": repo.get("visibility", "public"),
        }

    tracked_ids = set(tracking)
    additions = sorted(
        repo["name"]
        for repo_id, repo in by_id.items()
        if repo_id not in tracked_ids and not repo.get("archived", False)
    )
    for name in additions:
        repo = by_name[name]
        entries[name] = [f'  "{name}" = {{}}']
        tracking[str(repo["id"])] = {
            "archived": False,
            "name": name,
            "visibility": repo.get("visibility", "public"),
        }

    args.tfvars.write_text(format_inventory(prefix, entries, suffix))
    write_tracking(args.tracking_file, tracking)
    append_sections(
        args.moved_file,
        "# Generated by .github/scripts/sync-repositories.py.\n"
        "# Repository renames keep Terraform state attached to the same GitHub repository.",
        moved_sections,
    )
    append_sections(
        args.removed_file,
        "# Generated by .github/scripts/sync-repositories.py.\n"
        "# Archived repositories are forgotten from Terraform state without modifying GitHub.",
        removed_sections,
    )

    print(f"Added: {', '.join(additions) if additions else 'none'}")
    print(f"Renamed: {', '.join(renames) if renames else 'none'}")
    print(f"Archived: {', '.join(retirements) if retirements else 'none'}")


if __name__ == "__main__":
    main()
