# Fixed-Point-Bilinear-Scaler
Parameterized fixed-point bilinear image scaling engine in Verilog HDL supporting grayscale and RGB images with a pipelined RTL architecture.

# Overview

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

    # Architecture

## Overview

The SCALE-X image scaler is implemented as a **five-stage pipelined architecture** that performs fixed-point bilinear interpolation for each output pixel. Rather than processing one pixel completely before moving to the next, different stages of the interpolation process operate simultaneously on consecutive pixels, improving hardware utilization and throughput.

The design stores the complete input image in on-chip memory and processes each output pixel by first mapping it to the corresponding input coordinate, extracting the four neighboring pixels, computing the interpolation using fixed-point arithmetic, and finally writing the generated pixel into the output memory.

### Pipeline Stages
<img width="1672" height="941" alt="architecture" src="https://github.com/user-attachments/assets/2146b30b-8162-4d1b-b3d9-9ecad24a67dc" />

The pipeline operates continuously until every output pixel has been processed. Once the final pixel exits the pipeline, the generated image is written to an output hexadecimal file using `$writememh`.

