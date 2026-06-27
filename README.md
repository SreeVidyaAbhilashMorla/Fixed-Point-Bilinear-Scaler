# Fixed-Point-Bilinear-Scaler
Parameterized fixed-point bilinear image scaling engine in Verilog HDL supporting grayscale and RGB images with a pipelined RTL architecture.

## Overview

**SCALE-X** is a parameterized hardware accelerator for image scaling using **fixed-point bilinear interpolation**, implemented in **Verilog HDL**. The design resizes grayscale and RGB images while avoiding floating-point arithmetic, making it suitable for FPGA and ASIC-oriented digital image processing applications.

The scaler maps each output pixel to its corresponding input coordinate using fixed-point arithmetic, retrieves the four nearest neighboring pixels, and computes the interpolated output through bilinear interpolation. The entire computation is organized as a pipelined architecture to improve throughput while maintaining a synthesizable RTL implementation.

The design supports configurable input and output image resolutions through Verilog parameters and performs all interpolation using **8-bit fixed-point precision**.

For simulation, the design reads **pre-generated hexadecimal image files** using `$readmemh` and writes the scaled output image back as a hexadecimal file using `$writememh`. Image-to-hex conversion is not included in this repository and is considered a preprocessing step.

##  Features

* **Parameterized Image Scaling**

  * Supports configurable input and output image resolutions through Verilog parameters, enabling reuse across different scaling ratios.

* **Fixed-Point Bilinear Interpolation**

  * Implements bilinear interpolation using **8-bit fixed-point arithmetic**, eliminating the need for floating-point hardware while maintaining interpolation accuracy.

* **Grayscale and RGB Support**

  * Processes both **single-channel grayscale** and **three-channel RGB** images through a configurable `CHANNELS` parameter.

* **Five-Stage Pipelined Architecture**

  * Organizes computation into dedicated pipeline stages for coordinate mapping, fractional extraction, neighbor pixel fetching, interpolation, and output memory write-back, improving processing throughput.

* **Compile-Time Scale Factor Computation**

  * Computes horizontal and vertical scaling factors as local parameters, avoiding runtime division operations and reducing hardware complexity.

* **Boundary-Aware Pixel Access**

  * Safely handles image edges by clamping neighboring pixel indices, preventing out-of-bounds memory accesses during interpolation.

* **Memory-Based Image Processing**

  * Uses on-chip memory arrays to store input and output images, with image data loaded through `$readmemh` and exported using `$writememh`.

* **Configurable Multi-Resolution Design**

  * Easily adapts to different image dimensions without modifying the core interpolation architecture.

    ## Architecture

### Overview

The SCALE-X image scaler is implemented as a **five-stage pipelined architecture** that performs fixed-point bilinear interpolation for each output pixel. Rather than processing one pixel completely before moving to the next, different stages of the interpolation process operate simultaneously on consecutive pixels, improving hardware utilization and throughput.

The design stores the complete input image in on-chip memory and processes each output pixel by first mapping it to the corresponding input coordinate, extracting the four neighboring pixels, computing the interpolation using fixed-point arithmetic, and finally writing the generated pixel into the output memory.

<img width="1672" height="941" alt="architecture" src="https://github.com/user-attachments/assets/2146b30b-8162-4d1b-b3d9-9ecad24a67dc" />

The pipeline operates continuously until every output pixel has been processed. Once the final pixel exits the pipeline, the generated image is written to an output hexadecimal file using `$writememh`.

## Pipeline Stages
### Stage 1 – Coordinate Mapping

### Coordinate Mapping

The corresponding input coordinates are computed from the output pixel coordinates using the horizontal and vertical scaling factors:

```text
x_in(fp) = x_out × SCALE_X

y_in(fp) = y_out × SCALE_Y
```

where the scaling factors are computed once at compile time as:

```text
SCALE_X = (W_in × 256) / W_out

SCALE_Y = (H_in × 256) / H_out
```

The multiplication by **256 (2⁸)** converts the scaling factors into **Q8 fixed-point format**, providing **8 fractional bits** of precision while eliminating runtime division and floating-point operations.

At the end of this stage, the fixed-point input coordinates are registered and forwarded to the next pipeline stage for integer and fractional component extraction.

