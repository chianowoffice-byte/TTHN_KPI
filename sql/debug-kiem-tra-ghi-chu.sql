-- ============================================================================
-- CHỈ ĐỂ KIỂM TRA (không sửa dữ liệu) — chạy cả 2 câu dưới trong Supabase SQL
-- Editor rồi gửi lại toàn bộ kết quả (chụp màn hình hoặc copy bảng kết quả).
-- ============================================================================

-- 1) Dữ liệu THẬT của 2 việc trong ảnh — xem cột ghi_chu có giá trị hay NULL.
select
  dl.id as daily_log_id, jc.ma_cv, jc.ten_cong_viec,
  e.ho_ten as nguoi_lam, e.ma_cbnv,
  dl.ngay_bat_dau, dl.ngay_den_han, dl.ngay_ket_thuc_thuc_te,
  dl.ghi_chu, dl.created_at, dl.updated_at
from daily_log dl
join job_catalog jc on jc.id = dl.job_catalog_id
join employees e on e.id = dl.employee_id
where jc.ma_cv in ('HCVP-015', 'KHTH-019')
order by dl.updated_at desc
limit 10;

-- 2) Hàm get_pending_reviews hiện tại trên server có đang trả về cột ghi_chu
-- không (nếu thiếu "dl.ghi_chu" trong kết quả bên dưới nghĩa là migration
-- 18-chi-tiet-duyet-diem.sql CHƯA được chạy, màn Duyệt điểm sẽ luôn hiện
-- "Không có ghi chú" dù dữ liệu thật có ghi chú).
select pg_get_functiondef(oid) as dinh_nghia_ham
from pg_proc
where proname = 'get_pending_reviews';

-- 3) Liệt kê TẤT CẢ các phiên bản (overload) hiện có của các hàm hay đổi
-- tham số gần đây — nếu 1 tên hàm có nhiều hơn 1 dòng nghĩa là đang tồn tại
-- bản cũ + bản mới song song (có thể gây lỗi khi gọi).
select proname, pg_get_function_identity_arguments(oid) as tham_so
from pg_proc
where proname in ('start_task', 'update_task_progress', 'finish_task', 'get_pending_reviews', 'get_today_screen')
order by proname, tham_so;
