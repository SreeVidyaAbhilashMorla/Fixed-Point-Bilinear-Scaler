// ============================================================
// SCALE-X: Fixed-Point Bilinear Image Scaling Engine
// ============================================================
// Parameters:
//   W_in, H_in    : Input image dimensions (known at compile time)
//   W_out, H_out  : Output image dimensions (configurable)
//   CHANNELS      : 1 = Grayscale, 3 = RGB
// ============================================================

module bilinear_scaler #(
    parameter W_in     = 64,
    parameter H_in     = 64,
    parameter W_out    = 128,
    parameter H_out    = 128,
    parameter CHANNELS = 1       // 1 = Grayscale, 3 = RGB
)(
    input  wire clk,
    input  wire rst,
    output reg  done
);

// ============================================================
// SECTION 1: Local Parameters
// ============================================================

    // Fixed-point scale factors (256 = 2^8, so we shift by 8)
    // Computed ONCE at compile time — no division in hardware!
    localparam SCALE_X = (W_in * 256) / W_out;
    localparam SCALE_Y = (H_in * 256) / H_out;

    // Memory sizes
    localparam IN_SIZE  = W_in  * H_in  * CHANNELS;
    localparam OUT_SIZE = W_out * H_out * CHANNELS;

// ============================================================
// SECTION 2: Memory Declarations
// ============================================================

    // Input image memory  (loaded once from hex file)
    reg [7:0] in_mem  [0 : IN_SIZE  - 1];

    // Output image memory (written pixel by pixel)
    reg [7:0] out_mem [0 : OUT_SIZE - 1];

// ============================================================
// SECTION 3: Load Input Image
// ============================================================

    initial begin
        $readmemh("image.hex", in_mem);
    end

// ============================================================
// SECTION 4: Pipeline Stage Registers
// ============================================================

    // --- Pixel counter (generates x_out, y_out) ---
    reg [15:0] x_out, y_out;
    reg        pipeline_active;

    // --- Stage 1 Registers: Coordinate Mapping ---
    reg [23:0] s1_x_in_fp;     // x_out * SCALE_X  (up to 16bit * 256)
    reg [23:0] s1_y_in_fp;     // y_out * SCALE_Y
    reg [15:0] s1_x_out;       // pass through for output address
    reg [15:0] s1_y_out;
    reg        s1_valid;

    // --- Stage 2 Registers: Splitting ---
    reg [15:0] s2_x0;          // integer part of x_in
    reg [15:0] s2_y0;          // integer part of y_in
    reg [7:0]  s2_a_fp;        // fractional part of x_in (0-255)
    reg [7:0]  s2_b_fp;        // fractional part of y_in (0-255)
    reg [15:0] s2_x_out;
    reg [15:0] s2_y_out;
    reg        s2_valid;

    // --- Stage 3 Registers: 4 Neighbor Pixels ---
    // For each channel: I00, I10, I01, I11
    reg [7:0]  s3_I00 [0 : CHANNELS-1];
    reg [7:0]  s3_I10 [0 : CHANNELS-1];
    reg [7:0]  s3_I01 [0 : CHANNELS-1];
    reg [7:0]  s3_I11 [0 : CHANNELS-1];
    reg [7:0]  s3_a_fp;
    reg [7:0]  s3_b_fp;
    reg [15:0] s3_x_out;
    reg [15:0] s3_y_out;
    reg        s3_valid;

    // --- Stage 4 Registers: Blended Output ---
    reg [7:0]  s4_pixel [0 : CHANNELS-1];
    reg [15:0] s4_x_out;
    reg [15:0] s4_y_out;
    reg        s4_valid;

