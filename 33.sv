`timescale 1ns/1ps


module mod 
#(
	parameter MSB = 7 
)(
	output idle, 
	input calc, 
	output err, 
	output reg [MSB:0] q, 
	input [MSB:0] a, b, 
	input rstb, setb, clk 
);

reg [1:0] cst, nst;
parameter [1:0] I = 2'b01;
parameter [1:0] S = 2'b10;
parameter [1:0] R = 2'b11;
parameter [1:0] Q = 2'b00;
reg [MSB:0] r, c;

wire lt = r < c;
assign err = c == 0;
always@(negedge rstb or posedge clk) begin
	if(~rstb) cst <= Q;
	else if(setb) cst <= nst;
end
always@(*) begin
	nst = cst;
	case(cst)
		Q: if(calc) nst = I;
		I: nst = R;
		R: if(lt | err) nst = Q; else nst = S;
		S: nst = R;
	endcase
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) r <= {(MSB+1){1'b0}};
	else if(setb && (nst == S)) r <= r - c;
	else if(setb && (nst == I)) r <= a;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) c <= {(MSB+1){1'b0}};
	else if(setb && (nst == I)) c <= b;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) q <= {(MSB+1){1'b0}};
	else if(setb && (nst == Q)) q <= r;
end

assign idle = setb && (cst == Q);

endmodule


/*

# dc_shell 
analyze -format verilog 33.sv
set auto_insert_level_shifters_on_clocks all
set mv_insert_level_shifters_on_ideal_nets all
set power_cg_auto_identify true
set mv_insert_level_shifter_verbose true
set_leakage_optimization true
set_clock_gating_style -control_point before -positive_edge_logic {latch and} 
elaborate -update mod
create_clock -name clk -period 10 [get_ports clk] 
set_ideal_network [get_ports rstb]
set_clock_transition 0.1 clk
set_clock_uncertainty -setup 0.2 clk
set_clock_uncertainty -hold 0.2 clk
set_isolate_ports -type buffer -force [all_inputs]
# upf 
set upf_create_implicit_supply_sets false
create_power_domain TOP -include_scope
create_supply_net VCC -domain TOP
create_supply_net GND -domain TOP
set_domain_supply_net TOP -primary_power_net VCC -primary_ground_net GND
create_supply_port GND -domain TOP -direction in
create_supply_port VCC -domain TOP -direction in
add_port_state GND -state {state1 0.000000}
add_port_state VCC -state {state1 0.850000}
connect_supply_net GND -ports GND
connect_supply_net VCC -ports VCC
set_voltage 0.85 -object_list { VCC }
set_voltage 0.00 -object_list { GND }
# dc_shell 
compile_ultra -scan -gate_clock -area_high_effort_script 
# dft 
create_port -direction in  test_se
create_port -direction in  test_si
create_port -direction out test_so
set_dft_signal -port test_se -type scanenable  -active_state 1
set_dft_signal -port test_si -type scandatain  
set_dft_signal -port test_so -type scandataout 
set_dft_signal -port clk     -type scanclock   -timing {50 100} -view existing_dft 
create_test_protocol -infer_clock -infer_asynch
preview_dft
dft_drc
insert_dft


 */


`ifdef SIM
module mod_tb;

parameter MSB = 15;
wire idle;
reg calc;
wire err;
wire [MSB:0] q;
reg [MSB:0] a, b;
reg rstb, setb, clk;
wire [MSB:0] q0 = a % b;
reg check;

mod 
#(
	.MSB(MSB) 
) u_mod(
	.idle(idle), 
	.calc(calc), 
	.err(err), 
	.q(q), 
	.b(b), 
	.a(a), 
	.rstb(rstb), .setb(setb), .clk(clk) 
);

always #1 clk = ~clk;

