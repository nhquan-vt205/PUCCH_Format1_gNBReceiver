// ============================================================================
// Module : pucch_f1_lowpapr_phase_gen
// From the snapshot: sequence group u[h] (group-hopping Gold) and cyclic shift
// s_l per absolute symbol (cyclic-shift Gold) in PREPARE, then one forward
// phase token per data RE: r_phase = BASE[12*u[h]+n] + CS[t] (mod 65536),
// t = (n * s_l) mod 12 by remainder accumulation, with RE tags.
// Spec    : doc/spec/architecture/pucch_f1_lowpapr_phase_gen_spec.md
// Diagram : doc/diagram/pucch_f1_lowpapr_phase_gen/pucch_f1_lowpapr_phase_gen.svg (L1)
// Revision: 2.0 - regenerated from the S2 SVG model
// ============================================================================
`default_nettype none

module pucch_f1_lowpapr_phase_gen (
  input  wire        clk,             // clock, rising edge
  input  wire        rst_n,           // synchronous active-low reset
  input  wire        txn_start,       // start PREPARE
  input  wire        txn_clr,         // flush to IDLE
  input  wire [9:0]  n_id,            // n_ID
  input  wire [1:0]  gh_mode,         // 0 neither, 1 enable, 2 disable
  input  wire [4:0]  slot_idx,        // slot 0..19
  input  wire [3:0]  start_symbol,    // start symbol
  input  wire        hopping,         // intra-slot hopping
  input  wire [3:0]  m0,              // initial cyclic shift
  input  wire [2:0]  n_sf0,           // data symbols in hop0
  input  wire [6:0]  n_re,            // total RE count
  output wire        gen_ready,       // 1 from end of PREPARE until txn_clr
  output wire        lut_err,         // phase_valid with illegal base/CS address
  output wire        phase_valid,     // phase token valid
  input  wire        phase_ready,     // phase token ready
  output wire [15:0] r_phase,         // base + CS phase, unsigned
  output wire [6:0]  phase_sample_q,  // tag q
  output wire        phase_hop,       // tag h
  output wire [2:0]  phase_m,         // tag m
  output wire [3:0]  phase_n,         // tag n
  output wire [3:0]  phase_l_abs,     // tag l_abs
  output wire        phase_first,     // q == 0
  output wire        phase_last       // q == n_re - 1
);

  localparam [1:0] ST_IDLE = 2'd0;
  localparam [1:0] ST_PREP = 2'd1;
  localparam [1:0] ST_RUN  = 2'd2;
  localparam [1:0] ST_DONE = 2'd3;

  // Base ROM: (8192 * phi_u(n)) mod 65536, addr = 12*u + n (source 07 section 2)
  function [15:0] base_rom;
    input [8:0] addr;
    begin
      case (addr)
        9'd0: base_rom = 16'hA000;
        9'd1: base_rom = 16'h2000;
        9'd2: base_rom = 16'hA000;
        9'd3: base_rom = 16'hA000;
        9'd4: base_rom = 16'hA000;
        9'd5: base_rom = 16'h6000;
        9'd6: base_rom = 16'hA000;
        9'd7: base_rom = 16'hE000;
        9'd8: base_rom = 16'h2000;
        9'd9: base_rom = 16'h2000;
        9'd10: base_rom = 16'h2000;
        9'd11: base_rom = 16'hA000;
        9'd12: base_rom = 16'hA000;
        9'd13: base_rom = 16'h6000;
        9'd14: base_rom = 16'h2000;
        9'd15: base_rom = 16'hA000;
        9'd16: base_rom = 16'h2000;
        9'd17: base_rom = 16'h6000;
        9'd18: base_rom = 16'hE000;
        9'd19: base_rom = 16'hE000;
        9'd20: base_rom = 16'h2000;
        9'd21: base_rom = 16'h6000;
        9'd22: base_rom = 16'h6000;
        9'd23: base_rom = 16'h6000;
        9'd24: base_rom = 16'hA000;
        9'd25: base_rom = 16'h6000;
        9'd26: base_rom = 16'h6000;
        9'd27: base_rom = 16'h2000;
        9'd28: base_rom = 16'hA000;
        9'd29: base_rom = 16'h6000;
        9'd30: base_rom = 16'hE000;
        9'd31: base_rom = 16'h2000;
        9'd32: base_rom = 16'h6000;
        9'd33: base_rom = 16'hA000;
        9'd34: base_rom = 16'h6000;
        9'd35: base_rom = 16'hA000;
        9'd36: base_rom = 16'hA000;
        9'd37: base_rom = 16'hA000;
        9'd38: base_rom = 16'hE000;
        9'd39: base_rom = 16'h6000;
        9'd40: base_rom = 16'h6000;
        9'd41: base_rom = 16'h6000;
        9'd42: base_rom = 16'hA000;
        9'd43: base_rom = 16'h6000;
        9'd44: base_rom = 16'hA000;
        9'd45: base_rom = 16'h2000;
        9'd46: base_rom = 16'hE000;
        9'd47: base_rom = 16'hA000;
        9'd48: base_rom = 16'hA000;
        9'd49: base_rom = 16'hE000;
        9'd50: base_rom = 16'hE000;
        9'd51: base_rom = 16'h2000;
        9'd52: base_rom = 16'h6000;
        9'd53: base_rom = 16'h2000;
        9'd54: base_rom = 16'h2000;
        9'd55: base_rom = 16'hE000;
        9'd56: base_rom = 16'h2000;
        9'd57: base_rom = 16'hE000;
        9'd58: base_rom = 16'hA000;
        9'd59: base_rom = 16'h2000;
        9'd60: base_rom = 16'hA000;
        9'd61: base_rom = 16'hA000;
        9'd62: base_rom = 16'h6000;
        9'd63: base_rom = 16'h2000;
        9'd64: base_rom = 16'hA000;
        9'd65: base_rom = 16'hA000;
        9'd66: base_rom = 16'hA000;
        9'd67: base_rom = 16'hE000;
        9'd68: base_rom = 16'h6000;
        9'd69: base_rom = 16'hE000;
        9'd70: base_rom = 16'h2000;
        9'd71: base_rom = 16'h6000;
        9'd72: base_rom = 16'h2000;
        9'd73: base_rom = 16'hE000;
        9'd74: base_rom = 16'h6000;
        9'd75: base_rom = 16'hE000;
        9'd76: base_rom = 16'hE000;
        9'd77: base_rom = 16'hE000;
        9'd78: base_rom = 16'hA000;
        9'd79: base_rom = 16'hE000;
        9'd80: base_rom = 16'h2000;
        9'd81: base_rom = 16'h2000;
        9'd82: base_rom = 16'h2000;
        9'd83: base_rom = 16'hA000;
        9'd84: base_rom = 16'hE000;
        9'd85: base_rom = 16'hA000;
        9'd86: base_rom = 16'h6000;
        9'd87: base_rom = 16'hE000;
        9'd88: base_rom = 16'hA000;
        9'd89: base_rom = 16'hA000;
        9'd90: base_rom = 16'hA000;
        9'd91: base_rom = 16'hE000;
        9'd92: base_rom = 16'h2000;
        9'd93: base_rom = 16'hE000;
        9'd94: base_rom = 16'h2000;
        9'd95: base_rom = 16'hA000;
        9'd96: base_rom = 16'hA000;
        9'd97: base_rom = 16'hE000;
        9'd98: base_rom = 16'h6000;
        9'd99: base_rom = 16'h2000;
        9'd100: base_rom = 16'hA000;
        9'd101: base_rom = 16'hE000;
        9'd102: base_rom = 16'hA000;
        9'd103: base_rom = 16'h6000;
        9'd104: base_rom = 16'h2000;
        9'd105: base_rom = 16'h6000;
        9'd106: base_rom = 16'h6000;
        9'd107: base_rom = 16'h2000;
        9'd108: base_rom = 16'hA000;
        9'd109: base_rom = 16'hE000;
        9'd110: base_rom = 16'hE000;
        9'd111: base_rom = 16'hA000;
        9'd112: base_rom = 16'hA000;
        9'd113: base_rom = 16'hE000;
        9'd114: base_rom = 16'hA000;
        9'd115: base_rom = 16'h6000;
        9'd116: base_rom = 16'h2000;
        9'd117: base_rom = 16'h6000;
        9'd118: base_rom = 16'hE000;
        9'd119: base_rom = 16'hA000;
        9'd120: base_rom = 16'hA000;
        9'd121: base_rom = 16'h6000;
        9'd122: base_rom = 16'hA000;
        9'd123: base_rom = 16'h6000;
        9'd124: base_rom = 16'h6000;
        9'd125: base_rom = 16'hA000;
        9'd126: base_rom = 16'hE000;
        9'd127: base_rom = 16'hE000;
        9'd128: base_rom = 16'h6000;
        9'd129: base_rom = 16'h6000;
        9'd130: base_rom = 16'h2000;
        9'd131: base_rom = 16'hA000;
        9'd132: base_rom = 16'hA000;
        9'd133: base_rom = 16'hE000;
        9'd134: base_rom = 16'hA000;
        9'd135: base_rom = 16'hE000;
        9'd136: base_rom = 16'hE000;
        9'd137: base_rom = 16'hA000;
        9'd138: base_rom = 16'h6000;
        9'd139: base_rom = 16'h6000;
        9'd140: base_rom = 16'hE000;
        9'd141: base_rom = 16'hE000;
        9'd142: base_rom = 16'h2000;
        9'd143: base_rom = 16'hA000;
        9'd144: base_rom = 16'hA000;
        9'd145: base_rom = 16'hE000;
        9'd146: base_rom = 16'h6000;
        9'd147: base_rom = 16'hA000;
        9'd148: base_rom = 16'hA000;
        9'd149: base_rom = 16'hE000;
        9'd150: base_rom = 16'hA000;
        9'd151: base_rom = 16'h2000;
        9'd152: base_rom = 16'hE000;
        9'd153: base_rom = 16'hA000;
        9'd154: base_rom = 16'h6000;
        9'd155: base_rom = 16'h6000;
        9'd156: base_rom = 16'hA000;
        9'd157: base_rom = 16'h2000;
        9'd158: base_rom = 16'hE000;
        9'd159: base_rom = 16'hE000;
        9'd160: base_rom = 16'h6000;
        9'd161: base_rom = 16'h6000;
        9'd162: base_rom = 16'hA000;
        9'd163: base_rom = 16'hE000;
        9'd164: base_rom = 16'hE000;
        9'd165: base_rom = 16'hA000;
        9'd166: base_rom = 16'hE000;
        9'd167: base_rom = 16'hA000;
        9'd168: base_rom = 16'h2000;
        9'd169: base_rom = 16'h6000;
        9'd170: base_rom = 16'hA000;
        9'd171: base_rom = 16'h2000;
        9'd172: base_rom = 16'h6000;
        9'd173: base_rom = 16'h6000;
        9'd174: base_rom = 16'h6000;
        9'd175: base_rom = 16'h2000;
        9'd176: base_rom = 16'hE000;
        9'd177: base_rom = 16'h2000;
        9'd178: base_rom = 16'hE000;
        9'd179: base_rom = 16'h6000;
        9'd180: base_rom = 16'hA000;
        9'd181: base_rom = 16'h2000;
        9'd182: base_rom = 16'h6000;
        9'd183: base_rom = 16'hE000;
        9'd184: base_rom = 16'hE000;
        9'd185: base_rom = 16'hA000;
        9'd186: base_rom = 16'hA000;
        9'd187: base_rom = 16'hE000;
        9'd188: base_rom = 16'hE000;
        9'd189: base_rom = 16'h6000;
        9'd190: base_rom = 16'h2000;
        9'd191: base_rom = 16'hA000;
        9'd192: base_rom = 16'hE000;
        9'd193: base_rom = 16'hE000;
        9'd194: base_rom = 16'hE000;
        9'd195: base_rom = 16'hE000;
        9'd196: base_rom = 16'h2000;
        9'd197: base_rom = 16'hA000;
        9'd198: base_rom = 16'hE000;
        9'd199: base_rom = 16'h6000;
        9'd200: base_rom = 16'h6000;
        9'd201: base_rom = 16'hE000;
        9'd202: base_rom = 16'hA000;
        9'd203: base_rom = 16'h2000;
        9'd204: base_rom = 16'hE000;
        9'd205: base_rom = 16'h2000;
        9'd206: base_rom = 16'h2000;
        9'd207: base_rom = 16'hE000;
        9'd208: base_rom = 16'h2000;
        9'd209: base_rom = 16'h6000;
        9'd210: base_rom = 16'h6000;
        9'd211: base_rom = 16'hE000;
        9'd212: base_rom = 16'hE000;
        9'd213: base_rom = 16'hA000;
        9'd214: base_rom = 16'h2000;
        9'd215: base_rom = 16'hA000;
        9'd216: base_rom = 16'hA000;
        9'd217: base_rom = 16'h2000;
        9'd218: base_rom = 16'h6000;
        9'd219: base_rom = 16'h6000;
        9'd220: base_rom = 16'hE000;
        9'd221: base_rom = 16'hE000;
        9'd222: base_rom = 16'hA000;
        9'd223: base_rom = 16'h6000;
        9'd224: base_rom = 16'h6000;
        9'd225: base_rom = 16'hA000;
        9'd226: base_rom = 16'h6000;
        9'd227: base_rom = 16'hA000;
        9'd228: base_rom = 16'hA000;
        9'd229: base_rom = 16'hA000;
        9'd230: base_rom = 16'h6000;
        9'd231: base_rom = 16'hA000;
        9'd232: base_rom = 16'hE000;
        9'd233: base_rom = 16'h6000;
        9'd234: base_rom = 16'h6000;
        9'd235: base_rom = 16'h6000;
        9'd236: base_rom = 16'hE000;
        9'd237: base_rom = 16'hA000;
        9'd238: base_rom = 16'h2000;
        9'd239: base_rom = 16'hA000;
        9'd240: base_rom = 16'h6000;
        9'd241: base_rom = 16'h2000;
        9'd242: base_rom = 16'h6000;
        9'd243: base_rom = 16'h2000;
        9'd244: base_rom = 16'h6000;
        9'd245: base_rom = 16'hA000;
        9'd246: base_rom = 16'hE000;
        9'd247: base_rom = 16'h2000;
        9'd248: base_rom = 16'h6000;
        9'd249: base_rom = 16'h2000;
        9'd250: base_rom = 16'hE000;
        9'd251: base_rom = 16'hA000;
        9'd252: base_rom = 16'hA000;
        9'd253: base_rom = 16'h6000;
        9'd254: base_rom = 16'h2000;
        9'd255: base_rom = 16'h6000;
        9'd256: base_rom = 16'hA000;
        9'd257: base_rom = 16'h2000;
        9'd258: base_rom = 16'h2000;
        9'd259: base_rom = 16'h2000;
        9'd260: base_rom = 16'h2000;
        9'd261: base_rom = 16'h6000;
        9'd262: base_rom = 16'hA000;
        9'd263: base_rom = 16'h6000;
        9'd264: base_rom = 16'hA000;
        9'd265: base_rom = 16'h6000;
        9'd266: base_rom = 16'h6000;
        9'd267: base_rom = 16'h6000;
        9'd268: base_rom = 16'hE000;
        9'd269: base_rom = 16'hA000;
        9'd270: base_rom = 16'hA000;
        9'd271: base_rom = 16'hE000;
        9'd272: base_rom = 16'hA000;
        9'd273: base_rom = 16'h2000;
        9'd274: base_rom = 16'h6000;
        9'd275: base_rom = 16'hA000;
        9'd276: base_rom = 16'h6000;
        9'd277: base_rom = 16'hE000;
        9'd278: base_rom = 16'hA000;
        9'd279: base_rom = 16'h6000;
        9'd280: base_rom = 16'hA000;
        9'd281: base_rom = 16'hE000;
        9'd282: base_rom = 16'h6000;
        9'd283: base_rom = 16'h6000;
        9'd284: base_rom = 16'h6000;
        9'd285: base_rom = 16'hA000;
        9'd286: base_rom = 16'hE000;
        9'd287: base_rom = 16'hA000;
        9'd288: base_rom = 16'hA000;
        9'd289: base_rom = 16'hE000;
        9'd290: base_rom = 16'h2000;
        9'd291: base_rom = 16'hA000;
        9'd292: base_rom = 16'h2000;
        9'd293: base_rom = 16'h6000;
        9'd294: base_rom = 16'h6000;
        9'd295: base_rom = 16'h6000;
        9'd296: base_rom = 16'hE000;
        9'd297: base_rom = 16'hA000;
        9'd298: base_rom = 16'h6000;
        9'd299: base_rom = 16'h6000;
        9'd300: base_rom = 16'hA000;
        9'd301: base_rom = 16'h6000;
        9'd302: base_rom = 16'h2000;
        9'd303: base_rom = 16'hE000;
        9'd304: base_rom = 16'h6000;
        9'd305: base_rom = 16'h6000;
        9'd306: base_rom = 16'hA000;
        9'd307: base_rom = 16'h2000;
        9'd308: base_rom = 16'hE000;
        9'd309: base_rom = 16'h2000;
        9'd310: base_rom = 16'hE000;
        9'd311: base_rom = 16'h2000;
        9'd312: base_rom = 16'hE000;
        9'd313: base_rom = 16'h2000;
        9'd314: base_rom = 16'h6000;
        9'd315: base_rom = 16'hA000;
        9'd316: base_rom = 16'h2000;
        9'd317: base_rom = 16'hE000;
        9'd318: base_rom = 16'h2000;
        9'd319: base_rom = 16'hE000;
        9'd320: base_rom = 16'hE000;
        9'd321: base_rom = 16'hA000;
        9'd322: base_rom = 16'h2000;
        9'd323: base_rom = 16'hE000;
        9'd324: base_rom = 16'hA000;
        9'd325: base_rom = 16'hA000;
        9'd326: base_rom = 16'h6000;
        9'd327: base_rom = 16'h6000;
        9'd328: base_rom = 16'h6000;
        9'd329: base_rom = 16'hA000;
        9'd330: base_rom = 16'hE000;
        9'd331: base_rom = 16'h2000;
        9'd332: base_rom = 16'hA000;
        9'd333: base_rom = 16'h6000;
        9'd334: base_rom = 16'h2000;
        9'd335: base_rom = 16'hA000;
        9'd336: base_rom = 16'h2000;
        9'd337: base_rom = 16'hE000;
        9'd338: base_rom = 16'h6000;
        9'd339: base_rom = 16'h2000;
        9'd340: base_rom = 16'h2000;
        9'd341: base_rom = 16'hE000;
        9'd342: base_rom = 16'hE000;
        9'd343: base_rom = 16'hE000;
        9'd344: base_rom = 16'h2000;
        9'd345: base_rom = 16'h6000;
        9'd346: base_rom = 16'hA000;
        9'd347: base_rom = 16'h2000;
        9'd348: base_rom = 16'hA000;
        9'd349: base_rom = 16'h6000;
        9'd350: base_rom = 16'hA000;
        9'd351: base_rom = 16'h6000;
        9'd352: base_rom = 16'hA000;
        9'd353: base_rom = 16'hA000;
        9'd354: base_rom = 16'h6000;
        9'd355: base_rom = 16'hE000;
        9'd356: base_rom = 16'hE000;
        9'd357: base_rom = 16'h2000;
        9'd358: base_rom = 16'h6000;
        9'd359: base_rom = 16'hA000;
        default: base_rom = 16'h0000;
      endcase
    end
  endfunction

  // CS ROM: floor(65536 * t / 12) (source 07 section 4)
  function [15:0] cs_rom;
    input [3:0] t;
    begin
      case (t)
        4'd0:    cs_rom = 16'h0000;
        4'd1:    cs_rom = 16'h1555;
        4'd2:    cs_rom = 16'h2AAA;
        4'd3:    cs_rom = 16'h4000;
        4'd4:    cs_rom = 16'h5555;
        4'd5:    cs_rom = 16'h6AAA;
        4'd6:    cs_rom = 16'h8000;
        4'd7:    cs_rom = 16'h9555;
        4'd8:    cs_rom = 16'hAAAA;
        4'd9:    cs_rom = 16'hC000;
        4'd10:   cs_rom = 16'hD555;
        4'd11:   cs_rom = 16'hEAAA;
        default: cs_rom = 16'h0000;
      endcase
    end
  endfunction

  // ---------------- registers ----------------
  reg  [1:0]  state_q;
  reg         gen_ready_q;
  reg  [15:0] fgh_q;            // c_gh[16*slot .. 16*slot+15], bit b at position b
  reg  [6:0]  ncs_byte_q;       // n_cs bits 0..6 being assembled (bit 7 arrives last)
  reg  [3:0]  s_cache_q [0:13]; // s_l per absolute symbol
  reg  [4:0]  u0_q;             // sequence group hop0
  reg  [4:0]  u1_q;             // sequence group hop1
  reg  [6:0]  q_q;              // RE index
  reg  [2:0]  g_q;              // data symbol 0..6
  reg  [3:0]  n_q;              // subcarrier
  reg  [3:0]  t_q;              // CS remainder (n * s_l) mod 12

  // ---------------- Gold generators ----------------
  wire [9:0]  gh_div;
  wire [5:0]  gh_init;
  wire        gh_valid;
  wire        gh_bit;
  wire [11:0] gh_idx;
  wire        cs_valid;
  wire        cs_bit;
  wire [11:0] cs_idx;

  assign gh_div  = n_id / 10'd30;
  assign gh_init = gh_div[5:0];       // n_id / 30 <= 34

  pucch_f1_gold_gen u_gold_gh (
    .clk     (clk),
    .rst_n   (rst_n),
    .start   (txn_start),
    .clr     (txn_clr),
    .c_init  ({25'd0, gh_init}),
    .c_valid (gh_valid),
    .c_bit   (gh_bit),
    .c_idx   (gh_idx)
  );

  pucch_f1_gold_gen u_gold_cs (
    .clk     (clk),
    .rst_n   (rst_n),
    .start   (txn_start),
    .clr     (txn_clr),
    .c_init  ({21'd0, n_id}),
    .c_valid (cs_valid),
    .c_bit   (cs_bit),
    .c_idx   (cs_idx)
  );

  // ---------------- Gold bit capture (blk_cap) ----------------
  wire        prep;
  wire [11:0] gh_base;
  wire [11:0] gh_off;
  wire        gh_hit;
  wire [11:0] cs_base;
  wire [11:0] cs_off;
  wire        cs_hit;
  wire [7:0]  n_cs;
  wire        sc_we;
  wire [3:0]  sc_wa;
  wire [8:0]  sc_sum;
  wire [8:0]  sc_mod;
  wire [3:0]  sc_wd;
  wire        prep_done;
  wire        flush;

  assign prep      = (state_q == ST_PREP);
  assign flush     = txn_clr | txn_start;
  assign gh_base   = {3'd0, slot_idx, 4'd0};
  assign gh_off    = gh_idx - gh_base;
  assign gh_hit    = prep & gh_valid & (gh_idx >= gh_base) & (gh_off < 12'd16);
  assign cs_base   = {7'd0, slot_idx} * 12'd112;
  assign cs_off    = cs_idx - cs_base;
  assign cs_hit    = prep & cs_valid & (cs_idx >= cs_base) & (cs_off < 12'd112);
  assign n_cs      = {cs_bit, ncs_byte_q[6:0]};
  assign sc_we     = cs_hit & (cs_off[2:0] == 3'd7);
  assign sc_wa     = cs_off[6:3];
  assign sc_sum    = {5'd0, m0} + {1'b0, n_cs};
  assign sc_mod    = sc_sum % 9'd12;
  assign sc_wd     = sc_mod[3:0];
  assign prep_done = cs_hit & (cs_off == 12'd111);

  // ---------------- sequence group (blk_uq) ----------------
  wire [9:0]  f_ss_w;
  wire [7:0]  fgh0_w;
  wire [7:0]  fgh1_w;
  wire [4:0]  f_ss;
  wire [4:0]  fgh0;
  wire [4:0]  fgh1;
  wire [5:0]  u0_sum;
  wire [5:0]  u1_sum;
  wire [5:0]  u0_m;
  wire [5:0]  u1_m;
  wire [4:0]  u0_d;
  wire [4:0]  u1_d;

  assign f_ss_w = n_id % 10'd30;
  assign fgh0_w = fgh_q[7:0]  % 8'd30;
  assign fgh1_w = fgh_q[15:8] % 8'd30;
  assign f_ss   = f_ss_w[4:0];
  assign fgh0   = (gh_mode == 2'd1) ? fgh0_w[4:0] : 5'd0;
  assign fgh1   = (gh_mode == 2'd1) ? fgh1_w[4:0] : 5'd0;
  assign u0_sum = {1'b0, f_ss} + {1'b0, fgh0};
  assign u1_sum = {1'b0, f_ss} + {1'b0, fgh1};
  assign u0_m   = (u0_sum >= 6'd30) ? (u0_sum - 6'd30) : u0_sum;
  assign u1_m   = (u1_sum >= 6'd30) ? (u1_sum - 6'd30) : u1_sum;
  assign u0_d   = u0_m[4:0];
  assign u1_d   = u1_m[4:0];

  // ---------------- RE cursor tags (blk_cursor) ----------------
  wire        fire;
  wire [4:0]  l_abs5;
  wire [3:0]  s_l;
  wire [4:0]  t_sum;
  wire [3:0]  t_next;

  assign phase_valid    = (state_q == ST_RUN);
  assign fire           = phase_valid & phase_ready;
  assign phase_hop      = hopping & (g_q >= n_sf0);
  assign phase_m        = phase_hop ? (g_q - n_sf0) : g_q;
  assign l_abs5         = {1'b0, start_symbol} + {1'b0, g_q, 1'b1};
  assign phase_l_abs    = l_abs5[3:0];
  assign phase_sample_q = q_q;
  assign phase_n        = n_q;
  assign phase_first    = (q_q == 7'd0);
  assign phase_last     = (q_q == (n_re - 7'd1));
  assign s_l            = (l_abs5 <= 5'd13) ? s_cache_q[l_abs5[3:0]] : 4'd0;
  assign t_sum          = {1'b0, t_q} + {1'b0, s_l};
  assign t_next         = (t_sum >= 5'd12) ? (t_sum[3:0] - 4'd12) : t_sum[3:0];

  // ---------------- phase ROMs ----------------
  wire [4:0]  u_sel;
  wire [8:0]  base_addr;
  wire [15:0] base_phase;
  wire [15:0] cs_phase;

  assign u_sel      = phase_hop ? u1_q : u0_q;
  assign base_addr  = ({4'd0, u_sel} * 9'd12) + {5'd0, n_q};
  assign base_phase = ((u_sel <= 5'd29) & (n_q <= 4'd11)) ? base_rom(base_addr) : 16'h0000;
  assign cs_phase   = (t_q <= 4'd11) ? cs_rom(t_q) : 16'h0000;
  assign r_phase    = base_phase + cs_phase;
  assign lut_err    = phase_valid & ((u_sel > 5'd29) | (n_q > 4'd11) | (t_q > 4'd11) | (l_abs5 > 5'd13));

  // ---------------- FSM (cloud_next) ----------------
  reg  [1:0]  state_d;

  always @(*) begin
    state_d = state_q;
    if (txn_clr) begin
      state_d = ST_IDLE;
    end
    else if (txn_start) begin
      state_d = ST_PREP;
    end
    else begin
      case (state_q)
        ST_PREP: begin
          if (prep_done) begin
            state_d = ST_RUN;
          end
        end
        ST_RUN: begin
          if (fire & phase_last) begin
            state_d = ST_DONE;
          end
        end
        default: begin
          state_d = state_q;
        end
      endcase
    end
  end

  // ---------------- sequential ----------------
  integer i;
  always @(posedge clk) begin
    if (!rst_n || flush) begin
      fgh_q      <= 16'd0;
      ncs_byte_q <= 7'd0;
      for (i = 0; i < 14; i = i + 1) begin
        s_cache_q[i] <= 4'd0;
      end
      u0_q <= 5'd0;
      u1_q <= 5'd0;
      q_q  <= 7'd0;
      g_q  <= 3'd0;
      n_q  <= 4'd0;
      t_q  <= 4'd0;
    end
    else begin
      if (gh_hit) begin
        fgh_q[gh_off[3:0]] <= gh_bit;
      end
      if (cs_hit & (cs_off[2:0] != 3'd7)) begin
        ncs_byte_q[cs_off[2:0]] <= cs_bit;
      end
      if (sc_we) begin
        s_cache_q[sc_wa] <= sc_wd;
      end
      if (prep_done) begin
        u0_q <= u0_d;
        u1_q <= u1_d;
      end
      if (fire) begin
        q_q <= q_q + 7'd1;
        if (n_q == 4'd11) begin
          n_q <= 4'd0;
          t_q <= 4'd0;
          g_q <= g_q + 3'd1;
        end
        else begin
          n_q <= n_q + 4'd1;
          t_q <= t_next;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      state_q     <= ST_IDLE;
      gen_ready_q <= 1'b0;
    end
    else begin
      state_q <= state_d;
      if (flush) begin
        gen_ready_q <= 1'b0;
      end
      else if (prep_done) begin
        gen_ready_q <= 1'b1;
      end
    end
  end

  assign gen_ready = gen_ready_q;

endmodule

`default_nettype wire
