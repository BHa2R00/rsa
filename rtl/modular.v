`include "../rtl/rem.v"

module modmult #(
	parameter MSB = 7, 
	parameter I_MSB = 2 
)(
	output ack, 
	output reg [3:0] cst, nst, 
	output [1:0] rem_cst, rem_nst, 
	input req, 
	output reg [MSB:0] tx_data, 
	input [((2**(I_MSB+1))-1):0] rx_data_2, 
	input [MSB:0] rx_data_1, rx_data_3, 
	input enable, 
`ifdef ASYNC
	input async_se, rem_lck, lck, test_se, 
`endif
	input rstn, clk 
);

`ifdef ASYNC
wire clk0 = test_se ? clk : async_se ? lck  : clk;
`endif

reg [MSB:0] p, m;
reg [((2**(I_MSB+1))-1)+1:0] b;
reg [I_MSB+1:0] i;
wire b_i = b[i];
wire for_end = ~(i < 8);

wire rem_ack;
reg rem_req;
wire [MSB:0] rem_tx_data;
wire [MSB:0] n = rx_data_3;
reg [2*(MSB+1)-1:0] rem_rx_data_1;
rem #(
	.MSB(MSB) 
) rem(
	.ack(rem_ack), 
	.cst(rem_cst), .nst(rem_nst), 
	.req(rem_req), 
	.tx_data(rem_tx_data), 
	.rx_data_2(n), 
	.rx_data_1(rem_rx_data_1), 
`ifdef ASYNC
	.async_se(async_se), .lck(rem_lck), .test_se(test_se), 
`endif
	.enable(enable), 
	.rstn(rstn), .clk(clk) 
);

`ifndef GRAY
	`define GRAY(X) (X^(X>>1))
`endif
localparam [3:0]
	st_p		= `GRAY(9),
	st_p_ack	= `GRAY(8),
	st_p_req	= `GRAY(7),
	st_m		= `GRAY(6),
	st_m_ack	= `GRAY(5),
	st_m_req	= `GRAY(4),
	st_if		= `GRAY(3),
	st_for		= `GRAY(2),
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
		st_load: nst = st_for;
		st_for: nst = for_end ? st_idle : st_if;
		st_if: nst = b_i ? st_m_req : st_p_req;
		st_m_req: nst = st_m_ack;
		st_m_ack: nst = rem_ack ? st_m : cst;
		st_m: nst = st_p_req;
		st_p_req: nst = st_p_ack;
		st_p_ack: nst = rem_ack ? st_p : cst;
		st_p: nst = st_for;
		default: nst = st_idle;
	endcase
