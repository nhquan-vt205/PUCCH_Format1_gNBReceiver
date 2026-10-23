# 05 — LUT specification

**Version:** 1.0-vi. Tất cả pha đã chuẩn hóa theo **số vòng**: `phase16/65536` turn. “Chuẩn hóa pha” không có nghĩa chuẩn hóa biên độ sample thu.

Các LUT này loại pha low-PAPR/CS/OCC của `Y_hat` trích xuất từ RG đã channel estimation/equalization trước RE Extraction bên ngoài. LUT không chứa channel-estimation hay equalizer coefficients; upstream clarification không làm thay đổi nội dung/địa chỉ ROM.

## 1. ROM artifact và authority

Bản đọc tập trung: [07_LUT_Consolidated.md](07_LUT_Consolidated.md) chứa đầy đủ mọi bảng trong một file Markdown, gồm cả giá trị lý tưởng và mã pha ROM. Tái sinh bằng `python tools/build_lut_markdown.py`; kiểm tra đồng bộ bằng `python tools/build_lut_markdown.py --check`. Nguồn hiện có là CSV/MEM, chưa có workbook Excel trong workspace.

| Artifact | Entries | Word width | Address / mục đích |
|---|---:|---:|---|
| [r_base_phase16.mem](lut/r_base_phase16.mem) | 360 | 16 | `12*u+n`; phase base r(n) |
| [r_base_phase16.csv](lut/r_base_phase16.csv) | 360 rows | Human-readable | addr,u,n,phi,phase_hex đầy đủ |
| [occ_phase16.mem](lut/occ_phase16.mem) | 140 | 16 | Compact N_SF-major, i-major, m-major |
| [occ_phase16.csv](lut/occ_phase16.csv) | 140 rows | Human-readable | addr,N_SF,i,m,rho,phase_hex đầy đủ |
| [cs_phase16.mem](lut/cs_phase16.mem) | 12 | 16 | t=(s_l*n)%12 |
| [cs_phase16.csv](lut/cs_phase16.csv) | 12 rows | Human-readable | t,phase_hex |
| [n_sf.csv](lut/n_sf.csv) | 11 rows | Human-readable | L=4..14, no_hop,hop0,hop1 |
| [modulation.csv](lut/modulation.csv) | 6 rows | Human-readable | M_bit,k,b0,b1,phase,I/Q |
| [cordic_atan_phase24.mem](lut/cordic_atan_phase24.mem) | 16 | 24 | j=0..15 |
| [constants.json](lut/constants.json) | — | — | Gain inverse, widths, candidate component |
| [manifest.json](lut/manifest.json) | — | — | SHA256 và byte length của 10 artifacts |

`.mem` chứa một từ hex uppercase mỗi dòng, không `0x`, không header/comment. Phù hợp `$readmemh`; địa chỉ là line index bắt đầu 0. Pha dùng unsigned; không sign-extend ROM phase16 trước modulo arithmetic. `.csv` có header, địa chỉ decimal, phase hex không prefix. Tất cả tables immutable trong transaction.

Không cần LUT full `r(alpha,n)` gồm 30*12*12 entries hay ROM full candidate waveforms. Base r chỉ 360 entries; CS và OCC được cộng vào pha khi chạy.

## 2. Base sequence r(n)

Nguồn dữ liệu: bảng `phi_u(n)` trong appendix v1.3 người dùng cung cấp. CSV/MEM ở trên chứa đủ **30 nhóm × 12 subcarriers**, không phải placeholder hay ví dụ. Base lookup:

$$
addr_{base}=12u+n,\quad base\_phase=(8192\phi_u(n))\bmod65536.
$$

`u` 5 bits nhưng chỉ 0..29; `n` 4 bits nhưng chỉ 0..11; addr cần 9 bits, legal 0..359. ROM không có implicit alias cho illegal address.