initial begin
	`ifdef FST
	$dumpfile("a.fst");
	$dumpvars(0, mod_tb);
	`endif
	calc = 1'b0;
	rstb = 1'b0;
	setb = 1'b0;
	clk = 1'b0;
	check = 1;
	repeat(5) begin
		repeat(5) @(posedge clk); rstb = 1'b1;
		repeat(5) @(posedge clk); setb = 1'b1;
		calc = 1'b0;
		repeat(100) begin
			a = $urandom_range(0,321);
			b = $urandom_range(0,123);
			calc = 1'b1;
			$write("a = %d, b = %d, ", a, b); 
			@(posedge clk) calc = 1'b0;
			@(posedge idle); $write("q = %d, q0 = %d \n", q, q0);
			@(posedge clk); if(check && !err) check = q == q0;
		end
		repeat(5) @(posedge clk); setb = 1'b0;
		repeat(5) @(posedge clk); rstb = 1'b0;
	end
	if(check) $write("pass\n"); else $write("fail\n");
	$finish;
end

endmodule
`endif


module modmul
#(
	parameter MSB = 15 
)(
	output idle, 
	input calc, 
	output err, 
	output reg [MSB:0] q, 
	input [MSB:0] a, b, n, 
	input rstb, setb, clk 
);

reg [3:0] cst, nst;
parameter [3:0] IDLE = (0^(0>>1));
parameter [3:0] INIT = (1^(1>>1));
parameter [3:0] FOR  = (2^(2>>1));
parameter [3:0] IF1  = (3^(3>>1));
parameter [3:0] LDM  = (4^(4>>1));
parameter [3:0] TRM  = (5^(5>>1));
parameter [3:0] RTM  = (6^(6>>1));
parameter [3:0] LDP  = (7^(7>>1));
parameter [3:0] TRP  = (8^(8>>1));
parameter [3:0] RTP  = (9^(9>>1));
reg [MSB:0] mod_a, mod_b, p, m, c, i;
wire [MSB:0] mod_q;
wire ge = i >= MSB;
wire mod_idle;
reg mod_calc;

mod 
#(
	.MSB(MSB) 
) u_mod(
	.idle(mod_idle), 
	.calc(mod_calc), 
	.err(err), 
	.q(mod_q), 
	.b(mod_b), 
	.a(mod_a), 
	.rstb(rstb), .setb(setb), .clk(clk) 
);

always@(negedge rstb or posedge clk) begin
	if(~rstb) cst <= IDLE;
	else if(setb) cst <= nst;
end
always@(*) begin
	nst = cst;
	case(cst)
		IDLE: if(calc) nst = INIT;
		INIT: if(~calc) nst = IF1;
		IF1 : nst = c[i] ? LDM : LDP;
		LDM : if(~mod_idle) nst = TRM;
		TRM : if(mod_idle) nst = RTM;
		RTM : nst = LDP;
		LDP : if(~mod_idle) nst = TRP;
		TRP : if(mod_idle) nst = RTP;
		RTP : nst = FOR;
		FOR : nst = ge ? IDLE : IF1;
	endcase
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) mod_a <= {(MSB+1){1'b0}};
	else if(setb) begin
		case(nst)
			LDM : mod_a <= m + p;
			LDP : mod_a <= p << 1;
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) mod_b <= {(MSB+1){1'b0}};
	else if(setb && (nst == INIT)) mod_b <= n;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) c <= {(MSB+1){1'b0}};
	else if(setb && (nst == INIT)) c <= b;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) p <= {(MSB+1){1'b0}};
	else if(setb && (nst == INIT)) p <= a;
	else if(setb && (nst == RTP)) p <= mod_q;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) m <= {(MSB+1){1'b0}};
	else if(setb && (nst == INIT)) m <= {(MSB+1){1'b0}};
	else if(setb && (nst == RTM)) m <= mod_q;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) q <= {(MSB+1){1'b0}};
	else if(setb && (nst == IDLE) && (~err)) q <= m;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) i <= 0;
	else if(setb && (cst == INIT)) i <= 0;
	else if(setb && (cst == FOR)) i <= i + 1;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) mod_calc <= 1'b0;
	else if(setb && ((cst == LDM) || (cst == LDP))) mod_calc <= 1'b1;
	else if(setb && ((cst == TRM) || (cst == TRP))) mod_calc <= 1'b0;
end

assign idle = setb && (cst == IDLE);

endmodule


/*

# dc_shell 
analyze -format verilog 33.sv
set auto_insert_level_shifters_on_clocks all
set mv_insert_level_shifters_on_ideal_nets all
set power_cg_auto_identify true
set mv_insert_level_shifter_verbose true
set_leakage_optimization true
set_clock_gating_style -control_point before -positive_edge_logic {latch and} 
elaborate -update modmul
create_clock -name clk -period 10 [get_ports clk] 
set_ideal_network [get_ports rstb]
set_clock_transition 0.1 clk
set_clock_uncertainty -setup 0.2 clk
set_clock_uncertainty -hold 0.2 clk
set_isolate_ports -type buffer -force [all_inputs]
# upf 
set upf_create_implicit_supply_sets false
create_power_domain TOP -include_scope
create_supply_net VCC -domain TOP
create_supply_net GND -domain TOP
set_domain_supply_net TOP -primary_power_net VCC -primary_ground_net GND
create_supply_port GND -domain TOP -direction in
create_supply_port VCC -domain TOP -direction in
add_port_state GND -state {state1 0.000000}
add_port_state VCC -state {state1 0.850000}
connect_supply_net GND -ports GND
connect_supply_net VCC -ports VCC
set_voltage 0.85 -object_list { VCC }
set_voltage 0.00 -object_list { GND }
# dc_shell 
compile_ultra -scan -gate_clock -area_high_effort_script 
# dft 
create_port -direction in  test_se
create_port -direction in  test_si
create_port -direction out test_so
set_dft_signal -port test_se -type scanenable  -active_state 1
set_dft_signal -port test_si -type scandatain  
set_dft_signal -port test_so -type scandataout 
set_dft_signal -port clk     -type scanclock   -timing {50 100} -view existing_dft 
create_test_protocol -infer_clock -infer_asynch
preview_dft
dft_drc
insert_dft


 */


`ifdef SIM
module modmul_tb;

