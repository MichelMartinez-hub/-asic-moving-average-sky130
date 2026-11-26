#!/usr/bin/env python3
"""Execute the SKY130 HD moving-average flow, one implementation at a time."""

import argparse
import csv
import fcntl
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"
PHYSICAL = ROOT / "results/physical"
PDK = Path("/foss/pdks/sky130A")
CELLS = PDK / "libs.ref/sky130_fd_sc_hd"
TECH = PDK / "libs.tech"
LIB = CELLS / "lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
DEF2STREAM = Path("/foss/designs/orfs/flow/util/def2stream.py")
SDC = ROOT / "constraints/sta_preplacement.sdc"
CORNERS = {"tt": "nom", "ss": "max", "ff": "min"}
NUM = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?"
BUFFER = r"sky130_fd_sc_hd__(?:buf|bufbuf|bufinv|clkbuf|dlygate)[^_]*_\d+"

# Keep the original artifact names inside each isolated working directory.
OPENROAD = {
    "import": ("import", "direct_import"),
    "floorplan": ("floorplan", "direct_floorplan"),
    "pins": ("pins", "direct_pins"),
    "tapcells": ("tapcells", "direct_tapcells"),
    "pdn": ("pdn", "direct_pdn"),
    "global_place": ("global_place", "direct_global_place"),
    "detailed_place": ("detailed_place", "direct_detailed_place"),
    "repair": ("repair", "direct_repaired"),
    "cts": ("cts", "direct_cts"),
    "hold_tt": ("repair_hold", "direct_hold_repaired"),
    "hold_ff": ("repair_hold_ff", "direct_hold_ff_candidate"),
    "global_route": ("global_route_ff_candidate", "direct_ff_global_route"),
    "detailed_route": ("detailed_route_ff_candidate", "direct_ff_detailed_route"),
}
STAGES = (
    "rtl", "synthesis", *OPENROAD, "metrics", "sta_tt", "sta_ss", "sta_ff",
    "antenna", "fillers", "gds", "drc", "reference", "magic", "lvs",
)


class FlowError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise FlowError(message)


def read(path):
    return path.read_text(errors="replace")


def atomic_write(path, content):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(content)
    temporary.replace(path)


def number(pattern, report):
    values = re.findall(pattern, report, re.MULTILINE)
    require(values, f"Métrica ausente ({pattern})")
    return float(values[-1])


def timing(report, corner):
    return {
        f"{corner}_{check}_{metric}_ns": number(rf"^{label} {delay} ({NUM})\s*$", report)
        for check, delay in (("setup", "max"), ("hold", "min"))
        for metric, label in (("wns", "worst slack"), ("tns", "tns"))
    }


def violations(path, top):
    xml = ET.parse(path).getroot()
    items = xml.find("items")
    require(xml.tag == "report-database" and items is not None
            and xml.findtext("top-cell") == top, f"Reporte DRC inválido: {path}")
    return sum(int(item.findtext("multiplicity", "1")) for item in items.findall("item"))


def lvs_matches(report):
    return bool(re.search(r"^Final result: Circuits match uniquely\.\s*$", report, re.MULTILINE))


def files_available(directory, names):
    return all((directory / name).is_file() and (directory / name).stat().st_size
               for name in names)


def buffers_added(netlist, placed_def):
    initial = set(re.findall(rf"^\s*{BUFFER}\s+(\S+)\s*\(", netlist, re.M))
    final = set(re.findall(rf"^\s+-\s+(\S+)\s+{BUFFER}\s+\+", placed_def, re.M))
    return len(final - initial)


