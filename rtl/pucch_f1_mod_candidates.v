// ============================================================================
// Module : pucch_f1_mod_candidates
// Builds the 2 (M_bit=1) or 4 (M_bit=2) modulation candidates d_k(0) on
// txn_start and offers the whole table as one valid/ready transfer.
// Spec    : doc/spec/architecture/pucch_f1_mod_candidates_spec.md
// Diagram : doc/diagram/pucch_f1_mod_candidates/pucch_f1_mod_candidates.svg (L2)
// Revision: 2.0 - regenerated from the S2 SVG model
// ============================================================================
`default_nettype none

module pucch_f1_mod_candidates (
  input  wire        clk,         // clock, rising edge
  input  wire        rst_n,       // synchronous active-low reset
  input  wire        txn_start,   // build table
  input  wire        txn_clr,     // drop table
  input  wire [1:0]  m_bit,       // 1 or 2
  output wire        cand_valid,  // table valid
  input  wire        cand_ready,  // table ready
  output wire [3:0]  cand_mask,   // active entries
  output wire [1:0]  cand_m_bit,  // copy of m_bit
  output wire [63:0] cand_i,      // 4 x signed16 F15, entry k = [16k+15:16k]
  output wire [63:0] cand_q,      // 4 x signed16 F15
  output wire [63:0] cand_phase,  // 4 x unsigned16 phase
  output wire [7:0]  cand_bits    // 4 x packed {b1, b0}
);

  // Constant tables (23170 = 16'h5A82, -23170 = 16'hA57E)
  localparam [63:0] QPSK_I    = 64'hA57E_A57E_5A82_5A82;
  localparam [63:0] QPSK_Q    = 64'hA57E_5A82_A57E_5A82;
  localparam [63:0] QPSK_PH   = 64'hA000_6000_E000_2000;
  localparam [7:0]  QPSK_BITS = 8'b11_01_10_00;
  localparam [63:0] BPSK_I    = 64'h0000_0000_A57E_5A82;
  localparam [63:0] BPSK_Q    = 64'h0000_0000_A57E_5A82;
  localparam [63:0] BPSK_PH   = 64'h0000_0000_A000_2000;
  localparam [7:0]  BPSK_BITS = 8'b00_00_01_00;

  reg  [1:0] m_bit_q;       // captured M_bit
  reg        cand_valid_q;  // table offered
  reg        cand_valid_d;
  wire       tbl_hs;
  wire       is_qpsk;

  assign tbl_hs = cand_valid_q & cand_ready;

  always @(*) begin
    cand_valid_d = cand_valid_q;
    if (txn_clr) begin
      cand_valid_d = 1'b0;
    end
    else if (txn_start) begin
      cand_valid_d = 1'b1;
    end
    else if (tbl_hs) begin
      cand_valid_d = 1'b0;
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      m_bit_q      <= 2'd0;
      cand_valid_q <= 1'b0;
    end
    else begin
      if (txn_start) begin
        m_bit_q <= m_bit;
      end
      cand_valid_q <= cand_valid_d;
    end
  end

  // Table selected by the captured M_bit
  assign is_qpsk    = (m_bit_q == 2'd2);
  assign cand_mask  = is_qpsk ? 4'b1111   : 4'b0011;
  assign cand_i     = is_qpsk ? QPSK_I    : BPSK_I;
  assign cand_q     = is_qpsk ? QPSK_Q    : BPSK_Q;
  assign cand_phase = is_qpsk ? QPSK_PH   : BPSK_PH;
  assign cand_bits  = is_qpsk ? QPSK_BITS : BPSK_BITS;
  assign cand_m_bit = m_bit_q;
  assign cand_valid = cand_valid_q;

endmodule

`default_nettype wire
