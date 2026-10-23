#!/usr/bin/env python3
"""Build and complete the pucch_f1_rx_core test data (input / output files).

File format: doc/report/pucch_f1_rx_core_tb_data_format.md
  doc/database/input/pucch_f1_rx_core_input.txt   : everything driven into the DUT (CFG + RE lines)
  doc/database/output/pucch_f1_rx_core_output.txt : everything used to judge the DUT (SRC/TX/MATLAB/EXP lines)

Modes (run from the project root):
  python3 sim/script/pucch_f1_rx_core_gen_vectors.py
      Build both files from the MATLAB database in doc/database/:
      1. read rx_grid_SNR_20dB.csv and decoded_bits_SNR_20dB.csv;
      2. locate the PUCCH PRB and recover the PUCCH config blindly, cross-checked
         against doc/database/system_config.md;
      3. emulate the upstream block the core assumes (spec 01 section 3): LS
         channel estimate on the DM-RS symbols, time interpolation, ZF
         equalization, quantization to signed Q1.15 (Y_hat);
      4. run the bit-exact reference model of source 03 to fill the EXP lines.
  python3 sim/script/pucch_f1_rx_core_gen_vectors.py --fill-exp IN OUT
      Check the syntax of an externally generated pair (e.g. MATLAB export) and
      write the bit-exact EXP line of every case into OUT (in place). Cases with
      a sample order/marker error are left without EXP (write it by hand).
"""
import cmath
import csv
import math
import os
import re
import sys
import argparse

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DB = os.path.join(ROOT, 'doc', 'database')
LUT_MD = os.path.join(ROOT, 'doc', 'spec', 'source', '07_LUT_Consolidated.md')
IN_FILE = os.path.join(DB, 'input', 'pucch_f1_rx_core_input.txt')
OUT_FILE = os.path.join(DB, 'output', 'pucch_f1_rx_core_output.txt')

# ----------------------------------------------------------------------------
# LUTs (parsed from source 07, read-only)
# ----------------------------------------------------------------------------
txt = open(LUT_MD, encoding='utf-8').read()
PHI = []
for line in txt.split('### Bảng phi_u(n)')[1].split('### Bảng ROM base')[0].splitlines():
    m = re.match(r'\| (\d+) \| \d+\.\.\d+ \|(.*)\|$', line)
    if m:
        PHI.append([int(x) for x in m.group(2).split('|')])
RHO = {}
for line in txt.split('### Bảng rho[N][i][m]')[1].split('### Bảng ROM OCC')[0].splitlines():
    m = re.match(r'\| (\d) \| (\d) \| \d+\.\.\d+ \|(.*)\|$', line)
    if m:
        n_sf = int(m.group(1))
        RHO[(n_sf, int(m.group(2)))] = [int(x.strip()) for x in m.group(3).split('|')[:n_sf]]
assert len(PHI) == 30 and len(RHO) == 28

