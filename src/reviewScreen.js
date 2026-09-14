import { getSession, callAuthedRpc } from './auth.js';
import { esc, fmtDiem } from './utils.js';
import { topbarHtml, wireTopbar } from './nav.js';

const CAP_LABEL = { kiem_soat: 'Kiểm soát', truong_phong: 'Trưởng phòng', pgd: 'PGĐ', gd: 'GĐ' };

// Duyệt từng mục chỉ đổi state cục bộ (điểm sửa tại chỗ + đánh dấu "sẽ
// duyệt") — không gọi RPC cho tới khi bấm "Lưu", giống hệt màn Hôm nay.
let staged = null;
function resetStaged() {
  staged = { approve: new Set() }; // participant_id
}

export async function renderReview(app, onLogout, onGoto) {
  const session = getSession();

  app.innerHTML = `
    <div class="screen">
      ${topbarHtml(session, 'review')}
      <div class="body" id="review-body">
        <div class="empty-msg">Đang tải danh sách chờ duyệt…</div>
      </div>
    </div>
  `;

  wireTopbar(app, onLogout, onGoto);

  await loadAndRender(app, onLogout, onGoto);
}

async function loadAndRender(app, onLogout, onGoto) {
  const body = app.querySelector('#review-body');
  resetStaged();
  let data;
  try {
    data = await callAuthedRpc('get_pending_reviews', {});
  } catch (err) {
    body.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
    if (err.message === 'Chưa đăng nhập.') onLogout();
    return;
  }
  renderShell(app, data.items || [], onLogout, onGoto);
}

function renderShell(app, items, onLogout, onGoto) {
  const body = app.querySelector('#review-body');

  body.innerHTML = `
    <div class="fixed-controls">
      <div class="ring-row">
        <div>
          <div class="ring-num">${items.length} việc chờ duyệt</div>
          <div class="ring-label">Điểm mặc định đã tính sẵn theo đúng/trễ hạn — chỉ sửa khi cần</div>
        </div>
      </div>
    </div>

    <div class="list-scroll" id="review-list">
      ${items.length === 0 ? `<div class="empty-msg">Không có việc nào chờ duyệt.</div>` : items.map(reviewItemHtml).join('')}
    </div>

    <div class="save-bar" id="save-bar" hidden>
      <button class="btn-primary" id="btn-save">Lưu duyệt điểm</button>
    </div>
  `;

  wireReviewItems(body, app, onLogout, onGoto);
}

function reviewItemHtml(item) {
  const lateBadge = item.ngay_ket_thuc_thuc_te > item.ngay_den_han
    ? `<span class="freq" style="color:var(--danger)">Trễ hạn</span>`
    : `<span class="freq" style="color:var(--accent)">Đúng hạn</span>`;
  return `
    <div class="review-card" data-participant-id="${item.participant_id}" data-max="${item.diem_toi_da}">
      <div class="ip-title">${esc(item.ten_cong_viec)}</div>
      <div class="ip-code">
        ${esc(item.ma_cv)} · Cấp ${esc(CAP_LABEL[item.cap] || item.cap)} · Tối đa ${fmtDiem(item.diem_toi_da)}đ
      </div>
      <div class="ip-code">
        Người làm: ${esc(item.nguoi_thuc_hien)} (${esc(item.ma_cbnv_thuc_hien)}) · SL ${item.so_luong}
        · Xong ${esc(item.ngay_ket_thuc_thuc_te)} / Hạn ${esc(item.ngay_den_han)} ${lateBadge}
      </div>
      <div class="ip-fields">
        <label>Điểm Tiến độ <input type="number" step="0.1" min="0" max="${item.diem_toi_da}" class="rv-tien-do" value="${item.diem_tien_do ?? item.diem_toi_da}" /></label>
        <label>Điểm Chất lượng <input type="number" step="0.1" min="0" max="${item.diem_toi_da}" class="rv-chat-luong" value="${item.diem_chat_luong ?? item.diem_toi_da}" /></label>
      </div>
      <div class="ip-actions">
        <button class="btn-small btn-approve" type="button">Duyệt</button>
      </div>
    </div>
  `;
}

function wireReviewItems(body, app, onLogout, onGoto) {
  body.querySelectorAll('.review-card').forEach((card) => {
    const pid = card.dataset.participantId;
    const btn = card.querySelector('.btn-approve');

    btn.addEventListener('click', () => {
      if (staged.approve.has(pid)) {
        staged.approve.delete(pid);
      } else {
        staged.approve.add(pid);
      }
      btn.classList.toggle('active', staged.approve.has(pid));
      updateSaveBar(app, onLogout, onGoto);
    });

    ['.rv-tien-do', '.rv-chat-luong'].forEach((sel) => {
      card.querySelector(sel).addEventListener('input', () => updateSaveBar(app, onLogout, onGoto));
    });
  });
}

function updateSaveBar(app, onLogout, onGoto) {
  const saveBar = app.querySelector('#save-bar');
  const n = staged.approve.size;
  if (n === 0) {
    saveBar.hidden = true;
    return;
  }
  saveBar.hidden = false;
  const btn = saveBar.querySelector('#btn-save');
  btn.textContent = `Lưu ${n} lượt duyệt`;
  btn.onclick = () => saveChanges(app, onLogout, onGoto);
}

async function saveChanges(app, onLogout, onGoto) {
  const btn = app.querySelector('#btn-save');
  btn.disabled = true;
  btn.textContent = 'Đang lưu…';

  const errors = [];
  for (const pid of staged.approve) {
    const card = app.querySelector(`.review-card[data-participant-id="${pid}"]`);
    const tienDo = parseFloat(card.querySelector('.rv-tien-do').value);
    const chatLuong = parseFloat(card.querySelector('.rv-chat-luong').value);
    try {
      await callAuthedRpc('duyet_diem', { p_participant_id: pid, p_diem_tien_do: tienDo, p_diem_chat_luong: chatLuong });
    } catch (err) {
      errors.push(err.message);
    }
  }

  if (errors.length > 0) alert('Một số lượt duyệt không lưu được:\n' + errors.join('\n'));

  await loadAndRender(app, onLogout, onGoto);
}
