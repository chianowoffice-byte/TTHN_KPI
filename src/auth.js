import { supabase } from './supabaseClient.js';

// Quản lý "vé" (token) của phiên đăng nhập tự xây (bảng login_sessions) —
// KHÔNG phải session của Supabase Auth. Lưu trong localStorage của trình
// duyệt, chỉ tồn tại trên máy cán bộ đó.
const STORAGE_KEY = 'qlnb_kpi_session';

export function getSession() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function setSession(session) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
}

export function clearSession() {
  localStorage.removeItem(STORAGE_KEY);
}

/** Đăng nhập bằng mã CBNV + mật khẩu. Ném lỗi (Error) với message tiếng Việt
 *  sẵn sàng hiện thẳng cho người dùng nếu sai. */
export async function login(maCBNV, matKhau) {
  const { data, error } = await supabase.rpc('login', {
    p_ma_cbnv: maCBNV,
    p_mat_khau: matKhau,
  });
  if (error) throw new Error(error.message);
  setSession(data);
  return data;
}

export async function logout() {
  const session = getSession();
  if (session?.token) {
    await supabase.rpc('logout', { p_token: session.token }).catch(() => {});
  }
  clearSession();
}

export async function doiMatKhau(matKhauCu, matKhauMoi) {
  const session = getSession();
  if (!session) throw new Error('Chưa đăng nhập.');
  const { error } = await supabase.rpc('doi_mat_khau', {
    p_token: session.token,
    p_mat_khau_cu: matKhauCu,
    p_mat_khau_moi: matKhauMoi,
  });
  if (error) throw new Error(error.message);
  setSession({ ...session, must_change_password: false });
}

/** Gọi 1 RPC nghiệp vụ (thêm dần khi dựng từng màn), tự đính kèm token của
 *  phiên hiện tại vào tham số p_token. Nếu phiên hết hạn (RPC báo lỗi từ
 *  session_employee_id), xoá session local để app quay lại màn đăng nhập. */
export async function callAuthedRpc(fnName, params = {}) {
  const session = getSession();
  if (!session) throw new Error('Chưa đăng nhập.');
  const { data, error } = await supabase.rpc(fnName, { p_token: session.token, ...params });
  if (error) {
    if (error.message?.includes('Phiên đăng nhập')) clearSession();
    throw new Error(error.message);
  }
  return data;
}
