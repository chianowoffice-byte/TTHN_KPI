import { getSession, callAuthedRpc } from './auth.js';
import { esc, fmtDiem } from './utils.js';
import { topbarHtml, wireTopbar } from './nav.js';
import { weekChartSvg } from './chart.js';

let state = { nam: null, thang: null };

export async function renderMyStats(app, onLogout, onGoto) {
  const session = getSession();
  const now = new Date();
  if (!state.nam) { state.nam = now.getFullYear(); state.thang = now.getMonth() + 1; }

  app.innerHTML = `
    <div class="screen">
      ${topbarHtml(session, 'mystats')}
      <div class="body" id="mystats-body">
        <div class="empty-msg">Đang tải thống kê…</div>
      </div>
    </div>
  `;

  wireTopbar(app, onLogout, onGoto);
  await loadAndRender(app, onLogout, onGoto);
}

async function loadAndRender(app, onLogout, onGoto) {
  const body = app.querySelector('#mystats-body');
  let data;
  try {
    data = await callAuthedRpc('get_my_month_overview', { p_nam: state.nam, p_thang: state.thang });
  } catch (err) {
    body.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
    if (err.message === 'Chưa đăng nhập.') onLogout();
    return;
  }
  render(app, data, onLogout, onGoto);
}

function render(app, data, onLogout, onGoto) {
  const body = app.querySelector('#mystats-body');
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
    `}
  `;

  body.querySelector('#btn-prev-month').addEventListener('click', () => changeMonth(app, onLogout, onGoto, -1));
  body.querySelector('#btn-next-month').addEventListener('click', () => changeMonth(app, onLogout, onGoto, 1));
}

function changeMonth(app, onLogout, onGoto, delta) {
  state.thang += delta;
  if (state.thang < 1) { state.thang = 12; state.nam -= 1; }
  if (state.thang > 12) { state.thang = 1; state.nam += 1; }
  app.querySelector('#mystats-body').innerHTML = `<div class="empty-msg">Đang tải thống kê…</div>`;
  loadAndRender(app, onLogout, onGoto);
}
