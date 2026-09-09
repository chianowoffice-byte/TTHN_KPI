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

  await loadAndRender(app, ngay, onLogout);
}

async function loadAndRender(app, ngay, onLogout) {
  const body = app.querySelector('#today-body');
  let items = [];
  try {
    const data = await callAuthedRpc('get_today_screen', { p_ngay: ngay });
    items = (data.items || []).map((i) => ({ ...i, localDone: i.done }));
  } catch (err) {
    body.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
    if (err.message === 'Chưa đăng nhập.') onLogout();
    return;
  }
  renderShell(app, items, ngay, onLogout);
}

function renderShell(app, items, ngay, onLogout) {
  const body = app.querySelector('#today-body');

  const hangNgay = items.filter((i) => /ngày/i.test(i.dinh_ky_tan_suat || ''));
  const khac = items.filter((i) => !/ngày/i.test(i.dinh_ky_tan_suat || ''));

  body.innerHTML = `
    <div class="fixed-controls">
      <div class="ring-row">
        <div>
          <div class="ring-num" id="ring-count"></div>
          <div class="ring-label" id="ring-label"></div>
        </div>
      </div>
      <div class="search-box">
        ${iconSearch}
        <input id="task-search" type="text" placeholder="Tìm việc theo tên hoặc mã…" />
      </div>
    </div>

    <div class="list-scroll" id="list-scroll">
      ${items.length === 0 ? `
        <div class="empty-msg">Chưa có việc nào trong danh mục — liên hệ Trưởng/Phó phòng để bổ sung.</div>
      ` : `
        ${hangNgay.length ? `<div class="group-label">Việc hàng ngày</div>${hangNgay.map(taskHtml).join('')}` : ''}
        ${khac.length ? `<div class="group-label">Việc khác — tìm để tích khi phát sinh</div>${khac.map(taskHtml).join('')}` : ''}
      `}
    </div>

    <div class="save-bar" id="save-bar" hidden>
      <button class="btn-primary" id="btn-save">Lưu thay đổi</button>
    </div>
  `;

  const searchInput = body.querySelector('#task-search');
  searchInput.addEventListener('input', () => {
    const q = searchInput.value.trim().toLowerCase();
    body.querySelectorAll('.task').forEach((el) => {
      const hay = el.dataset.search || '';
      el.style.display = !q || hay.includes(q) ? '' : 'none';
    });
    body.querySelectorAll('.group-label').forEach((el) => {
      el.style.display = q ? 'none' : '';
    });
  });

  body.querySelectorAll('.task').forEach((el) => {
    const item = items.find((i) => i.job_catalog_id === el.dataset.id);
    el.addEventListener('click', () => toggleLocal(el, item, items, app, ngay, onLogout));
  });

  updateSummary(items, body);
  updateSaveBar(items, app, ngay, onLogout);
}

function taskHtml(item) {
  const search = `${item.ten_cong_viec} ${item.ma_cv}`.toLowerCase();
  return `
    <div class="task ${item.localDone ? 'done' : ''}" data-id="${item.job_catalog_id}" data-search="${esc(search)}">
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

function toggleLocal(el, item, items, app, ngay, onLogout) {
  item.localDone = !item.localDone;
  el.classList.toggle('done', item.localDone);
  const body = app.querySelector('#today-body');
  updateSummary(items, body);
  updateSaveBar(items, app, ngay, onLogout);
}

function updateSummary(items, body) {
  const doneItems = items.filter((i) => i.localDone);
  const doneValue = doneItems.reduce((sum, i) => sum + Number(i.gia_tri_cv), 0);
  const totalValue = items.reduce((sum, i) => sum + Number(i.gia_tri_cv), 0);
  body.querySelector('#ring-count').textContent = `${doneItems.length}/${items.length} việc đã tích hôm nay`;
  body.querySelector('#ring-label').innerHTML =
    `Giá trị đã hoàn thành: <span class="mono">${fmtDiem(doneValue)}</span>/${fmtDiem(totalValue)}đ`;
}

function updateSaveBar(items, app, ngay, onLogout) {
  const saveBar = app.querySelector('#save-bar');
  const dirty = items.filter((i) => i.localDone !== i.done);

  if (dirty.length === 0) {
    saveBar.hidden = true;
    return;
  }
  saveBar.hidden = false;
  const btn = saveBar.querySelector('#btn-save');
  btn.textContent = `Lưu ${dirty.length} thay đổi`;
  btn.onclick = () => saveChanges(dirty, items, app, ngay, onLogout);
}

async function saveChanges(dirty, items, app, ngay, onLogout) {
  const btn = app.querySelector('#btn-save');
  btn.disabled = true;
  btn.textContent = 'Đang lưu…';

  const results = await Promise.allSettled(
    dirty.map((item) => callAuthedRpc('toggle_today_task', { p_job_catalog_id: item.job_catalog_id, p_ngay: ngay }))
  );

  const failed = results
    .map((r, idx) => (r.status === 'rejected' ? { item: dirty[idx], reason: r.reason } : null))
    .filter(Boolean);

  if (failed.length > 0) {
    const first = failed[0].reason;
    alert(`Lưu được ${dirty.length - failed.length}/${dirty.length} thay đổi. Lỗi: ${first.message || first}`);
    if (first.message === 'Chưa đăng nhập.') { onLogout(); return; }
  }

  // Tải lại toàn bộ để đồng bộ đúng trạng thái thật trên server (kể cả phần
  // đã lưu thành công lẫn phần lỗi), rồi dựng lại danh sách từ đầu.
  await loadAndRender(app, ngay, onLogout);
}
