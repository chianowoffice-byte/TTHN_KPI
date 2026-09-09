import { createClient } from '@supabase/supabase-js';

// Không dùng Supabase Auth (xem sql/01-schema-va-rls.sql) — client này chỉ
// dùng để gọi các hàm RPC (supabase.rpc(...)) bằng anon key. Không bật session
// tự động của thư viện vì ta tự quản lý "vé" (token) trong bảng login_sessions.
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY,
  { auth: { persistSession: false } }
);