class Implementation:
    def __init__(self, architecture, window, directory, utilization):
        self.architecture = architecture
        self.window = window
        self.top = f"moving_average_{architecture}"
        self.path = directory
        self.utilization = utilization
        self.rtl = ROOT / f"rtl/filters/{self.top}.sv"
        self.bench = "tb_direct_param" if architecture == "direct" else "tb_filter_equivalence"
        self.path.mkdir(parents=True, exist_ok=True)
        self.state_file = self.path / "state.json"

    def config(self):
        sources = [
            Path(__file__), SDC, self.rtl, ROOT / f"tb/{self.bench}.sv",
            *sorted(SCRIPTS.glob("openroad_*_n4.tcl")),
            SCRIPTS / "physical_metrics.tcl", SCRIPTS / "magic_extract_lvs_n4.tcl",
            DEF2STREAM,
        ]
        if self.architecture == "recursive":
            sources.append(ROOT / "rtl/filters/moving_average_direct.sv")
        digest = hashlib.sha256()
        for source in sources:
            digest.update(source.read_bytes())
        return dict(architecture=self.architecture, window=self.window,
                    utilization=self.utilization, inputs_sha256=digest.hexdigest())

    def save(self):
        atomic_write(self.state_file, json.dumps(self.state, indent=2) + "\n")

    def command(self, *args, cwd=None, stdin=None, **environment):
        args = [str(arg) for arg in args]
        with self.log.open("a") as log:
            log.write(f"$ {shlex.join(args)}\n")
            log.flush()
            result = subprocess.run(args, cwd=cwd or self.path, stdout=log,
                                    stderr=subprocess.STDOUT, input=stdin, text=True,
                                    env={**os.environ, **environment})
        require(result.returncode == 0, f"{args[0]} terminó con código {result.returncode}")
        report = read(self.log)
        require(not re.search(r"^\s*(?:\[ERROR\b|ERROR:|Error:|Traceback \()", report, re.M),
                f"{args[0]} registró un error")
        return report

    def outputs(self, *names):
        self.artifacts.extend(names)
        for name in names:
            (self.path / name).unlink(missing_ok=True)

    def template(self, name, **environment):
        source = read(SCRIPTS / name)
        replacements = {
            str(ROOT / "results/physical/n4/direct_ff_final.gds"): "direct_ff_final.gds",
            "results/physical/n4/": "",
            'set ROOT "results/physical/n4"': 'set ROOT "."',
            "results/synthesis/n4/direct_sky130_filtered.v": "synth.v",
            "moving_average_direct": self.top,
            "constraints/sta_preplacement.sdc": "{" + str(SDC) + "}",
            "-utilization 40": f"-utilization {self.utilization}",
            "-density 0.55": f"-density {max(0.55, self.utilization / 100 + 0.08):.3f}",
        }
        for old, new in replacements.items():
            source = source.replace(old, new)
        if name == "openroad_sta_corners_ff_candidate_n4.tcl":
            source = re.sub(r"^(report_(?:worst_slack|tns) -m(?:ax|in))$", r"\1 -digits 9",
                            source, flags=re.M)
        script = self.path / "tcl" / name
        script.write_text(source)
        if name.startswith("magic"):
            return script
        return self.command("openroad", "-threads", "1", "-exit", script, **environment)

    def rtl_check(self):
        sources = [self.rtl]
        if self.architecture == "recursive":
            sources.insert(0, ROOT / "rtl/filters/moving_average_direct.sv")
        binary = f"obj_dir/V{self.bench}"
        self.outputs(binary)
        self.command("verilator", "--binary", "--timing", "--top-module", self.bench,
                     "-j", "1", "-Wno-fatal", "-GDATA_W=12", f"-GWINDOW_N={self.window}",
                     *sources, ROOT / f"tb/{self.bench}.sv")
        report = self.command(self.path / binary)
        require(re.search(rf"^PASS: N={self.window},", report, re.M), "Falta PASS de simulación")

    def synthesis(self, metrics):
        self.outputs("synth.v")
        script = self.path / "synthesis.ys"
        script.write_text(
            f'read_verilog -sv "{self.rtl}"\n'
            f"hierarchy -check -top {self.top} -chparam DATA_W 12 -chparam WINDOW_N {self.window}\n"
            f"synth -top {self.top} -noabc\n"
            f'dfflibmap -liberty "{LIB}"\n'
            f'abc -liberty "{LIB}" -dont_use sky130_fd_sc_hd__lpflow* '
            "-dont_use sky130_fd_sc_hd__clkinv* -dont_use sky130_fd_sc_hd__probe*\n"
            f"clean\nstat -liberty \"{LIB}\"\nwrite_verilog -noattr synth.v\n"
        )
        report = self.command("yosys", "-s", script)
        metrics["synth_area_um2"] = number(rf"Chip area .*?:\s*({NUM})", report)

    def gds(self):
        self.outputs("direct_ff_final.gds")
        klayout = TECH / "klayout/tech"
        tech = read(klayout / "sky130A.lyt")
        marker = "<lef-files>merged.lef</lef-files>"
        require(tech.count(marker) == 1, "No se encontró la referencia LEF en sky130A.lyt")
        lefs = [CELLS / "techlef/sky130_fd_sc_hd__nom.tlef", CELLS / "lef/sky130_fd_sc_hd.lef"]
        export = self.path / "sky130A_export.lyt"
        export.write_text(tech.replace(marker, "".join(f"<lef-files>{p}</lef-files>" for p in lefs)))
        self.klayout("-zz", DEF2STREAM, tech_file=export, layer_map=klayout / "sky130A.map",
                     in_def="direct_ff_fillers.def", design_name=self.top, seal_file="",
                     in_files=CELLS / "gds/sky130_fd_sc_hd.gds", out_file="direct_ff_final.gds")

    def klayout(self, flag, script, **variables):
        arguments = [arg for key, value in variables.items() for arg in ("-rd", f"{key}={value}")]
        return self.command("klayout", flag, *arguments, "-r", script, QT_QPA_PLATFORM="offscreen")

    def execute(self, stage, metrics):
        if stage == "rtl":
            self.rtl_check()
        elif stage == "synthesis":
            self.synthesis(metrics)
        elif stage in OPENROAD:
            template, artifact = OPENROAD[stage]
            self.outputs(f"{artifact}.odb")
            if stage != "import":
                self.outputs(f"{artifact}.def")
            if stage == "global_route":
                self.outputs("direct_ff_route.guide")
            report = self.template(f"openroad_{template}_n4.tcl")
            if stage == "detailed_route":
                metrics["route_drc"] = int(number(r"^Violaciones DRC: (\d+)$", report))
                require(metrics["route_drc"] == 0 and "Estado de enrutamiento: COMPLETO" in report,
                        "Detailed Routing incompleto o con violaciones")
                lengths = re.findall(r"^Total wire length = (\d+) um\.", report, re.M)
                if lengths:
                    metrics["wirelength_um"] = int(lengths[-1])
        elif stage == "metrics":
            self.outputs("physical_metrics.txt")
            self.command("openroad", "-threads", "1", "-exit", SCRIPTS / "physical_metrics.tcl",
                         FLOW_LIB=str(LIB))
            for line in read(self.path / "physical_metrics.txt").splitlines():
                key, value = line.split()
                metrics[key] = float(value) if key.endswith("_um2") else int(value)
            metrics["utilization_pct"] = 100 * metrics["placed_area_um2"] / metrics["core_area_um2"]
            metrics["buffers_added"] = buffers_added(
                read(self.path / "synth.v"), read(self.path / "direct_ff_detailed_route.def"))
        elif stage.startswith("sta_"):
            corner = stage[4:]
            self.outputs(f"direct_ff_candidate_{corner}_{CORNERS[corner]}.spef")
            report = self.template("openroad_sta_corners_ff_candidate_n4.tcl", PVT_CORNER=corner)
            values = timing(report, corner)
            metrics.update(values)
            # Continue collecting the remaining corners and signoff reports on timing violations.
            if any(value < 0 or str(value).startswith("-") for value in values.values()):
                return "failed_check"
        elif stage == "antenna":
            report = self.template("openroad_antenna_n4.tcl")
            for kind in ("net", "pin"):
                metrics[f"antenna_{kind}"] = int(number(rf"Found (\d+) {kind} violations\.", report))
            if metrics["antenna_net"] or metrics["antenna_pin"]:
                return "failed_check"
        elif stage == "fillers":
            self.outputs("direct_ff_fillers.odb", "direct_ff_fillers.def")
            self.template("openroad_fillers_n4.tcl")
        elif stage == "gds":
            self.gds()
        elif stage == "drc":
            self.outputs("direct_ff_drc.lyrdb")
            report = self.path / "direct_ff_drc.lyrdb"
            self.klayout("-b", TECH / "klayout/drc/sky130A_mr.drc",
                         input=self.path / "direct_ff_final.gds", top_cell=self.top, report=report,
                         feol="true", beol="true", offgrid="true", seal="false", floating_met="false")
            metrics["drc"] = violations(report, self.top)
            if metrics["drc"]:
                return "failed_check"
        elif stage == "reference":
            self.outputs("direct_ff_reference.cdl", "reference_with_masters.spice")
            self.template("openroad_lvs_reference_n4.tcl")
            cdl = read(self.path / "direct_ff_reference.cdl")
            masters = read(CELLS / "spice/sky130_fd_sc_hd.spice")
            (self.path / "reference_with_masters.spice").write_text(cdl + "\n" + masters)
        elif stage == "magic":
            self.outputs(f"lvs_magic/{self.top}_extracted.spice")
            cwd = self.path / "lvs_magic"
            (cwd / "extfiles").mkdir(parents=True, exist_ok=True)
            script = self.template("magic_extract_lvs_n4.tcl")
            source = read(script).replace("gds read direct_ff_final.gds", "gds read ../direct_ff_final.gds")
            script.write_text(source)
            self.command("magic", "-dnull", "-noconsole", "-rcfile",
                         TECH / "magic/sky130A.magicrc", cwd=cwd, stdin=source)
        elif stage == "lvs":
            self.outputs("lvs_comp.out")
            self.command("netgen", "-batch", "lvs", f"lvs_magic/{self.top}_extracted.spice {self.top}",
                         f"reference_with_masters.spice {self.top}",
                         TECH / "netgen/sky130A_setup.tcl", "lvs_comp.out")
            metrics["lvs"] = "PASS" if lvs_matches(read(self.path / "lvs_comp.out")) else "FAIL"
            if metrics["lvs"] == "FAIL":
                return "failed_check"
        return "completed"

    def run(self):
        for folder in ("logs", "tcl"):
            (self.path / folder).mkdir(exist_ok=True)
        config = self.config()
        self.state = json.loads(read(self.state_file)) if self.state_file.exists() else {
            "config": config, "stages": {name: {"status": "pending"} for name in STAGES},
        }
        require(self.state["config"] == config,
                f"Cambiaron los insumos o la utilización. Usa otro --output-root para {self.path.name}")
        stages = self.state["stages"]
        for index, stage in enumerate(STAGES):
            previous = stages[stage]
            if (previous["status"] in ("completed", "failed_check")
                    and files_available(self.path, previous["artifacts"] + [previous["log"]])):
                continue
            for name in STAGES[index:]:
                stages[name] = {"status": "pending"}
            self.log = self.path / f"logs/{stage}_{time.time_ns()}.log"
            self.artifacts = []
            entry = {"status": "running", "log": str(self.log.relative_to(self.path)), "metrics": {}}
            stages[stage] = entry
            self.save()
            print(f"{self.path.name}: {stage}", flush=True)
            try:
                status = self.execute(stage, entry["metrics"])
                require(files_available(self.path, self.artifacts), "Faltan artefactos de la etapa")
                entry.update(status=status, artifacts=self.artifacts)
            except (FlowError, OSError, ValueError, ET.ParseError, KeyboardInterrupt) as error:
                entry.update(status="failed", error=str(error) or "Interrumpido")
                with self.log.open("a") as log:
                    log.write(f"FLOW: {entry['error']}\n")
                raise
            finally:
                self.save()
        return all(stage["status"] == "completed" for stage in stages.values())


