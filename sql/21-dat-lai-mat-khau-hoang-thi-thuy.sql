-- Đặt lại mật khẩu của Hoàng Thị Thủy (mã CBNV 157267) về 123456.
-- Bắt đổi mật khẩu ở lần đăng nhập kế tiếp, mở khoá nếu đang bị khoá do nhập sai,
-- và thu hồi các phiên đăng nhập cũ. Chạy lại an toàn.

update accounts a set
  mat_khau_hash = extensions.crypt('123456', extensions.gen_salt('bf')),
  must_change_password = true,
  failed_attempts = 0,
  locked_until = null,
  updated_at = now()
from employees e
where e.id = a.employee_id and e.ma_cbnv = '157267';

update login_sessions s set revoked = true
from employees e
where e.id = s.employee_id and e.ma_cbnv = '157267' and not s.revoked;

-- Kiểm tra: phải ra đúng 1 dòng, ho_ten = Hoàng Thị Thủy, must_change_password = true
select e.ho_ten, e.ma_cbnv, a.must_change_password, a.failed_attempts, a.locked_until
from employees e join accounts a on a.employee_id = e.id
where e.ma_cbnv = '157267';
