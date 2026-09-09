import { getSession, logout, callAuthedRpc } from './auth.js';
import { esc, fmtDiem, todayStr } from './utils.js';
import { iconCheck, iconSearch, iconLogout } from './icons.js';

// Toàn bộ thao tác (Bắt đầu / sửa Số lượng-Ngày / Kết thúc / Huỷ / Bỏ Kết
// thúc) chỉ tác động lên state cục bộ dưới đây — không gọi RPC cho tới khi
// bấm "Lưu thay đổi". Reset mỗi lần tải lại dữ liệu từ server.
let staged = null;
function resetStaged() {
  staged = {
    starts: new Set(),      // job_catalog_id — Số lượng/Kết thúc luôn đọc trực tiếp từ DOM lúc Lưu
    finish: new Set(),      // daily_log_id
    cancel: new Set(),      // daily_log_id
    unfinish: new Set(),    // daily_log_id (đang done_today, sẽ mở lại)
  };
}

export async function renderToday(app, onLogout) {
  const session = getSession();

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

  await loadAndRender(app, onLogout);
}

async function loadAndRender(app, onLogout) {
  const body = app.querySelector('#today-body');
  resetStaged();
  let data;
  try {
    data = await callAuthedRpc('get_today_screen', {});
  } catch (err) {
    body.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
    if (err.message === 'Chưa đăng nhập.') onLogout();
    return;
  }
  renderShell(app, data, onLogout);
}

function dueColor(ngayDenHan) {
  const today = todayStr();
  if (ngayDenHan > today) return 'due-green';
  if (ngayDenHan === today) return 'due-yellow';
  return 'due-red';
}

function renderShell(app, data, onLogout) {
  window.__qlnb_onLogout = onLogout;
  const body = app.querySelector('#today-body');
  const inProgress = data.in_progress || [];
  const catalog = data.catalog || [];

  const doneToday = catalog.filter((i) => i.done_today);
  const notStarted = catalog.filter((i) => !i.done_today);
  const hangNgay = notStarted.filter((i) => /ngày/i.test(i.dinh_ky_tan_suat || ''));
  const khac = notStarted.filter((i) => !/ngày/i.test(i.dinh_ky_tan_suat || ''));

  body.innerHTML = `
    <div class="fixed-controls">
      <div class="ring-row">
        <div>
          <div class="ring-num" id="ring-count"></div>
          <div class="ring-label">Đang thực hiện: ${inProgress.length} việc</div>
        </div>
      </div>
      <div class="search-box">
        ${iconSearch}
        <input id="task-search" type="text" placeholder="Tìm việc theo tên hoặc mã…" />
      </div>
    </div>

    <div class="list-scroll" id="list-scroll">
      ${inProgress.length ? `<div class="group-label">Đang thực hiện</div>${inProgress.map(inProgressHtml).join('')}` : ''}
      ${doneToday.length ? `<div class="group-label">Đã kết thúc hôm nay</div>${doneToday.map(doneTodayHtml).join('')}` : ''}
      ${notStarted.length === 0 && inProgress.length === 0 && doneToday.length === 0 ? `
        <div class="empty-msg">Chưa có việc nào trong danh mục — liên hệ Trưởng/Phó phòng để bổ sung.</div>
      ` : ''}
      ${hangNgay.length ? `<div class="group-label">Việc hàng ngày</div>${hangNgay.map(catalogHtml).join('')}` : ''}
      ${khac.length ? `<div class="group-label">Việc khác — tìm để bắt đầu khi phát sinh</div>${khac.map(catalogHtml).join('')}` : ''}
    </div>

    <div class="save-bar" id="save-bar" hidden>
      <button class="btn-primary" id="btn-save">Lưu thay đổi</button>
    </div>
  `;

  const searchInput = body.querySelector('#task-search');
  searchInput.addEventListener('input', () => {
    const q = searchInput.value.trim().toLowerCase();
    body.querySelectorAll('[data-search]').forEach((el) => {
      const hay = el.dataset.search || '';
      el.style.display = !q || hay.includes(q) ? '' : 'none';
    });
    body.querySelectorAll('.group-label').forEach((el) => {
      el.style.display = q ? 'none' : '';
    });
  });

  wireCatalogTaps(body);
  wireInProgressCards(body);
  wireDoneTodayTaps(body);
  updateSaveBar(app, onLogout);
}

