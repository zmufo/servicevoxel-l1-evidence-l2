#!/usr/bin/env bash
# L2 external review package / verify.sh (macOS / Linux)
# Scope: byte-level hash recheck ONLY. Does NOT produce L2 conclusions.
# Requires: MANIFEST.sha256 in this folder. No install needed (openssl fallback included).
set -u
cd "$(dirname "$0")" || exit 2

OUT="verify_result.txt"
TMP=".manifest.verify.tmp"
trap 'rm -f "$TMP"' EXIT

if [ ! -f MANIFEST.sha256 ]; then
  echo "ERROR: MANIFEST.sha256 NOT FOUND" >&2
  exit 2
fi

# 1) strip UTF-8 BOM if present  2) strip CR  3) Windows '\' -> '/' for POSIX paths
if [ "$(head -c 3 MANIFEST.sha256 | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then
  tail -c +4 MANIFEST.sha256 > "$TMP"
else
  cat MANIFEST.sha256 > "$TMP"
fi
tr -d '\r' < "$TMP" | sed 's/\\/\//g' > "${TMP}.2"
mv "${TMP}.2" "$TMP"

{
  echo '# verify_result.txt'
  echo 'scope: operation_layer_hash_recheck_only'
  echo 'this_is_not: L2 approval / independent_review PASS / baseline_record_corrected'
  echo 'independent_review: PENDING'
  echo 'approval: PENDING'
  echo 'layer_A: PENDING'
  echo 'layer_B: NOT_COVERED'
  echo 'reason_layer_B: original_stdout_missing_no_rerun'
  echo "generated_at: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo '---'
} > "$OUT"

RC=2
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c "$TMP" 2>&1 | tee -a "$OUT"
  RC=${PIPESTATUS[0]}
elif command -v openssl >/dev/null 2>&1; then
  TOTAL=0; MATCH=0; FAIL=0; MISS=0
  while IFS= read -r line; do
    case "$line" in
      ????????????????????????????????????????????????????????????????'  '*) ;;
      *) continue ;;
    esac
    exp=${line:0:64}
    rel=${line:66}
    TOTAL=$((TOTAL+1))
    if [ ! -f "$rel" ]; then
      echo "MISSING   $rel" | tee -a "$OUT"
      MISS=$((MISS+1)); continue
    fi
    act=$(openssl dgst -sha256 -r "$rel" 2>/dev/null | cut -d' ' -f1)
    if [ "$(printf '%s' "$act" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$exp" | tr 'A-Z' 'a-z')" ]; then
      echo "MATCH     $rel" | tee -a "$OUT"
      MATCH=$((MATCH+1))
    else
      echo "MISMATCH  $rel  expected=$exp  actual=$act" | tee -a "$OUT"
      FAIL=$((FAIL+1))
    fi
  done < "$TMP"
  echo "total: $TOTAL  match: $MATCH  mismatch: $FAIL  missing: $MISS" | tee -a "$OUT"
  if [ "$TOTAL" -gt 0 ] && [ "$FAIL" -eq 0 ] && [ "$MISS" -eq 0 ]; then RC=0; else RC=1; fi
else
  echo 'checker: NO_SHA256_TOOL_FOUND (install coreutils or openssl)' | tee -a "$OUT"
fi

{
  echo '---'
  echo "checker_exit: $RC"
  if [ "$RC" -eq 0 ]; then echo 'hash_check: PASSED'; else echo 'hash_check: FAILED'; fi
  echo 'note: hash_check PASSED only means bytes survived upload. It does NOT mean layer_A PASS, layer_B covered, or L2 approved.'
  echo 'disclaimer: 本复核仅代表操作层面的代码运行一致，不代表对项目商业价值的背书；不代表与原始运行输出一致（层 B 未覆盖）。您可以匿名或使用代号。'
} | tee -a "$OUT"

# blank receipt copy; do NOT pre-fill, do NOT create placeholder content
if [ -f "03_任务书与回执/review_receipt_v1.0.yaml" ] && [ ! -f "回执_待填.yaml" ]; then
  cp "03_任务书与回执/review_receipt_v1.0.yaml" "回执_待填.yaml"
  echo 'receipt: 回执_待填.yaml (blank copy, fill by human reviewer)' | tee -a "$OUT"
else
  echo 'receipt: TEMPLATE_NOT_FOUND_OR_ALREADY_EXISTS (no placeholder created)' | tee -a "$OUT"
fi

exit "$RC"
