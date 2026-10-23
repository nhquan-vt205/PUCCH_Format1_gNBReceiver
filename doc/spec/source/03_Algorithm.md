# 03 — Algorithm và numerical contract

**Version:** 1.0-vi. Công thức thực định nghĩa thuật toán; các công thức số nguyên định nghĩa baseline fixed-point mới. Không yêu cầu bit-exact với metric Euclidean vector của v1.3.

## 1. Ký hiệu

| Ký hiệu | Ý nghĩa |
|---|---|
| `L` | `cfg_nsymb`, số OFDM symbols của PUCCH, 4..14 |
| `g` | Global data-symbol index, 0..floor(L/2)-1 |
| `l_rel`, `l_abs` | Relative symbol trong PUCCH; absolute symbol trong slot |
| `h` | Hop index 0/1; bằng 0 nếu no hopping |
| `m` | Data spreading-symbol index trong hop, reset ở đầu hop |
| `n` | Subcarrier index 0..11 |
| `q` | Global data RE index, 0..N_RE-1 |
| `u_h` | Sequence group của hop h, 0..29 |
| `n_cs(l_abs)` | Gold-derived 8-bit cyclic-shift term |
| `s_l` | Cyclic shift index `(m0+n_cs)%12` |
| `rho[N_SF][i][m]` | OCC exponent theo bảng, không phải base `phi` |
| `d_k` | Một modulation symbol candidate, magnitude 1 |
| `S`, `Z`, `d_rx` | Sum có gain CORDIC; sum đã bù gain; estimate đã chia N_RE |

## 2. Mapping và counts

PUCCH data tại `l_rel=1,3,5,...`; `g=q//12`, `n=q%12`, `l_rel=2*g+1`, `l_abs=cfg_start_symbol+l_rel`.

Nếu hopping, split physical symbols tại `H=floor(L/2)`; `h=0` khi `l_rel<H`, còn lại `h=1`. Nếu no hopping, `h=0`. `m=g` cho hop0; `m=g-N_SF0` cho hop1.

$$
q=12m+n+12\sum_{a=0}^{h-1}N_{SF,a}.
$$

Tổng active count `N_RE=12*floor(L/2)`, maximum 84. Hop counts lấy bảng 05; chúng phải bằng số data symbols ở mỗi physical hop. Không dùng công thức offset `12*N_SF[h]*h` cho hai hop khác độ dài.

## 3. Modulation chiều xuôi

Một bit:

$$
d_k=\frac{1-2b(0)}{\sqrt2}(1+j),\quad k=b(0)\in\{0,1\}.
$$

Hai bit:

$$
d_k=\frac{(1-2b(0))+j(1-2b(1))}{\sqrt2},\quad k=2b(0)+b(1).
$$

| M_bit | k | b(0),b(1) | phase16 | Candidate I/Q integers, F15 |
|---:|---:|---|---|---|
| 1 | 0 | 0, unused | 2000 | +23170,+23170 |
| 1 | 1 | 1, unused | A000 | -23170,-23170 |
| 2 | 0 | 0,0 | 2000 | +23170,+23170 |
| 2 | 1 | 0,1 | E000 | +23170,-23170 |
| 2 | 2 | 1,0 | 6000 | -23170,+23170 |
| 2 | 3 | 1,1 | A000 | -23170,-23170 |

Hex phase là unsigned. `uci_bits[0]=b(0)`, `uci_bits[1]=b(1)`. Vì vậy packed vector của candidate k=1 trong QPSK là `2'b10`, của k=2 là `2'b01`; không assign trực tiếp `uci_bits=candidate_idx`.

Modulation generator dùng bảng để xuất cả phase và I/Q. Không cần CORDIC để sinh bốn điểm đã biết. MLE nhận I/Q; phase dùng để debug và tham chiếu.

## 4. Low-PAPR generation và Gold

Low-PAPR chiều xuôi:

$$
r_u^{\alpha_l}(n)=\exp\left[j\left(\frac\pi4\phi_u(n)+\frac{2\pi}{12}s_ln\right)\right].
$$