// ---------- Render từng loại dòng ----------

function catalogHtml(item) {
  const search = `${item.ten_cong_viec} ${item.ma_cv}`.toLowerCase();
  return `
    <div class="task" data-job-id="${item.job_catalog_id}" data-search="${esc(search)}">
      <div class="box">${iconCheck}</div>
      <div class="t">
        <div class="title">${esc(item.ten_cong_viec)}</div>
        <div class="meta">
          <span class="code">${esc(item.ma_cv)}</span>
          <span class="val">${fmtDiem(item.gia_tri_cv)}đ</span>
          <span class="freq">${esc(item.dinh_ky_tan_suat || '')}</span>
        </div>
        <div class="quick-finish-row">
          <label class="qty-inline">SL <input type="number" min="1" class="chk-so-luong" value="1" /></label>
          <label class="finish-now-toggle">
            <input type="checkbox" class="chk-finish-now" /> Kết thúc luôn (xong hôm nay)
          </label>
        </div>
      </div>
    </div>
  `;
}

function doneTodayHtml(item) {
  const search = `${item.ten_cong_viec} ${item.ma_cv}`.toLowerCase();
  return `
    <div class="task done" data-log-id="${item.log_id}" data-search="${esc(search)}">
      <div class="box">${iconCheck}</div>
      <div class="t">
        <div class="title">${esc(item.ten_cong_viec)}</div>
        <div class="meta">
          <span class="code">${esc(item.ma_cv)}</span>
          <span class="val">SL ${item.finished_so_luong} · ${fmtDiem(item.finished_gia_tri_tong)}đ</span>
          ${item.finished_is_ghi_bu ? `<span class="freq" style="color:var(--warn)">Ghi bù</span>` : ''}
        </div>
      </div>
    </div>
  `;
}

function inProgressHtml(item) {
  return `
    <div class="in-progress-card ${dueColor(item.ngay_den_han)}" data-log-id="${item.daily_log_id}" data-unit-value="${item.gia_tri_don_vi}">
      <div class="ip-title">${esc(item.ten_cong_viec)}</div>
      <div class="ip-code">${esc(item.ma_cv)} · ${fmtDiem(item.gia_tri_don_vi)}đ/đơn vị${item.is_ghi_bu ? ' · <span style="color:var(--warn)">Ghi bù</span>' : ''}</div>
      <div class="ip-fields">
        <label>SL <input type="number" min="1" class="ip-so-luong" value="${item.so_luong}" data-orig="${item.so_luong}" /></label>
        <label>Bắt đầu <input type="date" class="ip-ngay-bat-dau" value="${item.ngay_bat_dau}" data-orig="${item.ngay_bat_dau}" max="${todayStr()}" /></label>
        <label>Hạn <input type="date" class="ip-ngay-den-han" value="${item.ngay_den_han}" data-orig="${item.ngay_den_han}" /></label>
      </div>
      <div class="ip-total">Tổng: <span class="mono ip-gia-tri-tong">${fmtDiem(item.gia_tri_tong)}</span>đ</div>
      <div class="ip-actions">
        <button class="btn-small btn-cancel" type="button">Huỷ bắt đầu</button>
        <button class="btn-small btn-finish" type="button">Kết thúc</button>
      </div>
    </div>
  `;
}

// ---------- Gắn sự kiện: chỉ đổi state cục bộ + hiển thị, không gọi RPC ----------

