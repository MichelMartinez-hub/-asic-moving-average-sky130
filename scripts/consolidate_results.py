import csv

import re

from pathlib import Path


# Archivos de entrada

AREA_CSV = Path("results/synthesis/synthesis_area.csv")

TIMING_DIR = Path("results/timing")


# Archivo de salida

OUTPUT = Path("results/preplacement_comparison.csv")



def extract_wns(architecture, n):

    log = TIMING_DIR / f"{architecture}_n{n}_sta.log"


    text = log.read_text()


    match = re.search(

        r"worst slack max\s+([-+]?\d+(?:\.\d+)?)",

        text

    )


    if match is None:

        raise ValueError(f"WNS no encontrado: {log}")


    return float(match.group(1))



results = []


with AREA_CSV.open(newline="") as file:

    reader = csv.DictReader(file)


    for row in reader:


        n = int(row["window"])


        direct_wns = extract_wns("direct", n)

        recursive_wns = extract_wns("recursive", n)


        results.append({

            "window": n,

            "direct_area_um2": row["direct_area_um2"],

            "recursive_area_um2": row["recursive_area_um2"],

            "area_difference_percent": row["difference_percent"],

            "direct_wns_ns": direct_wns,

            "recursive_wns_ns": recursive_wns,

            "wns_difference_ns": round(

                recursive_wns - direct_wns, 4

            ),

        })



OUTPUT.parent.mkdir(parents=True, exist_ok=True)


with OUTPUT.open("w", newline="") as file:


    writer = csv.DictWriter(

        file,

        fieldnames=results[0].keys()

    )


    writer.writeheader()

    writer.writerows(results)



print(f"Resultados guardados en: {OUTPUT}")

print(f"Configuraciones procesadas: {len(results)}")