end
assign ack = cst == st_idle;
`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) rem_req <= 1'b0;
	else if(enable) begin
		case(nst)
			st_m_req: rem_req <= ~rem_req;
			st_p_req: rem_req <= ~rem_req;
			default: rem_req <= rem_req;
		endcase
	end
end

`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) begin
		p <= 0;
		b <= 0;
		m <= 0;
		i <= 0;
		rem_rx_data_1 <= 0;
		//n <= 0;
		tx_data <= 0;
	end
	else if(enable) begin
		case(nst)
			st_idle: tx_data <= m;
			st_load: begin
				p <= rx_data_1;
				b <= {1'b0, rx_data_2};
				//n <= rx_data_3;
				m <= 0;
				i <= 0;
			end
			st_m_req: rem_rx_data_1 <= {{(MSB+1){1'b0}}, m} + {{(MSB+1){1'b0}}, p};
			st_m: m <= rem_tx_data;
			st_p_req: rem_rx_data_1 <= ({{(MSB+1){1'b0}}, p} << 1);
			st_p: begin
				p <= rem_tx_data;
				i <= i + 1;
			end
			default: begin
		 		p <= p;
				b <= b;
		 		m <= m;
		 		i <= i;
		 		rem_rx_data_1 <= rem_rx_data_1;
				//n <= n;
			end
		endcase
	end
end

endmodule


module modexpt #(
	parameter I_MSB = 3, 
	parameter J_MSB = 3 
)(
	output ack, 
	output reg [3:0] cst, nst, 
	output [3:0] modmult_cst, modmult_nst, 
	output [1:0] rem_cst, rem_nst, 
	input req, 
	output reg [(2**(I_MSB+1)-1):0] tx_data, 
	input [((2**(J_MSB+1))-1):0] rx_data_2, 
	input [J_MSB+1:0] rx_data_2_msb, 
	input [(2**(I_MSB+1)-1):0] rx_data_1, rx_data_3, 
	input enable, 
`ifdef ASYNC
	input async_se, rem_lck, modmult_lck, lck, test_se, 
`endif
	input rstn, clk 
);

`ifdef ASYNC
wire clk0 = test_se ? clk : async_se ? lck  : clk;
`endif

reg [(2**(I_MSB+1)-1):0] a;
reg [(2**(J_MSB+1)-1):0] b;
reg [J_MSB+1:0] j;
wire b_j = b[j[J_MSB:0]];
wire for_end = j == {(J_MSB+1+1){1'b1}};

wire modmult_ack;
reg modmult_req;
wire [(2**(I_MSB+1)-1):0] modmult_tx_data;
reg [(2**(I_MSB+1)-1):0] e;
reg [(2**(I_MSB+1)-1):0] modmult_rx_data_1;
wire [(2**(I_MSB+1)-1):0] n = rx_data_3;
modmult #(
	.MSB((2**(I_MSB+1)-1)), 
	.I_MSB(I_MSB) 
) modmult(
	.ack(modmult_ack), 
	.cst(modmult_cst), .nst(modmult_nst), 
	.rem_cst(rem_cst), .rem_nst(rem_nst), 
	.req(modmult_req), 
	.tx_data(modmult_tx_data), 
	.rx_data_2(e), 
	.rx_data_1(modmult_rx_data_1), .rx_data_3(n), 
	.enable(enable), 
`ifdef ASYNC
	.async_se(async_se), .rem_lck(rem_lck), .lck(modmult_lck), .test_se(test_se), 
`endif
	.rstn(rstn), .clk(clk) 
);

`ifndef GRAY
	`define GRAY(X) (X^(X>>1))
`endif
localparam [3:0]
	st_j		= `GRAY(10),
	st_e1		= `GRAY(9),
	st_e1_ack	= `GRAY(8),
	st_e1_req	= `GRAY(7),
	st_if		= `GRAY(6),
	st_e0		= `GRAY(5),
	st_e0_ack	= `GRAY(4),
	st_e0_req	= `GRAY(3),
	st_for		= `GRAY(2),
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
		st_load: nst = st_for;
		st_for: nst = for_end ? st_idle : st_e0_req;
		st_e0_req: nst = st_e0_ack;
		st_e0_ack: nst = modmult_ack ? st_e0 : cst;
		st_e0: nst = st_if;
		st_if: nst = b_j ? st_e1_req : st_j;
		st_e1_req: nst = st_e1_ack;
		st_e1_ack: nst = modmult_ack ? st_e1 : cst;
		st_e1: nst = st_j;
		st_j: nst = st_for;
		default: nst = st_idle;
	endcase
end
assign ack = cst == st_idle;
`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) modmult_req <= 1'b0;
	else if(enable) begin
		case(nst)
			st_e0_req: modmult_req <= ~modmult_req;
			st_e1_req: modmult_req <= ~modmult_req;
			default: modmult_req <= modmult_req;
		endcase
	end
end

`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) begin
		a <= 0;
		b <= 0;
		modmult_rx_data_1 <= 0;
		e <= 0;
		//n <= 0;
		j <= 0;
		tx_data <= 0;
	end
	else if(enable) begin
		case(nst)
			st_idle: begin
				tx_data <= e;
				//j <= {1'b0, {(J_MSB+1){1'b1}}};
				j <= rx_data_2_msb;
			end
			st_load: begin
				a <= rx_data_1;
				b <= rx_data_2;
				e <= b_j ? rx_data_1 : 1;
				//n <= rx_data_3;
				j <= j - 1;
			end
			st_e0_req: modmult_rx_data_1 <= e;
			st_e0: e <= modmult_tx_data;
			st_e1_req: modmult_rx_data_1 <= a;
			st_e1: e <= modmult_tx_data;
			st_j: j <= j - 1;
			default: begin
				a <= a;
				b <= b;
				modmult_rx_data_1 <= modmult_rx_data_1;
				e <= e;
				//n <= n;
			end
		endcase
	end
end

endmodule