parameter MSB = 15;
wire idle;
reg calc;
wire err;
wire [MSB:0] q;
reg [MSB:0] a, b, n;
reg rstb, setb, clk;
integer a0, b0, n0, q0;
reg check;

modmul
#(
	.MSB(MSB)
) u_modmul(
	.idle(idle), 
	.calc(calc), 
	.err(err), 
	.q(q), 
	.a(a), .b(b), .n(n), 
	.rstb(rstb), .setb(setb), .clk(clk) 
);

always #1 clk = ~clk;

initial begin
	`ifdef FST
	$dumpfile("a.fst");
	$dumpvars(0, modmul_tb);
	`endif
	calc = 1'b0;
	rstb = 1'b0;
	setb = 1'b0;
	clk = 1'b0;
	check = 1;
	repeat(5) begin
		repeat(5) @(posedge clk); rstb = 1'b1;
		repeat(5) @(posedge clk); setb = 1'b1;
		calc = 1'b0;
		repeat(100) begin
			a = $urandom_range(0,231);
			b = $urandom_range(0,123);
			n = $urandom_range(0,23);
			a0 = a; b0 = b; n0 = n; q0 = (a0 * b0) % n0;
			calc = 1'b1;
			$write("a = %d, b = %d, n = %d, ", a, b, n); 
			@(posedge clk) calc = 1'b0;
			@(posedge idle); $write("q = %d, q0 = %d \n", q, q0);
			@(posedge clk); if(check && !err) check = q == q0[MSB:0];
		end
		repeat(5) @(posedge clk); setb = 1'b0;
		repeat(5) @(posedge clk); rstb = 1'b0;
	end
	if(check) $write("pass\n"); else $write("fail\n");
	$finish;
