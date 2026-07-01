#!/usr/bin/env python3
"""Add deterministic jitter to all volsync ReplicationSource schedules.

Computes VOLSYNC_SCHEDULE = "MM H * * *" where:
  - total_minutes = md5(app_name) % 240  (spanning 4 hours: 00:00–03:59)
  - H = total_minutes // 60, MM = total_minutes % 60

This spreads backups across 4 hours so they don't all hit MinIO at midnight.

Idempotent — safe to run multiple times.
"""

import hashlib
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def compute_schedule(app_name: str) -> tuple[int, int]:
    """Deterministic (hour, minute) from app name, spanning 00:00–03:59."""
    digest = hashlib.md5(app_name.encode()).hexdigest()
    total_minutes = int(digest[:8], 16) % 240  # 0–239 across 4 hours
    return (total_minutes // 60, total_minutes % 60)


def process_file(filepath: Path) -> bool:
    """Process a ks.yaml file, adding/updating VOLSYNC_SCHEDULE for each
    Kustomization that has APP: and the volsync component.

    Returns True if any changes were made.
    """
    content = filepath.read_text()
    lines = content.split("\n")
    new_lines = []
    changes = 0
    skip_next = False

    i = 0
    while i < len(lines):
        line = lines[i]

        if skip_next:
            # This line is an old VOLSYNC_SCHEDULE that we've already replaced
            skip_next = False
            i += 1
            continue

        # Match lines like: "      APP: some-app-name"
        app_match = re.match(r"^(\s*)APP:\s*(\S+)", line)

        if app_match:
            indent = app_match.group(1)
            app_name = app_match.group(2)
            hour, minute = compute_schedule(app_name)
            schedule = f"{minute:02d} {hour} * * *"
            sched_line = f'{indent}VOLSYNC_SCHEDULE: "{schedule}"'

            # Check if the next line is already VOLSYNC_SCHEDULE
            sched_match = None
            if i + 1 < len(lines):
                sched_match = re.match(
                    r'^(\s*)VOLSYNC_SCHEDULE:\s*"([^"]+)"', lines[i + 1]
                )

            if sched_match:
                if sched_match.group(2) != schedule:
                    # Update existing schedule
                    new_lines.append(line)
                    new_lines.append(sched_line)
                    changes += 1
                    print(
                        f"  {filepath.relative_to(REPO_ROOT)}:"
                        f" {app_name} {sched_match.group(2)} → {schedule}"
                    )
                else:
                    # Already correct — keep as-is
                    new_lines.append(line)
                    new_lines.append(lines[i + 1])
                # Skip the old VOLSYNC_SCHEDULE line next iteration
                skip_next = True
            else:
                # No existing VOLSYNC_SCHEDULE, add it
                new_lines.append(line)
                new_lines.append(sched_line)
                changes += 1
                print(
                    f"  {filepath.relative_to(REPO_ROOT)}:"
                    f" {app_name} → {schedule}"
                )
        else:
            new_lines.append(line)

        i += 1

    if changes:
        filepath.write_text("\n".join(new_lines) + "\n")
        return True
    return False


def main():
    ks_files = sorted(REPO_ROOT.glob("kubernetes/apps/**/ks.yaml"))

    total = 0
    for f in ks_files:
        content = f.read_text()
        if "volsync" in content:
            if process_file(f):
                total += 1

    print(f"\nUpdated {total} file(s)")


if __name__ == "__main__":
    main()