def historical():
    directory = PHYSICAL / "n4"
    row = {"architecture": "direct", "window": 4, "status": "INCOMPLETE", "source": str(directory)}
    try:
        row["synth_area_um2"] = number(
            rf"Chip area .*?:\s*({NUM})", read(ROOT / "results/synthesis/n4/direct_sky130_filtered.log"))
        floorplan = read(directory / "direct_floorplan.log")
        row["core_area_um2"] = number(rf"Core area:\s*({NUM}) um\^2", floorplan)
        bbox = re.search(rf"Die BBox:\s*\(\s*({NUM})\s+({NUM})\s*\)"
                         rf"\s*\(\s*({NUM})\s+({NUM})\s*\)", floorplan)
        if bbox:
            x_min, y_min, x_max, y_max = map(float, bbox.groups())
            row["die_area_um2"] = (x_max - x_min) * (y_max - y_min)
        hold = read(directory / "direct_repair_hold_ff.log")
        row["placed_area_um2"] = number(rf"^Design area ({NUM}) um\^2", hold)
        row["utilization_pct"] = number(rf"^Design area .*? ({NUM})% utilization", hold)
        placed = read(directory / "direct_ff_detailed_route.def")
        row["instances"] = int(number(r"^COMPONENTS (\d+) ;", placed))
        row["registers"] = len(re.findall(r"^\s+-\s+\S+\s+sky130_fd_sc_hd__dfxtp_\d+\s+\+", placed, re.M))
        row["buffers_added"] = buffers_added(
            read(ROOT / "results/synthesis/n4/direct_sky130_filtered.v"), placed)
        route = read(directory / "direct_ff_detailed_route.log")
        row["route_drc"] = int(number(r"^Violaciones DRC: (\d+)$", route))
        row["wirelength_um"] = number(r"^Total wire length = (\d+) um\.", route)
        for corner, rc in CORNERS.items():
            require(files_available(directory, [f"direct_ff_candidate_{corner}_{rc}.spef"]),
                    f"Falta SPEF histórico de {corner}")
            row.update(timing(read(directory / f"direct_ff_candidate_sta_{corner}_{rc}.log"), corner))
        antenna = read(directory / "direct_ff_antenna.log")
        for kind in ("net", "pin"):
            row[f"antenna_{kind}"] = int(number(rf"Found (\d+) {kind} violations\.", antenna))
        row["drc"] = violations(directory / "direct_ff_drc.lyrdb", "moving_average_direct")
        row["lvs"] = "PASS" if lvs_matches(read(directory / "direct_ff_lvs_v2_comp.out")) else "FAIL"
        rtl = ROOT / "results/sim_direct_n4/Vtb_direct_param"
        require(rtl.is_file() and (directory / "direct_ff_final.gds").stat().st_size,
                "Caso histórico incompleto")
        row["status"] = "PASS" if (
            row["lvs"] == "PASS" and "Estado de enrutamiento: COMPLETO" in route
            and all(row[key] == 0 for key in ("route_drc", "drc", "antenna_net", "antenna_pin"))
            and all(v >= 0 and not str(v).startswith("-") for k, v in row.items() if k.endswith("_ns"))
        ) else "FAIL"
    except (FlowError, OSError, ValueError, ET.ParseError):
        pass
    return row