function wireCatalogTaps(body) {
  body.querySelectorAll('.task[data-job-id]').forEach((el) => {
    const jobId = el.dataset.jobId;

    el.addEventListener('click', (e) => {
      if (e.target.closest('.quick-finish-row')) return; // bấm vào ô SL/checkbox không toggle theo dòng
      if (staged.starts.has(jobId)) {
        staged.starts.delete(jobId);
        el.classList.remove('staged');
      } else {
        staged.starts.add(jobId);
        el.classList.add('staged');
      }
      refreshSaveBarFromDom(el);
    });

    // Bấm vào ô Số lượng không được làm toggle cả dòng.
    el.querySelector('.chk-so-luong').addEventListener('click', (e) => e.stopPropagation());

    // Tích "Kết thúc luôn" tự tích luôn cả Bắt đầu (không cần bấm dòng trước) —
    // Ngày bắt đầu luôn = hôm nay cho trường hợp này (mặc định của start_task).
    // Bỏ tích lại KHÔNG tự bỏ tích Bắt đầu, chỉ tắt phần "kết thúc ngay".
    el.querySelector('.chk-finish-now').addEventListener('change', (e) => {
      e.stopPropagation();
      if (e.target.checked && !staged.starts.has(jobId)) {
        staged.starts.add(jobId);
        el.classList.add('staged');
      }
      refreshSaveBarFromDom(el);
    });
  });
}

function wireDoneTodayTaps(body) {
  body.querySelectorAll('.task.done[data-log-id]').forEach((el) => {
    el.addEventListener('click', () => {
      const logId = el.dataset.logId;
      if (staged.unfinish.has(logId)) {
        staged.unfinish.delete(logId);
        el.classList.remove('staged-unfinish');
      } else {
        staged.unfinish.add(logId);
        el.classList.add('staged-unfinish');
      }
      refreshSaveBarFromDom(el);
    });
  });
}

function wireInProgressCards(body) {
  body.querySelectorAll('.in-progress-card').forEach((card) => {
    const logId = card.dataset.logId;
    const unitVal = parseFloat(card.dataset.unitValue);
    const soLuongInput = card.querySelector('.ip-so-luong');
    const totalEl = card.querySelector('.ip-gia-tri-tong');
    const btnCancel = card.querySelector('.btn-cancel');
    const btnFinish = card.querySelector('.btn-finish');

    soLuongInput.addEventListener('input', () => {
      totalEl.textContent = fmtDiem(unitVal * (parseInt(soLuongInput.value, 10) || 1));
      refreshSaveBarFromDom(card);
    });
    card.querySelector('.ip-ngay-bat-dau').addEventListener('change', () => refreshSaveBarFromDom(card));
    card.querySelector('.ip-ngay-den-han').addEventListener('change', (e) => {
      card.className = `in-progress-card ${dueColor(e.target.value)}${staged.cancel.has(logId) ? ' staged-cancel' : ''}${staged.finish.has(logId) ? ' staged-finish' : ''}`;
      refreshSaveBarFromDom(card);
    });

    btnCancel.addEventListener('click', () => {
      if (staged.cancel.has(logId)) {
        staged.cancel.delete(logId);
        card.classList.remove('staged-cancel');
      } else {
        staged.cancel.add(logId);
        staged.finish.delete(logId);
        btnFinish.classList.remove('active');
        card.classList.remove('staged-finish');
        card.classList.add('staged-cancel');
      }
      btnCancel.classList.toggle('active', staged.cancel.has(logId));
      refreshSaveBarFromDom(card);
    });

    btnFinish.addEventListener('click', () => {
      if (staged.finish.has(logId)) {
        staged.finish.delete(logId);
        card.classList.remove('staged-finish');
      } else {
        staged.finish.add(logId);
        staged.cancel.delete(logId);
        btnCancel.classList.remove('active');
        card.classList.remove('staged-cancel');
        card.classList.add('staged-finish');
      }
      btnFinish.classList.toggle('active', staged.finish.has(logId));
      refreshSaveBarFromDom(card);
    });
  });
}

function inProgressCardEdited(card) {
  return ['.ip-so-luong', '.ip-ngay-bat-dau', '.ip-ngay-den-han'].some((sel) => {
    const input = card.querySelector(sel);
    return input.value !== input.dataset.orig;
  });
}

function countDirty(app) {
  const body = app.querySelector('#today-body');
  let n = staged.starts.size + staged.unfinish.size + staged.cancel.size;
  body.querySelectorAll('.in-progress-card').forEach((card) => {
    const logId = card.dataset.logId;
    if (staged.cancel.has(logId)) return; // đã đếm ở cancel rồi
    if (staged.finish.has(logId) || inProgressCardEdited(card)) n++;
  });
  return n;
}

