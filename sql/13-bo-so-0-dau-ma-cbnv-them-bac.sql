-- ============================================================================
-- 1) Bỏ '00' ở đầu mã CBNV cho toàn bộ 12 người hiện có (vd 00157251 → 157251)
--    — chỉ đổi cách đăng nhập, không ảnh hưởng dữ liệu khác (mọi bảng khác
--    tham chiếu qua employee_id, không lưu lại mã CBNV ở đâu khác).
-- 2) Gán mã CBNV thật cho Huỳnh Thị Bắc (157763), thay mã tạm TAMTHOI-BACHT,
--    và tạo tài khoản đăng nhập cho chị (trước đó chưa có vì chưa có mã thật)
--    — mật khẩu mặc định 123456, bắt đổi ở lần đăng nhập đầu như mọi người.
-- Chạy lại an toàn.
-- ============================================================================

update employees set ma_cbnv = substring(ma_cbnv from 3)
where ma_cbnv like '00%' and length(ma_cbnv) = 8;

update employees set ma_cbnv = '157763'
where ma_cbnv = 'TAMTHOI-BACHT';

insert into accounts (employee_id, mat_khau_hash, must_change_password)
select id, crypt('123456', gen_salt('bf')), true
from employees where ma_cbnv = '157763'
on conflict (employee_id) do nothing;
