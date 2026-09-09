import { getSession, logout, callAuthedRpc } from './auth.js';
import { esc, fmtDiem, todayStr } from './utils.js';
import { iconCheck, iconSearch, iconLogout } from './icons.js';

export async function renderToday(app, onLogout) {
  const session = getSession();
  const ngay = todayStr();

  app.innerHTML = `
    <div class="screen">
      <div class="topbar">
        <div class="who">
          <span class="name">${esc(session.ma_cbnv)}</span>
          <h1>${esc(session.ho_ten)}</h1>
        </div>
        <button class="logout-btn" id="btn-logout" title="Đăng xuất">${iconLogout}</button>
      </div>
      <div class="body" id="today-body">
        <div class="empty-msg">Đang tải danh mục công việc…</div>
      </div>
    </div>
  `;

  app.querySelector('#btn-logout').addEventListener('click', async () => {
    await logout();
    onLogout();
  });

  let items = [];
  try {
    const data = await callAuthedRpc('get_today_screen', { p_ngay: ngay });
    items = data.items || [];
  } catch (err) {
    app.querySelector('#today-body').innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
    if (err.message === 'Chưa đăng nhập.') onLogout();
    return;
  }

  renderList(app, items, ngay, onLogout);
}

function renderList(app, items, ngay, onLogout) {
  const body = app.querySelector('#today-body');

  const doneCount = items.filter((i) => i.done).length;
  const doneValue = items.filter((i) => i.done).reduce((sum, i) => sum + Number(i.gia_tri_cv), 0);
  const totalValue = items.reduce((sum, i) => sum + Number(i.gia_tri_cv), 0);

  const hangNgay = items.filter((i) => /ngày/i.test(i.dinh_ky_tan_suat || ''));
  const khac = items.filter((i) => !/ngày/i.test(i.dinh_ky_tan_suat || ''));

  body.innerHTML = `
    <div class="ring-row">
      <div>
        <div class="ring-num">${doneCount}/${items.length} việc đã tích hôm nay</div>
        <div class="ring-label">Giá trị đã hoàn thành: <span class="mono">${fmtDiem(doneValue)}</span>/${fmtDiem(totalValue)}đ</div>
      </div>
    </div>

    <div class="search-box">
      ${iconSearch}
      <input id="task-search" type="text" placeholder="Tìm việc theo tên hoặc mã…" />
    </div>

    ${items.length === 0 ? `
      <div class="empty-msg">Chưa có việc nào trong danh mục — liên hệ Trưởng/Phó phòng để bổ sung.</div>
    ` : `
      ${hangNgay.length ? `<div class="group-label">Việc hàng ngày</div>${hangNgay.map(taskHtml).join('')}` : ''}
      ${khac.length ? `<div class="group-label">Việc khác — tìm để tích khi phát sinh</div>${khac.map(taskHtml).join('')}` : ''}
    `}
  `;

  const searchInput = body.querySelector('#task-search');
  if (searchInput) {
    searchInput.addEventListener('input', () => {
      const q = searchInput.value.trim().toLowerCase();
      body.querySelectorAll('.task').forEach((el) => {
        const hay = (el.dataset.search || '');
        el.style.display = !q || hay.includes(q) ? '' : 'none';
      });
      body.querySelectorAll('.group-label').forEach((el) => {
        el.style.display = q ? 'none' : '';
      });
    });
  }

  body.querySelectorAll('.task').forEach((el) => {
    el.addEventListener('click', () => onToggle(el, app, ngay, onLogout));
  });
}

function taskHtml(item) {
  const search = `${item.ten_cong_viec} ${item.ma_cv}`.toLowerCase();
  return `
    <div class="task ${item.done ? 'done' : ''}" data-id="${item.job_catalog_id}" data-search="${esc(search)}">
      <div class="box">${iconCheck}</div>
      <div class="t">
        <div class="title">${esc(item.ten_cong_viec)}</div>
        <div class="meta">
          <span class="code">${esc(item.ma_cv)}</span>
          <span class="val">${fmtDiem(item.gia_tri_cv)}đ</span>
          <span class="freq">${esc(item.dinh_ky_tan_suat || '')}</span>
          ${item.is_ghi_bu ? `<span class="freq" style="color:var(--warn)">Ghi bù</span>` : ''}
        </div>
      </div>
    </div>
  `;
}

async function onToggle(el, app, ngay, onLogout) {
  if (el.classList.contains('pending')) return;
  el.classList.add('pending');
  const jobCatalogId = el.dataset.id;

  try {
    await callAuthedRpc('toggle_today_task', { p_job_catalog_id: jobCatalogId, p_ngay: ngay });
    // Tải lại toàn bộ danh sách để đồng bộ số đếm/tổng giá trị — đơn giản và
    // đủ nhanh với ~50-150 việc/người; có thể tối ưu cập nhật tại chỗ sau.
    const data = await callAuthedRpc('get_today_screen', { p_ngay: ngay });
    renderList(app, data.items || [], ngay, onLogout);
  } catch (err) {
    el.classList.remove('pending');
    if (err.message === 'Chưa đăng nhập.') { onLogout(); return; }
    alert(err.message);
  }
}