end

endmodule
`endif


/*
iverilog -g2012 -gspecify 33.sv -D SIM -D FST -s modmul_tb

 */


module modexp
#(
	parameter AMSB = 7, 
	parameter ASUM = (2**(AMSB+1)), 
	parameter MSB = ((ASUM*8)-1) 
)(
	output reg idle, 
	input calc, 
	output err, 
	output reg [7:0] q, 
	input [7:0] a, n, 
	input [7:0] data, 
	input [AMSB:0] addr, 
	input write,
	input rstb, setb, clk 
);

reg [7:0] mem [ASUM-1:0];
wire [MSB:0] b;
generate
genvar k;
for(k = 0; k < ASUM; k = k+1) begin
	assign b[k*8+7:k*8] = mem[k];
end
endgenerate
reg [3:0] cst, nst;
parameter [3:0] IDLE = ( 0^( 0>>1));
parameter [3:0] INIT = ( 1^( 1>>1));
parameter [3:0] FOR  = ( 2^( 2>>1));
parameter [3:0] IF1  = ( 3^( 3>>1));
parameter [3:0] LD1  = ( 4^( 4>>1));
parameter [3:0] TR1  = ( 5^( 5>>1));
parameter [3:0] RT1  = ( 6^( 6>>1));
parameter [3:0] IF2  = ( 7^( 7>>1));
parameter [3:0] LD2  = ( 8^( 8>>1));
parameter [3:0] TR2  = ( 9^( 9>>1));
parameter [3:0] RT2  = (10^(10>>1));
reg [15:0] modmul_a, modmul_n, c, e;
wire [15:0] modmul_q;
reg signed [MSB:0] i;
wire le = i <= 0;
wire modmul_idle;
reg modmul_calc;

modmul
#(
	.MSB(15)
) u_modmul(
	.idle(modmul_idle), 
	.calc(modmul_calc), 
	.err(err), 
	.q(modmul_q), 
	.a(modmul_a), .b(e), .n(modmul_n), 
	.rstb(rstb), .setb(setb), .clk(clk) 
);

always@(negedge rstb or posedge clk) begin
	if(~rstb) cst <= IDLE;
	else if(setb) cst <= nst;
end
always@(*) begin
	nst = cst;
	case(cst)
		IDLE: if(calc) nst = INIT;
		INIT: if(~calc) nst = IF1;
		IF1 : nst = b[i] ? LD1 : IF2;
		LD1 : if(~modmul_idle) nst = TR1;
		TR1 : if(modmul_idle) nst = RT1;
		RT1 : nst = IF2;
		IF2 : nst = (i != 0) ? LD2 : FOR;
		LD2 : if(~modmul_idle) nst = TR2;
		TR2 : if(modmul_idle) nst = RT2;
		RT2 : nst = FOR;
		FOR : nst = le ? IDLE : IF1;
	endcase
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) modmul_a <= {(MSB+1){1'b0}};
	else if(setb) begin
		case(nst)
			LD1 : modmul_a <= c;
			LD2 : modmul_a <= e;
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) modmul_n <= 16'd0;
	else if(setb && (nst == INIT)) modmul_n <= {8'd0,n};
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) c <= 16'd0;
	else if(setb && (nst == INIT)) c <= {8'd0,a};
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) e <= 16'd0;
	else if(setb && (nst == INIT)) e <= 16'd1;
	else if(setb && ((nst == RT1) | (nst == RT2))) e <= modmul_q;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) q <= 16'd0;
	else if(setb && (nst == IDLE) && (~err)) q <= e;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) i <= MSB;
	else if(setb && (cst == INIT)) i <= MSB;
	else if(setb && (cst == FOR)) i <= i - 1;
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) modmul_calc <= 1'b0;
	else if(setb && ((cst == LD1) || (cst == LD2))) modmul_calc <= 1'b1;
	else if(setb && ((cst == TR1) || (cst == TR2))) modmul_calc <= 1'b0;
end

always@(*) idle = setb && (cst == IDLE);

always@(posedge clk) begin
	if(setb && (cst == IDLE) && write) mem[addr] <= data;
end

endmodule


/*

# dc_shell 
analyze -format verilog 33.sv
set auto_insert_level_shifters_on_clocks all
set mv_insert_level_shifters_on_ideal_nets all
set power_cg_auto_identify true
set mv_insert_level_shifter_verbose true
set_leakage_optimization true
set_clock_gating_style -control_point before -positive_edge_logic {latch and} 
elaborate -update modexp
create_clock -name clk -period 10 [get_ports clk] 
set_ideal_network [get_ports rstb]
set_clock_transition 0.1 clk
set_clock_uncertainty -setup 0.2 clk
set_clock_uncertainty -hold 0.2 clk
set_isolate_ports -type buffer -force [all_inputs]
# upf 
set upf_create_implicit_supply_sets false
create_power_domain TOP -include_scope
create_supply_net VCC -domain TOP
create_supply_net GND -domain TOP
set_domain_supply_net TOP -primary_power_net VCC -primary_ground_net GND
create_supply_port GND -domain TOP -direction in
create_supply_port VCC -domain TOP -direction in
add_port_state GND -state {state1 0.000000}
add_port_state VCC -state {state1 0.850000}
connect_supply_net GND -ports GND
connect_supply_net VCC -ports VCC
set_voltage 0.85 -object_list { VCC }
set_voltage 0.00 -object_list { GND }
# dc_shell 
compile_ultra -scan -gate_clock -area_high_effort_script 
# dft 
create_port -direction in  test_se
create_port -direction in  test_si
create_port -direction out test_so
set_dft_signal -port test_se -type scanenable  -active_state 1
set_dft_signal -port test_si -type scandatain  
set_dft_signal -port test_so -type scandataout 
set_dft_signal -port clk     -type scanclock   -timing {50 100} -view existing_dft 
create_test_protocol -infer_clock -infer_asynch
preview_dft
dft_drc
insert_dft


 */


`ifdef SIM
module modexp_tb;

