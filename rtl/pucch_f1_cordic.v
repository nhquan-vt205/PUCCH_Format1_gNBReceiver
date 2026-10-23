// ============================================================================
// Module : pucch_f1_cordic
// Bit-exact full-circle rotation CORDIC: quadrant pre-rotation (stage 0),
// 16 micro-rotations (stages 1..16), RNE /64 + saturation to signed18 (output
// stage). No gain compensation (gain A16). One token per clock, 18-clock
// latency, tags carried with every token.
// Spec    : doc/spec/architecture/pucch_f1_cordic_spec.md
// Diagram : doc/diagram/pucch_f1_cordic/pucch_f1_cordic.svg (L1)
// Revision: 2.0 - regenerated from the S2 SVG model
// ============================================================================
`default_nettype none

module pucch_f1_cordic (
  input  wire        clk,           // clock, rising edge
  input  wire        rst_n,         // synchronous active-low reset
  input  wire        clr,           // clear all stage valids
  input  wire        in_valid,      // token valid
  input  wire [15:0] in_i,          // I, signed F15
  input  wire [15:0] in_q,          // Q, signed F15
  input  wire [15:0] in_phase,      // rotation angle, unsigned, 1 turn = 65536
  input  wire [6:0]  in_sample_q,   // tag q
  input  wire        in_first,      // tag first
  input  wire        in_last,       // tag last
  output wire        out_valid,     // token valid
  output wire [17:0] out_i,         // I, signed F15, gain A16
  output wire [17:0] out_q,         // Q, signed F15, gain A16
  output wire [6:0]  out_sample_q,  // tag q
  output wire        out_first,     // tag first
  output wire        out_last,      // tag last
  output wire        ovf_err        // overflow / saturation with this token
);

  // ATAN24[j] = RNE(atan(2^-j) / (2*pi) * 2^24)
  function [23:0] atan24;
    input [3:0] j;
    begin
      case (j)
        4'd0:    atan24 = 24'd2097152;
        4'd1:    atan24 = 24'd1238021;
        4'd2:    atan24 = 24'd654136;
        4'd3:    atan24 = 24'd332050;
        4'd4:    atan24 = 24'd166669;
        4'd5:    atan24 = 24'd83416;
        4'd6:    atan24 = 24'd41718;
        4'd7:    atan24 = 24'd20860;
        4'd8:    atan24 = 24'd10430;
        4'd9:    atan24 = 24'd5215;
        4'd10:   atan24 = 24'd2608;
        4'd11:   atan24 = 24'd1304;
        4'd12:   atan24 = 24'd652;
        4'd13:   atan24 = 24'd326;
        4'd14:   atan24 = 24'd163;
        default: atan24 = 24'd81;
      endcase
    end
  endfunction

  // Pipeline registers: index 0 = stage 0 (pre-rotated), 16 = after iteration 15
  reg               v_q    [0:16];
  reg signed [23:0] x_q    [0:16];
  reg signed [23:0] y_q    [0:16];
  reg signed [23:0] z_q    [0:16];
  reg               ovf_q  [0:16];
  reg        [8:0]  tag_q  [0:16];  // {sample_q, first, last}

  // Output stage registers
  reg               out_valid_q;
  reg        [17:0] out_i_q;
  reg        [17:0] out_q_q;
  reg        [8:0]  out_tag_q;
  reg               ovf_err_q;

  // Stage 0 combinational pre-rotation
  wire signed [23:0] x_in;
  wire signed [23:0] y_in;
  wire signed [23:0] z_in;
  wire               rot_pos;
  wire               rot_neg;
  wire signed [23:0] x0_d;
  wire signed [23:0] y0_d;
  wire signed [23:0] z0_d;

  assign x_in    = {{2{in_i[15]}}, in_i, 6'd0};
  assign y_in    = {{2{in_q[15]}}, in_q, 6'd0};
  assign z_in    = {in_phase, 8'd0};
  assign rot_pos = (z_in >  $signed(24'd4194304));
  assign rot_neg = (z_in < -$signed(24'd4194304));
  assign x0_d    = (rot_pos | rot_neg) ? -x_in : x_in;
  assign y0_d    = (rot_pos | rot_neg) ? -y_in : y_in;
  // z -/+ 2^23 modulo 2^24 is the same bit operation: invert the MSB
  assign z0_d    = (rot_pos | rot_neg) ? {~z_in[23], z_in[22:0]} : z_in;

  // Micro-rotations (combinational next values of stages 1..16)
  reg signed [24:0] xn25 [0:15];
  reg signed [24:0] yn25 [0:15];
  reg signed [23:0] zn   [0:15];
  reg               ofn  [0:15];
  reg signed [23:0] xs;
  reg signed [23:0] ys;
  integer           jc;

  always @(*) begin
    for (jc = 0; jc < 16; jc = jc + 1) begin
      xs = x_q[jc] >>> jc;
      ys = y_q[jc] >>> jc;
      if (!z_q[jc][23]) begin
        xn25[jc] = {x_q[jc][23], x_q[jc]} - {ys[23], ys};
        yn25[jc] = {y_q[jc][23], y_q[jc]} + {xs[23], xs};
        zn[jc]   = z_q[jc] - atan24(jc[3:0]);
      end
      else begin
        xn25[jc] = {x_q[jc][23], x_q[jc]} + {ys[23], ys};
        yn25[jc] = {y_q[jc][23], y_q[jc]} - {xs[23], xs};
        zn[jc]   = z_q[jc] + atan24(jc[3:0]);
      end
      ofn[jc] = (xn25[jc][24] != xn25[jc][23]) | (yn25[jc][24] != yn25[jc][23]);
    end
  end

  // Output stage: RNE(x / 64) and saturation to signed18
  wire [23:0] ax;
  wire [23:0] ay;
  wire [18:0] vx;
  wire [18:0] vy;
  wire [18:0] ox;
  wire [18:0] oy;
  wire        sat_x;
  wire        sat_y;
  wire [17:0] out_i_d;
  wire [17:0] out_q_d;

  assign ax      = x_q[16][23] ? -x_q[16] : x_q[16];
  assign ay      = y_q[16][23] ? -y_q[16] : y_q[16];
  assign vx      = {1'b0, ax[23:6]} + {18'd0, ((ax[5:0] > 6'd32) | ((ax[5:0] == 6'd32) & ax[6]))};
  assign vy      = {1'b0, ay[23:6]} + {18'd0, ((ay[5:0] > 6'd32) | ((ay[5:0] == 6'd32) & ay[6]))};
  assign ox      = x_q[16][23] ? -vx : vx;
  assign oy      = y_q[16][23] ? -vy : vy;
  assign sat_x   = ~x_q[16][23] & (vx > 19'd131071);
  assign sat_y   = ~y_q[16][23] & (vy > 19'd131071);
  assign out_i_d = sat_x ? 18'd131071 : ox[17:0];
  assign out_q_d = sat_y ? 18'd131071 : oy[17:0];

  // Pipeline datapath (no reset)
  integer js;
  always @(posedge clk) begin
    x_q[0]   <= x0_d;
    y_q[0]   <= y0_d;
    z_q[0]   <= z0_d;
    tag_q[0] <= {in_sample_q, in_first, in_last};
    ovf_q[0] <= 1'b0;
    for (js = 0; js < 16; js = js + 1) begin
      x_q[js+1]   <= xn25[js][23:0];
      y_q[js+1]   <= yn25[js][23:0];
      z_q[js+1]   <= zn[js];
      tag_q[js+1] <= tag_q[js];
      ovf_q[js+1] <= (js == 0) ? ofn[js] : (ovf_q[js] | ofn[js]);
    end
    out_i_q   <= out_i_d;
    out_q_q   <= out_q_d;
    out_tag_q <= tag_q[16];
  end

  // Valid pipeline and error flag (reset / clr)
  integer jv;
  always @(posedge clk) begin
    if (!rst_n || clr) begin
      for (jv = 0; jv <= 16; jv = jv + 1) begin
        v_q[jv] <= 1'b0;
      end
      out_valid_q <= 1'b0;
      ovf_err_q   <= 1'b0;
    end
    else begin
      v_q[0] <= in_valid;
      for (jv = 0; jv < 16; jv = jv + 1) begin
        v_q[jv+1] <= v_q[jv];
      end
      out_valid_q <= v_q[16];
      ovf_err_q   <= v_q[16] & (ovf_q[16] | sat_x | sat_y);
    end
  end

  assign out_valid    = out_valid_q;
  assign out_i        = out_i_q;
  assign out_q        = out_q_q;
  assign out_sample_q = out_tag_q[8:2];
  assign out_first    = out_tag_q[1];
  assign out_last     = out_tag_q[0];
  assign ovf_err      = ovf_err_q;

endmodule

`default_nettype wire
