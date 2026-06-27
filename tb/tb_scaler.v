// ============================================================
// Testbench for bilinear_scaler
// ============================================================

`timescale 1ns/1ps

module tb_bilinear_scaler;

    // Clock and reset
    reg clk;
    reg rst;
    wire done;

    // Instantiate the scaler
    // Change parameters here to test different configurations
    bilinear_scaler #(
        .W_in     (64),       // Input width
        .H_in     (64),       // Input height
        .W_out    (128),      // Output width
        .H_out    (128),      // Output height
        .CHANNELS (3)         // 1=Grayscale, 3=RGB
    ) uut (
        .clk  (clk),
        .rst  (rst),
        .done (done)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset and run
    initial begin
        $display("SCALE-X Testbench Starting...");
        rst = 1;
        #20;
        rst = 0;
        $display("Reset released. Pipeline running...");

        // Wait for done signal (timeout after 1M cycles)
        #10000000;
        $display("Timeout! Something went wrong.");
        $finish;
    end

    // Monitor done
    always @(posedge done) begin
        $display("Scaling complete!");
    end

    // Optional: dump waveforms
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_bilinear_scaler);
    end

endmodule
