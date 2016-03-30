// $Id: $
// File name:   sync_high.sv
// Created:     1/28/2016
// Author:      Tian Qiu
// Lab Section: 337-05
// Version:     1.0  Initial Design Entry
// Description: synchigh

module sync_high
(
 input wire clk,
 input wire n_rst,
 input wire async_in,
 output reg sync_out
 );

   reg 	    Q;
   

   always_ff @ (posedge clk, negedge n_rst)
   begin:sync_high
      if (1'b0 == n_rst) begin
	 Q <= 1;
	 sync_out <= 1;
      end
      else begin
	 Q <= async_in;  // input to Q, Q to output
	 sync_out <= Q;
      end
   end
	 
endmodule
