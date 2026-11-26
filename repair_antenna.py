#!/usr/bin/env python3
"""Repair an antenna-only failure and publish its row after physical signoff."""

import argparse
import csv
import fcntl
import hashlib
import io
import json
import shutil
import tempfile
from pathlib import Path

from run_flow import (
    LIB, PHYSICAL, SCRIPTS, STAGES, FlowError, Implementation, atomic_write,
    files_available, number, read, require,
)


def repair(case, original, checkpoint, output, row):
    state = json.loads(read(original / "state.json"))
    config = state["config"]
    inputs = ["synth.v", "direct_ff_detailed_route.odb", "direct_ff_route.guide",
              "direct_ff_antenna.rpt"]
    require(files_available(original, inputs), "Faltan datos originales de routing")
    attempt = Implementation(config["architecture"], config["window"], output,
                             config["utilization"])
    (output / "tcl").mkdir()
    (output / "logs").mkdir()
    shutil.copyfile(original / "synth.v", output / "synth.v")
    script = output / "tcl/repair_routed_antenna.tcl"
    shutil.copyfile(SCRIPTS / script.name, script)
    evidence = {
        "original": str(original),
        "original_sha256": {},
        "checkpoint": str(checkpoint),
        "checkpoint_sha256": {},
        "stages": {},
    }
    for directory, hashes, names in (
        (original, evidence["original_sha256"], inputs),
        (checkpoint, evidence["checkpoint_sha256"], inputs[1:]),
    ):
        for name in names:
            with (directory / name).open("rb") as stream:
                hashes[name] = hashlib.file_digest(stream, "sha256").hexdigest()
    shutil.copyfile(original / "direct_ff_antenna.rpt", output / "original_antenna.rpt")

    statuses = evidence["stages"]
    metrics = {}
    downstream = STAGES[STAGES.index("metrics"):]
    stages = ("repair_antenna", "detailed_route", "antenna",
              *(stage for stage in downstream if stage != "antenna"))
    for stage in stages:
        attempt.log = output / f"logs/{stage}.log"
        attempt.artifacts = []
        print(f"{case}: {stage}", flush=True)
        entry = statuses[stage] = {"log": str(attempt.log.relative_to(output)), "metrics": {}}
        try:
            if stage == "repair_antenna":
                attempt.outputs("direct_ff_global_route.odb", "direct_ff_route.guide")
                report = attempt.command("openroad", "-threads", "1", "-exit", script,
                                         ANTENNA_CHECKPOINT=str(checkpoint), FLOW_LIB=str(LIB))
                require(number(r"Found (\d+) antenna violations\.", report) == 1
                        and number(r"Inserted (\d+) diodes\.", report) == 1,
                        "Se esperaba una violación y un diodo")
                status = "completed"
            else:
                status = attempt.execute(stage, entry["metrics"])
            require(files_available(output, attempt.artifacts), "Faltan artefactos de la etapa")
            entry.update(status=status, artifacts=attempt.artifacts)
            metrics.update(entry["metrics"])
        except Exception as error:
            entry.update(status="failed", error=str(error))
            raise
        finally:
            atomic_write(output / "verification.json", json.dumps(evidence, indent=2) + "\n")
        require(status == "completed", f"Falló {stage}: {output}")
    row.update({key: value for key, value in metrics.items() if key in row})
    row.update(status="PASS", source=str(output))


def summary_rows(summary):
    reader = csv.DictReader(io.StringIO(read(summary)))
    return reader.fieldnames, list(reader)


def select(rows, architecture, window):
    selected = [row for row in rows
                if (row["architecture"], row["window"]) == (architecture, window)]
    require(len(selected) == 1, f"Fila original ambigua: {architecture} N={window}")
    return selected[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", choices=("direct_n8", "direct_n32", "recursive_n8", "recursive_n16"))
    parser.add_argument("--verify-only", action="store_true",
                        help="Repite la reparación original sin publicar en el CSV")
    parser.add_argument("--checkpoint", type=Path,
                        help="Reutiliza el routing sin fillers de un intento con antena residual")
    args = parser.parse_args()
    case = args.case
    architecture, window = case.split("_n")
    summary = PHYSICAL / "summary.csv"
    original = PHYSICAL / case
    attempts = PHYSICAL / "antenna_repairs"
    checkpoint = original
    if args.checkpoint:
        checkpoint = args.checkpoint.resolve()
        require(checkpoint.parent == attempts, "Checkpoint fuera del directorio de reparación")
        previous = json.loads(read(checkpoint / "verification.json"))
        require(previous["original"] == str(original)
                and previous["stages"]["detailed_route"]["status"] == "completed"
                and previous["stages"]["antenna"]["status"] == "failed_check",
                "El checkpoint debe pertenecer al mismo caso y tener antena residual")
    _, rows = summary_rows(summary)
    baseline = select(rows, architecture, window)
    if args.verify_only:
        original_stages = json.loads(read(original / "state.json"))["stages"]
        require(original_stages["antenna"]["metrics"] == {"antenna_net": 1, "antenna_pin": 1},
                f"Faltan las métricas originales de antena: {case}")
    else:
        require(baseline["status"] == "FAIL" and baseline["source"] == str(original)
                and baseline["route_drc"] == baseline["drc"] == "0" and baseline["lvs"] == "PASS"
                and baseline["antenna_net"] == baseline["antenna_pin"] == "1"
                and all(float(value) >= 0 and not value.startswith("-")
                        for key, value in baseline.items() if key.endswith("_ns")),
                f"La fila no indica un fallo exclusivo de antena: {case}")
    attempts.mkdir(exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix=f"{case}_", dir=attempts))
    print(output, flush=True)
    verified = baseline.copy()
    repair(case, original, checkpoint, output, verified)
    if args.verify_only:
        print(f"{case}: PASS", flush=True)
        return
    with (PHYSICAL / ".flow.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        fields, rows = summary_rows(summary)
        row = select(rows, architecture, window)
        require(row == baseline, f"La fila cambió durante la verificación: {case}")
        row.update(verified)
        contents = io.StringIO(newline="")
        writer = csv.DictWriter(contents, fields)
        writer.writeheader()
        writer.writerows(rows)
        atomic_write(summary, contents.getvalue())
        print(f"{case}: PASS", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (FlowError, OSError, ValueError) as error:
        raise SystemExit(str(error)) from error
