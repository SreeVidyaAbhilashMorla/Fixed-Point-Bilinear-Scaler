# Data Files

This directory contains the hexadecimal image files used by the SCALE-X image scaling engine during simulation.

The Verilog design loads the input image using the `$readmemh` system task. To simplify simulation, rename the desired input file (`grayscale.hex` or `rgb.hex`) to **`image.hex`** before running the simulation. The generated scaled image is written to **`output.hex`** using `$writememh`.

Available input files:

* `grayscale.hex` – 8-bit grayscale input image
* `rgb.hex` – 8-bit RGB input image

**Note:** The image-to-hex conversion process is not included in this repository. The provided hexadecimal files are pre-generated and are intended solely for simulation and verification of the hardware design.