### Stage 2 – Integer and Fraction Extraction

The fixed-point input coordinates generated in the previous stage are separated into their **integer** and **fractional** components. The integer portion identifies the top-left neighboring pixel in the input image, while the fractional portion represents the relative distance from that pixel and is later used to compute the interpolation weights.

The extraction is performed using simple bit operations:

```text
x0   = x_in(fp) >> 8
y0   = y_in(fp) >> 8

a_fp = x_in(fp)[7:0]
b_fp = y_in(fp)[7:0]
```

where:

| Parameter  | Description                                              |
| ---------- | -------------------------------------------------------- |
| `x0`, `y0` | Integer coordinates of the top-left neighboring pixel    |
| `a_fp`     | Fractional distance along the x-axis (8-bit fixed-point) |
| `b_fp`     | Fractional distance along the y-axis (8-bit fixed-point) |

Using bit slicing and right-shift operations eliminates complex arithmetic while preserving the fractional precision required for bilinear interpolation. The extracted coordinates and interpolation weights are then registered and forwarded to the next stage for neighboring pixel retrieval.

### Stage 3 – Neighbor Pixel Fetch

Once the integer coordinates are obtained, the scaler retrieves the four neighboring pixels required for bilinear interpolation from the input image memory. These pixels correspond to the corners surrounding the mapped input coordinate and are used to compute the interpolated output pixel.

The neighboring pixels are defined as:

```text
I00 = I(x0,     y0)
I10 = I(x0 + 1, y0)
I01 = I(x0,     y0 + 1)
I11 = I(x0 + 1, y0 + 1)
```

The input image is stored as a one-dimensional memory array. Each pixel is accessed using the address:

```text
Address = (y × W_in + x) × CHANNELS + channel
```

where `CHANNELS` is configurable as **1** for grayscale images or **3** for RGB images. For RGB images, the Red, Green, and Blue components are fetched independently while sharing the same pixel coordinates.

To prevent out-of-bounds memory accesses at the image boundaries, the design clamps the values of `x0 + 1` and `y0 + 1` to the valid image dimensions. This ensures that interpolation can be performed safely even for pixels located along the rightmost column or bottom row of the input image.

The retrieved neighboring pixels, along with the fractional interpolation weights (`a_fp` and `b_fp`), are registered and forwarded to the next pipeline stage for fixed-point bilinear interpolation.

### Stage 4 – Fixed-Point Bilinear Interpolation

In this stage, the four neighboring pixels are combined using the standard bilinear interpolation equation. Instead of floating-point arithmetic, the interpolation weights are represented using **8-bit fixed-point precision**, allowing the computation to be performed entirely with integer multiplications and additions.

The interpolation is evaluated as:

```text
Output =
((256-a) × (256-b) × I00 +
 a × (256-b) × I10 +
 (256-a) × b × I01 +
 a × b × I11) >> 16
```

where:

| Parameter | Description                                  |
| --------- | -------------------------------------------- |
| `I00`     | Top-left neighboring pixel                   |
| `I10`     | Top-right neighboring pixel                  |
| `I01`     | Bottom-left neighboring pixel                |
| `I11`     | Bottom-right neighboring pixel               |
| `a`       | Fractional distance along the x-axis (0–255) |
| `b`       | Fractional distance along the y-axis (0–255) |

The interpolation is implemented by computing four weighted products (`term1`, `term2`, `term3`, and `term4`), accumulating them into a single intermediate result, and finally performing a **16-bit right shift (`>>16`)** to normalize the value back to an 8-bit pixel intensity.

For RGB images, the same computation is performed independently for each color channel, whereas grayscale images require only a single interpolation operation. The resulting interpolated pixel values are then registered and forwarded to the final pipeline stage for storage.

### Stage 5 – Output Memory Write

The interpolated pixel values generated in the previous stage are written into the output image memory. Each pixel is stored at the corresponding output image location using the address:

```text
Address = (y_out × W_out + x_out) × CHANNELS + channel
```

This addressing scheme supports both grayscale and RGB images, with each color channel written independently when processing multi-channel images.

After all output pixels have passed through the pipeline, a drain mechanism ensures that the remaining valid data exits the pipeline before asserting the **`done`** signal. Once processing is complete, the contents of the output memory are exported as a hexadecimal file using Verilog's `$writememh` system task.

