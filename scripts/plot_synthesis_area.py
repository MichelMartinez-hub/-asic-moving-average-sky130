import csv

from pathlib import Path


import matplotlib

matplotlib.use("Agg")


import matplotlib.pyplot as plt


# Directorios

ROOT = Path("results")

CSV = ROOT / "synthesis" / "synthesis_area.csv"

OUT = ROOT / "figures"


OUT.mkdir(parents=True, exist_ok=True)


# Leer resultados

window = []

direct = []

recursive = []


with CSV.open() as file:

    reader = csv.DictReader(file)


    for row in reader:

        window.append(int(row["window"]))

        direct.append(float(row["direct_area_um2"]))

        recursive.append(float(row["recursive_area_um2"]))


# Crear figura

fig, ax = plt.subplots(figsize=(8, 5))


ax.plot(

    window,

    direct,

    marker="o",

    linewidth=2,

    label="Arquitectura directa"

)


ax.plot(

    window,

    recursive,

    marker="s",

    linewidth=2,

    label="Arquitectura recursiva"

)


# Configuracion

ax.set_xlabel("Longitud de ventana (N)")

ax.set_ylabel("Area de celdas estandar (um²)")


ax.set_title(

    "Comparacion de area sintetizada - SKY130"

)


ax.set_xticks(window)

ax.set_xscale("log", base=2)


ax.grid(True, alpha=0.3)

ax.legend()


fig.tight_layout()


# Guardar resultados

fig.savefig(

    OUT / "synthesis_area.png",

    dpi=300

)


fig.savefig(

    OUT / "synthesis_area.svg"

)


plt.close(fig)


print("Graficas generadas correctamente.")
