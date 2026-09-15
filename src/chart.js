// Biểu đồ cột theo tuần trong tháng (SVG, đúng hạn/quá hạn xếp chồng) — dùng
// chung cho màn "Tổng quan" (Trưởng phòng, cả phòng) và "Thống kê" (cá nhân).
export function weekChartSvg(weeks) {
  const W = 320, H = 140, PAD_L = 28, PAD_B = 20, PAD_T = 10;
  const plotW = W - PAD_L - 8;
  const plotH = H - PAD_T - PAD_B;
  const byWeek = new Map(weeks.map((w) => [w.tuan, w]));
  const maxTuan = weeks.length ? Math.max(...weeks.map((w) => w.tuan)) : 5;
  const tuanList = Array.from({ length: maxTuan }, (_, i) => i + 1);
  const maxTotal = Math.max(1, ...tuanList.map((t) => (byWeek.get(t)?.dung_han || 0) + (byWeek.get(t)?.qua_han || 0)));

  const barW = Math.min(38, plotW / tuanList.length - 10);
  const gap = (plotW - barW * tuanList.length) / (tuanList.length + 1);

  const yTicks = [0, Math.round(maxTotal / 2), maxTotal];

  const GAP_SEG = 2; // khe hở giữa 2 đoạn xếp chồng, theo quy tắc "2px surface gap"
  let bars = '';
  tuanList.forEach((t, i) => {
    const w = byWeek.get(t) || { dung_han: 0, qua_han: 0 };
    const total = w.dung_han + w.qua_han;
    const x = PAD_L + gap + i * (barW + gap);
    const yBase = PAD_T + plotH;
    let hQua = total > 0 ? (w.qua_han / maxTotal) * plotH : 0;
    let hDung = total > 0 ? (w.dung_han / maxTotal) * plotH : 0;
    const bothPresent = w.qua_han > 0 && w.dung_han > 0;
    if (bothPresent) { hQua = Math.max(0, hQua - GAP_SEG / 2); hDung = Math.max(0, hDung - GAP_SEG / 2); }

    if (w.qua_han > 0) {
      bars += `<rect x="${x}" y="${yBase - hQua}" width="${barW}" height="${hQua}" rx="2.5" fill="var(--danger)" />`;
    }
    if (w.dung_han > 0) {
      const yTop = yBase - hQua - (bothPresent ? GAP_SEG : 0) - hDung;
      bars += `<rect x="${x}" y="${yTop}" width="${barW}" height="${hDung}" rx="2.5" fill="var(--accent)" />`;
    }
    bars += `<text x="${x + barW / 2}" y="${H - 4}" text-anchor="middle" font-size="10" fill="var(--ink-faint)">T${t}</text>`;
    if (total > 0) {
      const yLabel = yBase - hQua - (bothPresent ? GAP_SEG : 0) - hDung - 4;
      bars += `<text x="${x + barW / 2}" y="${yLabel}" text-anchor="middle" font-size="10" fill="var(--ink-dim)">${total}</text>`;
    }
  });

  const gridLines = yTicks.map((v) => {
    const y = PAD_T + plotH - (v / maxTotal) * plotH;
    return `<line x1="${PAD_L}" y1="${y}" x2="${W - 6}" y2="${y}" stroke="var(--border)" stroke-width="1" />
            <text x="${PAD_L - 6}" y="${y + 3}" text-anchor="end" font-size="9" fill="var(--ink-faint)">${v}</text>`;
  }).join('');

  return `<svg viewBox="0 0 ${W} ${H}" style="width:100%; height:auto;">${gridLines}${bars}</svg>`;
}