parameter AMSB = 7;
parameter ASUM = (2**(AMSB+1));
parameter MSB = ((ASUM*8)-1);
wire idle;
reg calc;
wire err;
wire [7:0] q;
reg [7:0] a, n;
reg [MSB:0] b;
logic [7:0] data;
logic [AMSB:0] addr;
reg write;
reg rstb, setb, clk;
logic [8191:0] a0, b0, n0, q0;
reg check;

modexp
#(
	.AMSB(AMSB)
) u_modexp(
	.idle(idle), 
	.calc(calc), 
	.err(err), 
	.q(q), 
	.a(a), .n(n), 
	.data(data),
	.addr(addr),
	.write(write), 
	.rstb(rstb), .setb(setb), .clk(clk) 
);

always #1 clk = ~clk;

initial begin
	`ifdef FST
	$dumpfile("a.fst");
	$dumpvars(0, modexp_tb);
	`endif
	calc = 1'b0;
	rstb = 1'b0;
	setb = 1'b0;
	clk = 1'b0;
	write = 1'b0;
	check = 1;
	repeat(5) begin
		repeat(5) @(posedge clk); rstb = 1'b1;
		repeat(5) @(posedge clk); setb = 1'b1;
		calc = 1'b0;
		repeat(10) begin
			a = $urandom_range(0,123);
			b = $urandom_range(0,321);
			n = $urandom_range(0,32);
			a0 = a; b0 = b; n0 = n; q0 = (a0 ** b0) % n0;
			@(negedge clk);
			write = 1'b1;
			addr = 8'd0;
			data = (b >> (addr*8)) & 8'b11111111;
			repeat(ASUM) begin
				@(negedge clk);
				addr = addr + 1;
				data = (b >> (addr*8)) & 8'b11111111;
			end
			@(posedge clk);
			write = 1'b0;
			@(posedge clk);
			calc = 1'b1;
			$write("a = %5d, b = %5d, n = %5d, ", a, b, n); 
			@(posedge clk) calc = 1'b0;
			@(posedge idle); $write("q = %5d, q0 = %5d \n", q, q0);
			@(posedge clk); if(check && !err) check = q == q0[MSB:0];
		end
		repeat(5) @(posedge clk); setb = 1'b0;
		repeat(5) @(posedge clk); rstb = 1'b0;
	end
	if(check) $write("pass\n"); else $write("fail\n");
	$finish;