Baseline length 12: `delta=0`, `m_cs=0`. Base sequence không phụ thuộc `v`; không cần port `v` hay sequence-hopping Gold engine để tạo r length 12. `disable` mode được nhận nhưng cho cùng base group với `neither` trong phạm vi này. Không khẳng định mọi sequence length khác đều không phụ thuộc v.

Gold recurrence cho mỗi `c_init`:

$$
x_1(t+31)=x_1(t+3)\oplus x_1(t),
$$
$$
x_2(t+31)=x_2(t+3)\oplus x_2(t+2)\oplus x_2(t+1)\oplus x_2(t),
$$
$$
c(t)=x_1(t+1600)\oplus x_2(t+1600).
$$

Init `x1[0]=1`, `x1[1..30]=0`, `x2[i]=(c_init>>i)&1`, i=0..30. Chạy đủ offset 1600 trước khi đánh số `c(0)`. Gold bit index và shift-register orientation phải khớp công thức; không reset PRBS ở đầu mỗi data symbol.

Với `slot=cfg_slot_idx`, `n_ID=cfg_n_id`:

```text
f_ss = n_ID % 30
if mode == enable:
    c_gh = Gold(c_init = n_ID // 30)
    f_gh[h] = sum(2**b * c_gh[8*(2*slot+h)+b], b=0..7) % 30
else:  # neither hoặc disable, trong length-12 core
    f_gh[h] = 0
u[h] = (f_ss + f_gh[h]) % 30

c_cs = Gold(c_init = n_ID)
n_cs[l_abs] = sum(2**b * c_cs[8*(14*slot+l_abs)+b], b=0..7)
s_l = (cfg_m0 + n_cs[l_abs]) % 12
```

Đã đối chiếu group hopping: chỉ số là `8*(2*slot+h)+b`, mode enable có `v=0`; xem [TS 38.211 §6.3.2.2.1](https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/15.10.00_60/ts_138211v151000p.pdf). Công thức `c_cs` và base table giữ từ nguồn cục bộ. Core có thể cache 14 `n_cs` cho cả slot trong PREPARE.

## 5. Phase addition và inverse

`Y_hat` trong các phương trình là data RE được RE Extraction bên ngoài trích xuất trực tiếp từ RG đã qua channel estimation/equalization. Vì channel compensation đã thực hiện trên RG trước extraction, mô hình dưới đây không nhân thêm channel response `H` và core không equalize lần nữa. Low-PAPR, cyclic shift và OCC vẫn là các hệ số waveform cần loại bỏ bằng inverse phase.

Forward model trên mỗi RE:

$$
\hat Y(h,m,n)=d_{true}\,w_i(m)\,r_{u_h}^{\alpha_l}(n)+e(h,m,n).
$$

Đặt:

$$
\theta_r=\frac\pi4\phi_{u_h}(n)+\frac{2\pi}{12}s_ln,
\qquad\theta_w=\frac{2\pi}{N_{SF,h}}\rho[N_{SF,h}][i][m].
$$

Thứ tự inverse về khái niệm là bỏ OCC, bỏ cyclic shift, bỏ base spreading. Vì các hệ số đều scalar unit phasor và phép nhân giao hoán, hợp nhất được:

$$
\theta_{remove}=-(\theta_r+\theta_w),
\qquad x_q=\hat Y_qe^{j\theta_{remove}}.
$$

Noiseless `x_q=d_true`; đây là **một rotation** để thực hiện tất cả inverse phase operations. Phép cộng RE sau đó là coherent combining, không phải phép cộng các góc của `Y_hat`.

$$
Z=\sum_{q=0}^{N_{RE}-1}x_q,\qquad d_{rx}(0)=\frac{Z}{N_{RE}}.
$$

Không quyết định bit ở mỗi RE rồi vote. Không đưa candidate modulation phase vào `theta_remove`, vì như vậy receiver output sẽ phụ thuộc candidate.

## 6. Phase-code contract

Phase full-turn F=65536. Base code `(8192*phi)&65535`, chính xác vì phi là số nguyên. OCC code `floor(65536*rho/N_SF)`.

