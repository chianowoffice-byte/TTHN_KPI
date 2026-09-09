/**
 * Tạo 12 tài khoản đăng nhập Supabase Auth cho cán bộ Phòng QLNB, rồi nối
 * auth_user_id vào bảng employees tương ứng. CHẠY 1 LẦN, Ở MÁY LOCAL.
 *
 * Vì sao không nhờ Claude chạy hộ: bước này cần "service_role key" — khoá có
 * toàn quyền trên database, bỏ qua RLS. Khoá đó KHÔNG được dán vào chat hay
 * đưa cho Claude trong bất kỳ trường hợp nào; chỉ dùng cục bộ ở máy của
 * anh/chị rồi xoá khỏi màn hình.
 *
 * Cách chạy:
 *   1. Vào Supabase Dashboard → Project Settings → API → copy "service_role"
 *      key (KHÁC với anon key đã đưa cho Claude).
 *   2. Trong PowerShell, tại thư mục dự án:
 *        $env:SUPABASE_SERVICE_ROLE_KEY = "<dán key vào đây>"
 *        node scripts/tao-tai-khoan-dang-nhap.mjs
 *   3. Xong thì đóng cửa sổ PowerShell đó (để key không còn trong lịch sử phiên).
 *
 * Script chạy lại an toàn — nếu tài khoản đã tồn tại thì bỏ qua, không tạo trùng.
 */
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://tsgxvuawnezxgojgtibk.supabase.co';
const EMAIL_SUFFIX = '@qlnb.noibo';
const DEFAULT_PASSWORD = '123456';

const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!serviceKey) {
  console.error('Thiếu SUPABASE_SERVICE_ROLE_KEY — xem hướng dẫn ở đầu file này.');
  process.exit(1);
}

const admin = createClient(SUPABASE_URL, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// 12 cán bộ Phòng QLNB — đúng mã CBNV trong sql/02-seed-nhan-su.sql.
// Muốn thêm tài khoản Ban Giám đốc: thêm 1 dòng mã CBNV riêng vào đây VÀ vào
// employees (app_role='ban_giam_doc') trước khi chạy script.
const MA_CBNV_LIST = [
  '00157251', '00169422', '00146999', '00157761', '00157764', '00157765',
  '00157760', '00157279', '00157267', '00157280', '00157275', '00183881',
];

async function main() {
  for (const maCBNV of MA_CBNV_LIST) {
    const email = `${maCBNV}${EMAIL_SUFFIX}`;

    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password: DEFAULT_PASSWORD,
      email_confirm: true, // không gửi email xác nhận thật, tài khoản dùng được ngay
    });

    let userId = created?.user?.id;

    if (createErr) {
      if (createErr.message?.includes('already been registered')) {
        // Đã tồn tại từ lần chạy trước — tra lại id để vẫn nối vào employees.
        const { data: list } = await admin.auth.admin.listUsers();
        const existing = list?.users?.find((u) => u.email === email);
        userId = existing?.id;
        console.log(`= ${maCBNV}: tài khoản đã có sẵn, dùng lại id.`);
      } else {
        console.error(`✗ ${maCBNV}: lỗi tạo tài khoản —`, createErr.message);
        continue;
      }
    } else {
      console.log(`+ ${maCBNV}: đã tạo tài khoản (${email}).`);
    }

    if (!userId) continue;

    const { error: updateErr } = await admin
      .from('employees')
      .update({ auth_user_id: userId })
      .eq('ma_cbnv', maCBNV);

    if (updateErr) {
      console.error(`  ✗ nối employees.auth_user_id thất bại —`, updateErr.message);
    } else {
      console.log(`  → đã nối vào employees.ma_cbnv=${maCBNV}.`);
    }
  }

  console.log('\nXong. Mật khẩu mặc định cho mọi tài khoản: 123456 (app sẽ bắt đổi ở lần đăng nhập đầu).');
}

main();
