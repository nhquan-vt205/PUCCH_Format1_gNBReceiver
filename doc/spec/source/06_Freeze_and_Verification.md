# 06 — Design freeze, change record và verification

**Version:** 1.0-vi · **Decision basis:** yêu cầu kiến trúc mới của người thiết kế. Đây là architecture change được ghi rõ, không phải extension giữ nguyên mọi freeze v1.3.

## 1. Thay đổi so với hai nguồn

| Chủ đề | Nguồn trước | Freeze mới |
|---|---|---|
| Boundary | v1.3 từ RG RAM/extraction | Từ stream Y_hat do RE Extraction bên ngoài xuất; RG trước extraction đã estimation/equalization |
| Noisy path | v1.3 D09/D10 và Algorithm: raw RE vector, cấm inverse | Inverse phase + coherent sum + normalize thành d_rx scalar |
| Candidate branch | v1.3 Standard-Z full spread sequence | Chỉ 2/4 modulation symbols d_k |
| MLE | v1.3 D13/D14: Euclidean vector, unsigned42 | Scalar dot-product, argmax signed43 |
| Storage | v1.3 Config RAM, RG RAM, noisy buffer84 | Port field snapshot, phase ROM và pipeline nhỏ |
| Control | v1.3 AXI4-Lite và AXI4-Full | cfg/y/res ready-valid streams |
| Result | v1.3 pulse1, sticky CSR | Valid giữ đến ready; success/error record |
| RX OCC | Combined cho phép separate OCC/sign-swap | Cộng OCC vào total phase trước một CORDIC |
| OCC N=4 | Combined dùng DFT4 | Table Walsh từ appendix v1.3 |
| CS phase | Combined lặp phase step đã floor | Modulo12 remainder rồi phase LUT |
| Negative phase | Combined đồng nhất floor góc âm với negate code | Quantize forward, negate modulo; định nghĩa hai phép khác nhau |
| CORDIC gain | Combined đề xuất không bù | Bù sau sum, trước d_rx; explicit constant |
| d(0) scale | Combined dùng Z≈N*A*d | d_rx≈d sau gain/count correction; Z riêng |
| Gold group hopping | Nguồn cũ thiếu factor2/hop trong f_gh và v enable không đúng | `8*(2*slot+h)+b`, enable v=0 |
| Sequence v length12 | Combined còn câu hỏi mở | Base table length12 không phụ thuộc v; không port v |
| Pipeline numeric | Combined chỉ output18/sum26 | Internal I/Q24 F21 và phase24, output18, sum26 |

Các quyết định mới thay v1.3 D04..D17 và D19 ở những điểm nằm ngoài hoặc mâu thuẫn scope; giữ tinh thần một clock, một context, config snapshot, bit ordering và tie smallest-index. Không sửa các tài liệu nguồn.

Gold/OCC correction đã kiểm tra với [TS 38.211 V15.10.0](https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/15.10.00_60/ts_138211v151000p.pdf), §6.3.2.2.1, §5.2.2.2 và Table 6.3.2.4.1-2. Chứng minh và numeric conventions còn lại là quyết định thiết kế mới, không gán cho 3GPP receiver implementation.

## 2. Decision register

| ID | Quyết định | Trạng thái |
|---|---|---|
| F01 | Bốn compute blocks theo Architecture | Baseline frozen |
| F02 | RG đầu vào RE Extraction bên ngoài mặc định đã estimation/equalization; core nhận trực tiếp Y_hat data-only từ extraction, giữ convention I/Q của RG | Baseline frozen |
| F03 | Config field ports + capture một context; không config memory/decode | Baseline frozen |
| F04 | M_bit1/2; BPSK diagonal và QPSK; bit-order theo Algorithm | Baseline frozen |
| F05 | Low-PAPR generator xuất phase base+CS; Gold nằm trong generator | Baseline frozen |
| F06 | OCC ROM trong RX; cộng toàn pha và một CORDIC/RE | Baseline frozen |
| F07 | Base phi*pi/4; CS remainder12; OCC đúng bảng N4 | Baseline frozen |
| F08 | Sum tất cả active hops, bù gain, chia total count | Baseline frozen |
| F09 | Output d_rx phức26 F15 chưa hard decision | Baseline frozen |
| F10 | MLE table-based correlation43 signed; products42, gap44 | Baseline frozen |
| F11 | Candidate scalar constant±23170, mọi norm bằng nhau | Baseline frozen |
| F12 | Tie ascending k; no DTX policy | Baseline frozen |
| F13 | Handshake mọi stream; REPORT chờ consumer | Baseline frozen |
| F14 | Reset synchronous low-active; error abort | Baseline frozen |
| F15 | RNE tại narrowing/normalization; shift arithmetic trong CORDIC | Baseline frozen |
| F16 | Physical ROM style, number of DSP/BRAM, divider implementation | Microarchitecture deliverable |
| F17 | Exact Gold-prep/normalizer latency, top-level latency và timing closure | Microarchitecture deliverable |
| F18 | RTL synthesis, CDC ngoài core, upstream channel/equalizer integration | Implementation verification deliverable |

