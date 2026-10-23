// ============================================================================
// Module : pucch_f1_rx_inverse
// Per joined RE: add OCC phase to r_phase, negate the total once, rotate Y_hat
// with one CORDIC, accumulate all REs of both hops into S (signed26 F15).
// After the last RE the normalizer outputs d_rx = RNE(RNE(S*KINV)/N_RE).
// Spec    : doc/spec/architecture/pucch_f1_rx_inverse_spec.md
// Diagram : doc/diagram/pucch_f1_rx_inverse/pucch_f1_rx_inverse.svg (L1)
// Revision: 2.0 - regenerated from the S2 SVG model
// ============================================================================
`default_nettype none

module pucch_f1_rx_inverse (
  input  wire        clk,             // clock, rising edge
  input  wire        rst_n,           // synchronous active-low reset
  input  wire        txn_clr,         // flush join, pipeline, sum, normalizer
  input  wire        join_fire,       // capture data + phase pair
  input  wire [15:0] y_i,             // Y_hat I, signed F15
  input  wire [15:0] y_q,             // Y_hat Q, signed F15
  input  wire [15:0] r_phase,         // base + CS phase
  input  wire [6:0]  phase_sample_q,  // tag q
  input  wire        phase_hop,       // tag h
  input  wire [2:0]  phase_m,         // tag m
  input  wire        phase_first,     // tag first
  input  wire        phase_last,      // tag last
  input  wire [2:0]  occ_i,           // OCC index
  input  wire [2:0]  n_sf0,           // N_SF hop0
  input  wire [2:0]  n_sf1,           // N_SF hop1
  input  wire [6:0]  n_re,            // N_RE
  output wire        occ_err,         // illegal OCC (N, i, m) for current tag
  output wire        acc_done,        // 1-clock pulse: last RE accumulated
  output wire        num_err,         // numeric overflow / saturation pulse
  output wire        d_valid,         // d_rx valid
  input  wire        d_ready,         // d_rx ready
  output wire [25:0] d_i,             // d_rx I, signed F15
  output wire [25:0] d_q,             // d_rx Q, signed F15
  output wire [6:0]  d_n_re           // = n_re (debug)
);

  // OCC ROM: floor(65536 * rho / N), addr = offset[N] + i*N + m (source 07 section 3)
  function [15:0] occ_rom;
    input [7:0] addr;
    begin
      case (addr)
        8'd0: occ_rom = 16'h0000;
        8'd1: occ_rom = 16'h0000;
        8'd2: occ_rom = 16'h0000;
        8'd3: occ_rom = 16'h0000;
        8'd4: occ_rom = 16'h8000;
        8'd5: occ_rom = 16'h0000;
        8'd6: occ_rom = 16'h0000;
        8'd7: occ_rom = 16'h0000;
        8'd8: occ_rom = 16'h0000;
        8'd9: occ_rom = 16'h5555;
        8'd10: occ_rom = 16'hAAAA;
        8'd11: occ_rom = 16'h0000;
        8'd12: occ_rom = 16'hAAAA;
        8'd13: occ_rom = 16'h5555;
        8'd14: occ_rom = 16'h0000;
        8'd15: occ_rom = 16'h0000;
        8'd16: occ_rom = 16'h0000;
        8'd17: occ_rom = 16'h0000;
        8'd18: occ_rom = 16'h0000;
        8'd19: occ_rom = 16'h8000;
        8'd20: occ_rom = 16'h0000;
        8'd21: occ_rom = 16'h8000;
        8'd22: occ_rom = 16'h0000;
        8'd23: occ_rom = 16'h0000;
        8'd24: occ_rom = 16'h8000;
        8'd25: occ_rom = 16'h8000;
        8'd26: occ_rom = 16'h0000;
        8'd27: occ_rom = 16'h8000;
        8'd28: occ_rom = 16'h8000;
        8'd29: occ_rom = 16'h0000;
        8'd30: occ_rom = 16'h0000;
        8'd31: occ_rom = 16'h0000;
        8'd32: occ_rom = 16'h0000;
        8'd33: occ_rom = 16'h0000;
        8'd34: occ_rom = 16'h0000;
        8'd35: occ_rom = 16'h0000;
        8'd36: occ_rom = 16'h3333;
        8'd37: occ_rom = 16'h6666;
        8'd38: occ_rom = 16'h9999;
        8'd39: occ_rom = 16'hCCCC;
        8'd40: occ_rom = 16'h0000;
        8'd41: occ_rom = 16'h6666;
        8'd42: occ_rom = 16'hCCCC;
        8'd43: occ_rom = 16'h3333;
        8'd44: occ_rom = 16'h9999;
        8'd45: occ_rom = 16'h0000;
        8'd46: occ_rom = 16'h9999;
        8'd47: occ_rom = 16'h3333;
        8'd48: occ_rom = 16'hCCCC;
        8'd49: occ_rom = 16'h6666;
        8'd50: occ_rom = 16'h0000;
        8'd51: occ_rom = 16'hCCCC;
        8'd52: occ_rom = 16'h9999;
        8'd53: occ_rom = 16'h6666;
        8'd54: occ_rom = 16'h3333;
        8'd55: occ_rom = 16'h0000;
        8'd56: occ_rom = 16'h0000;
        8'd57: occ_rom = 16'h0000;
        8'd58: occ_rom = 16'h0000;
        8'd59: occ_rom = 16'h0000;
        8'd60: occ_rom = 16'h0000;
        8'd61: occ_rom = 16'h0000;
        8'd62: occ_rom = 16'h2AAA;
        8'd63: occ_rom = 16'h5555;
        8'd64: occ_rom = 16'h8000;
        8'd65: occ_rom = 16'hAAAA;
        8'd66: occ_rom = 16'hD555;
        8'd67: occ_rom = 16'h0000;
        8'd68: occ_rom = 16'h5555;
        8'd69: occ_rom = 16'hAAAA;
        8'd70: occ_rom = 16'h0000;
        8'd71: occ_rom = 16'h5555;
        8'd72: occ_rom = 16'hAAAA;
        8'd73: occ_rom = 16'h0000;
        8'd74: occ_rom = 16'h8000;
        8'd75: occ_rom = 16'h0000;
        8'd76: occ_rom = 16'h8000;
        8'd77: occ_rom = 16'h0000;
        8'd78: occ_rom = 16'h8000;
        8'd79: occ_rom = 16'h0000;
        8'd80: occ_rom = 16'hAAAA;
        8'd81: occ_rom = 16'h5555;
        8'd82: occ_rom = 16'h0000;
        8'd83: occ_rom = 16'hAAAA;
        8'd84: occ_rom = 16'h5555;
        8'd85: occ_rom = 16'h0000;
        8'd86: occ_rom = 16'hD555;
        8'd87: occ_rom = 16'hAAAA;
        8'd88: occ_rom = 16'h8000;
        8'd89: occ_rom = 16'h5555;
        8'd90: occ_rom = 16'h2AAA;
        8'd91: occ_rom = 16'h0000;
        8'd92: occ_rom = 16'h0000;
        8'd93: occ_rom = 16'h0000;
        8'd94: occ_rom = 16'h0000;
        8'd95: occ_rom = 16'h0000;
        8'd96: occ_rom = 16'h0000;
        8'd97: occ_rom = 16'h0000;
        8'd98: occ_rom = 16'h0000;
        8'd99: occ_rom = 16'h2492;
        8'd100: occ_rom = 16'h4924;
        8'd101: occ_rom = 16'h6DB6;
        8'd102: occ_rom = 16'h9249;
        8'd103: occ_rom = 16'hB6DB;
        8'd104: occ_rom = 16'hDB6D;
        8'd105: occ_rom = 16'h0000;
        8'd106: occ_rom = 16'h4924;
        8'd107: occ_rom = 16'h9249;
        8'd108: occ_rom = 16'hDB6D;
        8'd109: occ_rom = 16'h2492;
        8'd110: occ_rom = 16'h6DB6;
        8'd111: occ_rom = 16'hB6DB;
        8'd112: occ_rom = 16'h0000;
        8'd113: occ_rom = 16'h6DB6;
        8'd114: occ_rom = 16'hDB6D;
        8'd115: occ_rom = 16'h4924;
        8'd116: occ_rom = 16'hB6DB;
        8'd117: occ_rom = 16'h2492;
        8'd118: occ_rom = 16'h9249;
        8'd119: occ_rom = 16'h0000;
        8'd120: occ_rom = 16'h9249;
        8'd121: occ_rom = 16'h2492;
        8'd122: occ_rom = 16'hB6DB;
        8'd123: occ_rom = 16'h4924;
        8'd124: occ_rom = 16'hDB6D;
        8'd125: occ_rom = 16'h6DB6;
        8'd126: occ_rom = 16'h0000;
        8'd127: occ_rom = 16'hB6DB;
        8'd128: occ_rom = 16'h6DB6;
        8'd129: occ_rom = 16'h2492;
        8'd130: occ_rom = 16'hDB6D;
        8'd131: occ_rom = 16'h9249;
        8'd132: occ_rom = 16'h4924;
        8'd133: occ_rom = 16'h0000;
        8'd134: occ_rom = 16'hDB6D;
        8'd135: occ_rom = 16'hB6DB;
        8'd136: occ_rom = 16'h9249;
        8'd137: occ_rom = 16'h6DB6;
        8'd138: occ_rom = 16'h4924;
        8'd139: occ_rom = 16'h2492;
        default: occ_rom = 16'h0000;
      endcase
    end
  endfunction

  // ---------------- OCC lookup (blk_occ, mem_occ) ----------------
  wire [2:0]  n_sel;
  reg  [7:0]  occ_off;
  wire [7:0]  occ_addr;
  wire [15:0] occ_phase;
  wire [15:0] tot_phase;
  wire [15:0] rm_phase;

  assign n_sel = phase_hop ? n_sf1 : n_sf0;

  always @(*) begin
    case (n_sel)
      3'd1:    occ_off = 8'd0;
      3'd2:    occ_off = 8'd1;
      3'd3:    occ_off = 8'd5;
      3'd4:    occ_off = 8'd14;
      3'd5:    occ_off = 8'd30;
      3'd6:    occ_off = 8'd55;
      3'd7:    occ_off = 8'd91;
      default: occ_off = 8'd0;
    endcase
  end

  assign occ_addr  = occ_off + ({5'd0, occ_i} * {5'd0, n_sel}) + {5'd0, phase_m};
  assign occ_err   = (n_sel == 3'd0) | (occ_i >= n_sel) | (phase_m >= n_sel);
  assign occ_phase = occ_err ? 16'h0000 : occ_rom(occ_addr);
  assign tot_phase = r_phase + occ_phase;   // forward base + CS + OCC, mod 65536
  assign rm_phase  = -tot_phase;            // negate the total once, mod 65536

  // ---------------- join register ----------------
  reg         j_valid_q;
  reg  [15:0] j_i_q;
  reg  [15:0] j_q_q;
  reg  [15:0] j_phase_q;
  reg  [6:0]  j_sample_q_q;
  reg         j_first_q;
  reg         j_last_q;

  always @(posedge clk) begin
    if (!rst_n) begin
      j_valid_q    <= 1'b0;
      j_i_q        <= 16'd0;
      j_q_q        <= 16'd0;
      j_phase_q    <= 16'd0;
      j_sample_q_q <= 7'd0;
      j_first_q    <= 1'b0;
      j_last_q     <= 1'b0;
    end
    else begin
      j_valid_q <= join_fire & ~txn_clr;
      if (join_fire) begin
        j_i_q        <= y_i;
        j_q_q        <= y_q;
        j_phase_q    <= rm_phase;
        j_sample_q_q <= phase_sample_q;
        j_first_q    <= phase_first;
        j_last_q     <= phase_last;
      end
    end
  end

  // ---------------- CORDIC ----------------
  wire        c_valid;
  wire [17:0] c_i;
  wire [17:0] c_q;
  wire [6:0]  c_sample_q;
  wire        c_first;
  wire        c_last;
  wire        c_ovf_err;

  pucch_f1_cordic u_cordic (
    .clk          (clk),
    .rst_n        (rst_n),
    .clr          (txn_clr),
    .in_valid     (j_valid_q),
    .in_i         (j_i_q),
    .in_q         (j_q_q),
    .in_phase     (j_phase_q),
    .in_sample_q  (j_sample_q_q),
    .in_first     (j_first_q),
    .in_last      (j_last_q),
    .out_valid    (c_valid),
    .out_i        (c_i),
    .out_q        (c_q),
    .out_sample_q (c_sample_q),
    .out_first    (c_first),
    .out_last     (c_last),
    .ovf_err      (c_ovf_err)
  );

  // ---------------- coherent accumulator (blk_acc) ----------------
  reg  [25:0] s_i_q;
  reg  [25:0] s_q_q;
  reg         acc_done_q;
  reg         acc_ovf_q;
  wire [25:0] x_i;
  wire [25:0] x_q;
  wire [26:0] sum_i;
  wire [26:0] sum_q;
  wire        ovf;

  assign x_i   = {{8{c_i[17]}}, c_i};
  assign x_q   = {{8{c_q[17]}}, c_q};
  assign sum_i = c_first ? {x_i[25], x_i} : ({s_i_q[25], s_i_q} + {x_i[25], x_i});
  assign sum_q = c_first ? {x_q[25], x_q} : ({s_q_q[25], s_q_q} + {x_q[25], x_q});
  assign ovf   = (sum_i[26] != sum_i[25]) | (sum_q[26] != sum_q[25]);

  always @(posedge clk) begin
    if (!rst_n || txn_clr) begin
      s_i_q      <= 26'd0;
      s_q_q      <= 26'd0;
      acc_done_q <= 1'b0;
      acc_ovf_q  <= 1'b0;
    end
    else begin
      if (c_valid) begin
        s_i_q <= sum_i[25:0];
        s_q_q <= sum_q[25:0];
      end
      acc_ovf_q  <= c_valid & ovf;
      acc_done_q <= c_valid & c_last & ~ovf;
    end
  end

  // ---------------- normalizer ----------------
  wire n_sat_err;

  pucch_f1_normalize u_normalize (
    .clk     (clk),
    .rst_n   (rst_n),
    .clr     (txn_clr),
    .start   (acc_done_q),
    .s_i     (s_i_q),
    .s_q     (s_q_q),
    .n_re    (n_re),
    .d_valid (d_valid),
    .d_ready (d_ready),
    .d_i     (d_i),
    .d_q     (d_q),
    .sat_err (n_sat_err)
  );

  assign acc_done = acc_done_q;
  assign num_err  = c_ovf_err | acc_ovf_q | n_sat_err;
  assign d_n_re   = n_re;

endmodule

`default_nettype wire
