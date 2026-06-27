# Data Files

# Data Files

This directory contains the hexadecimal files used for simulation of the SCALE-X image scaling engine.

## Input Files

The Verilog design reads the input image using the `$readmemh` system task. To run a simulation, rename the desired input file (`grayscale.hex` or `rgb.hex`) to **`image.hex`** and place it in the simulation working directory.

Available input files:

* `grayscale.hex` – 8-bit grayscale input image
* `rgb.hex` – 8-bit RGB input image

## Output Files

After the simulation completes, the generated scaled image is written to **`output.hex`** using the `$writememh` system task.

The `output.hex` file contains the pixel values of the resized image. To visualize the simulation result, convert the generated hexadecimal file back into a standard image format (e.g., PNG) using an external image conversion utility.

> **Note:** Image-to-hex and hex-to-image conversion utilities are not included in this repository. The provided hexadecimal files are intended solely for functional simulation and verification of the hardware design.