// ============================================================
// SECTION 5: Pipeline Logic
// ============================================================

    // Loop variable for channel iteration
    integer ch;

    // Blending intermediate wires
    // Large enough to hold: 255 * 256 * 256 = ~16.7M (needs 24 bits)
    reg [23:0] term1, term2, term3, term4, blend_sum;

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            // Reset all pipeline stages
            x_out           <= 0;
            y_out           <= 0;
            pipeline_active <= 1;
            done            <= 0;
            s1_valid        <= 0;
            s2_valid        <= 0;
            s3_valid        <= 0;
            s4_valid        <= 0;
        end

        else begin

        // ====================================================
        // PIXEL COUNTER
        // Generates (x_out, y_out) for each output pixel
        // ====================================================
        if (pipeline_active) begin
            if (x_out == W_out - 1) begin
                x_out <= 0;
                if (y_out == H_out - 1) begin
                    pipeline_active <= 0;   // all pixels sent into pipeline
                end else begin
                    y_out <= y_out + 1;
                end
            end else begin
                x_out <= x_out + 1;
            end
        end

        // ====================================================
        // STAGE 1: Coordinate Mapping
        // x_in_fp = x_out * SCALE_X  (contains ×256 inside)
        // y_in_fp = y_out * SCALE_Y
        // ====================================================
        s1_x_in_fp <= x_out * SCALE_X;
        s1_y_in_fp <= y_out * SCALE_Y;
        s1_x_out   <= x_out;
        s1_y_out   <= y_out;
        s1_valid   <= pipeline_active;

        // ====================================================
        // STAGE 2: Splitting
        // x0   = integer part  = x_in_fp >> 8
        // a_fp = fraction part = x_in_fp[7:0]
        // ====================================================
        if (s1_valid) begin
            s2_x0    <= s1_x_in_fp >> 8;
            s2_y0    <= s1_y_in_fp >> 8;
            s2_a_fp  <= s1_x_in_fp[7:0];
            s2_b_fp  <= s1_y_in_fp[7:0];
            s2_x_out <= s1_x_out;
            s2_y_out <= s1_y_out;
            s2_valid <= 1;
        end else begin
            s2_valid <= 0;
        end

        // ====================================================
        // STAGE 3: Read 4 Neighbors from Input Memory
        // For each channel separately
        // address = (y * W_in + x) * CHANNELS + channel
        // ====================================================
        if (s2_valid) begin
            for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                // Clamp x0+1 and y0+1 to avoid going out of bounds
                s3_I00[ch] <= in_mem[(s2_y0 * W_in + s2_x0) * CHANNELS + ch];

                s3_I10[ch] <= in_mem[(s2_y0 * W_in +
                               (s2_x0 < W_in-1 ? s2_x0+1 : s2_x0))
                               * CHANNELS + ch];

                s3_I01[ch] <= in_mem[((s2_y0 < H_in-1 ? s2_y0+1 : s2_y0)
                               * W_in + s2_x0) * CHANNELS + ch];

                s3_I11[ch] <= in_mem[((s2_y0 < H_in-1 ? s2_y0+1 : s2_y0)
                               * W_in +
                               (s2_x0 < W_in-1 ? s2_x0+1 : s2_x0))
                               * CHANNELS + ch];
            end
            s3_a_fp  <= s2_a_fp;
            s3_b_fp  <= s2_b_fp;
            s3_x_out <= s2_x_out;
            s3_y_out <= s2_y_out;
            s3_valid <= 1;
        end else begin
            s3_valid <= 0;
        end

        // ====================================================
        // STAGE 4: Bilinear Blending (Fixed-Point)
        //
        // Formula:
        // out = (256-a)(256-b)*I00 + a(256-b)*I10
        //     + (256-a)*b*I01     + a*b*I11
        // Then >> 16 to normalize back
        //
        // Applied independently for each channel
        // ====================================================
        if (s3_valid) begin
            for (ch = 0; ch < CHANNELS; ch = ch + 1) begin

                term1 = (256 - s3_a_fp) * (256 - s3_b_fp) * s3_I00[ch];
                term2 = s3_a_fp         * (256 - s3_b_fp) * s3_I10[ch];
                term3 = (256 - s3_a_fp) * s3_b_fp         * s3_I01[ch];
                term4 = s3_a_fp         * s3_b_fp          * s3_I11[ch];

                blend_sum = term1 + term2 + term3 + term4;

                // Right shift by 16 (divide by 256×256)
                s4_pixel[ch] <= blend_sum >> 16;
            end
            s4_x_out <= s3_x_out;
            s4_y_out <= s3_y_out;
            s4_valid <= 1;
        end else begin
            s4_valid <= 0;
        end

        // ====================================================
        // STAGE 5: Write Output Pixel to Output Memory
        // address = (y_out * W_out + x_out) * CHANNELS + ch
        // ====================================================
        if (s4_valid) begin
            for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                out_mem[(s4_y_out * W_out + s4_x_out) * CHANNELS + ch]
                    <= s4_pixel[ch];
            end
        end

        end // end else (not reset)
    end // end always

// ============================================================
// SECTION 6: Done Signal + Write Output File
// ============================================================

    // Pipeline drains 4 cycles after last pixel enters
    // We track this with a shift register of valid signals
    reg [3:0] drain_sr;   // 4 stage drain shift register

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            drain_sr <= 4'b0000;
            done     <= 0;
        end else begin
            drain_sr <= {drain_sr[2:0], (~pipeline_active & s1_valid)};
            if (drain_sr[3]) begin
                done <= 1;
            end
        end
    end

    // Write output file when done
    always @(posedge done) begin
        $writememh("output.hex", out_mem);
        $display("SCALE-X: Done! Output written to output.hex");
        $finish;
    end

endmodule
