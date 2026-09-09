-- Chạy cả khối này, xem kết quả từng bảng rồi dán lại cho Claude.

-- 1. Đếm số dòng mỗi bảng — kỳ vọng: departments=1, employees=12, accounts=12, job_catalog=457
select 'departments' as bang, count(*) from departments
union all select 'employees', count(*) from employees
union all select 'accounts', count(*) from accounts
union all select 'job_catalog', count(*) from job_catalog;

-- 2. Kiểm tra cây quản lý trực tiếp đã gán đúng chưa (Trưởng phòng phải NULL, còn lại không NULL)
select ma_cbnv, ho_ten, app_role, quan_ly_truc_tiep_id is not null as co_quan_ly
from employees order by app_role, ho_ten;

-- 3. Thử gọi hàm đăng nhập thật — dùng mã CBNV của Nguyệt Anh, mật khẩu mặc định
select login('00146999', '123456');

-- 4. Xác nhận bảng bị khoá đúng như thiết kế — câu này PHẢI báo lỗi
-- "permission denied for table employees" (nếu KHÔNG báo lỗi mà ra được dữ
-- liệu thì nghĩa là REVOKE chưa có tác dụng, cần báo lại cho Claude ngay).
select * from employees limit 1;