function refreshSaveBarFromDom(elInside) {
  const app = elInside.closest('#app') || document.getElementById('app');
  updateSaveBar(app);
}

function updateSaveBar(app, onLogout) {
  const saveBar = app.querySelector('#save-bar');
  const ringCount = app.querySelector('#ring-count');
  if (!saveBar) return;
  const n = countDirty(app);
  if (ringCount) {
    const doneCount = app.querySelectorAll('.task.done').length;
    ringCount.textContent = `${doneCount} việc đã kết thúc hôm nay`;
  }
  if (n === 0) {
    saveBar.hidden = true;
    return;
  }
  saveBar.hidden = false;
  const btn = saveBar.querySelector('#btn-save');
  btn.textContent = `Lưu ${n} thay đổi`;
  btn.onclick = () => saveChanges(app, onLogout || window.__qlnb_onLogout);
}

// ---------- Lưu: áp toàn bộ staged lên server, rồi tải lại ----------

async function saveChanges(app, onLogout) {
  window.__qlnb_onLogout = onLogout; // để updateSaveBar gọi lại được sau reload nếu cần
  const body = app.querySelector('#today-body');
  const btn = app.querySelector('#btn-save');
  btn.disabled = true;
  btn.textContent = 'Đang lưu…';

  const errors = [];
  const today = todayStr();

  // 1) Huỷ các lượt đang thực hiện bị đánh dấu Huỷ.
  for (const logId of staged.cancel) {
    try { await callAuthedRpc('cancel_task', { p_daily_log_id: logId }); }
    catch (err) { errors.push(err.message); }
  }

  // 2) Các thẻ đang thực hiện còn lại: lưu sửa đổi (nếu có) rồi Kết thúc (nếu đánh dấu).
  for (const card of body.querySelectorAll('.in-progress-card')) {
    const logId = card.dataset.logId;
    if (staged.cancel.has(logId)) continue;
    try {
      if (inProgressCardEdited(card)) {
        await callAuthedRpc('update_task_progress', {
          p_daily_log_id: logId,
          p_so_luong: parseInt(card.querySelector('.ip-so-luong').value, 10) || 1,
          p_ngay_bat_dau: card.querySelector('.ip-ngay-bat-dau').value,
          p_ngay_den_han: card.querySelector('.ip-ngay-den-han').value,
        });
      }
      if (staged.finish.has(logId)) {
        await callAuthedRpc('finish_task', { p_daily_log_id: logId, p_ngay_ket_thuc: today });
      }
    } catch (err) { errors.push(err.message); }
  }

  // 3) Mở lại các việc đã Kết thúc hôm nay nhưng bị đánh dấu bỏ Kết thúc.
  for (const logId of staged.unfinish) {
    try { await callAuthedRpc('unfinish_task', { p_daily_log_id: logId }); }
    catch (err) { errors.push(err.message); }
  }

  // 4) Bắt đầu các việc mới được tích trong danh mục (Ngày bắt đầu = hôm nay,
  // Số lượng đọc trực tiếp từ ô nhập trên dòng) — nếu có tích "Kết thúc luôn"
  // thì kết thúc ngay sau đó.
  for (const jobId of staged.starts) {
    const row = body.querySelector(`.task[data-job-id="${jobId}"]`);
    const soLuong = parseInt(row?.querySelector('.chk-so-luong')?.value, 10) || 1;
    const finishNow = row?.querySelector('.chk-finish-now')?.checked || false;
    try {
      const res = await callAuthedRpc('start_task', { p_job_catalog_id: jobId, p_so_luong: soLuong });
      if (finishNow) {
        await callAuthedRpc('finish_task', { p_daily_log_id: res.daily_log_id, p_ngay_ket_thuc: today });
      }
    } catch (err) { errors.push(err.message); }
  }

  if (errors.length > 0) {
    alert('Một số thay đổi không lưu được:\n' + errors.join('\n'));
  }

  await loadAndRender(app, onLogout);
}
