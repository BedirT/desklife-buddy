#!/usr/bin/python3 -I
"""Install reviewed snapshot bytes as a recoverable local transaction."""

from __future__ import annotations

import argparse
import atexit
import hashlib
import json
import os
import pathlib
import re
import secrets
import stat
import subprocess


PACKAGES = {"Features", "DesignSystem"}
MAX_PROPOSAL_BYTES = 2 * 1024 * 1024
MAX_COMPLETION_BYTES = 64 * 1024
MAX_REVIEW_BYTES = 256 * 1024 * 1024
MAX_PNG_BYTES = 32 * 1024 * 1024
MAX_TRANSACTION_BYTES = 256 * 1024 * 1024
PROPOSAL_KEYS = {
    "schemaVersion", "package", "runId", "generated", "head",
    "sourceStateSHA256", "changed", "new", "unmatched",
}
ENTRY_REQUIRED = {
    "suite", "state", "variant", "image", "baselinePath", "candidatePath",
    "baselineSHA256", "candidateSHA256", "visibleFraction", "anyFraction",
    "maxDelta", "resized",
}
ENTRY_OPTIONAL = {"beforeDims", "afterDims"}


def digest(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def lexical_absolute(raw: str) -> pathlib.Path:
    path = pathlib.Path(raw)
    if not path.is_absolute() or ".." in path.parts:
        raise SystemExit(f"Refusing non-canonical reviewed path: {raw}")
    return path.parent.resolve() / path.name


def relative_to(path: pathlib.Path, root: pathlib.Path) -> pathlib.PurePath:
    try:
        return path.relative_to(root)
    except ValueError:
        raise SystemExit(f"Refusing path outside reviewed root: {path}") from None


def is_within(path: pathlib.Path, root: pathlib.Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def current_checkout_state(root: pathlib.Path) -> tuple[str, str]:
    head = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    source_state = subprocess.run(
        [
            "/bin/bash", "-p", "-c",
            '. "$1/scripts/lib.sh"; source_state_hash', "_", str(root),
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    return head, source_state


def open_parent(path: pathlib.Path, root: pathlib.Path) -> tuple[int, str]:
    relative = relative_to(path, root)
    if not relative.parts:
        raise SystemExit(f"Refusing root as a reviewed file: {path}")
    descriptor = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != os.geteuid() \
          or metadata.st_mode & 0o022:
            raise SystemExit(f"Refusing unsafe reviewed root: {root}")
        for component in relative.parts[:-1]:
            next_descriptor = os.open(
                component,
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                dir_fd=descriptor,
            )
            os.close(descriptor)
            descriptor = next_descriptor
            metadata = os.fstat(descriptor)
            if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != os.geteuid() \
              or metadata.st_mode & 0o022:
                raise SystemExit(f"Refusing unsafe reviewed ancestor: {path.parent}")
        return descriptor, relative.parts[-1]
    except BaseException:
        os.close(descriptor)
        raise


def read_relative(
    path: pathlib.Path,
    root: pathlib.Path,
    maximum: int,
    keep_parent: bool = False,
) -> tuple[bytes, os.stat_result, int | None, str]:
    parent, leaf = open_parent(path, root)
    descriptor = -1
    try:
        descriptor = os.open(leaf, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent)
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_uid != os.geteuid() \
          or before.st_nlink != 1:
            raise SystemExit(f"Refusing unsafe reviewed file: {path}")
        if before.st_size < 0 or before.st_size > maximum:
            raise SystemExit(f"Reviewed file exceeds its size limit: {path}")
        content = bytearray()
        while len(content) <= maximum:
            chunk = os.read(descriptor, min(1024 * 1024, maximum + 1 - len(content)))
            if not chunk:
                break
            content.extend(chunk)
        after = os.fstat(descriptor)
        identity = (before.st_dev, before.st_ino, before.st_size)
        if len(content) != before.st_size or identity != (after.st_dev, after.st_ino, after.st_size):
            raise SystemExit(f"Reviewed file changed while being read: {path}")
        retained = parent if keep_parent else None
        if not keep_parent:
            os.close(parent)
        return bytes(content), before, retained, leaf
    except BaseException:
        os.close(parent)
        raise
    finally:
        if descriptor >= 0:
            os.close(descriptor)


def stage_bytes(parent: int, content: bytes, mode: int) -> str:
    for _ in range(32):
        name = f".snapshot-accept.{secrets.token_hex(12)}"
        try:
            descriptor = os.open(
                name,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                mode,
                dir_fd=parent,
            )
        except FileExistsError:
            continue
        try:
            view = memoryview(content)
            written = 0
            while written < len(view):
                written += os.write(descriptor, view[written:])
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
        return name
    raise SystemExit("Could not allocate private snapshot transaction staging.")


def unused_stage_name(parent: int) -> str:
    for _ in range(32):
        name = f".snapshot-accept.{secrets.token_hex(12)}"
        try:
            os.stat(name, dir_fd=parent, follow_symlinks=False)
        except FileNotFoundError:
            return name
    raise SystemExit("Could not allocate private snapshot transaction staging.")


def write_named_bytes(parent: int, name: str, content: bytes, mode: int) -> None:
    descriptor = os.open(
        name,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        mode,
        dir_fd=parent,
    )
    try:
        view = memoryview(content)
        written = 0
        while written < len(view):
            written += os.write(descriptor, view[written:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def read_at(parent: int, leaf: str, maximum: int) -> tuple[bytes, os.stat_result]:
    descriptor = os.open(leaf, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent)
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_uid != os.geteuid() \
          or before.st_nlink != 1 or before.st_size < 0 or before.st_size > maximum:
            raise SystemExit(f"Refusing unsafe reviewed file: {leaf}")
        content = bytearray()
        while len(content) <= maximum:
            chunk = os.read(descriptor, min(1024 * 1024, maximum + 1 - len(content)))
            if not chunk:
                break
            content.extend(chunk)
        after = os.fstat(descriptor)
        if len(content) != before.st_size or (before.st_dev, before.st_ino, before.st_size) != \
          (after.st_dev, after.st_ino, after.st_size):
            raise SystemExit(f"Reviewed file changed while being read: {leaf}")
        return bytes(content), before
    finally:
        os.close(descriptor)


def write_json_at(parent: int, leaf: str, value: object) -> None:
    content = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()
    staged = stage_bytes(parent, content, 0o600)
    os.rename(staged, leaf, src_dir_fd=parent, dst_dir_fd=parent)
    os.fsync(parent)


def unlink_path(path: pathlib.Path, root: pathlib.Path) -> None:
    parent, leaf = open_parent(path, root)
    try:
        os.unlink(leaf, dir_fd=parent)
        os.fsync(parent)
    finally:
        os.close(parent)


def strict_proposal(content: bytes) -> dict:
    try:
        proposal = json.loads(content)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SystemExit(f"Malformed snapshot proposal: {error}") from None
    if not isinstance(proposal, dict) or set(proposal) != PROPOSAL_KEYS:
        raise SystemExit("Snapshot proposal schema is not canonical.")
    if proposal["schemaVersion"] != 2 or proposal["package"] not in PACKAGES:
        raise SystemExit("Unsupported snapshot proposal version or package.")
    if not isinstance(proposal["changed"], list) or not isinstance(proposal["new"], list):
        raise SystemExit("Snapshot proposal change lists are malformed.")
    if not isinstance(proposal["unmatched"], list) or proposal["unmatched"]:
        raise SystemExit("Snapshot proposal has unmatched candidates; acceptance is blocked.")
    for entry in proposal["changed"]:
        if not isinstance(entry, dict):
            raise SystemExit("Snapshot proposal entry is malformed.")
        keys = set(entry)
        if not ENTRY_REQUIRED.issubset(keys) or not keys.issubset(ENTRY_REQUIRED | ENTRY_OPTIONAL):
            raise SystemExit("Snapshot proposal entry schema is not canonical.")
        for key in ("baselineSHA256", "candidateSHA256"):
            if not isinstance(entry[key], str) or not re.fullmatch(r"[0-9a-f]{64}", entry[key]):
                raise SystemExit("Snapshot proposal contains an invalid digest.")
    return proposal


def percent(value: float | None) -> str:
    if value is None:
        return "?"
    if value and value < 0.001:
        return "<0.1%"
    return f"{(value or 0) * 100:.1f}%"


def journal_payload(
    proposal_digest: str, entries: list[dict], installed: int, phase: str = "installing"
) -> dict:
    return {
        "schemaVersion": 2,
        "proposalSHA256": proposal_digest,
        "phase": phase,
        "installed": installed,
        "entries": [
            {
                "baselinePath": str(item["baseline"]),
                "backupPath": str(item["backup"]),
                "originalSHA256": item["entry"]["baselineSHA256"],
                "candidateSHA256": item["entry"]["candidateSHA256"],
                "stagedName": item["stagedName"],
            }
            for item in entries
        ],
    }


def recover_journal(root: pathlib.Path, journal: pathlib.Path) -> None:
    artifact_root = root / "artifacts" / "snapshot-review"
    content, _, journal_parent, journal_leaf = read_relative(
        journal, artifact_root, MAX_PROPOSAL_BYTES, keep_parent=True
    )
    assert journal_parent is not None
    try:
        value = json.loads(content)
        if not isinstance(value, dict) or set(value) != {
            "schemaVersion", "proposalSHA256", "phase", "installed", "entries"
        } or value["schemaVersion"] != 2 or value["phase"] not in {"installing", "committed"} \
          or not isinstance(value["entries"], list):
            raise SystemExit(f"Malformed pending snapshot acceptance: {journal}")
        if not isinstance(value["installed"], int) or isinstance(value["installed"], bool) \
          or not 0 <= value["installed"] <= len(value["entries"]):
            raise SystemExit(f"Malformed pending snapshot acceptance: {journal}")
        transaction_complete = value["phase"] == "committed"
        if transaction_complete and value["installed"] != len(value["entries"]):
            raise SystemExit(f"Malformed pending snapshot acceptance: {journal}")
        proposal_path = journal.parent / "proposal.json"
        proposal_bytes, _, _, _ = read_relative(
            proposal_path, artifact_root, MAX_PROPOSAL_BYTES
        )
        if digest(proposal_bytes) != value["proposalSHA256"]:
            raise SystemExit(f"Pending acceptance does not match its reviewed proposal: {journal}")
        proposal = strict_proposal(proposal_bytes)
        reviewed = {
            str(lexical_absolute(entry["baselinePath"])): (
                entry["baselineSHA256"], entry["candidateSHA256"]
            )
            for entry in proposal["changed"]
        }
        for entry in value["entries"]:
            if not isinstance(entry, dict) or set(entry) != {
                "baselinePath", "backupPath", "originalSHA256", "candidateSHA256", "stagedName"
            }:
                raise SystemExit(f"Malformed pending snapshot acceptance: {journal}")
            baseline = lexical_absolute(entry["baselinePath"])
            backup = lexical_absolute(entry["backupPath"])
            if reviewed.get(str(baseline)) != (
                entry["originalSHA256"], entry["candidateSHA256"]
            ):
                raise SystemExit(f"Pending acceptance entry was not reviewed: {baseline}")
            package = next(
                (name for name in PACKAGES if is_within(baseline, root / "Packages" / name)),
                None,
            )
            if package is None:
                raise SystemExit(f"Pending acceptance names an unsafe baseline: {baseline}")
            package_root = root / "Packages" / package
            current, metadata, parent, leaf = read_relative(
                baseline, package_root, MAX_PNG_BYTES, keep_parent=True
            )
            assert parent is not None
            try:
                current_digest = digest(current)
                try:
                    backup_bytes, _, _, _ = read_relative(backup, artifact_root, MAX_PNG_BYTES)
                except FileNotFoundError:
                    backup_bytes = None
                if current_digest == entry["candidateSHA256"]:
                    if not transaction_complete:
                        if backup_bytes is None or digest(backup_bytes) != entry["originalSHA256"]:
                            raise SystemExit(f"Pending acceptance backup is invalid: {backup}")
                        staged = stage_bytes(parent, backup_bytes, stat.S_IMODE(metadata.st_mode))
                        os.rename(staged, leaf, src_dir_fd=parent, dst_dir_fd=parent)
                        os.fsync(parent)
                elif current_digest != entry["originalSHA256"] or transaction_complete:
                    raise SystemExit(f"Pending acceptance cannot safely restore: {baseline}")
                staged_name = entry["stagedName"]
                if re.fullmatch(r"\.snapshot-accept\.[0-9a-f]{24}", staged_name):
                    try:
                        staged_metadata = os.stat(staged_name, dir_fd=parent, follow_symlinks=False)
                        if stat.S_ISREG(staged_metadata.st_mode) and staged_metadata.st_uid == os.geteuid() \
                          and staged_metadata.st_nlink == 1:
                            os.unlink(staged_name, dir_fd=parent)
                    except FileNotFoundError:
                        pass
            finally:
                os.close(parent)
            if backup_bytes is not None:
                unlink_path(backup, artifact_root)
        os.unlink(journal_leaf, dir_fd=journal_parent)
        try:
            os.rmdir("rollback", dir_fd=journal_parent)
        except FileNotFoundError:
            pass
        os.fsync(journal_parent)
        print(f"Recovered incomplete snapshot acceptance: {journal.parent.name}")
    finally:
        os.close(journal_parent)


def recover_pending(root: pathlib.Path) -> int:
    review_root = root / "artifacts" / "snapshot-review"
    if not review_root.is_dir() or review_root.is_symlink():
        return 0
    journals = []
    for run in review_root.iterdir():
        if run.is_dir() and not run.is_symlink():
            candidate = run / "acceptance-journal.json"
            try:
                metadata = candidate.lstat()
            except FileNotFoundError:
                continue
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.geteuid() \
              or metadata.st_nlink != 1:
                raise SystemExit(f"Unsafe pending snapshot acceptance: {candidate}")
            journals.append(candidate)
    for journal in sorted(journals):
        recover_journal(root, journal)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--recover-pending", action="store_true")
    parser.add_argument("--proposal")
    parser.add_argument("--review")
    parser.add_argument("--completion")
    parser.add_argument("--expected-proposal")
    parser.add_argument("--head")
    parser.add_argument("--source-state")
    parser.add_argument("--only", default="", help="substring filter over baseline paths")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    root = pathlib.Path(args.root).resolve()
    if args.recover_pending:
        return recover_pending(root)
    required = (args.proposal, args.review, args.completion, args.expected_proposal, args.head, args.source_state)
    if any(value is None for value in required):
        raise SystemExit("Snapshot acceptance requires a completed reviewed proposal.")

    artifact_root = root / "artifacts" / "snapshot-review"
    proposal_path = lexical_absolute(args.proposal)
    review_path = lexical_absolute(args.review)
    completion_path = lexical_absolute(args.completion)
    if len({proposal_path.parent, review_path.parent, completion_path.parent}) != 1:
        raise SystemExit("Review files do not belong to one completed run.")
    proposal_bytes, _, _, _ = read_relative(proposal_path, artifact_root, MAX_PROPOSAL_BYTES)
    review_bytes, _, _, _ = read_relative(review_path, artifact_root, MAX_REVIEW_BYTES)
    completion_bytes, _, _, _ = read_relative(completion_path, artifact_root, MAX_COMPLETION_BYTES)
    proposal_digest = digest(proposal_bytes)
    review_digest = digest(review_bytes)
    try:
        completion = json.loads(completion_bytes)
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise SystemExit("Snapshot review completion envelope is malformed.") from None
    if not re.fullmatch(r"[0-9a-f]{64}", args.expected_proposal) \
      or proposal_digest != args.expected_proposal:
        raise SystemExit("Proposal no longer matches the digest from the inspected review.")
    if set(completion) != {"schemaVersion", "proposalSHA256", "reviewSHA256"} \
      or completion["schemaVersion"] != 1 \
      or completion["proposalSHA256"] != proposal_digest \
      or completion["reviewSHA256"] != review_digest:
        raise SystemExit("Snapshot review completion envelope does not match its artifacts.")
    marker = re.findall(
        rb'<meta name="snapshot-proposal-sha256" content="([0-9a-f]{64})">', review_bytes
    )
    if marker != [proposal_digest.encode()]:
        raise SystemExit("Reviewed HTML is not bound to this proposal.")

    proposal = strict_proposal(proposal_bytes)
    if proposal["head"] != args.head or proposal["sourceStateSHA256"] != args.source_state:
        raise SystemExit("Checkout source state changed after visual review; rerun snapshots.")
    package = proposal["package"]
    package_root = root / "Packages" / package
    candidate_root = root / "artifacts" / "snapshot-candidates"
    changed = proposal["changed"]
    if args.only:
        changed = [entry for entry in changed if args.only in entry["baselinePath"]]

    verified: list[dict] = []

    def cleanup_verified() -> None:
        for item in verified:
            if item.get("stagedName"):
                try:
                    os.unlink(item["stagedName"], dir_fd=item["parent"])
                except OSError:
                    pass
            try:
                os.close(item["parent"])
            except OSError:
                pass

    atexit.register(cleanup_verified)
    destinations: set[pathlib.Path] = set()
    total_bytes = 0
    for entry in changed:
        candidate = lexical_absolute(entry["candidatePath"])
        baseline = lexical_absolute(entry["baselinePath"])
        relative_to(candidate, candidate_root)
        relative_to(baseline, package_root)
        if "__Snapshots__" not in baseline.parts:
            raise SystemExit(f"Refusing baseline outside {package} snapshots: {baseline}")
        if baseline.parent.name != entry["suite"] or baseline.name != entry["image"]:
            raise SystemExit("Snapshot proposal identity does not match its baseline path.")
        if baseline in destinations:
            raise SystemExit(f"Snapshot proposal repeats a baseline destination: {baseline}")
        destinations.add(baseline)
        candidate_bytes, _, _, _ = read_relative(candidate, candidate_root, MAX_PNG_BYTES)
        baseline_bytes, baseline_metadata, baseline_parent, baseline_leaf = read_relative(
            baseline, package_root, MAX_PNG_BYTES, keep_parent=True
        )
        assert baseline_parent is not None
        total_bytes += len(candidate_bytes) + len(baseline_bytes)
        if total_bytes > MAX_TRANSACTION_BYTES:
            os.close(baseline_parent)
            raise SystemExit("Snapshot acceptance exceeds its aggregate byte budget.")
        if digest(candidate_bytes) != entry["candidateSHA256"]:
            os.close(baseline_parent)
            raise SystemExit(f"Candidate changed after review: {candidate}")
        if digest(baseline_bytes) != entry["baselineSHA256"]:
            os.close(baseline_parent)
            raise SystemExit(f"Baseline changed after review: {baseline}")
        staged_name = "" if args.dry_run else unused_stage_name(baseline_parent)
        verified.append({
            "entry": entry,
            "baseline": baseline,
            "baselineBytes": baseline_bytes,
            "candidateBytes": candidate_bytes,
            "baselineIdentity": (baseline_metadata.st_dev, baseline_metadata.st_ino),
            "baselineMode": stat.S_IMODE(baseline_metadata.st_mode),
            "parent": baseline_parent,
            "leaf": baseline_leaf,
            "stagedName": staged_name,
        })

    try:
        if not verified:
            print("Nothing to accept; every existing baseline matched.")
            return 0
        if args.dry_run:
            verb = "Would accept"
        else:
            journal = proposal_path.parent / "acceptance-journal.json"
            rollback = proposal_path.parent / "rollback"
            journal_parent, journal_leaf = open_parent(journal, artifact_root)
            try:
                try:
                    os.stat(journal_leaf, dir_fd=journal_parent, follow_symlinks=False)
                except FileNotFoundError:
                    pass
                else:
                    raise SystemExit(f"An incomplete snapshot acceptance needs recovery: {journal}")
                for index, item in enumerate(verified):
                    item["backup"] = rollback / f"{index:04d}.png"
                live_head, live_source_state = current_checkout_state(root)
                if live_head != args.head or live_source_state != args.source_state:
                    raise SystemExit("Checkout source state changed before snapshot installation.")
                # Durable intent comes before every transaction artifact, so any later
                # interruption is discoverable by the ordinary recovery entrypoint.
                write_json_at(
                    journal_parent, journal_leaf,
                    journal_payload(proposal_digest, verified, 0),
                )
                os.mkdir("rollback", 0o700, dir_fd=journal_parent)
                rollback_descriptor = os.open(
                    "rollback", os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=journal_parent
                )
                try:
                    for index, item in enumerate(verified):
                        write_named_bytes(
                            rollback_descriptor, f"{index:04d}.png", item["baselineBytes"], 0o600
                        )
                    os.fsync(rollback_descriptor)
                finally:
                    os.close(rollback_descriptor)
                for item in verified:
                    write_named_bytes(
                        item["parent"], item["stagedName"],
                        item["candidateBytes"], item["baselineMode"],
                    )
                    os.fsync(item["parent"])
                for index, item in enumerate(verified):
                    baseline_bytes, metadata = read_at(
                        item["parent"], item["leaf"], MAX_PNG_BYTES
                    )
                    if (metadata.st_dev, metadata.st_ino) != item["baselineIdentity"] \
                      or digest(baseline_bytes) != item["entry"]["baselineSHA256"]:
                        raise SystemExit(f"Baseline changed before installation: {item['baseline']}")
                    canonical_parent, canonical_leaf = open_parent(item["baseline"], package_root)
                    if canonical_leaf != item["leaf"] or \
                      (os.fstat(canonical_parent).st_dev, os.fstat(canonical_parent).st_ino) != \
                      (os.fstat(item["parent"]).st_dev, os.fstat(item["parent"]).st_ino):
                        os.close(canonical_parent)
                        raise SystemExit(f"Baseline directory changed before installation: {item['baseline']}")
                    write_json_at(
                        journal_parent, journal_leaf,
                        journal_payload(proposal_digest, verified, index),
                    )
                    try:
                        os.rename(
                            item["stagedName"], item["leaf"],
                            src_dir_fd=item["parent"], dst_dir_fd=canonical_parent,
                        )
                        item["stagedName"] = ""
                        os.fsync(canonical_parent)
                    finally:
                        os.close(canonical_parent)
                    write_json_at(
                        journal_parent, journal_leaf,
                        journal_payload(proposal_digest, verified, index + 1),
                    )
                write_json_at(
                    journal_parent, journal_leaf,
                    journal_payload(proposal_digest, verified, len(verified), "committed"),
                )
                for item in verified:
                    unlink_path(item["backup"], artifact_root)
                os.rmdir("rollback", dir_fd=journal_parent)
                os.fsync(journal_parent)
                os.unlink(journal_leaf, dir_fd=journal_parent)
                os.fsync(journal_parent)
            finally:
                os.close(journal_parent)
            verb = "Accepted"

        print(f"{verb} {len(verified)} reviewed baseline(s) for {package}.")
        print("\n--- commit body ---")
        print(f"Accept {len(verified)} reviewed {package} baseline change(s):")
        for item in sorted(verified, key=lambda value: -(value["entry"].get("visibleFraction") or 0)):
            entry = item["entry"]
            note = "size changed" if entry.get("resized") else f'{percent(entry.get("visibleFraction"))} of pixels'
            print(f"  {entry['suite']}/{entry['image']} - {note}")
        print("-------------------")
        return 0
    finally:
        for item in verified:
            if item["stagedName"]:
                try:
                    os.unlink(item["stagedName"], dir_fd=item["parent"])
                except FileNotFoundError:
                    pass
            os.close(item["parent"])


if __name__ == "__main__":
    raise SystemExit(main())
