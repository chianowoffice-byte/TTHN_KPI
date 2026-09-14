import { esc } from './utils.js';
import { iconLogout, iconToday, iconClipboard, iconChart } from './icons.js';

// Phó/Trưởng phòng có thêm màn "Duyệt điểm"; riêng Trưởng phòng có thêm
// "Tổng quan" toàn phòng theo tháng.
const REVIEW_ROLES = ['pho_truong_phong', 'truong_phong'];

export function canReview(session) {
  return REVIEW_ROLES.includes(session?.app_role);
}
export function canViewOverview(session) {
  return session?.app_role === 'truong_phong';
}

/** Vẽ thanh đầu trang dùng chung: tên cán bộ + (tuỳ vai trò) các tab chuyển
 *  màn + nút đăng xuất. `current` là 'today' | 'review' | 'overview'. */
export function topbarHtml(session, current, pendingCount) {
  const tabs = [];
  tabs.push(`<button type="button" class="nav-tab ${current === 'today' ? 'active' : ''}" data-goto="today">${iconToday} Hôm nay</button>`);
  if (canReview(session)) {
    tabs.push(`<button type="button" class="nav-tab ${current === 'review' ? 'active' : ''}" data-goto="review">
      ${iconClipboard} Duyệt điểm${pendingCount ? ` <span class="nav-badge">${pendingCount}</span>` : ''}
    </button>`);
  }
  if (canViewOverview(session)) {
    tabs.push(`<button type="button" class="nav-tab ${current === 'overview' ? 'active' : ''}" data-goto="overview">${iconChart} Tổng quan</button>`);
  }

  return `
    <div class="topbar">
      <div class="who">
        <span class="name">${esc(session.ma_cbnv)}</span>
        <h1>${esc(session.ho_ten)}</h1>
      </div>
      <div class="nav-tabs">${tabs.join('')}</div>
      <button class="logout-btn" id="btn-logout" title="Đăng xuất">${iconLogout}</button>
    </div>
  `;
}

/** Gắn sự kiện cho nút đăng xuất + các tab. `onGoto(screenName)` được gọi
 *  khi bấm tab khác màn hiện tại. */
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
