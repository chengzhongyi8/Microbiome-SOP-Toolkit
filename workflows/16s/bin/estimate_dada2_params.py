#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Estimate DADA2 trim/trunc parameters from QIIME2 demux-exported FASTQ files,
and (optionally) detect whether amplicon primers are still present at the
start of the reads.

Design goals
------------
* Pure Python 3 standard library only (no numpy/biopython), so it runs in any
  Python 3 on the server or workstation.
* Samples a bounded number of reads from a bounded number of samples so it is
  fast even on TB-scale datasets.
* Output is a shell-sourcable "KEY=value" env file, consumed by
  03_cutadapt_optional.sh / 08_auto_dada2_params.sh.

Input layout
------------
--dir should point to a QIIME2 `qiime tools export` output of
SampleData[PairedEndSequencesWithQuality] or SampleData[SequencesWithQuality]:

  paired:  <dir>/<sample>/forward.fastq.gz   <dir>/<sample>/reverse.fastq.gz
  single:  <dir>/<sample>/<sample>.fastq.gz   (any *.fastq.gz under the dir)

Flat R1/R2 files (e.g. <sample>_R1.fastq.gz) are also paired automatically.

Outputs (full mode)
-------------------
READ_LEN_P25 / READ_LEN_P50 : read-length percentiles of the sampled reads
TRUNC_LEN_F / TRUNC_LEN_R   : recommended DADA2 trunc-len (raw read positions;
                              the shell subtracts trim-left before using it)
MEAN_Q_AT_TRUNC_F/R         : mean quality at the chosen truncation position
WARNING                     : ';'-joined advisory messages (single quoted line)

