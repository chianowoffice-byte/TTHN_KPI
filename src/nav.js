import { esc } from './utils.js';
import { iconLogout, iconToday, iconClipboard } from './icons.js';

// Phó/Trưởng phòng có thêm màn "Duyệt điểm" — cán bộ thường chỉ có "Hôm nay".
const REVIEW_ROLES = ['pho_truong_phong', 'truong_phong'];

export function canReview(session) {
  return REVIEW_ROLES.includes(session?.app_role);
}

/** Vẽ thanh đầu trang dùng chung: tên cán bộ + (tuỳ vai trò) 2 tab chuyển màn
 *  + nút đăng xuất. `current` là 'today' hoặc 'review'. `pendingCount` để
 *  hiện số việc chờ duyệt cạnh tab, truyền 0/undefined nếu chưa biết. */
export function topbarHtml(session, current, pendingCount) {
  const tabs = canReview(session) ? `
    <div class="nav-tabs">
      <button type="button" class="nav-tab ${current === 'today' ? 'active' : ''}" data-goto="today">${iconToday} Hôm nay</button>
      <button type="button" class="nav-tab ${current === 'review' ? 'active' : ''}" data-goto="review">
        ${iconClipboard} Duyệt điểm${pendingCount ? ` <span class="nav-badge">${pendingCount}</span>` : ''}
      </button>
    </div>` : '';

  return `
    <div class="topbar">
      <div class="who">
        <span class="name">${esc(session.ma_cbnv)}</span>
        <h1>${esc(session.ho_ten)}</h1>
      </div>
      ${tabs}
      <button class="logout-btn" id="btn-logout" title="Đăng xuất">${iconLogout}</button>
    </div>
  `;
}

/** Gắn sự kiện cho nút đăng xuất + 2 tab (nếu có). `onGoto(screenName)` được
 *  gọi khi bấm tab khác màn hiện tại. */
export function wireTopbar(app, onLogout, onGoto) {
  app.querySelector('#btn-logout').addEventListener('click', async () => {
    const { logout } = await import('./auth.js');
    await logout();
    onLogout();
  });
  app.querySelectorAll('.nav-tab').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (!btn.classList.contains('active')) onGoto(btn.dataset.goto);
    });
  });
}
