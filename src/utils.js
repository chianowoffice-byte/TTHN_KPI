export function esc(s) {
  if (s === null || s === undefined) return '';
  return String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/** 6.7 -> "6,7" — kiểu số Việt Nam, bỏ .0 thừa (10.0 -> "10"). */
export function fmtDiem(n) {
  if (n === null || n === undefined) return '';
  const num = Number(n);
  const rounded = Math.round(num * 10) / 10;
  return (Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1)).replace('.', ',');
}

export function todayStr() {
  // Giờ Việt Nam (UTC+7), tránh lệch ngày quanh nửa đêm như đã gặp ở dự án khác.
  return new Date(Date.now() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
}