BASE = [[(8192 * p) & 0xFFFF for p in row] for row in PHI]
CS = [(65536 * t) // 12 for t in range(12)]
OCC_OFF = {1: 0, 2: 1, 3: 5, 4: 14, 5: 30, 6: 55, 7: 91}
OCC = {}
for (n_sf, i), r in RHO.items():
    for m, rv in enumerate(r):
        OCC[OCC_OFF[n_sf] + i * n_sf + m] = (65536 * rv) // n_sf
ATAN = [2097152, 1238021, 654136, 332050, 166669, 83416, 41718, 20860,
        10430, 5215, 2608, 1304, 652, 326, 163, 81]
KINV = 652032874
CAND = {1: [(23170, 23170, 0b00), (-23170, -23170, 0b01)],
        2: [(23170, 23170, 0b00), (23170, -23170, 0b10),
            (-23170, 23170, 0b01), (-23170, -23170, 0b11)]}


# ----------------------------------------------------------------------------
# Reference model (source 03)
# ----------------------------------------------------------------------------
def gold(c_init, n):
    x1 = [0] * (1600 + n + 31)
    x2 = [0] * (1600 + n + 31)
    x1[0] = 1
    for i in range(31):
        x2[i] = (c_init >> i) & 1
    for t in range(1600 + n):
        x1[t + 31] = x1[t + 3] ^ x1[t]
        x2[t + 31] = x2[t + 3] ^ x2[t + 2] ^ x2[t + 1] ^ x2[t]
    return [x1[t + 1600] ^ x2[t + 1600] for t in range(n)]


def counts(nsymb, hop):
    nd = nsymb // 2
    return (nd // 2, nd - nd // 2, 12 * nd) if hop else (nd, 0, 12 * nd)


def u_and_s(n_id, slot, mode, m0):
    f_ss = n_id % 30
    if mode == 1:
        c = gold(n_id // 30, 16 * slot + 16)
        u = [(f_ss + sum((1 << b) * c[8 * (2 * slot + h) + b] for b in range(8)) % 30) % 30 for h in range(2)]
    else:
        u = [f_ss, f_ss]
    c = gold(n_id, 112 * slot + 112)
    s = [(m0 + sum((1 << b) * c[8 * (14 * slot + l) + b] for b in range(8))) % 12 for l in range(14)]
    return u, s


def remove_phases(cfg):
    n_sf0, n_sf1, n_re = counts(cfg['nsymb'], cfg['hop'])
    u, s = u_and_s(cfg['n_id'], cfg['slot'], cfg['gh_mode'], cfg['m0'])
    out = []
    for q in range(n_re):
        g, n = q // 12, q % 12
        h = 1 if (cfg['hop'] and g >= n_sf0) else 0
        m = g - n_sf0 if h else g
        l_abs = cfg['start'] + 2 * g + 1
        n_sf = n_sf1 if h else n_sf0
        r = (BASE[u[h]][n] + CS[(n * s[l_abs]) % 12]) & 0xFFFF
        occ = OCC[OCC_OFF[n_sf] + cfg['occ'] * n_sf + m]
        out.append((-((r + occ) & 0xFFFF)) & 0xFFFF)
    return out


def rne_div(p, d):
    a = abs(p)
    v, r = divmod(a, d)
    if 2 * r > d or (2 * r == d and (v & 1)):
        v += 1
    return -v if p < 0 else v


def fits(v, bits):
    return -(1 << (bits - 1)) <= v < (1 << (bits - 1))


def wrap(v, bits):
    return ((v + (1 << (bits - 1))) % (1 << bits)) - (1 << (bits - 1))


def cordic(i16, q16, ph16):
    ovf = False
    x, y = i16 << 6, q16 << 6
    z = wrap(ph16 << 8, 24)
    if z > (1 << 22):
        x, y, z = -x, -y, z - (1 << 23)
    elif z < -(1 << 22):
        x, y, z = -x, -y, z + (1 << 23)
    for j in range(16):
        d = 1 if z >= 0 else -1
        xn, yn, zn = x - d * (y >> j), y + d * (x >> j), z - d * ATAN[j]
        ovf |= not (fits(xn, 24) and fits(yn, 24))
        x, y, z = wrap(xn, 24), wrap(yn, 24), wrap(zn, 24)
    oi, oq = rne_div(x, 64), rne_div(y, 64)
    sat = oi > 131071 or oq > 131071
    return min(oi, 131071), min(oq, 131071), ovf or sat


def run_model(cfg, samples):
    n_re = counts(cfg['nsymb'], cfg['hop'])[2]
    si = sq = 0
    err = False
    for ph, (yi, yq) in zip(remove_phases(cfg), samples):
        oi, oq, e = cordic(yi, yq, ph)
        err |= e
        si, sq = si + oi, sq + oq
        err |= not (fits(si, 26) and fits(sq, 26))
    if err:
        return dict(error=1, code=5, k=0, bits=0, di=0, dq=0, best=0, second=0, gap=0)
    zi, zq = rne_div(si * KINV, 1 << 30), rne_div(sq * KINV, 1 << 30)
    di, dq = rne_div(zi, n_re), rne_div(zq, n_re)
    cands = CAND[cfg['m_bit']]
    met = [di * ci + dq * cq for ci, cq, _ in cands]
    order = sorted(range(len(cands)), key=lambda k: (-met[k], k))
    kb, ks = order[0], order[1]
    return dict(error=0, code=0, k=kb, bits=cands[kb][2], di=di, dq=dq,
                best=met[kb], second=met[ks], gap=met[kb] - met[ks])




def cfg_error(cfg):
    """Error code of the VALIDATE state (ctrl spec): 0 legal, 1 CFG_RANGE, 2 CFG_OCC."""
    if cfg['m_bit'] not in (1, 2) or not 4 <= cfg['nsymb'] <= 14 or cfg['start'] > 10 or \
            cfg['start'] + cfg['nsymb'] > 14 or cfg['gh_mode'] == 3 or cfg['m0'] > 11 or cfg['slot'] > 19:
        return 1
    n_sf0, n_sf1, _ = counts(cfg['nsymb'], cfg['hop'])
    if cfg['occ'] >= n_sf0 or (cfg['hop'] and cfg['occ'] >= n_sf1):
        return 2
    return 0


def expected(cfg, res):
    """EXP record for one case, or None when the RE stream has an order/marker error."""
    code = cfg_error(cfg)
    if code:
        return dict(error=1, code=code, m_bit=cfg['m_bit'], k=0, bits=0, di=0, dq=0, best=0, second=0, gap=0)
    n_re = counts(cfg['nsymb'], cfg['hop'])[2]
    good = [(q, int(q == 0), int(q == n_re - 1)) for q in range(n_re)]
    if [r[:3] for r in res] != good:
        return None
    e = run_model(cfg, [(r[3], r[4]) for r in res])
    e['m_bit'] = cfg['m_bit']
    return e


# ----------------------------------------------------------------------------
# Input / output file format (doc/report/pucch_f1_rx_core_tb_data_format.md)
# ----------------------------------------------------------------------------
CFG_KEYS = ['m_bit', 'nsymb', 'start', 'hop', 'gh_mode', 'n_id', 'm0', 'occ', 'slot']
CFG_RANGE = [(0, 3), (0, 15), (0, 15), (0, 1), (0, 3), (0, 1023), (0, 15), (0, 7), (0, 31)]
EXP_KEYS = ['error', 'code', 'm_bit', 'k', 'bits', 'di', 'dq', 'best', 'second', 'gap']
IN_HEADER = '''# PUCCH_F1_RX_CORE_INPUT v1
# Stimulus for pucch_f1_rx_core: one block CASE..END per transaction.
# CFG <m_bit> <nsymb> <start_symbol> <intra_slot_hopping> <group_hopping_mode> <n_id> <m0> <occ_i> <slot_idx>
# RE  <y_sample_q> <y_first> <y_last> <y_i> <y_q>      (y_i / y_q: signed decimal, Q1.15)
'''
OUT_HEADER = '''# PUCCH_F1_RX_CORE_OUTPUT v1
# Reference for pucch_f1_rx_core: one block CASE..END per transaction, same CASE ids as the input file.
# SRC    <frame_idx> <snr_db>
# TX     <tx_b0> <tx_b1>                               (-1 = not available)
# MATLAB <valid_decode> <dec_b0> <dec_b1>              (-1 = not available)
# EXP    <res_error> <res_error_code> <res_m_bit> <res_candidate_idx> <res_uci_bits> <res_d_rx_i> <res_d_rx_q> <res_metric_best> <res_metric_second> <res_metric_gap>
# INFO   <key>=<value> ...                             (free diagnostics, ignored by the testbench)
'''


class FormatError(Exception):
    pass


def read_blocks(path):
    """Return (header comment lines, [(case_id, [(key, [tokens], raw_line)])])."""
    header, blocks, cur = [], [], None
    for no, raw in enumerate(open(path, encoding='ascii'), 1):
        line = raw.rstrip('\n')
        s = line.strip()
        if not s or s.startswith('#'):
            if not blocks and cur is None:
                header.append(line)
            continue
        if len(line) > 200:
            raise FormatError('%s:%d line longer than 200 characters' % (path, no))
        tok = s.split()
        if tok[0] == 'CASE':
            if cur is not None or len(tok) != 2 or not tok[1].isdigit():
                raise FormatError('%s:%d bad CASE line' % (path, no))
            cur = (int(tok[1]), [])
        elif tok[0] == 'END':
            if cur is None:
                raise FormatError('%s:%d END without CASE' % (path, no))
            blocks.append(cur)
            cur = None
        else:
            if cur is None:
                raise FormatError('%s:%d %s outside CASE..END' % (path, no, tok[0]))
            cur[1].append((tok[0], tok[1:], line))
    if cur is not None:
        raise FormatError('%s: missing END for CASE %d' % (path, cur[0]))
    ids = [b[0] for b in blocks]
    if ids != sorted(set(ids)):
        raise FormatError('%s: CASE ids must be unique and ascending' % path)
    return header, blocks


def ints(path, cid, key, tok, n):
    if len(tok) != n:
        raise FormatError('%s CASE %d: %s needs %d fields, got %d' % (path, cid, key, n, len(tok)))
    try:
        return [int(t) for t in tok]
    except ValueError:
        raise FormatError('%s CASE %d: %s fields must be decimal integers' % (path, cid, key))


def parse_input(path):
    cases = []
    for cid, lines in read_blocks(path)[1]:
        cfg, res = None, []
        for key, tok, _ in lines:
            if key == 'CFG':
                if cfg is not None:
                    raise FormatError('%s CASE %d: more than one CFG' % (path, cid))
                v = ints(path, cid, key, tok, 9)
                for x, (lo, hi), name in zip(v, CFG_RANGE, CFG_KEYS):
                    if not lo <= x <= hi:
                        raise FormatError('%s CASE %d: CFG %s=%d does not fit the port' % (path, cid, name, x))
                cfg = dict(zip(CFG_KEYS, v))
            elif key == 'RE':
                v = ints(path, cid, key, tok, 5)
                if not (0 <= v[0] <= 127 and v[1] in (0, 1) and v[2] in (0, 1) and
                        all(-32768 <= x <= 32767 for x in v[3:])):
                    raise FormatError('%s CASE %d: RE %s does not fit the ports' % (path, cid, tok))
                res.append(tuple(v))
            else:
                raise FormatError('%s CASE %d: unknown input key %s' % (path, cid, key))
        if cfg is None:
            raise FormatError('%s CASE %d: missing CFG' % (path, cid))
        if len(res) > 128:
            raise FormatError('%s CASE %d: more than 128 RE lines' % (path, cid))
        cases.append((cid, cfg, res))
    return cases


def write_input(path, cases):
    with open(path, 'w') as f:
        f.write(IN_HEADER)
        for cid, cfg, res in cases:
            f.write('CASE %d\nCFG %s\n' % (cid, ' '.join(str(cfg[k]) for k in CFG_KEYS)))
            for r in res:
                f.write('RE %d %d %d %d %d\n' % r)
            f.write('END\n')


def exp_line(e):
    return 'EXP ' + ' '.join(str(e[k]) for k in EXP_KEYS)


def fill_exp(in_path, out_path):
    inp = parse_input(in_path)
    header, blocks = read_blocks(out_path)
    if [c[0] for c in inp] != [b[0] for b in blocks]:
        raise FormatError('CASE ids of %s and %s differ' % (in_path, out_path))
    text = '\n'.join(header) + '\n' if header else OUT_HEADER
    n_exp = 0
    for (cid, cfg, res), (_, lines) in zip(inp, blocks):
        keys = [k for k, _, _ in lines]
        for need in ('SRC', 'TX', 'MATLAB'):
            if keys.count(need) != 1:
                raise FormatError('%s CASE %d: needs exactly one %s line' % (out_path, cid, need))
        for key, tok, _ in lines:
            if key in ('SRC', 'TX', 'MATLAB') and len(tok) != {'SRC': 2, 'TX': 2, 'MATLAB': 3}[key]:
                raise FormatError('%s CASE %d: bad %s line' % (out_path, cid, key))
        e = expected(cfg, res)
        text += 'CASE %d\n' % cid
        text += ''.join(raw + '\n' for key, _, raw in lines if key not in ('EXP', 'INFO'))
        if e is not None:
            text += exp_line(e) + '\n'
            n_exp += 1
        else:
            print('CASE %d: RE order/marker error case, EXP left empty (write it by hand)' % cid)
        text += ''.join(raw + '\n' for key, _, raw in lines if key == 'INFO')
        text += 'END\n'
    open(out_path, 'w').write(text)
    print('%d cases checked, %d EXP lines written to %s' % (len(inp), n_exp, out_path))


# ----------------------------------------------------------------------------
# Database extraction
# ----------------------------------------------------------------------------
def read_config_md():
    """PUCCH fields of doc/database/system_config.md (table rows '| name | value |')."""
    p = os.path.join(DB, 'system_config.md')
    rows = {}
    if os.path.exists(p):
        for line in open(p, encoding='utf-8'):
            m = re.match(r'\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|', line)
            if m:
                rows[m.group(1)] = m.group(2)
    return rows


def from_database():
    grid_csv = os.path.join(DB, 'rx_grid_SNR_20dB.csv')
    bits_csv = os.path.join(DB, 'decoded_bits_SNR_20dB.csv')

    # pass 1: energy per PRB (antenna 1)
    prb_e = {}
    with open(grid_csv) as f:
        rd = csv.reader(f)
        next(rd)
        for row in rd:
            p = float(row[5]) ** 2 + float(row[6]) ** 2
            k = int(row[2]) // 12
            prb_e[k] = prb_e.get(k, 0.0) + p
    prb = max(prb_e, key=prb_e.get)
    others = sorted(v for k, v in prb_e.items() if k != prb)
    print('PUCCH PRB = %d (energy ratio vs median PRB = %.1f dB)' %
          (prb, 10 * math.log10(prb_e[prb] / others[len(others) // 2])))

    # pass 2: keep only the REs of that PRB
    grid = {}
    snr = {}
    with open(grid_csv) as f:
        rd = csv.reader(f)
        next(rd)
        for row in rd:
            sc = int(row[2])
            if prb * 12 <= sc < prb * 12 + 12 and int(row[4]) == 1:
                grid[(int(row[0]), sc - prb * 12, int(row[3]))] = complex(float(row[5]), float(row[6]))
                snr[int(row[0])] = row[1]
    frames = sorted({k[0] for k in grid})
    syms = sorted({k[2] for k in grid})
    print('frames = %d, OFDM symbols with energy = %d..%d' % (len(frames), syms[0], syms[-1]))

    # MATLAB decoded bits
    dec = {}
    with open(bits_csv) as f:
        rd = csv.DictReader(f)
        for row in rd:
            fr = int(row['FrameIndex'])
            ok = int(row['ValidDecode'])
            dec.setdefault(fr, {})[int(row['BitPositionInFrame'])] = (int(row['DecodedBit']) if ok else -1, ok)
    m_bit = max(len(v) for v in dec.values())

    # blind config recovery on frame 1: (u, s_l) per symbol
    f0 = frames[0]
    meas_u, meas_s = [], []
    for l in range(14):
        y = [grid[(f0, n, l)] for n in range(12)]
        best = None
        for u in range(30):
            for s in range(12):
                acc = sum(y[n] * cmath.exp(-1j * (math.pi / 4 * PHI[u][n] + 2 * math.pi * s * n / 12)) for n in range(12))
                if best is None or abs(acc) > best[0]:
                    best = (abs(acc), u, s)
        meas_u.append(best[1])
        meas_s.append(best[2])
    assert len(set(meas_u)) == 1, 'group hopping / hopping not supported by this extractor'
    u0 = meas_u[0]
    hits = []
    for n_id in range(u0, 1024, 30):
        c = gold(n_id, 112 * 20)
        for slot in range(20):
            ncs = [sum((1 << b) * c[8 * (14 * slot + l) + b] for b in range(8)) for l in range(14)]
            for m0 in range(12):
                if all((m0 + ncs[l]) % 12 == meas_s[l] for l in range(14)):
                    hits.append((n_id, slot, m0))
    assert len(hits) == 1, hits
    n_id, slot, m0 = hits[0]
    cfg = dict(m_bit=m_bit, nsymb=14, start=0, hop=0, gh_mode=0, n_id=n_id, m0=m0, occ=0, slot=slot)
    u, s = u_and_s(n_id, slot, 0, m0)
    print('recovered config: u=%d n_id=%d slot=%d m0=%d s_l=%s' % (u0, n_id, slot, m0, s))

    def r_seq(l, n):
        return cmath.exp(1j * (math.pi / 4 * PHI[u[0]][n] + 2 * math.pi * s[l] * n / 12))

    # OCC index check: data/DM-RS ratio per symbol must follow w_i(m) for N_SF = 7
    occ_score = []
    for i in range(7):
        acc = 0
        for fr in frames:
            for g in range(7):
                l = 2 * g + 1
                h = (sum(grid[(fr, n, l - 1)] / r_seq(l - 1, n) for n in range(12)) +
                     (sum(grid[(fr, n, l + 1)] / r_seq(l + 1, n) for n in range(12)) if l + 1 < 14 else 0))
                x = sum(grid[(fr, n, l)] / r_seq(l, n) for n in range(12)) / h
                acc += x * cmath.exp(-2j * math.pi * RHO[(7, i)][g] / 7)
        occ_score.append(abs(acc))
    cfg['occ'] = max(range(7), key=lambda i: occ_score[i])
    print('OCC index = %d' % cfg['occ'])

    # cross-check against system_config.md
    sc_md = read_config_md()
    declared = {'PRB Set': str(prb), 'NCellID': str(n_id), 'Hopping ID': str(n_id), 'NSlot': str(slot),
                'Initial Cyclic Shift': str(m0), 'OCCI': str(cfg['occ']), 'Number of UCI Bits': str(m_bit)}
    for k, v in declared.items():
        if k in sc_md:
            print('system_config %-22s = %-4s recovered = %-4s %s' % (k, sc_md[k], v, 'OK' if sc_md[k] == v else 'DIFF'))

    # upstream emulation: per-subcarrier LS on DM-RS (OCC i applies to DM-RS too, N_SF,DMRS = 7)
    wdmrs = [cmath.exp(2j * math.pi * RHO[(7, cfg['occ'])][m] / 7) for m in range(7)]
    inp, outp, agree = [], [], 0
    for ci, fr in enumerate(frames, 1):
        hd = {}
        for m in range(7):
            l = 2 * m
            for n in range(12):
                hd[(l, n)] = grid[(fr, n, l)] / (r_seq(l, n) * wdmrs[m])
        samples = []
        clipped = 0
        hmin = 1e9
        for g in range(7):
            l = 2 * g + 1
            for n in range(12):
                h = (hd[(l - 1, n)] + hd[(l + 1, n)]) / 2 if l + 1 <= 12 else hd[(12, n)]
                hmin = min(hmin, abs(h))
                yh = grid[(fr, n, l)] / h
                iq = []
                for v in (yh.real, yh.imag):
                    q = int(math.floor(abs(v) * 32768 + 0.5)) * (1 if v >= 0 else -1)
                    if q > 32767 or q < -32768:
                        clipped += 1
                    iq.append(max(-32768, min(32767, q)))
                samples.append(tuple(iq))
        n_re = len(samples)
        res = [(q, int(q == 0), int(q == n_re - 1), yi, yq) for q, (yi, yq) in enumerate(samples)]
        e = expected(cfg, res)
        valid = int(all(v[1] == 1 for v in dec[fr].values()))
        b0 = dec[fr][1][0]
        b1 = dec[fr][2][0] if m_bit == 2 else 0
        ok = int(valid and e['bits'] == (b1 << 1) | b0)
        agree += ok
        inp.append((ci, cfg, res))
        outp.append('CASE %d\nSRC %d %s\nTX -1 -1\nMATLAB %d %d %d\n%s\n'
                    'INFO min_abs_h=%.4f clipped_iq=%d model_vs_matlab=%s\nEND\n' %
                    (ci, fr, snr[fr], valid, b0, b1, exp_line(e), hmin, clipped, 'MATCH' if ok else 'MISMATCH'))
    os.makedirs(os.path.dirname(IN_FILE), exist_ok=True)
    os.makedirs(os.path.dirname(OUT_FILE), exist_ok=True)
    write_input(IN_FILE, inp)
    with open(OUT_FILE, 'w') as f:
        f.write(OUT_HEADER)
        f.write('# Source: doc/database/ (rx_grid / decoded_bits, SNR %s dB); Y_hat from LS + ZF emulation in\n'
                '# gen_vectors.py; EXP from the bit-exact model of doc/spec/source/03; TX bits not exported.\n'
                % snr[frames[0]])
        f.writelines(outp)
    print('cases = %d, bit-exact model vs MATLAB decoded bits: %d/%d match' % (len(frames), agree, len(frames)))
    print('wrote %s\n      %s' % (os.path.relpath(IN_FILE, ROOT), os.path.relpath(OUT_FILE, ROOT)))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--fill-exp', nargs=2, metavar=('IN', 'OUT'),
                    help='check an external input/output pair and write the EXP lines into OUT')
    a = ap.parse_args()
    try:
        if a.fill_exp:
            fill_exp(*a.fill_exp)
        else:
            from_database()
    except FormatError as err:
        print('FORMAT ERROR: %s' % err)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