end

endmodule
`endif


module uart_tx (
	output reg idle, 
	output reg tx, 
	input [7:0] data, 
	input write, 
	input [7:0] div, 
	input rstb, setb, clk 
);

reg [1:0] cst, nst;
parameter [1:0] IDLE = 0;
parameter [1:0] LOAD = 1;
parameter [1:0] WAIT = 2;
parameter [1:0] POP  = 3;
reg [7:0] cnt, div_r;
wire eq = cnt == 8'd0;
reg [10:0] data_r;
reg [3:0] bth;
wire gt = bth > 10;

always@(negedge rstb or posedge clk) begin
	if(~rstb) cst <= IDLE;
	else if(setb) cst <= nst;
end
always@(*) begin
	nst = cst;
	case(cst)
		IDLE: if(write) nst = LOAD;
		LOAD: if(~write) nst = WAIT;
		WAIT: if(eq) nst = POP;
		POP : nst = gt ? IDLE : WAIT;
	endcase
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) div_r <= 8'd0;
	else if(setb) begin
		case(nst)
			LOAD: div_r <= div;
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) cnt <= 8'd0;
	else if(setb) begin
		case(cst)
			LOAD, POP : cnt <= div_r;
			WAIT: cnt <= cnt - 8'd1;
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) bth <= 4'd0;
	else if(setb) begin
		case(cst)
			LOAD: bth <= 4'd0;
			POP : bth <= bth + 4'd1;
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) data_r <= 11'd0;
	else if(setb) begin
		case(cst)
			LOAD: data_r <= {1'b1,(^data),data,1'b0};
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) tx <= 1'b1;
	else if(setb) begin
		case(cst) 
			POP : if(~gt) tx <= data_r[bth];
		endcase
	end
end

always@(*) idle = cst == IDLE;

endmodule


/*

# dc_shell 
analyze -format verilog 33.sv
set auto_insert_level_shifters_on_clocks all
set mv_insert_level_shifters_on_ideal_nets all
set power_cg_auto_identify true
set mv_insert_level_shifter_verbose true
set_leakage_optimization true
set_clock_gating_style -control_point before -positive_edge_logic {latch and} 
elaborate -update uart_tx
create_clock -name clk -period 10 [get_ports clk] 
set_ideal_network [get_ports rstb]
set_clock_transition 0.1 clk
set_clock_uncertainty -setup 0.2 clk
set_clock_uncertainty -hold 0.2 clk
set_isolate_ports -type buffer -force [all_inputs]
# upf 
set upf_create_implicit_supply_sets false
create_power_domain TOP -include_scope
create_supply_net VCC -domain TOP
create_supply_net GND -domain TOP
set_domain_supply_net TOP -primary_power_net VCC -primary_ground_net GND
create_supply_port GND -domain TOP -direction in
create_supply_port VCC -domain TOP -direction in
add_port_state GND -state {state1 0.000000}
add_port_state VCC -state {state1 0.850000}
connect_supply_net GND -ports GND
connect_supply_net VCC -ports VCC
set_voltage 0.85 -object_list { VCC }
set_voltage 0.00 -object_list { GND }
# dc_shell 
compile_ultra -scan -gate_clock -area_high_effort_script 
# dft 
create_port -direction in  test_se
create_port -direction in  test_si
create_port -direction out test_so
set_dft_signal -port test_se -type scanenable  -active_state 1
set_dft_signal -port test_si -type scandatain  
set_dft_signal -port test_so -type scandataout 
set_dft_signal -port clk     -type scanclock   -timing {50 100} -view existing_dft 
create_test_protocol -infer_clock -infer_asynch
preview_dft
dft_drc
insert_dft


 */


`ifdef SIM
module uart_tx_tb;

