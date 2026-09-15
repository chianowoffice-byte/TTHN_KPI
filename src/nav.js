import { esc } from './utils.js';
import { iconLogout, iconToday, iconClipboard, iconChart, iconKey, iconStats } from './icons.js';

// Phó/Trưởng phòng có thêm màn "Duyệt điểm"; riêng Trưởng phòng có thêm
// "Tổng quan" toàn phòng theo tháng. "Thống kê" (cá nhân) thì ai cũng có.
const REVIEW_ROLES = ['pho_truong_phong', 'truong_phong'];

export function canReview(session) {
  return REVIEW_ROLES.includes(session?.app_role);
}
export function canViewOverview(session) {
  return session?.app_role === 'truong_phong';
}

/** Vẽ thanh đầu trang dùng chung — 2 dòng để nút Đổi mật khẩu/Đăng xuất
 *  luôn thấy được trên điện thoại dù có bao nhiêu tab:
 *   Dòng 1: mã CBNV + tên .......... [Đổi mật khẩu] [Đăng xuất]
 *   Dòng 2: các tab chuyển màn, cuộn ngang nếu cần.
 *  `current` là 'today' | 'review' | 'overview' | 'mystats'. */
export function topbarHtml(session, current, pendingCount) {
  const tabs = [];
  tabs.push(`<button type="button" class="nav-tab ${current === 'today' ? 'active' : ''}" data-goto="today">${iconToday} Hôm nay</button>`);
  if (canReview(session)) {
    tabs.push(`<button type="button" class="nav-tab ${current === 'review' ? 'active' : ''}" data-goto="review">
      ${iconClipboard} Duyệt điểm${pendingCount ? ` <span class="nav-badge">${pendingCount}</span>` : ''}
    </button>`);
  }
  tabs.push(`<button type="button" class="nav-tab ${current === 'mystats' ? 'active' : ''}" data-goto="mystats">${iconStats} Thống kê</button>`);
  if (canViewOverview(session)) {
    tabs.push(`<button type="button" class="nav-tab ${current === 'overview' ? 'active' : ''}" data-goto="overview">${iconChart} Tổng quan</button>`);
  }

  return `
    <div class="topbar">
      <div class="topbar-row1">
        <div class="who">
          <span class="name">${esc(session.ma_cbnv)}</span>
          <h1>${esc(session.ho_ten)}</h1>
        </div>
        <div class="topbar-actions">
          <button class="icon-btn" id="btn-change-password" title="Đổi mật khẩu">${iconKey}</button>
          <button class="icon-btn" id="btn-logout" title="Đăng xuất">${iconLogout}</button>
        </div>
      </div>
      <div class="nav-tabs">${tabs.join('')}</div>
    </div>
  `;
}

/** Gắn sự kiện cho nút đăng xuất/đổi mật khẩu + các tab. `onGoto(screenName)`
 *  được gọi khi bấm tab khác màn hiện tại hoặc bấm Đổi mật khẩu (screen
 *  'password'). */
export function wireTopbar(app, onLogout, onGoto) {
  app.querySelector('#btn-logout').addEventListener('click', async () => {
    const { logout } = await import('./auth.js');
    await logout();
    onLogout();
  });
  app.querySelector('#btn-change-password').addEventListener('click', () => onGoto('password'));
  app.querySelectorAll('.nav-tab').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (!btn.classList.contains('active')) onGoto(btn.dataset.goto);
    });
  });
}