| phi | Phase radians | Fraction of full turn | phase16 |
|---:|---|---|---|
| -3 | -3π/4 | 5/8 modulo 1 | A000 |
| -1 | -π/4 | 7/8 modulo 1 | E000 |
| +1 | +π/4 | 1/8 | 2000 |
| +3 | +3π/4 | 3/8 | 6000 |

Checkpoint row u=0:

```text
phi:  -3  1 -3 -3 -3  3 -3 -1  1  1  1 -3
phase: A000 2000 A000 A000 A000 6000 A000 E000 2000 2000 2000 A000
```

Có thể lưu compact phi2 thay ROM16 (720 bits) rồi decode bốn phase constants, nhưng baseline artifact canonical vẫn phase16. Mapping compact đề xuất: 00→-3,01→-1,10→+1,11→+3. Nếu dùng compact, kiểm tra mọi address trả đúng MEM16.

## 3. Cyclic-shift LUT

$$
t=(ns_l)\bmod12,\quad CS[t]=\left\lfloor\frac{65536t}{12}\right\rfloor.
$$

| t | phase16 | t | phase16 |
|---:|---|---:|---|
| 0 | 0000 | 6 | 8000 |
| 1 | 1555 | 7 | 9555 |
| 2 | 2AAA | 8 | AAAA |
| 3 | 4000 | 9 | C000 |
| 4 | 5555 | 10 | D555 |
| 5 | 6AAA | 11 | EAAA |

CS LUT lấy residue hiện tại, không lấy m0 trực tiếp làm góc. `s_l=(m0+n_cs)%12`; modulus của n_cs là 12, không lấy riêng bốn bit thấp. Remainder update cộng hai số 0..11, temporary5 đủ 0..22; nếu >=12 trừ12 một lần.

## 4. OCC w_i(m)

$$
w_i(m)=e^{j2\pi\rho[N][i][m]/N},\quad OCC=\lfloor65536\rho/N\rfloor.
$$

Bảng rho đầy đủ:

| N_SF | i | rho theo m=0..N-1 |
|---:|---:|---|
| 1 | 0 | 0 |
| 2 | 0 | 0,0 |
| 2 | 1 | 0,1 |
| 3 | 0 | 0,0,0 |
| 3 | 1 | 0,1,2 |
| 3 | 2 | 0,2,1 |
| 4 | 0 | 0,0,0,0 |
| 4 | 1 | 0,2,0,2 |
| 4 | 2 | 0,0,2,2 |
| 4 | 3 | 0,2,2,0 |
| 5 | 0 | 0,0,0,0,0 |
| 5 | 1 | 0,1,2,3,4 |
| 5 | 2 | 0,2,4,1,3 |
| 5 | 3 | 0,3,1,4,2 |
| 5 | 4 | 0,4,3,2,1 |
| 6 | 0 | 0,0,0,0,0,0 |
| 6 | 1 | 0,1,2,3,4,5 |
| 6 | 2 | 0,2,4,0,2,4 |
| 6 | 3 | 0,3,0,3,0,3 |
| 6 | 4 | 0,4,2,0,4,2 |
| 6 | 5 | 0,5,4,3,2,1 |
| 7 | 0 | 0,0,0,0,0,0,0 |
| 7 | 1 | 0,1,2,3,4,5,6 |
| 7 | 2 | 0,2,4,6,1,3,5 |
| 7 | 3 | 0,3,6,2,5,1,4 |
| 7 | 4 | 0,4,1,5,2,6,3 |
| 7 | 5 | 0,5,3,1,6,4,2 |
| 7 | 6 | 0,6,5,4,3,2,1 |

N=4 phải dùng bảng riêng trên. Đã đối chiếu [TS 38.211 Table 6.3.2.4.1-2](https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/15.10.00_60/ts_138211v151000p.pdf): các hàng này khác DFT-4 trong tài liệu Combined.

Compact address:

$$
offset[N]=\sum_{a=1}^{N-1}a^2,\quad addr=offset[N]+iN+m.
$$

