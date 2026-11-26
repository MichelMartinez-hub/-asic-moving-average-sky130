#!/usr/bin/env python3
"""Estimate TT postroute power for the eight verified moving-average designs."""

import csv
import hashlib
import io
import json
import math
import os
import re
import subprocess
import tempfile
from pathlib import Path

from run_flow import LIB, PHYSICAL, SCRIPTS, SDC, FlowError, atomic_write, read, require


REFERENCE = PHYSICAL / "summary_final_verified.csv"
ODB = "direct_ff_detailed_route.odb"
SPEF = "direct_ff_candidate_tt_nom.spef"
TCL = SCRIPTS / "openroad_power_postroute.tcl"
KEYS = ("internal", "switching", "leakage", "total")
CASES = [(a, n) for a in ("direct", "recursive") for n in (4, 8, 16, 32)]


def reference_rows():
    grouped = {}
    with REFERENCE.open(newline="") as stream:
        for row in csv.DictReader(stream):
            require(row["status"] == row["lvs"] == "PASS"
                    and all(row[key] == "0" for key in ("route_drc", "antenna_net", "antenna_pin", "drc")),
                    f"Implementación sin verificación física: {row['source']}")
            key = row["architecture"], int(row["window"])
            grouped.setdefault(key, []).append(row)
    require(set(grouped) == set(CASES), "El CSV debe cubrir las ocho configuraciones")
    for key, rows in grouped.items():
        if key == ("direct", 4) and len(rows) == 2:
            rows.sort(key=lambda row: Path(row["source"]).name != "n4")
            a, b = [Path(row["source"]) for row in rows]
            spefs = [re.sub(r"^\*DATE .*$", "", read(path / SPEF), flags=re.M) for path in (a, b)]
            require({a.name, b.name} == {"n4", "validation_direct_n4"}
                    and (a / ODB).read_bytes() == (b / ODB).read_bytes()
                    and spefs[0] == spefs[1],
                    "Las referencias duplicadas de Direct N=4 deben ser equivalentes")
        else:
            require(len(rows) == 1, f"Referencia ambigua: {key}")
    return [grouped[key][0] for key in CASES]


def liberty_models():
    library = read(LIB)
    for key, value in (("nom_voltage", 1.8), ("nom_temperature", 25)):
        match = re.search(rf"\b{key}\s*:\s*([\d.]+)\s*;", library)
        require(match and float(match[1]) == value, f"PVT inesperado en Liberty: {key}")
    parts = re.split(r'^\s*cell\s*\(\s*"?(\w+)"?\s*\)\s*\{', library, flags=re.M)
    return dict(zip(parts[1::2], parts[2::2]))


