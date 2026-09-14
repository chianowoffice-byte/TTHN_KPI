import { getSession, callAuthedRpc } from './auth.js';
import { esc, fmtDiem } from './utils.js';
import { topbarHtml, wireTopbar } from './nav.js';

let state = { nam: null, thang: null };

export async function renderOverview(app, onLogout, onGoto) {
  const session = getSession();
  const now = new Date();
  if (!state.nam) { state.nam = now.getFullYear(); state.thang = now.getMonth() + 1; }

  app.innerHTML = `
    <div class="screen">
      ${topbarHtml(session, 'overview')}
      <div class="body" id="overview-body">
        <div class="empty-msg">Đang tải tổng quan…</div>
      </div>
    </div>
  `;

  wireTopbar(app, onLogout, onGoto);
  await loadAndRender(app, onLogout, onGoto);
}

async function loadAndRender(app, onLogout, onGoto) {
  const body = app.querySelector('#overview-body');
  let data;
  try {
    data = await callAuthedRpc('get_month_overview', { p_nam: state.nam, p_thang: state.thang });
  } catch (err) {
    body.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
    if (err.message === 'Chưa đăng nhập.') onLogout();
    return;
  }
  render(app, data, onLogout, onGoto);
}

function render(app, data, onLogout, onGoto) {
  const body = app.querySelector('#overview-body');
  const pctDungHan = data.tong_viec > 0 ? Math.round((data.dung_han / data.tong_viec) * 100) : null;

  body.innerHTML = `
    <div class="month-switch">
      <button type="button" class="btn-small" id="btn-prev-month">‹</button>
      <div class="month-label">Tháng ${data.thang}/${data.nam}</div>
      <button type="button" class="btn-small" id="btn-next-month">›</button>
    </div>

    <div class="ov-tiles">
      <div class="ov-tile">
        <div class="ov-tile-v">${data.tong_viec}</div>
        <div class="ov-tile-l">Việc đã kết thúc</div>
      </div>
      <div class="ov-tile">
        <div class="ov-tile-v">${pctDungHan === null ? '—' : pctDungHan + '%'}</div>
        <div class="ov-tile-l">Tỷ lệ đúng hạn</div>
      </div>
      <div class="ov-tile">
        <div class="ov-tile-v" style="color:var(--accent)">${data.dung_han}</div>
        <div class="ov-tile-l">Đúng hạn</div>
      </div>
      <div class="ov-tile">
        <div class="ov-tile-v" style="color:var(--danger)">${data.qua_han}</div>
        <div class="ov-tile-l">Quá hạn</div>
      </div>
    </div>
    <div class="ov-tile ov-tile-wide">
      <div class="ov-tile-v">${fmtDiem(data.tong_gia_tri)}đ</div>
      <div class="ov-tile-l">Tổng giá trị công việc hoàn thành trong tháng</div>
    </div>

    ${data.tong_viec === 0 ? `<div class="empty-msg">Chưa có việc nào kết thúc trong tháng này.</div>` : `
      <div class="card">
        <div class="ov-section-title">Theo tuần trong tháng</div>
        ${weekChartSvg(data.theo_tuan)}
        <div class="ov-legend">
          <span class="ov-legend-item"><span class="ov-swatch" style="background:var(--accent)"></span>Đúng hạn</span>
          <span class="ov-legend-item"><span class="ov-swatch" style="background:var(--danger)"></span>Quá hạn</span>
        </div>
      </div>

      <div class="card">
        <div class="ov-section-title">Theo cán bộ</div>
        <div class="ov-can-bo-list">
          ${data.theo_can_bo.map(canBoRow).join('')}
        </div>
      </div>
    `}
  `;

  body.querySelector('#btn-prev-month').addEventListener('click', () => changeMonth(app, onLogout, onGoto, -1));
  body.querySelector('#btn-next-month').addEventListener('click', () => changeMonth(app, onLogout, onGoto, 1));
}

function changeMonth(app, onLogout, onGoto, delta) {
  state.thang += delta;
  if (state.thang < 1) { state.thang = 12; state.nam -= 1; }
  if (state.thang > 12) { state.thang = 1; state.nam += 1; }
  app.querySelector('#overview-body').innerHTML = `<div class="empty-msg">Đang tải tổng quan…</div>`;
  loadAndRender(app, onLogout, onGoto);
}

// ---------- Biểu đồ cột theo tuần (SVG, đúng hạn/quá hạn xếp chồng) ----------
function weekChartSvg(weeks) {
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

function canBoRow(cb) {
  const total = cb.dung_han + cb.qua_han;
  const pctDung = total > 0 ? (cb.dung_han / total) * 100 : 0;
  const pctQua = total > 0 ? (cb.qua_han / total) * 100 : 0;
  return `
    <div class="ov-cb-row">
      <div class="ov-cb-name">${esc(cb.ho_ten)} <span class="ov-cb-code">${esc(cb.ma_cbnv)}</span></div>
      <div class="ov-cb-bar">
        ${total === 0 ? `<div class="ov-cb-empty"></div>` : `
          <div class="ov-cb-seg" style="width:${pctDung}%; background:var(--accent)"></div>
          <div class="ov-cb-seg" style="width:${pctQua}%; background:var(--danger)"></div>
        `}
      </div>
      <div class="ov-cb-nums">${cb.so_viec} việc · <span style="color:var(--accent)">${cb.dung_han} đúng hạn</span> · <span style="color:var(--danger)">${cb.qua_han} quá hạn</span> · ${fmtDiem(cb.gia_tri)}đ</div>
    </div>
  `;
}