| N | offset | Last addr | floor phase values cho rho=0..N-1 |
|---:|---:|---:|---|
| 1 | 0 | 0 | 0000 |
| 2 | 1 | 4 | 0000,8000 |
| 3 | 5 | 13 | 0000,5555,AAAA |
| 4 | 14 | 29 | 0000,4000,8000,C000; bảng thực chỉ dùng rho=0,2 |
| 5 | 30 | 54 | 0000,3333,6666,9999,CCCC |
| 6 | 55 | 90 | 0000,2AAA,5555,8000,AAAA,D555 |
| 7 | 91 | 139 | 0000,2492,4924,6DB6,9249,B6DB,DB6D |

Address8 đủ; invalid N/i/m phải báo lỗi, không zero-pad như valid OCC. Receiver cộng **forward** OCC phase với r_phase rồi negate toàn bộ tổng; không negate OCC table thêm lần thứ hai.

Sign/swap chỉ đủ với phase0,π/2,π,3π/2; OCC N=3,5,7 cần quay góc khác. Baseline đã gộp OCC vào CORDIC nên không có hạn chế sign/swap.

## 5. N_SF table

| L | No hopping N_SF0 | Hopping N_SF0 | Hopping N_SF1 | N_RE |
|---:|---:|---:|---:|---:|
| 4 | 2 | 1 | 1 | 24 |
| 5 | 2 | 1 | 1 | 24 |
| 6 | 3 | 1 | 2 | 36 |
| 7 | 3 | 1 | 2 | 36 |
| 8 | 4 | 2 | 2 | 48 |
| 9 | 4 | 2 | 2 | 48 |
| 10 | 5 | 2 | 3 | 60 |
| 11 | 5 | 2 | 3 | 60 |
| 12 | 6 | 3 | 3 | 72 |
| 13 | 6 | 3 | 3 | 72 |
| 14 | 7 | 3 | 4 | 84 |

No hopping `n_sf1=0`. Compact lookup addr=L-4, 0..10. Can implement `N_data=L//2`, `N_SF0_hop=N_data//2`, `N_SF1_hop=N_data-N_SF0_hop`, equivalent to table. Không dùng `ceil(L/2)` làm data-symbol count.

## 6. Modulation LUT

Bảng đầy đủ ở Algorithm §3 và `lut/modulation.csv`. I/Q constants ±23170 = RNE(32768/√2), F15. Sáu logical entries: BPSK2 và QPSK4. Có thể share bốn điểm vật lý vì BPSK là subset QPSK, nhưng giữ `k` ordering riêng của M_bit.

Constellation phase là multiples π/4 và biểu diễn chính xác trong phase16. Norm sau I/Q quantization là `2*(23170/32768)^2`, hơi khác1 nhưng bằng nhau với tất cả candidates; MLE correlation hợp lệ.

## 7. CORDIC tables và gain

Atan ROM24 dùng RNE, không floor của phase16 LUT. Entry j theo increasing iteration; full-turn24=16777216. Internal phase24 của external input16 là input<<8. `constants.json` chứa `gain_inverse_q30=652032874` và `cordic_gain=1.6467602578654548`.

Atan không phải bảng sin/cos hay base sequence, không cộng vào reference phase trực tiếp. ROM phải khớp 16 iterations của Algorithm. Nếu đổi iteration count phải tái tính gain inverse và numeric tests.

## 8. Regeneration và kiểm tra

Từ thư mục spec:

```powershell
python tools/build_luts.py
python tools/check_spec.py
```

Generator đọc bảng base từ appendix gốc bằng UTF-8, kiểm tra 30×12 entries và bốn giá trị phi hợp lệ; tạo OCC bằng bảng riêng N=4; dùng integer floor cho mọi phase16 rational. SHA256 manifest cho phép phát hiện MEM/CSV bị sửa lệch.

RNE hằng atan/gain dùng Python binary64 đủ để tái sinh các hằng đã khóa; artifact hiện có mới là giá trị canonical. Đổi runtime/tool làm thay hằng phải được review, không silently cập nhật golden RTL.
