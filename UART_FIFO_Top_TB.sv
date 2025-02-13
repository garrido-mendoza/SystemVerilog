//`timescale 1ps / 1ps

module UART_FIFO_Top_TB();
    logic clk;
    logic rst;
    logic en;
    logic push_in;
    logic pop_in;
    logic [7:0] din;
    logic [3:0] threshold;
    logic [7:0] dout;
    logic empty;
    logic full;
    logic overrun;
    logic underrun;
    logic thr_trigger;
    
    // Seed for random number generation
    int seed = 12345;  // Set a specific seed value for repeatability
    
    initial begin
        clk = 0;
        rst = 0;
        en = 0;
        push_in = 0;
        pop_in = 0;
        din = 0;
        threshold = 4'hA;  // Set threshold value
    end
    
    UART_FIFO_Top uut_UART_FIFO (
        .clk(clk),
        .rst(rst),
        .en(en),
        .push_in(push_in),
        .pop_in(pop_in),
        .din(din),
        .dout(dout),
        .empty(empty),
        .full(full),
        .overrun(overrun),
        .underrun(underrun),
        .threshold(threshold),
        .thr_trigger(thr_trigger)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        // Assert reset
        rst = 1'b1;
        repeat(5) @(posedge clk);
        rst = 1'b0;
        
        // Enable FIFO and push data
        en = 1'b1;
        for (int i = 0; i < 20; i++) begin  // Write 20 random data items into the FIFO. 
            push_in = 1'b1;
            din = $urandom(seed);  // Use the specific seed value
            pop_in = 1'b0;
            @(posedge clk); // Wait for a single clock cycle (tick).
            // Display din value in TCL console
            $display("Cycle %0d: Pushing data - din: %h", i, din);
            seed = seed + 1;  // Change the seed for the next iteration
        end
        
        // Read data from FIFO
        for (int i = 0; i < 20; i++) begin
            push_in = 1'b0;
            din = 0;    // 'din' does not play any role during the read operation. 
            pop_in = 1'b1;
            @(posedge clk);
            // Display dout value in TCL console
            $display("Cycle %0d: Popping data - dout: %h", i, dout);
        end
        
        // End simulation
        $finish;
    end    

endmodule