def estimate(row, directory, models):
    architecture, window = row["architecture"], int(row["window"])
    case = f"{architecture}_n{window}"
    source = Path(row["source"])
    inputs = {"ODB": source / ODB, "SPEF": source / SPEF, "LIB": LIB, "SDC": SDC}
    for path in inputs.values():
        require(path.is_file() and path.stat().st_size, f"Falta el archivo {path}")
    log = directory / f"{case}.log"
    report = directory / f"{case}.json"
    with log.open("w") as stream:
        result = subprocess.run(
            ["openroad", "-no_init", "-threads", "1", "-exit", TCL],
            stdout=stream, stderr=subprocess.STDOUT,
            env={**os.environ, **{f"POWER_{key}": str(path) for key, path in inputs.items()},
                 "POWER_JSON": str(report)},
        )
    text = read(log)
    require(result.returncode == 0 and re.search(r"^POWER_COMPLETED$", text, re.M)
            and not re.search(r"^\s*(?:\[(?:ERROR|WARNING)\b|(?:error|warning):)", text, re.M | re.I),
            f"OpenROAD registró errores o advertencias: {log}")
    require(f"POWER_DESIGN moving_average_{architecture} {row['instances']}" in text.splitlines(),
            f"El ODB no coincide con el inventario físico: {case}")
    coverage = re.search(r"^Found (\d+) unannotated drivers\.\n(.*?)"
                         r"^Found (\d+) partially unannotated drivers\.$", text, re.M | re.S)
    unloaded = set(re.findall(r"^POWER_UNLOADED (\S+)$", text, re.M))
    require(coverage and int(coverage[3]) == 0, f"SPEF parcial: {log}")
    omitted = set(coverage[2].split())
    require(len(omitted) == int(coverage[1]) and omitted <= unloaded,
            f"El SPEF omite drivers con carga: {log}")
    annotated = re.findall(r"^ user (\S+)$", text, re.M)
    required_ports = {"enable", "in_valid", "rst_n", *(f"in_data[{bit}]" for bit in range(12))}
    require(len(annotated) == 15 and set(annotated) == required_ports,
            f"Anotación de actividad incorrecta: {log}")
    slacks = dict(re.findall(r"^worst slack (max|min) ([-+\d.]+)$", text, re.M))
    for delay, check in (("max", "setup"), ("min", "hold")):
        reference = row[f"tt_{check}_wns_ns"]
        precision = len(reference.partition(".")[2])
        require(delay in slacks and math.isclose(float(slacks[delay]), float(reference),
                rel_tol=0, abs_tol=0.5 * 10 ** -precision + 1e-9),
                f"STA TT no coincide con el CSV verificado: {case} {check}")
    masters = re.findall(r"^POWER_MASTER (\S+) (\S+)$", text, re.M)
    require(masters, f"No hay inventario de modelos Liberty: {log}")
    for master, _ in masters:
        model = models.get(master, "")
        require(re.search(r"\bcell_leakage_power\s*:", model)
                and (master == "sky130_fd_sc_hd__conb_1"
                     or re.search(r"\binternal_power\s*\(", model)),
                f"Faltan modelos de potencia para {master}: {log}")
    parsed = json.loads(read(report))
    totals = parsed["Total"]
    groups = [parsed[name] for name in ("Sequential", "Combinational", "Clock", "Macro", "Pad")]
    for group in [totals, *groups]:
        require(all(math.isfinite(group[key]) and group[key] >= 0 for key in KEYS)
                and math.isclose(group["total"], sum(group[key] for key in KEYS[:-1]), rel_tol=2e-6),
                f"Desglose de potencia incoherente: {report}")
    # OpenSTA accumulates the design total and the group subtotals separately.
    require(all(totals[key] > 0 and math.isclose(totals[key], sum(group[key] for group in groups),
                                               rel_tol=1e-5) for key in KEYS)
            and groups[2]["total"] > 0, f"Potencia total o de reloj inválida: {report}")
    with (directory / f"{case}.inputs.json").open("w") as stream:
        manifest = {}
        for path in [*inputs.values(), TCL, REFERENCE]:
            with path.open("rb") as file:
                manifest[str(path)] = hashlib.file_digest(file, "sha256").hexdigest()
        json.dump(manifest, stream, indent=2)
        stream.write("\n")
    result = {"architecture": architecture, "window": window,
              **{f"{key}_uw": totals[key] * 1e6 for key in KEYS},
              "energy_pj_per_sample": totals["total"] * 1e12 / 50e6,
              "source": str(source), "report": str(report.relative_to(PHYSICAL))}
    print(f"{case}: {result['total_uw']:.6f} µW", flush=True)
    return result


def plot(rows, destination):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    plt.rcParams.update({"font.family": "DejaVu Sans", "pdf.fonttype": 42})
    fig, ax = plt.subplots(figsize=(6, 3.7), layout="constrained")
    for architecture, label, marker in (("direct", "Directa", "o"), ("recursive", "Recursiva", "s")):
        series = [row for row in rows if row["architecture"] == architecture]
        ax.plot([row["window"] for row in series], [row["total_uw"] for row in series],
                label=label, marker=marker, linewidth=1.8)
    ax.set(xlabel="Tamaño de ventana N", ylabel="Potencia total (µW)", ylim=(0, None),
           xticks=(4, 8, 16, 32))
    ax.grid(axis="y", alpha=0.25)
    ax.legend(frameon=False)
    fig.savefig(destination)
    plt.close(fig)


def main():
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pilot-only", action="store_true", help="Valida únicamente Direct N=4")
    args = parser.parse_args()
    rows = reference_rows()
    models = liberty_models()
    output = Path(tempfile.mkdtemp(prefix="power_tt_", dir=PHYSICAL))
    print(output, flush=True)
    results = [estimate(rows[0], output, models)]
    if args.pilot_only:
        return
    results.extend(estimate(row, output, models) for row in rows[1:])
    contents = io.StringIO(newline="")
    writer = csv.DictWriter(contents, fieldnames=list(results[0]))
    writer.writeheader()
    writer.writerows(results)
    figure = output / "power_total_vs_n.pdf"
    plot(results, figure)
    figure.replace(PHYSICAL / figure.name)
    atomic_write(PHYSICAL / "power_summary.csv", contents.getvalue())


if __name__ == "__main__":
    try:
        main()
    except (FlowError, OSError, ValueError, KeyError) as error:
        raise SystemExit(str(error)) from error