**CS accumulator được freeze theo miền remainder:**

```text
symbol start: t = 0
for n = 0..11:
    cs_phase = CS_LUT[t]         # floor(65536*t/12)
    r_phase = (base_phase[u][n] + cs_phase) & 0xFFFF
    t_next = (t + s_l) % 12
```

`t` tăng khi RE tương ứng commit. Reset `t=0` ở mỗi data symbol, không chỉ ở mỗi transaction/hop. Remainder progression chính xác bằng `(n*s_l)%12`.

Nếu dùng 16-bit `cs_code += floor(65536*s_l/12)`, kết quả có drift đến vài LSB trên n; không phải baseline này. Ví dụ s_l=1, n=3: repeated step cho 16383 còn bảng residue cho 16384.

Hợp nhất phần cứng:

```text
total_phase = (r_phase + occ_phase) & 0xFFFF
remove_phase = (-total_phase) & 0xFFFF
```

Lượng tử pha forward trước rồi negation modulo. Với phân số không biểu diễn chính xác, `-floor(a)` không bằng `floor(-a)`; không dùng hai cách tùy tiện. Tổng base+CS+OCC mã đã lượng tử có thể khác floor của tổng góc thực tối đa 1 LSB vì CS/OCC được floor độc lập.

## 7. Full-circle CORDIC, bit-level baseline

Input I/Q signed16 F15. Đổi sang signed24 F21 bằng sign-extension rồi left shift 6. Phase16 đổi sang signed24 modulo bằng `{phase16,8'b0}`, rồi diễn giải khoảng `[-2^23,2^23-1]`.

Quadrant preprocessing:

```text
if z > +2**22:  x,y = -x,-y; z = z - 2**23
if z < -2**22:  x,y = -x,-y; z = z + 2**23
# final z thuộc [-pi/2,+pi/2]
```

Thực hiện cộng/trừ góc trong signed25 temporary rồi đưa về signed24. I/Q đã rộng nên negation của input -32768 không overflow. Các góc ±pi/2 nằm trong micro-rotation interval; không pre-rotate lần thứ hai.

Cho j=0..15, sử dụng cùng old x,y,z:

```text
direction = +1 if z >= 0 else -1
x_next = x - direction * arithmetic_shift_right(y, j)
y_next = y + direction * arithmetic_shift_right(x, j)
z_next = z - direction * ATAN24[j]
```

`ATAN24[j]=RNE(atan(2^-j)/(2*pi)*2^24)`. Table ở 05. x/y stage signed24 F21; add/sub sử dụng signed25 temporary và kiểm tra overflow trước narrowing. z stage signed24. Output sau iteration15: RNE x,y chia 64, saturate vào signed18 F15; saturation là error.

Gain không compensate trong từng sample:

$$
A_{16}=\prod_{j=0}^{15}\sqrt{1+2^{-2j}}\approx1.6467602578654548.
$$

Noiseless output mỗi RE khoảng `A16*d_true`, vẫn giữ amplitude. Gain positive chung không đổi hướng nhưng phải bù để `d_rx` có scale chuẩn.

## 8. Accumulation và normalization

Mỗi output18 sign-extend lên signed26 F15 rồi cộng. `first` clear/initialize sum bằng sample đầu. `last` phải publish `sum_next`, không publish accumulator cũ thiếu sample cuối. Maximum count 84.

Width proof bảo thủ tại port: mỗi component18 có trị tuyệt đối ≤131072; `84*131072=11010048<2^25`. Signed26 đủ ngay cả cho full-range output18; không nhân thêm A16 lần nữa trong proof vì output đã chứa gain. Arithmetic overflow vẫn được check để phát hiện lỗi/context sai.

Normalize một lần, giữ 26-bit F15 output:

```text
KINV_Q30 = 652032874                 # RNE((1/A16)*2**30)
P_I = S_I * signed_positive(KINV_Q30) # multiplier 26 x 31 -> signed57
P_Q = S_Q * signed_positive(KINV_Q30)
Z_I = RNE_div(P_I, 2**30)            # gain corrected sum, signed26 F15
Z_Q = RNE_div(P_Q, 2**30)
d_rx_I = RNE_div(Z_I, N_RE)          # signed26 F15
d_rx_Q = RNE_div(Z_Q, N_RE)
```

