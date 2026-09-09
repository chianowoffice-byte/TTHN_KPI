import { login, doiMatKhau, getSession } from './auth.js';
import { esc } from './utils.js';

export function renderLogin(app, onDone) {
  app.innerHTML = `
    <div class="login-wrap">
      <div class="brand">
        <div class="eyebrow">Phòng Quản lý nội bộ</div>
        <h1>Sổ KPI QLNB</h1>
      </div>
      <form id="login-form">
        <div id="login-error"></div>
        <div class="field">
          <label for="ma-cbnv">Mã CBNV</label>
          <input id="ma-cbnv" type="text" inputmode="numeric" autocomplete="username" placeholder="Ví dụ: 00146999" required />
        </div>
        <div class="field">
          <label for="mat-khau">Mật khẩu</label>
          <input id="mat-khau" type="password" autocomplete="current-password" required />
        </div>
        <button class="btn-primary" type="submit">Đăng nhập</button>
      </form>
    </div>
  `;

  const form = app.querySelector('#login-form');
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const maCBNV = app.querySelector('#ma-cbnv').value.trim();
    const matKhau = app.querySelector('#mat-khau').value;
    const errorEl = app.querySelector('#login-error');
    const btn = form.querySelector('button');

    errorEl.innerHTML = '';
    btn.disabled = true;
    btn.textContent = 'Đang kiểm tra…';

    try {
      await login(maCBNV, matKhau);
      onDone();
    } catch (err) {
      errorEl.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
      btn.disabled = false;
      btn.textContent = 'Đăng nhập';
    }
  });
}

export function renderChangePassword(app, onDone) {
  const session = getSession();
  app.innerHTML = `
    <div class="login-wrap">
      <div class="brand">
        <div class="eyebrow">Chào ${esc(session?.ho_ten || '')}</div>
        <h1>Đổi mật khẩu lần đầu</h1>
      </div>
      <form id="change-form">
        <div id="change-error"></div>
        <p style="font-size:13px;color:var(--ink-dim);margin:0;">Tài khoản đang dùng mật khẩu mặc định — đổi sang mật khẩu riêng (ít nhất 6 ký tự) trước khi vào app.</p>
        <div class="field">
          <label for="mk-cu">Mật khẩu mặc định</label>
          <input id="mk-cu" type="password" autocomplete="current-password" required />
        </div>
        <div class="field">
          <label for="mk-moi">Mật khẩu mới</label>
          <input id="mk-moi" type="password" autocomplete="new-password" minlength="6" required />
        </div>
        <div class="field">
          <label for="mk-moi-2">Nhập lại mật khẩu mới</label>
          <input id="mk-moi-2" type="password" autocomplete="new-password" minlength="6" required />
        </div>
        <button class="btn-primary" type="submit">Đổi mật khẩu &amp; tiếp tục</button>
      </form>
    </div>
  `;

  const form = app.querySelector('#change-form');
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const mkCu = app.querySelector('#mk-cu').value;
    const mkMoi = app.querySelector('#mk-moi').value;
    const mkMoi2 = app.querySelector('#mk-moi-2').value;
    const errorEl = app.querySelector('#change-error');
    const btn = form.querySelector('button');

    if (mkMoi !== mkMoi2) {
      errorEl.innerHTML = `<div class="error-msg">Hai lần nhập mật khẩu mới không khớp.</div>`;
      return;
    }

    errorEl.innerHTML = '';
    btn.disabled = true;
    btn.textContent = 'Đang lưu…';

    try {
      await doiMatKhau(mkCu, mkMoi);
      onDone();
    } catch (err) {
      errorEl.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
      btn.disabled = false;
      btn.textContent = 'Đổi mật khẩu & tiếp tục';
    }
  });
}