Outputs (--detect-primers mode)
-------------------------------
PRIMER_DETECTED_F / PRIMER_DETECTED_R : yes|no
PRIMER_MATCH_RATE_F / PRIMER_MATCH_RATE_R : fraction of sampled reads matching
READS_ANALYZED : total reads examined
"""
import argparse
import gzip
import os
import re
import sys

IUPAC = {
    'A': 'A', 'C': 'C', 'G': 'G', 'T': 'T', 'U': 'U',
    'R': 'AG', 'Y': 'CT', 'S': 'GC', 'W': 'AT', 'K': 'GT', 'M': 'AC',
    'B': 'CGT', 'D': 'AGT', 'H': 'ACT', 'V': 'ACG', 'N': 'ACGT',
}

COMPLEMENT = {'A': 'T', 'T': 'A', 'C': 'G', 'G': 'C', 'U': 'A', 'N': 'N',
              'R': 'Y', 'Y': 'R', 'S': 'S', 'W': 'W', 'K': 'M', 'M': 'K',
              'B': 'V', 'V': 'B', 'D': 'H', 'H': 'D'}


def revcomp(seq):
    return ''.join(COMPLEMENT.get(c.upper(), 'N') for c in reversed(seq))


def iupac_match(base, code):
    base = base.upper()
    if base == 'N':
        # an N in a read is uninformative; do not count it as a mismatch
        return True
    return base in IUPAC.get(code.upper(), code.upper())


def iupac_regex(primer):
    """Compile an anchored regex that matches a primer allowing 0 mismatches."""
    pat = ''
    for c in primer:
        codes = IUPAC.get(c.upper(), c.upper())
        if len(codes) == 1:
            pat += codes
        else:
            pat += '[' + codes + ']'
    return re.compile('^' + pat)


def mismatches(seq, primer, max_count=3):
    """Return number of mismatches between seq start and primer (IUPAC-aware),
    or max_count+1 once the mismatch budget is exceeded (fast reject)."""
    n = min(len(seq), len(primer))
    mm = 0
    for i in range(n):
        if not iupac_match(seq[i], primer[i]):
            mm += 1
            if mm > max_count:
                return mm
    return mm


def shq(value):
    return "'" + str(value).replace("'", "'\\''") + "'"


def open_fastq(path):
    if path.endswith('.gz'):
        return gzip.open(path, 'rt')
    return open(path, 'rt')


def read_fastq(path, max_reads):
    """Yield (seq, qual) tuples; skips malformed records."""
    count = 0
    with open_fastq(path) as fh:
        while count < max_reads:
            header = fh.readline()
            if not header:
                break
            seq = fh.readline().rstrip('\n')
            plus = fh.readline()
            qual = fh.readline().rstrip('\n')
            if len(seq) != len(qual):
                continue
            yield seq, qual
            count += 1


def collect_files(root):
    out = []
    for dirpath, _dirs, files in os.walk(root):
        for name in sorted(files):
            if name.endswith(('.fastq.gz', '.fq.gz', '.fastq', '.fq')):
                out.append(os.path.join(dirpath, name))
    return sorted(out)


def _strip_suffix(name):
    for suf in ('.fastq.gz', '.fq.gz', '.fastq', '.fq'):
        if name.endswith(suf):
            return name[:-len(suf)]
    return name


_DIR_MARKERS = (
    ('_r1', 'F'), ('.r1', 'F'), ('_r2', 'R'), ('.r2', 'R'),
    ('_forward', 'F'), ('.forward', 'F'), ('_reverse', 'R'), ('.reverse', 'R'),
)

# Casava 1.8 style names produced by QIIME2 SingleLanePerSample*FastqDirFmt:
#   <sample>_<barcode>_L<lane>_R1_001.fastq.gz  /  ..._R2_001.fastq.gz
_CASAVA_RE = re.compile(r'^(?P<sample>.+?)_L\d+_R(?P<dir>[12])_001$', re.IGNORECASE)
# Some exports drop the lane: <sample>_R1_001.fastq.gz
_CASAVA_RE2 = re.compile(r'^(?P<sample>.+?)_R(?P<dir>[12])_001$', re.IGNORECASE)


def _classify_read_file(stem):
    """Return (direction, key_type, key_value) for a FASTQ stem.

    Handles the naming conventions produced by different QIIME2 versions:
      <sample>/forward.fastq.gz, <sample>/reverse.fastq.gz
      <sample>/R1.fastq.gz,      <sample>/R2.fastq.gz
      <sample>_R1.fastq.gz,      <sample>_R2.fastq.gz   (flat)
      <sample>_forward.fastq.gz, <sample>_reverse.fastq.gz (flat)
      <sample>/<sample>_R1.fastq.gz (per-sample dir, prefixed names)
    """
    low = stem.lower()
    if low in ('forward', 'f', 'r1'):
        return 'F', 'subdir', None
    if low in ('reverse', 'r', 'r2'):
        return 'R', 'subdir', None
    for marker, direction in _DIR_MARKERS:
        if low.endswith(marker):
            return direction, 'flat', stem[:-len(marker)]
    m = _CASAVA_RE.match(stem) or _CASAVA_RE2.match(stem)
    if m:
        return ('F' if m.group('dir') == '1' else 'R'), 'flat', m.group('sample')
    # unknown: treat as forward
    return 'F', 'flat', low


def collect_pairs(files, mode):
    """Return list of (forward_path, reverse_path_or_None)."""
    if mode == 'single':
        return [(f, None) for f in files]

    fwd = {}
    rev = {}
    for path in files:
        stem = _strip_suffix(os.path.basename(path))
        direction, ktype, kval = _classify_read_file(stem)
        key = (os.path.dirname(path),) if ktype == 'subdir' else ('flat', kval)
        (fwd if direction == 'F' else rev)[key] = path

    pairs = []
    for key in sorted(set(fwd) | set(rev)):
        f = fwd.get(key)
        r = rev.get(key)
        if f and r:
            pairs.append((f, r))
        elif f:
            pairs.append((f, None))

    # Fallback: if naming heuristics found no reverse reads, pair by directory
    # (2 files per sample dir) or by consecutive sorted order in a flat dir.
    if not any(r for _, r in pairs):
        by_dir = {}
        for path in files:
            by_dir.setdefault(os.path.dirname(path), []).append(path)
        pairs = []
        for d in sorted(by_dir):
            fs = sorted(by_dir[d])
            for i in range(0, len(fs) - 1, 2):
                pairs.append((fs[i], fs[i + 1]))
            if len(fs) % 2:
                pairs.append((fs[-1], None))
    return pairs


def aggregate(pairs, max_samples, max_reads_per_sample, mode):
    """Return (sum_q_f, n_f, sum_q_r, n_r, lengths_f, lengths_r, reads_analyzed)."""
    max_len = 0
    sum_q_f = []
    n_f = []
    sum_q_r = []
    n_r = []
    lengths_f = []
    lengths_r = []
    reads_analyzed = 0

    def extend(arrays, new_len):
        for arr in arrays:
            if len(arr) < new_len:
                arr.extend([0] * (new_len - len(arr)))

    for fwd, rev in pairs[:max_samples]:
        r1 = list(read_fastq(fwd, max_reads_per_sample))
        r2 = list(read_fastq(rev, max_reads_per_sample)) if rev else []
        for seq, qual in r1:
            if len(seq) > max_len:
                max_len = len(seq)
            extend([sum_q_f, n_f], len(seq))
            for i, ch in enumerate(qual):
                q = ord(ch) - 33
                if q < 0:
                    q = 0
                sum_q_f[i] += q
                n_f[i] += 1
            lengths_f.append(len(seq))
            reads_analyzed += 1
        for seq, qual in r2:
            if len(seq) > max_len:
                max_len = len(seq)
            extend([sum_q_r, n_r], len(seq))
            for i, ch in enumerate(qual):
                q = ord(ch) - 33
                if q < 0:
                    q = 0
                sum_q_r[i] += q
                n_r[i] += 1
            lengths_r.append(len(seq))
            reads_analyzed += 1

    return sum_q_f, n_f, sum_q_r, n_r, lengths_f, lengths_r, reads_analyzed, max_len


def mean_q(sum_q, n):
    return [sum_q[i] / n[i] if n[i] else 0.0 for i in range(len(sum_q))]


def percentile(sorted_vals, p):
    if not sorted_vals:
        return 0
    k = (len(sorted_vals) - 1) * p
    lo = int(k)
    hi = min(lo + 1, len(sorted_vals) - 1)
    frac = k - lo
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * frac


def smooth(vals, window=5):
    out = []
    n = len(vals)
    for i in range(n):
        lo = max(0, i - window // 2)
        hi = min(n, i + window // 2 + 1)
        out.append(sum(vals[lo:hi]) / (hi - lo))
    return out


def pick_trunc(mean, threshold, len_cap, min_trunc, warnings, label):
    """Longest position whose smoothed mean Q >= threshold, capped by len_cap."""
    if len(mean) == 0:
        warnings.append(label + ': no quality data')
        return 0
    sm = smooth(mean)
    best = 0
    for i in range(len(sm)):
        if sm[i] >= threshold:
            best = i + 1  # 1-based length
    best = min(best, len_cap)
    if best < min_trunc:
        warnings.append('%s: quality/length cap (%d) below MIN_TRUNC_LEN (%d); using %d'
                        % (label, best, min_trunc, min_trunc))
        best = min(min_trunc, len_cap)
    return best


def detect_primer(pairs, primer, is_reverse, max_samples, max_reads_per_sample, max_mismatch):
    """Return (detected, match_rate, reads).

    Standard Illumina R2 reads start with the reverse primer AS WRITTEN
    (e.g. 806R: GGACTACNVGGGTWTCTAAT), because R2 sequences the reverse
    strand 5'->3' from the reverse-primer end.  Some providers instead
    deliver R2 already reverse-complemented (starts with RC of the reverse
    primer).  For is_reverse=True we therefore accept either orientation.
    """
    targets = [primer]
    if is_reverse:
        targets.append(revcomp(primer))
    regexes = [iupac_regex(t) for t in targets]
    matched = 0
    total = 0
    for fwd, rev in pairs[:max_samples]:
        path = rev if (is_reverse and rev) else fwd
        if not path:
            continue
        for seq, _qual in read_fastq(path, max_reads_per_sample):
            total += 1
            for t, rx in zip(targets, regexes):
                if rx.match(seq) or mismatches(seq, t, max_mismatch) <= max_mismatch:
                    matched += 1
                    break
    rate = (matched / total) if total else 0.0
    return rate >= 0.05, rate, total


def ensure_overlap(trunc_f, trunc_r, cap_f, cap_r, expected, warnings):
    """Extend truncation lengths so R1+R2 can cover the expected insert."""
    if expected is None:
        return trunc_f, trunc_r
    if trunc_f + trunc_r >= expected:
        return trunc_f, trunc_r
    nf, nr = trunc_f, trunc_r
    extended_lowq = False
    while nf + nr < expected:
        if nf < cap_f:
            nf += 1
        elif nr < cap_r:
            nr += 1
        else:
            break
    if nf + nr < expected:
        warnings.append(
            'paired overlap: R1+R2 (%d+%d=%d) still cannot cover expected insert %d; '
            'reads may fail to merge (check read length / amplicon length)'
            % (nf, nr, nf + nr, expected))
    elif (nf, nr) != (trunc_f, trunc_r):
        warnings.append(
            'paired overlap: extended truncation to %d+%d to cover expected insert %d '
            '(may include bases below Q%d)'
            % (nf, nr, expected, args.quality_threshold))
    return nf, nr


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--dir', required=True, help='demux export directory')
    ap.add_argument('--mode', choices=['paired', 'single'], default='paired')
    ap.add_argument('--forward-primer', default='')
    ap.add_argument('--reverse-primer', default='')
    ap.add_argument('--detect-primers', action='store_true',
                    help='only detect primers at read starts and exit')
    ap.add_argument('--quality-threshold', type=float, default=20.0)
    ap.add_argument('--min-trunc-len', type=int, default=50)
    ap.add_argument('--length-quantile', type=float, default=0.10,
                    help='cap truncation at this read-length quantile (default 0.10)')
    ap.add_argument('--expected-amplicon-length', type=int, default=None)
    ap.add_argument('--max-samples', type=int, default=5)
    ap.add_argument('--max-reads-per-sample', type=int, default=20000)
    ap.add_argument('--max-primer-mismatch', type=int, default=2)
    ap.add_argument('--output', default='')
    global args
    args = ap.parse_args()

    warnings = []

    if not os.path.isdir(args.dir):
        print("ERROR: --dir not found: %s" % args.dir, file=sys.stderr)
        sys.exit(1)

    files = collect_files(args.dir)
    if not files:
        print("ERROR: no FASTQ files under %s" % args.dir, file=sys.stderr)
        sys.exit(1)

    pairs = collect_pairs(files, args.mode)
    if not pairs:
        print("ERROR: could not pair any reads under %s" % args.dir, file=sys.stderr)
        sys.exit(1)

    if args.mode == 'paired' and args.forward_primer:
        df, rf, nf = detect_primer(pairs, args.forward_primer, False,
                                   args.max_samples, args.max_reads_per_sample,
                                   args.max_primer_mismatch)
        dr, rr, nr = detect_primer(pairs, args.reverse_primer, True,
                                   args.max_samples, args.max_reads_per_sample,
                                   args.max_primer_mismatch)
        if args.detect_primers:
            lines = [
                'PRIMER_DETECTED_F=%s' % shq('yes' if df else 'no'),
                'PRIMER_DETECTED_R=%s' % shq('yes' if dr else 'no'),
                'PRIMER_MATCH_RATE_F=%s' % shq('%.4f' % rf),
                'PRIMER_MATCH_RATE_R=%s' % shq('%.4f' % rr),
                'READS_ANALYZED_F=%s' % shq(str(nf)),
                'READS_ANALYZED_R=%s' % shq(str(nr)),
            ]
            if df != dr:
                lines.append('WARNING=%s' % shq(
                    'forward and reverse primer detection disagree; check primer orientation'))
            emit(lines, args.output)
            return
    elif args.detect_primers:
        # single-end: check forward primer only
        d, rate, n = detect_primer(pairs, args.forward_primer, False,
                                   args.max_samples, args.max_reads_per_sample,
                                   args.max_primer_mismatch)
        lines = [
            'PRIMER_DETECTED_F=%s' % shq('yes' if d else 'no'),
            'PRIMER_DETECTED_R=%s' % shq('no'),
            'PRIMER_MATCH_RATE_F=%s' % shq('%.4f' % rate),
            'PRIMER_MATCH_RATE_R=%s' % shq('0.0000'),
            'READS_ANALYZED_F=%s' % shq(str(n)),
            'READS_ANALYZED_R=%s' % shq('0'),
        ]
        emit(lines, args.output)
        return

    # ---- full estimation mode ----
    sum_q_f, n_f, sum_q_r, n_r, len_f, len_r, reads_analyzed, max_len = aggregate(
        pairs, args.max_samples, args.max_reads_per_sample, args.mode)

    if reads_analyzed == 0:
        print('ERROR: no reads could be parsed', file=sys.stderr)
        sys.exit(1)

    len_f_sorted = sorted(len_f)
    len_r_sorted = sorted(len_r)
    p25_f = int(percentile(len_f_sorted, args.length_quantile))
    p50_f = int(percentile(len_f_sorted, 0.5))
    if len_r:
        p25_r = int(percentile(len_r_sorted, args.length_quantile))
        p50_r = int(percentile(len_r_sorted, 0.5))
    else:
        p25_r = p50_r = 0

    # 安全截断上限：绝不能 >= 实测读长（否则 DADA2 会把几乎全部 reads 滤掉）。
    # 在分位数基础上再留 2 bp 余量，并硬性保证 <= 最小实测读长 - 1。
    def safe_cap(vals):
        if not vals:
            return 0
        q = int(percentile(vals, args.length_quantile))
        mn = vals[0]
        return max(1, min(q - 2, mn - 1))
    cap_f = safe_cap(len_f_sorted)
    cap_r = safe_cap(len_r_sorted) if len_r_sorted else 0
    if cap_f < args.min_trunc_len or (args.mode == 'paired' and cap_r and cap_r < args.min_trunc_len):
        warnings.append('reads very short; truncation caps R1=%d R2=%d' % (cap_f, cap_r))

    mean_f = mean_q(sum_q_f, n_f)
    mean_r = mean_q(sum_q_r, n_r)

    trunc_f = pick_trunc(mean_f, args.quality_threshold, cap_f, args.min_trunc_len, warnings, 'R1')
    if args.mode == 'paired' and mean_r and cap_r:
        trunc_r = pick_trunc(mean_r, args.quality_threshold, cap_r, args.min_trunc_len, warnings, 'R2')
    else:
        trunc_r = 0

    if args.mode == 'paired':
        trunc_f, trunc_r = ensure_overlap(trunc_f, trunc_r, cap_f, cap_r,
                                          args.expected_amplicon_length, warnings)

    mq_f = mean_f[trunc_f - 1] if 0 < trunc_f <= len(mean_f) else 0.0
    mq_r = mean_r[trunc_r - 1] if 0 < trunc_r <= len(mean_r) else 0.0

    lines = [
        'TRUNC_LEN_F=%s' % shq(str(trunc_f)),
        'TRUNC_LEN_R=%s' % shq(str(trunc_r)),
        'MEAN_Q_AT_TRUNC_F=%s' % shq('%.1f' % mq_f),
        'MEAN_Q_AT_TRUNC_R=%s' % shq('%.1f' % mq_r),
        'READ_LEN_P25_F=%s' % shq(str(p25_f)),
        'READ_LEN_P50_F=%s' % shq(str(p50_f)),
        'READ_LEN_P25_R=%s' % shq(str(p25_r)),
        'READ_LEN_P50_R=%s' % shq(str(p50_r)),
        'READS_ANALYZED=%s' % shq(str(reads_analyzed)),
        'QUALITY_THRESHOLD=%s' % shq(str(int(args.quality_threshold))),
        'WARNING=%s' % shq('; '.join(warnings) if warnings else 'none'),
    ]
    emit(lines, args.output)


def emit(lines, output):
    text = '\n'.join(lines) + '\n'
    if output:
        with open(output, 'w') as fh:
            fh.write(text)
    else:
        sys.stdout.write(text)


if __name__ == '__main__':
    main()
