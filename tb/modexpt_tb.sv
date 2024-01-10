//`define ASYNC
`include "../rtl/modular.v"
`timescale 1ns/100ps

module modexpt_tb;

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

parameter I_MSB = 2;
parameter J_MSB = 10;

wire ack;
reg req;
wire [(2**(I_MSB+1)-1):0] tx_data;
reg [(2**(J_MSB+1)-1):0] rx_data_2;
reg [(2**(I_MSB+1)-1):0] rx_data_1, rx_data_3;
reg enable;
modexpt #(
	.I_MSB(I_MSB), 
	.J_MSB(J_MSB)
) u_modexpt(
	.ack(ack), 
	.req(req), 
	.tx_data(tx_data), 
	.rx_data_2(rx_data_2), 
	.rx_data_1(rx_data_1), .rx_data_3(rx_data_3), 
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
		rx_data_1 = $urandom_range(0, 2**(2**(I_MSB+1))-1);
		rx_data_2 = $urandom_range(1, 2**(2**(J_MSB+1))-1);
		rx_data_3 = $urandom_range(1, 2**(2**(I_MSB+1))-1);
		req = ~req;
		@(posedge ack);
		$display("(modexpt %d %d %d) -> %d", rx_data_1, rx_data_2, rx_data_3, tx_data);
	end
	enable_n;
	$display("test1 end");
endtask

initial begin
	rx_data_1 = $urandom_range(0, 2**(2**(I_MSB+1))-1);
	rx_data_2 = $urandom_range(1, 2**(2**(J_MSB+1))-1);
	rx_data_3 = $urandom_range(1, 2**(2**(I_MSB+1))-1);
	req = 0;
	reset_n;
	repeat(10) test1;
	reset_p;
	$finish;
end

initial begin
  $dumpfile("../work/modexpt_tb.fst");
	$dumpvars(0, modexpt_tb);
end

endmodule
