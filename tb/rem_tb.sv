//`define ASYNC
`include "../rtl/rem.v"
`timescale 1ns/100ps

module rem_tb;

reg clk;
initial clk = 0;
always #4.446 clk = ~clk;
reg rstn;

task reset_n;
	rstn = 0;
	repeat(10) @(negedge clk);
	rstn = 1;
endtask

task reset_p;
	rstn = 1;
	repeat(10) @(negedge clk);
	rstn = 0;
endtask

parameter MSB = 7;
wire ack;
wire [1:0] cst, nst;
reg req;
wire [MSB:0] tx_data;
reg [MSB:0] rx_data_2;
reg [2*(MSB+1)-1:0] rx_data_1;
reg enable;
rem #(
	.MSB(MSB) 
) u_rem(
	.ack(ack), 
	.cst(cst), .nst(nst), 
	.req(req), 
	.tx_data(tx_data), 
	.rx_data_2(rx_data_2), 
	.rx_data_1(rx_data_1), 
	.enable(enable), 
	.rstn(rstn), .clk(clk) 
);

task enable_p;
	enable = 0;
	repeat(10) @(negedge clk);
	enable = 1;
endtask

task enable_n;
	enable = 1;
	repeat(10) @(negedge clk);
	enable = 0;
endtask

task test1;
	$display("test1 start");
	enable_p;
	repeat(10) begin
		rx_data_1 = $urandom_range(0, 2**(2**(MSB+1))-1);
		rx_data_2 = $urandom_range(0, 2**MSB);
		req = ~req;
		@(posedge ack);
	end
	enable_n;
	$display("test1 end");
endtask

initial begin
	rx_data_1 = $urandom_range(0, 2**(2**(MSB+1))-1);
	rx_data_2 = $urandom_range(0, 2**MSB);
	req = 0;
	reset_n;
	repeat(10) test1;
	reset_p;
	$finish;
end

initial begin
	$dumpfile("../work/rem_tb.fst");
	$dumpvars(0, rem_tb);
end

endmodule
