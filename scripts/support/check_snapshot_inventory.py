#!/usr/bin/python3 -I
"""Validate SnapshotSupport exports against the package baseline inventory."""

import json
import os
import pathlib
import stat
import sys

MAX_EXPORT_ENTRIES = 512
MAX_SIDECAR_BYTES = 1024 * 1024


def fail(message):
    raise SystemExit(message)


def require_directory(path, label):
    try:
        metadata = os.lstat(path)
    except OSError as error:
        fail("{} is unavailable: {}".format(label, error))
    if not stat.S_ISDIR(metadata.st_mode):
        fail("{} is not a real directory".format(label))


def require_regular_file(path, label):
    try:
        metadata = os.lstat(path)
    except OSError as error:
        fail("{} is unavailable: {}".format(label, error))
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        fail("{} is not a single-link regular file: {}".format(label, path.name))


def snapshot_directories(tests_dir):
    directories = []
    for root, names, _files in os.walk(str(tests_dir), topdown=True, followlinks=False):
        root_path = pathlib.Path(root)
        retained = []
        for name in names:
            candidate = root_path / name
            if name == ".build":
                continue
            if name == "__Snapshots__":
                require_directory(candidate, "snapshot baseline directory")
                directories.append(candidate)
            else:
                retained.append(name)
        names[:] = retained
    return directories


def expected_identities(package_dir):
    tests_dir = package_dir / "Tests"
    require_directory(tests_dir, "package Tests directory")
    identities = []

    for snapshots_dir in snapshot_directories(tests_dir):
        relative = snapshots_dir.relative_to(tests_dir)
        if len(relative.parts) < 2 or relative.parts[-1] != "__Snapshots__":
            fail("snapshot baseline directory has an invalid package-relative path")
        source_prefix = relative.parts[:-1]

        for entry in sorted(os.scandir(str(snapshots_dir)), key=lambda item: item.name):
            entry_path = pathlib.Path(entry.path)
            if entry.name == ".gitkeep":
                require_regular_file(entry_path, "snapshot scaffold marker")
                if entry_path.read_bytes():
                    fail("snapshot scaffold marker must be empty")
                continue
            require_directory(entry_path, "snapshot source directory")
            for baseline in sorted(os.scandir(str(entry_path)), key=lambda item: item.name):
                baseline_path = pathlib.Path(baseline.path)
                require_regular_file(baseline_path, "snapshot baseline")
                if baseline_path.suffix != ".png":
                    fail("unexpected snapshot baseline entry: {}".format(baseline_path.name))
                identity = "/".join(source_prefix + (entry.name, baseline_path.stem))
                identities.append(identity)

    if not identities:
        fail("snapshot mode has no committed snapshot inventory")
    if len(identities) != len(set(identities)):
        fail("duplicate committed snapshot identity")
    return set(identities)


def exported_identities(export_dir, expected_verification_mode):
    require_directory(export_dir, "snapshot export directory")
    images = {}
    sidecars = {}

    entries = list(os.scandir(str(export_dir)))
    if len(entries) > MAX_EXPORT_ENTRIES:
        fail("snapshot export exceeds the entry-count limit")
    for entry in sorted(entries, key=lambda item: item.name):
        path = pathlib.Path(entry.path)
        require_regular_file(path, "snapshot export entry")
        if path.suffix == ".png":
            images[path.stem] = path
        elif path.suffix == ".json" and path.name != "run.json":
            sidecars[path.stem] = path
        else:
            fail("unexpected snapshot export entry: {}".format(path.name))

    if set(images) != set(sidecars):
        fail(
            "snapshot render file-pair mismatch: images={} metadata={}".format(
                len(images), len(sidecars)
            )
        )

    identities = []
    metadata_by_identity = {}
    for stem in sorted(sidecars):
        sidecar = sidecars[stem]
        try:
            if sidecar.stat().st_size > MAX_SIDECAR_BYTES:
                fail("render metadata exceeds its size limit: {}".format(sidecar.name))
            metadata = json.loads(sidecar.read_text())
        except (OSError, ValueError) as error:
            fail("invalid render metadata: {}: {}".format(sidecar.name, error))
        context = metadata.get("context")
        identity = metadata.get("baseline_identity")
        verification_mode = metadata.get("verification_mode")
        if not isinstance(context, dict) or not isinstance(identity, str) or not identity:
            fail("incomplete render identity: {}".format(sidecar.name))
        if verification_mode != expected_verification_mode:
            fail("compiled snapshot mode does not match requested mode: {}".format(sidecar.name))
        if len(pathlib.PurePosixPath(identity).parts) < 3 \
                or identity.startswith("/") \
                or "\\" in identity \
                or any(part in ("", ".", "..") for part in identity.split("/")):
            fail("non-canonical render identity: {}".format(sidecar.name))
        file_id = context.get("file_id")
        test_name = context.get("test_name")
        if not all(isinstance(value, str) and value for value in (file_id, test_name)):
            fail("incomplete render context: {}".format(sidecar.name))
        identities.append(identity)
        metadata_by_identity[identity] = metadata

    if not identities:
        fail("snapshot run produced no logical renders")
    if len(identities) != len(set(identities)):
        fail("duplicate logical snapshot render")
    return set(identities), metadata_by_identity


def validate_filter(metadata_by_identity, filter_arg):
    components = filter_arg.split("/")
    target = components[0]
    test = components[2] if len(components) == 3 else None
    for identity, metadata in metadata_by_identity.items():
        context = metadata["context"]
        file_id = context["file_id"]
        test_name = context["test_name"]
        if file_id.split("/", 1)[0] != target:
            fail("filtered snapshot run exported a different target: {}".format(identity))
        if test is not None and test_name.split("(", 1)[0] != test:
            fail("filtered snapshot run exported a different test: {}".format(identity))


def main():
    if len(sys.argv) != 6:
        fail(
            "usage: check_snapshot_inventory.py <package-dir> <export-dir> "
            "<complete|filtered> <filter> <baseline|render-only>"
        )
    package_dir = pathlib.Path(sys.argv[1])
    export_dir = pathlib.Path(sys.argv[2])
    scope = sys.argv[3]
    filter_arg = sys.argv[4]
    verification_mode = sys.argv[5]
    if scope not in ("complete", "filtered"):
        fail("snapshot inventory scope must be complete or filtered")
    if (scope == "filtered") != bool(filter_arg):
        fail("snapshot inventory scope does not match its filter")
    if verification_mode not in ("baseline", "render-only"):
        fail("snapshot verification mode must be baseline or render-only")

    expected = expected_identities(package_dir)
    actual, metadata_by_identity = exported_identities(export_dir, verification_mode)
    missing = expected - actual
    unexpected = actual - expected

    if scope == "complete" and (missing or unexpected):
        fail(
            "snapshot render inventory mismatch: missing={} unexpected={}".format(
                len(missing), len(unexpected)
            )
        )
    if scope == "filtered":
        validate_filter(metadata_by_identity, filter_arg)
        if unexpected:
            fail(
                "snapshot render inventory mismatch: missing=0 unexpected={}".format(
                    len(unexpected)
                )
            )

    print(
        "snapshot render inventory: OK ({} {} logical renders)".format(
            len(actual), scope
        )
    )


if __name__ == "__main__":
    main()
