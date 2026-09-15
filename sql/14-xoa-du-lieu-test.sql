-- ============================================================================
-- XOÁ SẠCH DỮ LIỆU NHẬT KÝ/DUYỆT ĐIỂM TEST — đưa về trạng thái sạch để bắt
-- đầu dùng thật. KHÔNG đụng tới: employees, accounts, job_catalog, mang_cv,
-- employee_mang_cv (danh mục & nhân sự vẫn giữ nguyên).
--
-- Lưu ý: trong lúc test tôi vẫn luôn dọn lại sau mỗi lần (huỷ/bỏ Kết thúc dữ
-- liệu vừa tạo), nên daily_log nhiều khả năng đã trống sẵn — chạy file này để
-- chắc chắn 100%, không sót gì.
-- ============================================================================

delete from daily_log_participants;
delete from daily_log;
delete from kpi_quarter;
delete from satisfaction_survey;

-- Dọn luôn các phiên đăng nhập cũ phát sinh lúc test (không bắt buộc — phiên
-- cũ tự hết hạn sau 30 ngày và không ảnh hưởng gì, chỉ dọn cho gọn).
delete from login_sessions;

-- Xác nhận đã sạch.
select
  (select count(*) from daily_log) as daily_log,
  (select count(*) from daily_log_participants) as daily_log_participants,
  (select count(*) from kpi_quarter) as kpi_quarter,
  (select count(*) from satisfaction_survey) as satisfaction_survey,
  (select count(*) from login_sessions) as login_sessions;
