//`timescale 1ns / 1ps

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
    
    initial begin
        clk = 0;
        rst = 0;
        en = 0;
        din = 0;
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
        rst = 1'b1;
        repeat(5) @(posedge clk);
        
        for (int i = 0; i < 20; i++) begin  // Write 20 random data items into the FIFO. 
            rst = 1'b0;
            push_in = 1'b1;
            din = $urandom();
            pop_in = 1'b0;
            en = 1'b1;
            threshold = 4'hA;
            @(posedge clk); // Wait for a single clock cycle (tick).
        end
        
        // Read
        for (int i = 0; i < 20; i++) begin
            rst = 1'b0;
            push_in = 1'b0;
            din = 0;    // 'din' does not play any role during the read operation. 
            pop_in = 1'b1;
            en = 1'b1;
            threshold = 4'hA;   // Threshold only plays a role during write operations.  
            @(posedge clk);
        end
    end    

endmodule