wire idle;
wire tx;
reg [7:0] data;
reg write;
reg [7:0] div;
reg rstb, setb, clk;

uart_tx u_uart_tx (
	.idle(idle), 
	.tx(tx), 
	.data(data), 
	.write(write), 
	.div(div), 
	.rstb(rstb), .setb(setb), .clk(clk) 
);

always #1 clk = ~clk;

initial begin
	`ifdef FST
	$dumpfile("a.fst");
	$dumpvars(0,uart_tx_tb);
	`endif
	rstb = 1'b0;
	setb = 1'b0;
	clk = 1'b0;
	write = 1'b0;
	repeat(5) begin
		repeat(5) @(posedge clk); rstb = 1'b1;
		repeat(5) @(posedge clk); setb = 1'b1;
		repeat(100) begin
			@(posedge clk);
			data = $urandom_range(0,255);
			write = 1'b0;
			div = $urandom_range(0,25);
			@(posedge clk); write = 1'b1;
			@(posedge clk); write = 1'b0;
			@(posedge idle);
		end
		repeat(5) @(posedge clk); rstb = 1'b0;
		repeat(5) @(posedge clk); setb = 1'b0;
	end
	$finish;
end

endmodule
`endif


module uart_rx (
	output reg idle, err, 
	input rx, 
	output reg [7:0] data, 
	input read, 
	input [7:0] div, 
	input rstb, setb, clk 
);

reg [1:0] cst, nst;
parameter [1:0] IDLE = 0;
parameter [1:0] LOAD = 1;
parameter [1:0] WAIT = 2;
parameter [1:0] PUSH = 3;
reg [7:0] cnt, div_r;
wire eq = cnt == 8'd0;
reg [9:0] data_r;
reg [3:0] bth;
wire gt = bth > 9;

always@(negedge rstb or posedge clk) begin
	if(~rstb) cst <= IDLE;
	else if(setb) cst <= nst;
end
always@(*) begin
	nst = cst;
	case(cst)
		IDLE: if(read) nst = LOAD;
		LOAD: if((~read) && (~rx)) nst = WAIT;
		WAIT: if(eq) nst = PUSH;
		PUSH: nst = (gt && data_r[9]) ? IDLE : WAIT;
	endcase
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) div_r <= 8'd0;
	else if(setb) begin
		case(nst)
			LOAD: div_r <= div;
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) cnt <= 8'd0;
	else if(setb) begin
		case(cst)
			LOAD, PUSH : cnt <= div_r;
			WAIT: cnt <= cnt - 8'd1;
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) bth <= 4'd0;
	else if(setb) begin
		case(cst)
			LOAD: bth <= 4'd0;
			PUSH: bth <= bth + 4'd1;
		endcase
	end
end

always@(posedge clk) begin
	if(setb) begin
		case(cst)
			PUSH: data_r[bth] <= rx;
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) data <= 8'd0;
	else if(setb) begin
		case(nst)
			IDLE: if(~err) data <= data_r[7:0];
		endcase
	end
end

always@(negedge rstb or posedge clk) begin
	if(~rstb) err <= 1'b0;
	else if(setb) begin
		case(cst)
			PUSH: if(bth == 9) err <= (^data_r[7:0]) != data_r[8];
		endcase
	end
end

always@(*) idle = cst == IDLE;

endmodule


/*

# dc_shell 
analyze -format verilog 33.sv
set auto_insert_level_shifters_on_clocks all
set mv_insert_level_shifters_on_ideal_nets all
set power_cg_auto_identify true
set mv_insert_level_shifter_verbose true
set_leakage_optimization true
set_clock_gating_style -control_point before -positive_edge_logic {latch and} 
elaborate -update uart_rx
create_clock -name clk -period 10 [get_ports clk] 
set_ideal_network [get_ports rstb]
set_clock_transition 0.1 clk
set_clock_uncertainty -setup 0.2 clk
set_clock_uncertainty -hold 0.2 clk
set_isolate_ports -type buffer -force [all_inputs]
# upf 
set upf_create_implicit_supply_sets false
create_power_domain TOP -include_scope
create_supply_net VCC -domain TOP
create_supply_net GND -domain TOP
set_domain_supply_net TOP -primary_power_net VCC -primary_ground_net GND
create_supply_port GND -domain TOP -direction in
create_supply_port VCC -domain TOP -direction in
add_port_state GND -state {state1 0.000000}
add_port_state VCC -state {state1 0.850000}
connect_supply_net GND -ports GND
connect_supply_net VCC -ports VCC
set_voltage 0.85 -object_list { VCC }
set_voltage 0.00 -object_list { GND }
# dc_shell 
compile_ultra -scan -gate_clock -area_high_effort_script 
# dft 
create_port -direction in  test_se
create_port -direction in  test_si
create_port -direction out test_so
set_dft_signal -port test_se -type scanenable  -active_state 1
set_dft_signal -port test_si -type scandatain  
set_dft_signal -port test_so -type scandataout 
set_dft_signal -port clk     -type scanclock   -timing {50 100} -view existing_dft 
create_test_protocol -infer_clock -infer_asynch
preview_dft
dft_drc
insert_dft


 */


`ifdef SIM
module uart_rx_tb;

