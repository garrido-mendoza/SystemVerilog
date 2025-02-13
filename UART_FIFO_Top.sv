`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: N/A (DEMO)
// Engineer: Diego Garrido-Mendoza 
// 
// Create Date: 02/08/2025 12:40:04 PM
// Module Name: UART_FIFO_Top
//
// Description: Implementation of UART 16550. Full UART 16550 could support an 
// interrupt, DMA logic, and modem control, but this model does not support these.
// 
// This model does include a 16550 Tx FIFO, which stores 16 bytes of data. It also
// includes a Rx FIFO capable of storing 16 bytes of data. Additionally, this model
// relies on a transmission logic (Tx logic) and a reception logic (Rx logic). The 
// Tx logic handles reading data from the Tx FIFO, adding formatting bits such as 
// the start bit, stop bit, parity bit, and sending these bits serially using a shift 
// register. The Rx logic collects data from an Rx pin and stores it in the Rx FIFO.
//
// This model also includes a Baud generator that relies on LSB and MSB baud divider
// values provided by the user. With these values, the baud pulse is generated.  
// 
// Additional Comments:
// UART 16550 supports two oversampling methods: 
// 1) oversampling of 16.
// 2) oversampling of 13. 
//
// The data width for UART transaction go up to 8 bits, excluding the start, stop, 
// and parity bits. This FIFO is capable of storing 8 bits of data. The depth for 
// the 16550 UART is 16, so this FIFO model is capable of storing 16 data elements. 
// 
// Global signals: clk, rst. 
// Control signals: en, push_in, pop_in. 
// Status signals: empty, full, overrun, underrun, thr_trigger. 
//
//
//////////////////////////////////////////////////////////////////////////////////

module UART_FIFO_Top #(
    parameter DATA_WIDTH = 8,   // Parameter for data width
    parameter FIFO_DEPTH = 16,  // Parameter for FIFO depth
    parameter ADDR_WIDTH = 4    // Parameter for address width
)(
    input clk,
    input rst,
    input en,               
    input push_in,          
    input pop_in,           
    input [DATA_WIDTH-1:0] din,        
    input [3:0] threshold,  
    output [DATA_WIDTH-1:0] dout,      
    output empty,           
    output full,            
    output overrun,         
    output underrun,        
    output thr_trigger      
);

reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];      
reg [ADDR_WIDTH-1:0] waddr = 0;    

// Temporary variables of reg type. Status signals.
reg empty_t;    // Used to store the value of the empty flag.    
reg full_t;     // Used to store the value of the full flag.     
reg underrun_t;
reg overrun_t;
reg thr_t;

// Temporary variables of logic type: push, pop.
// Logic type can take either reg or wire data types.
// Requirements: We don't want to push data when the FIFO is full. We don't want to pop data when the FIFO is empty.
// We are not using push_in and pop_in to deal with these requirements because these inputs can be randomly high or low.
// Instead, we use 'push' and 'pop.' The behavior of push and pop are controlled by the user based on the empty and full flags.
logic push; // Push will be zero if the full flag is set.  
logic pop;  // Pop will be zero if the empty flag is set.  

// Empty flag logic.
// When FIFO is empty during a read operation.
// If pop is high, an OR operation is performed on all the bits of the write address.
// The write address keeps track of the number of bytes stored in the FIFO.
// ~|(waddr): If we have a byte stored in the FIFO, after ORing the eight bits, we'll get one to indicate that this byte can be read.
// This means that the empty_t flag will be high, but because of the not-operator, the empty_t flag is actually pulled low.
// Now, when the waddr signal itself is zero, once the 8 bits are ORed, the empty_t flag gets asserted because of the not-operator.
// |~(en): When the FIFO is not enabled, the FIFO is empty because no data has been written into the FIFO yet, since it's disabled.
// This means that the empty_t flag will be pulled high.
always @(posedge clk, posedge rst) begin
    if (rst) begin
        empty_t <= 1'b1;    // Initialize to empty state.  
    end else begin
        case ({push, pop})  
            2'b01: empty_t <= (~|(waddr) |~(en));   
            2'b10: empty_t <= 1'b0; // When the push operation is performed, data will be written into the FIFO; thus, the empty_t flag will be pulled low (reset). 
            default: ;
        endcase
    end
end

// Full flag logic.
// When FIFO is full during a write operation.
// &(waddr): If push is high, an AND operation is performed on all the bits of the write address. The FIFO will be full when the address 15 is reached.
// When address 15 is reached, all the bits of the write address will be one. By ANDing all these bits, we set the full flag.
// ~(en): If enable is zero, the full flag is set, as well. When the FIFO is not enabled, both the empty and full flags are asserted.
// In the case of a pop event when the FIFO is full, the full flag gets reset because if the FIFO is full but we request reading back data,
// the FIFO won't remain in a full state.
always @(posedge clk, posedge rst) begin
    if (rst) begin
        full_t <= 1'b0; // Initialize to not full state.  
    end else begin
        case ({push, pop})  
            2'b10: full_t <= (&(waddr) |~(en)); 
            2'b01: full_t <= 1'b0;
            default: ;
        endcase
    end    
end

// Push & pop assignment conditions.
assign push = push_in & ~full_t;    // We don't want to push data when the FIFO is full. Push must be high only when the FIFO has some storage space left in it.    
assign pop = pop_in & ~empty_t;     // We don't want to pop data when the FIFO is empty. Pop must be high only when the FIFO has some data left in it.     

// Read FIFO assignment.
assign dout = mem[0];

// Write address update logic: This block updates the write address.
// In the case of a push operation (when the user wants to write data), we verify that the address is not equal to 15 (last FIFO storage slot)
// and that the full flag is low. If this condition is met, that means that there are still a few storage locations available in the FIFO.
// Then, we increment the address by one, and we add the new element to the address.
always @(posedge clk, posedge rst) begin
    if (rst) begin
        waddr <= 4'h0;
    end else begin
        case ({push, pop})
            2'b10: begin
                if (waddr != FIFO_DEPTH-1 && full_t == 1'b0)        
                    waddr <= waddr + 1;                 
                else
                    waddr <= waddr;
            end
            2'b01: begin
                if (waddr != 4'h0 && empty_t == 1'b0)
                    waddr <= waddr - 1;
                else
                    waddr <= waddr;
            end
            default: ;
        endcase
    end
end

// Memory update logic: This block updates the memory contents.
// In the case of a push operation (2'b10), data input is stored in the memory at the write address.
// In the case of a pop operation (2'b01), memory content is shifted left, and the last memory slot is zeroed out.
// In the case of simultaneous push and pop (2'b11), the same left shift operation is performed before storing the input data.
always @(posedge clk, posedge rst) begin
    if (rst) begin
        for (int i = 0; i < FIFO_DEPTH; i++)
            mem[i] <= {DATA_WIDTH{1'b0}};
    end else begin
        case ({push, pop})
            2'b00: ;
            2'b01: begin    
                for (int i = 0; i < FIFO_DEPTH-2; i++) begin
                    mem[i] <= mem[i+1];
                end
                mem[FIFO_DEPTH-1] <= {DATA_WIDTH{1'b0}};
            end
            2'b10: begin
                mem[waddr] <= din;
            end
            2'b11: begin
                for (int i = 0; i < FIFO_DEPTH-2; i++) begin
                    mem[i] <= mem[i+1];
                end
                mem[FIFO_DEPTH-1] <= {DATA_WIDTH{1'b0}};
                mem[waddr - 1] <= din;
            end
        endcase
    end
end

// Underrun logic: This block sets the underrun flag if a pop operation is attempted when the FIFO is empty.
always @(posedge clk, posedge rst) begin
    if (rst)
        underrun_t <= 1'b0;
    else if (pop_in == 1'b1 && empty_t == 1'b1)
        underrun_t <= 1'b1;
    else
        underrun_t <= 1'b0;
end

// Overrun logic: This block sets the overrun flag if a push operation is attempted when the FIFO is full.
always @(posedge clk, posedge rst) begin
    if (rst)
        overrun_t <= 1'b0;
    else if (push_in == 1'b1 && full_t == 1'b1)
        overrun_t <= 1'b1;
    else
        overrun_t <= 1'b0;
end

// Threshold logic.
// Threshold trigger occurs during write operations.
// Since the threshold flag does not depend on the empty and full status.
always @(posedge clk, posedge rst) begin
    if (rst) begin
        thr_t <= 1'b0;
    end else if (push ^ pop) begin  // The ^ operator is a bitwise XOR (exclusive OR) operator. It compares the corresponding bits of two operands
                                    // and returns 1 if the bits are different and 0 if they are the same.
                                    // This XOR operation is to prevent the threshold trigger to take effect when read and write are performed simultaneously.
                                    // So, if push is high and pop is low, that's a valid operation that will set the threshold flag.
                                    // If pop is high and push is low, this expression will also evaluate to true. But, since we are performing a pop, the
                                    // current value of the write address will not be incremented further.
        thr_t <= (waddr >= threshold) ? 1'b1 : 1'b0;    // Write address update.
                                                        // If the write address exceeds the threshold, then the threshold trigger will be asserted.    
    end            
end

// Assignments for status signals.
assign empty = empty_t;
assign full = full_t;
assign overrun = overrun_t;
assign underrun = underrun_t;
assign thr_trigger = thr_t;

endmodule

