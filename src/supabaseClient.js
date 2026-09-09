import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

// App cho đăng nhập bằng "mã CBNV" (vd 00146999) thay vì email — Supabase Auth
// vẫn cần một email nội bộ để xác thực, nên ghép mã CBNV với hậu tố cố định.
// Hậu tố lấy từ .env (VITE_AUTH_EMAIL_SUFFIX) để đổi được mà không sửa code.
const EMAIL_SUFFIX = import.meta.env.VITE_AUTH_EMAIL_SUFFIX || '@qlnb.noibo';

export function maCBNVToEmail(maCBNV) {
  return `${maCBNV.trim()}${EMAIL_SUFFIX}`;
}