“Baseline frozen” là convention của bộ tài liệu mới để RTL có một model nhất quán. Đây không phải tuyên bố đã được implementation sign-off bởi người thiết kế. Muốn đổi F01..F15 thì cập nhật toàn bộ file liên quan và golden/checks trong cùng revision.

## 3. Verification matrix

| ID | Test group | Expected check |
|---|---|---|
| V01 | L=4..14 × nohop/hop × legal start symbols × legal OCC; upstream RG đã estimation/equalization | Y_hat giữ convention I/Q của RG qua RE Extraction; physical symbol count, N_SF, q/h/m/n/l_abs đúng; max84 |
| V02 | Gaps, stall, invalid q, wrong first/last, reset mỗi state | Counters chỉ tiến khi transfer; error/restart đúng |
| V03 | M_bit1/2, mọi k, packed bits | Phase/IQ LUT và valid mask đúng; modulation độc lập receive config khác |
| V04 | u=0..29,n=0..11; slot0..19; IDs0,1,29,30,31,1023; hopping modes | Base table/Gold/u/n_cs/reference phase đúng |
| V05 | CS index0..11, OCC mọi row; random sample/full-circle phase | Remainder phase, inverse sign, one rotation và tag alignment |
| V06 | Noiseless mọi legal config/candidate, input Q1.15 | Candidate đúng; no gain/count/hop amplitude mismatch |
| V07 | I/Q extrema, axis/diagonal rotation, RNE tie, negative quotient | Bit-exact widths/rounding; no wrap; saturation → error |
| V08 | Generic candidate metric vs sign form, axes/zero/ties | MLE signed43 đúng; smallest k; best/second/gap |
| V09 | AWGN variance sweep, seeds, ideal vs phase16 vs bit-exact | BER characterization; report numeric degradation, không bịa threshold |
| V10 | Residual phase/gain và unequal noise variance | Document giới hạn unweighted coherent ML; không nhầm thành weighted detector |
| V11 | Corrupt MEM/CSV/checksum; illegal ROM address | Check script phát hiện lệch artifact; RTL không alias invalid address |
| V12 | Success/error result stall, consecutive transactions | Result ổn định; không trộn context hay old phase/candidate |

Reference vectors phải lưu config, input integers, phase per RE, CORDIC output, S, Z, d_rx, mọi metrics, k và packed bits. Các checkpoint đó cho phép phân biệt wrong bit mapping với sai phase/index/numeric.

## 4. Các regression bắt buộc cho lỗi nguồn

1. `L=8,nohop,N_SF=4,i=1,m=1`: OCC phase phải 8000; DFT4 cho 4000 là sai.
2. `s_l=1,n=3`: CS phase phải 4000; repeated floor-step cho 3FFF là sai.
3. Hopping `L=14`: N_SF0=3, N_SF1=4, q hop1 bắt đầu36; không reset accumulator tại q36.
4. QPSK k=1 phải xuất packed `uci_bits=2'b10`; k=2 phải `2'b01`.
5. BPSK input estimate I>0 nhưng I+Q<0 phải decode b0=1.
6. Group hopping phải dùng hai khác biệt: factor2 của slot và hop index, không `8*slot+b`.
7. Accepted last phải cộng sample cuối trước normalization; stall không cộng lại sample.
8. Negate forward code với fractional phase, không recompute floor negative angle.

## 5. Phạm vi script kiểm tra đi kèm

`tools/check_spec.py` kiểm tra checksum/MEM↔CSV, toàn bộ base/CS/OCC addressing, orthogonality thực của bảng OCC, mapping counts và packed bits, noiseless inverse trên ideal/phase16 và bit-level CORDIC arithmetic, một tập Gold/metric/tie invariants. Kết quả tự ghi `VERIFICATION_REPORT.md` với số case thực chạy và giới hạn.

Không có RTL trong bộ này; không gọi script là RTL simulation hoặc BER conformance test. Handshake/reset/error cycle behavior, exhaustive n_ID × slot × mode, AWGN BER, timing và synthesis vẫn phải thực hiện khi có RTL/golden harness tương ứng.

## 6. Trước khi bắt đầu RTL và trước sign-off

Có thể bắt đầu thiết kế module từ baseline port/numeric hiện tại. Microarchitecture cần ghi cụ thể Gold implementation (serial/jump-ahead), latency PREPARE, divider và latency NORMALIZE, ROM read latency, join capacity và global pipeline enable wiring. Các lựa chọn đó không được làm đổi arithmetic model.

Trước sign-off cần hoàn thành V01..V12 ở mức RTL phù hợp, bit-exact against numerical model, synthesis resource report và timing ở clock mục tiêu. Nếu chỉ verify subset cấu hình thì công bố subset và không tuyên bố hỗ trợ đầy đủ legal space. Không để “TBD” về bit order, OCC row, phase sign, candidate count hay numeric scale trong RTL implementation.
