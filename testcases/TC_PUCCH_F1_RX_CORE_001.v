// ============================================================================
// TC_PUCCH_F1_RX_CORE_001 - MATLAB decoded bits (continuous stream, no stall)
// Every case with a valid MATLAB decode, continuous RE stream, res_ready held
// high; {res_error, res_uci_bits} must equal {0, MATLAB decoded bits}.
// Copied to sim/run_test.v and included inside tb_pucch_f1_rx_core.
// ============================================================================
  initial begin
    init_test;
    reset_dut;
    $display("-- MATLAB decoded bits test --");
    tx_cases  = 0;
    tx_errors = 0;
    open_data;
    while (case_valid) begin
      if (mat_valid == 1) begin
        run_case(1'b0, 0);
        $sformat(case_name, "case_%0d_frame_%0d_snr_%0g_%0s_vs_matlab", cur_id, src_frame, src_snr, cfg_tag);
        check_bits(case_name, ref_matlab, act_bits);
        if (tx_b0 >= 0) begin
          tx_cases = tx_cases + 1;
          if (act_bits[1:0] !== {(tx_b1 < 0) ? 1'b0 : tx_b1[0], tx_b0[0]}) begin
            tx_errors = tx_errors + 1;
            $display("[INFO] case_%0d DUT bits %b differ from TX bits b1=%0d b0=%0d", cur_id, act_bits[1:0],
                     tx_b1, tx_b0);
          end
        end
      end
      else begin
        $display("[INFO] case_%0d skipped: no valid MATLAB decode", cur_id);
      end
      load_case;
    end
    close_data;
    if (tx_cases > 0) begin
      $display("[INFO] DUT vs TX bits: %0d of %0d cases differ", tx_errors, tx_cases);
    end
    end_test;
  end