def summary(root):
    fields = [
        "architecture", "window", "synth_area_um2", "placed_area_um2", "core_area_um2",
        "die_area_um2", "utilization_pct", "instances", "registers", "buffers_added",
        "wirelength_um", *[f"{c}_{s}_{m}_ns" for c in CORNERS for s in ("setup", "hold")
                           for m in ("wns", "tns")],
        "route_drc", "antenna_net", "antenna_pin", "drc", "lvs", "status", "source",
    ]
    destination = root / "summary.csv"
    with destination.with_suffix(".tmp").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fields)
        writer.writeheader()
        if (PHYSICAL / "n4").is_dir():
            writer.writerow(historical())
        for path in sorted(root.glob("*/state.json")):
            state = json.loads(read(path))
            config, stages = state["config"], state["stages"]
            statuses = set()
            valid_metrics = {}
            for stage in stages.values():
                status = stage["status"]
                if status in ("completed", "failed_check") and not files_available(
                        path.parent, stage["artifacts"] + [stage["log"]]):
                    statuses.add("pending")
                    continue
                statuses.add(status)
                valid_metrics.update(stage.get("metrics", {}))
            status = "PASS" if statuses == {"completed"} else (
                "FAIL" if statuses & {"failed", "failed_check"} else "INCOMPLETE")
            row = dict(architecture=config["architecture"], window=config["window"],
                       status=status, source=str(path.parent))
            row.update(valid_metrics)
            writer.writerow({key: row[key] for key in fields if key in row})
    destination.with_suffix(".tmp").replace(destination)
    print(destination, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--all", action="store_true", help="Ejecuta las siete configuraciones restantes")
    mode.add_argument("--summary", action="store_true", help="Regenera el CSV sin ejecutar herramientas")
    mode.add_argument("--validate", action="store_true", help="Reproduce direct N=4 al 40 %% histórico")
    parser.add_argument("--architecture", choices=("direct", "recursive"))
    parser.add_argument("--window", type=int, choices=(4, 8, 16, 32))
    parser.add_argument("--utilization", type=float, help="Utilización objetivo de floorplan en porcentaje")
    parser.add_argument("--output-root", type=Path, default=PHYSICAL)
    args = parser.parse_args()
    if args.all or args.summary or args.validate:
        if args.architecture or args.window:
            parser.error("La selección individual requiere --architecture y --window sin otro modo")
    elif not (args.architecture and args.window):
        parser.error("Indica --architecture y --window, --all, --validate o --summary")
    utilization = args.utilization if args.utilization is not None else (40 if args.validate else 47)
    if not 0 < utilization <= 60:
        parser.error("--utilization debe estar entre 0 y 60 % (excluido 0)")
    root = args.output_root.resolve()
    legacy = (PHYSICAL / "n4").resolve()
    if root.is_relative_to(legacy):
        parser.error("El directorio histórico está protegido")
    root.mkdir(parents=True, exist_ok=True)
    failures = False
    with (root / ".flow.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            parser.error(f"Hay otra ejecución usando {root}")
        if args.summary:
            summary(root)
            return 0
        cases = [(args.architecture, args.window)]
        if args.all:
            cases = [(a, n) for a in ("direct", "recursive") for n in (4, 8, 16, 32)
                     if (a, n) != ("direct", 4)]
        if args.validate:
            cases = [("direct", 4)]
        try:
            for architecture, window in cases:
                name = "validation_direct_n4" if args.validate else f"{architecture}_n{window}"
                path = (root / name).resolve()
                try:
                    require(path.parent == root and not path.is_relative_to(legacy),
                            f"Directorio de implementación no permitido: {path}")
                    success = Implementation(architecture, window, path, utilization).run()
                    print(f"{name}: {'PASS' if success else 'FAIL'}", flush=True)
                    failures |= not success
                except (FlowError, OSError, ValueError, ET.ParseError) as error:
                    failures = True
                    print(f"{name}: {error}", file=sys.stderr)
        except KeyboardInterrupt:
            failures = True
        finally:
            summary(root)
    return int(failures)


if __name__ == "__main__":
    sys.exit(main())
