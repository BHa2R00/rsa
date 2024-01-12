module rem #(
	parameter MSB = 7 
)(
	output ack, 
	output reg [1:0] cst, nst, 
	input req, 
	output reg [MSB:0] tx_data, 
	input [MSB:0] rx_data_2, 
	input [2*(MSB+1)-1:0] rx_data_1, 
	input enable, 
`ifdef ASYNC
	input async_se, lck, test_se, 
`endif
	input rstn, clk 
);

`ifdef ASYNC
wire clk0 = test_se ? clk : async_se ? lck  : clk;
`endif

reg [2*(MSB+1)-1:0] r;
reg [MSB:0] b;
wire [2*(MSB+1)-1:0] nst_r = r + ~{{(MSB+1){b[MSB]}}, b} + 1;
wire lt = nst_r[2*(MSB+1)-1];
wire eq0 = b == 0;

`ifndef GRAY
	`define GRAY(X) (X^(X>>1))
`endif
localparam [1:0]
	st_calc		= `GRAY(3),
	st_if		= `GRAY(2),
	st_load		= `GRAY(1),
	st_idle		= `GRAY(0);
reg req_d;
`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) req_d <= 1'b0;
	else if(enable) req_d <= req;
end
wire req_x = req_d ^ req;
`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) cst <= st_idle;
	else if(enable) cst <= nst;
end
always@(*) begin
	case(cst)
		st_idle: nst = req_x ? st_load : cst;
		st_load: nst = st_if;
		st_if: nst = (lt || eq0) ? st_idle : st_calc;
		st_calc: nst = st_if;
		default: nst = st_idle;
	endcase
end
assign ack = cst == st_idle;

`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) begin
		r <= 0;
		b <= 0;
		tx_data <= 0;
	end
	else if(enable) begin
		case(nst)
			st_load: begin
				r <= rx_data_1;
				b <= rx_data_2;
			end
			st_calc: r <= nst_r;
			st_idle: tx_data <= r[MSB:0];
			default: begin
				r <= r;
				b <= b;
				tx_data <= tx_data;
			end
		endcase
	end
end

endmodule
