from pathlib import Path

import re

import csv


# Directorio de resultados

ROOT = Path("results/synthesis")


WINDOWS = [4, 8, 16, 32]


rows = []


def extract_area(log_file):


    text = log_file.read_text()


    match = re.search(

        r"Chip area for module [^\n]+?:\s*([\d.]+)",

        text

    )


    if not match:

        raise RuntimeError(

            f"No se encontró el área en {log_file}"

        )


    return float(match.group(1))



for n in WINDOWS:


    folder = ROOT / f"n{n}"


    suffix = "_sky130_filtered.log" if n == 4 else "_sky130.log"


    direct_log = folder / f"direct{suffix}"

    recursive_log = folder / f"recursive{suffix}"


    direct_area = extract_area(direct_log)

    recursive_area = extract_area(recursive_log)


    difference = (

        (recursive_area - direct_area)

        / direct_area

    ) * 100


    rows.append({

        "window": n,

        "direct_area_um2": f"{direct_area:.4f}",

        "recursive_area_um2": f"{recursive_area:.4f}",

        "difference_percent": f"{difference:.4f}"

    })



output = ROOT / "synthesis_area.csv"


with output.open("w", newline="") as file:


    writer = csv.DictWriter(

        file,

        fieldnames=rows[0].keys()

    )


    writer.writeheader()

    writer.writerows(rows)



print(f"Resultados guardados en: {output}")


for row in rows:

    print(row)