The generated `output.hex` file contains the resized image data and serves as the final output of the SCALE-X image scaling engine for simulation and verification.

# Fixed-Point Arithmetic

Floating-point arithmetic provides high numerical precision but requires complex hardware, making it unsuitable for lightweight FPGA and ASIC implementations. To achieve an efficient and synthesizable design, the SCALE-X engine performs all computations using **8-bit fixed-point (Q8) arithmetic**.

### Fixed-Point Representation

The horizontal and vertical scaling factors are represented with **8 fractional bits** by multiplying the scaling ratio by **256 (2⁸)** during compile time.

```text
SCALE_X = (W_in × 256) / W_out
SCALE_Y = (H_in × 256) / H_out
```

This representation preserves the fractional component of the scaling ratio while avoiding runtime division operations.

### Fractional Coordinate Extraction

After coordinate mapping, the fixed-point values are separated into integer and fractional components using simple bit operations.

```text
Integer Part    = Coordinate >> 8
Fractional Part = Coordinate[7:0]
```

The integer portion determines the neighboring pixel locations, while the fractional portion serves as the interpolation weights.

### Fixed-Point Bilinear Interpolation

Instead of using floating-point weights ranging from **0 to 1**, the implementation represents them as **0 to 255**. The interpolation is performed using integer multiplications and additions:

```text
Output =
((256-a)(256-b)I00 +
 a(256-b)I10 +
 (256-a)bI01 +
 abI11) >> 16
```

The final **16-bit right shift (`>>16`)** normalizes the accumulated result back to an 8-bit pixel value, since each interpolation weight contributes a scaling factor of **256 × 256**.

### Advantages

* Eliminates floating-point hardware.
* Avoids runtime division by using compile-time scaling factors.
* Uses only integer arithmetic, bit shifts, multiplications, and additions.
* Produces a synthesizable and hardware-efficient implementation suitable for FPGA and ASIC designs while maintaining interpolation accuracy.

  ## Simulation

The SCALE-X image scaling engine was functionally verified using **Xilinx Vivado Simulator**. The design reads a pre-generated hexadecimal image file, performs fixed-point bilinear interpolation, and writes the resized image back as a hexadecimal file for verification.

### Simulation Steps

1. Open the project in **Xilinx Vivado**.
2. Add the Verilog source file from the `rtl/` directory and the testbench from the `tb/` directory.
3. Select the desired input image (`grayscale.hex` or `rgb.hex`) from the `data/` directory and rename it to **`image.hex`**.
4. Place `image.hex` in the simulation working directory so it can be accessed by the `$readmemh` system task.
5. Run the behavioral simulation.
6. Once the simulation completes, the scaler automatically generates **`output.hex`** using the `$writememh` system task.
7. The generated hexadecimal file can then be converted back to an image using any suitable external utility for visual verification.

## Results

The SCALE-X image scaling engine was validated using both **grayscale** and **RGB** test images. The visual results demonstrate that the fixed-point bilinear interpolation implementation successfully produces smooth scaled images while preserving image details.

## Grayscale Image Scaling

|                     Input Image                    |                    Scaled Output                    |
| :------------------------------------------------: | :-------------------------------------------------: |
| <img width="64" height="64" alt="test_grayscale_64x64" src="https://github.com/user-attachments/assets/687bd9e6-19b1-4e17-9c03-1dc695e90ea8" />| <img width="128" height="128" alt="output_greyscale_128x128" src="https://github.com/user-attachments/assets/4ca9be45-0001-44eb-bffd-dd8453f2cdd8" />|

---

## RGB Image Scaling

|                  Input Image                 |                 Scaled Output                 |
| :------------------------------------------: | :-------------------------------------------: |
| <img width="64" height="64" alt="test_rgb_64x64" src="https://github.com/user-attachments/assets/0013489d-1fd7-4355-acd4-8c99b0137e56" />| <img width="128" height="128" alt="output_rgb_128x128" src="https://github.com/user-attachments/assets/38a17fbe-4e59-4f52-96e8-7683126ae4af" />|

The generated output images confirm the correct operation of the five-stage pipelined architecture and the fixed-point bilinear interpolation algorithm for both supported image formats.