wire ridle, widle, err;
wire x;
wire [7:0] rdata;
reg [7:0] wdata;
reg write, read;
reg [7:0] div;
reg rstb, setb, clk;
logic check;

uart_tx u_uart_tx (
	.idle(widle), 
	.tx(x), 
	.data(wdata), 
	.write(write), 
	.div(div), 
	.rstb(rstb), .setb(setb), .clk(clk) 
);

uart_rx u_uart_rx (
	.idle(ridle), .err(err), 
	.rx(x), 
	.data(rdata), 
	.read(read), 
	.div(div), 
	.rstb(rstb), .setb(setb), .clk(clk) 
);

always #1 clk = ~clk;

initial begin
	`ifdef FST
	$dumpfile("a.fst");
	$dumpvars(0,uart_rx_tb);
	`endif
	rstb = 1'b0;
	setb = 1'b0;
	clk = 1'b0;
	write = 1'b0;
	read = 1'b0;
	check = 1;
	repeat(5) begin
		repeat(5) @(posedge clk); rstb = 1'b1;
		repeat(5) @(posedge clk); setb = 1'b1;
		repeat(100) begin
			@(posedge clk);
			wdata = $urandom_range(0,255);
			write = 1'b0; read = 1'b0;
			div = $urandom_range(0,255);
			@(posedge clk); write = 1'b1; read = 1'b1;
			@(posedge clk); write = 1'b0; read = 1'b0;
			@(posedge (widle && ridle));
			if(check) begin
				check = wdata == rdata;
				$write("wdata = %x, rdata = %x, check = %b\n", wdata, rdata, check);
			end
		end
		repeat(5) @(posedge clk); rstb = 1'b0;
		repeat(5) @(posedge clk); setb = 1'b0;
	end
	if(check) $write("pass\n"); else $write("fail\n");
	$finish;
end

endmodule
`endif