Thực hiện **hai** bước RNE theo thứ tự này. Không gộp thành một division nếu muốn bit-exact baseline. Products57 full precision; Z và d_rx saturation signed26 là error. Candidate giữ signed16 F15, scalar giữ signed26 F15 để noise/residual magnitude >1 không clip.

Định nghĩa `RNE_div(P,D)` cho P signed, D positive: lấy a=abs(P) trong đủ width, `v=a//D`, `r=a%D`; tăng v nếu `2r>D` hoặc `2r==D && v odd`; trả `-v` nếu P<0. Zero luôn 0. Không dùng `(P+D/2)//D` cho số âm hoặc tie-even.

## 9. Scalar MLE

Giả định statistical ở Requirements, rotation unitary giữ distribution noise. Với candidate cùng energy:

$$
E_k=\sum_q|\hat Y_q-d_ka_q|^2
=C+N_{RE}|d_k|^2-2\Re\{d_k^*Z\}.
$$

Do `|d_k|=1` và N_RE positive, argmin E bằng argmax correlation với Z hay d_rx. Đây là chứng minh floating-point cho architecture mới; không chứng minh bit-exact với per-RE candidate Q1.15 vector được quantize trong v1.3.

Canonical scalar metric fixed-point:

$$
M_{k,int}=d_{rx,I,int}\,d_{k,I,int}+d_{rx,Q,int}\,d_{k,Q,int}.
$$

Mỗi product signed42, sum signed43, fractional bits 30. Không RNE/truncate metrics. Metric_best/second có thể âm; không dùng unsigned comparator. `metric_second` là candidate runner-up theo cùng thứ tự `(metric descending, k ascending)`; `metric_gap=best-second` unsigned44, nonnegative.

Candidate constants có cùng energy integer chính xác `2*23170^2`, nên scalar squared-distance ranking cũng tương đương correlation ranking mà không cần square datapath. Nếu đổi candidate LUT thành unequal norms, phải đưa energy term vào metric và revise freeze.

MLE có thể khai thác ±23170 để tính `23170*(±d_rx_I ±d_rx_Q)` bằng constant arithmetic. Sign extension trước negation của signed26, intermediate sum ít nhất signed27; vẫn phải xuất exact signed43 product metric.

Sanity decisions:

```text
M_bit=1: b0 = 0 if (d_rx_I+d_rx_Q) >= 0 else 1
M_bit=2: b0 = 0 if d_rx_I >= 0 else 1
         b1 = 0 if d_rx_Q >= 0 else 1
```

MLE architecture vẫn nhận table từ modulation block và evaluate K candidates; sign forms dùng để kiểm chứng equivalence, không loại bỏ nhánh modulation người thiết kế yêu cầu.

## 10. Golden processing order

```text
capture config, validate, derive counts/tags
generate candidate table
generate u per hop, n_cs per absolute symbol
for q = 0..N_RE-1:
    derive h,m,n,l_abs
    base = BASE_ROM[12*u[h]+n]
    cs = CS_ROM[(n*s_l)%12]
    occ = OCC_ROM[offset[N_SF[h]]+i*N_SF[h]+m]
    remove = -(base+cs+occ) mod 65536
    x = bit_exact_CORDIC(Y_hat[q], remove)
    S += x
Z = gain_correct_RNE(S)
d_rx = divide_count_RNE(Z)
metric[k] = exact_dot(d_rx,candidate[k]) for valid k
rank by (-metric[k],k); output winning bits and top two metrics
```

Reference có ba tầng: ideal complex math; phase16 rotation bằng exp và input quantization; bit-exact CORDIC + normalize + MLE. So sánh từng tầng để tách lỗi LUT/index khỏi approximation. Noiseless `L=14,no hop`: ideal Z=84*d và d_rx=d; trước gain correction S≈84*A16*d.
