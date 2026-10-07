import { getSession, callAuthedRpc } from './auth.js';
import { esc, fmtDiem, todayStr } from './utils.js';
import { topbarHtml, wireTopbar } from './nav.js';

const CAP_LABEL = { kiem_soat: 'Kiểm soát', truong_phong: 'Trưởng phòng', pgd: 'PGĐ', gd: 'GĐ' };

let range = null; // { tu, den } giữ lại khi chuyển màn rồi quay lại

function dauThang(iso) { return iso.slice(0, 8) + '01'; }
function addDays(iso, n) {
  const d = new Date(iso + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
function fmtNgay(iso) {
  if (!iso) return '';
  const [y, m, d] = String(iso).slice(0, 10).split('-');
  return `${d}/${m}/${y}`;
}

export async function renderReport(app, onLogout, onGoto) {
  const session = getSession();
  if (!range) range = { tu: dauThang(todayStr()), den: todayStr() };

  app.innerHTML = `
    <div class="screen">
      ${topbarHtml(session, 'report')}
      <div class="body" id="report-body">
        <div class="card report-controls">
          <div class="report-dates">
            <label class="qty-inline">Từ ngày <input type="date" id="rp-tu" value="${range.tu}" /></label>
            <label class="qty-inline">Đến ngày <input type="date" id="rp-den" value="${range.den}" /></label>
          </div>
          <div class="chip-row" id="rp-chips">
            <button type="button" class="chip" data-p="today">Hôm nay</button>
            <button type="button" class="chip" data-p="7d">7 ngày</button>
            <button type="button" class="chip" data-p="month">Tháng này</button>
            <button type="button" class="chip" data-p="lastmonth">Tháng trước</button>
          </div>
        </div>
        <div id="report-result"><div class="empty-msg">Đang tải báo cáo…</div></div>
      </div>
    </div>
  `;

  wireTopbar(app, onLogout, onGoto);

  const tuEl = app.querySelector('#rp-tu');
  const denEl = app.querySelector('#rp-den');
  const apply = () => {
    range = { tu: tuEl.value, den: denEl.value };
    load(app, onLogout);
  };
  tuEl.addEventListener('change', apply);
  denEl.addEventListener('change', apply);

  app.querySelectorAll('#rp-chips .chip').forEach((chip) => {
    chip.addEventListener('click', () => {
      const today = todayStr();
      const p = chip.dataset.p;
      if (p === 'today') { tuEl.value = today; denEl.value = today; }
      else if (p === '7d') { tuEl.value = addDays(today, -6); denEl.value = today; }
      else if (p === 'month') { tuEl.value = dauThang(today); denEl.value = today; }
      else {
        const cuoiThangTruoc = addDays(dauThang(today), -1);
        tuEl.value = dauThang(cuoiThangTruoc); denEl.value = cuoiThangTruoc;
      }
      apply();
    });
  });

  await load(app, onLogout);
}

async function load(app, onLogout) {
  const out = app.querySelector('#report-result');
  if (!range.tu || !range.den) { out.innerHTML = `<div class="empty-msg">Chọn Từ ngày và Đến ngày.</div>`; return; }
  out.innerHTML = `<div class="empty-msg">Đang tải báo cáo…</div>`;
  let data;
  try {
    data = await callAuthedRpc('get_my_report', { p_tu: range.tu, p_den: range.den });
  } catch (err) {
    out.innerHTML = `<div class="error-msg">${esc(err.message)}</div>`;
    if (err.message === 'Chưa đăng nhập.') onLogout();
    return;
  }
  out.innerHTML = resultHtml(data);
}

function noteHtml(ghiChu) {
  return ghiChu ? `<div class="review-note"><span class="review-note-label">Ghi chú</span>${esc(ghiChu)}</div>` : '';
}

function khaiBaoRowHtml(r) {
  let badge;
  if (!r.da_xong) badge = `<span class="freq" style="color:var(--warn)">Đang thực hiện</span>`;
  else if (r.dung_han) badge = `<span class="freq" style="color:var(--accent)">Đúng hạn</span>`;
  else badge = `<span class="freq" style="color:var(--danger)">Trễ hạn</span>`;
  return `
    <div class="report-row">
      <div class="ip-title">${esc(r.ten_cong_viec)}</div>
      <div class="ip-code">
        ${esc(r.ma_cv)} · ${esc(r.ten_mang)} · SL ${r.so_luong} · ${badge}
        ${r.la_diem_thuong ? `<span class="done-pill">Điểm thưởng</span>` : ''}
        ${r.is_ghi_bu ? `<span class="freq" style="color:var(--warn)">Ghi bù</span>` : ''}
      </div>
      <div class="report-points">
        ${r.da_xong
          ? `Điểm: <b>${fmtDiem(r.gia_tri_tong)}</b> · Tiến độ ${fmtDiem(r.diem_tien_do)} · Chất lượng ${fmtDiem(r.diem_chat_luong)}`
          : `Giá trị dự kiến: <b>${fmtDiem(r.gia_tri_tong)}</b> · Hạn ${fmtNgay(r.ngay_den_han)}`}
      </div>
      ${noteHtml(r.ghi_chu)}
    </div>`;
}

function ksRowHtml(r) {
  const coDiem = r.cap === 'kiem_soat' || r.cap === 'truong_phong';
  let diem;
  if (!r.da_duyet) diem = `<span style="color:var(--warn)">Chờ duyệt</span> (tối đa ${fmtDiem(r.diem_toi_da)})`;
  else if (coDiem) diem = `Điểm kiểm soát: Tiến độ <b>${fmtDiem(r.diem_tien_do)}</b> · Chất lượng <b>${fmtDiem(r.diem_chat_luong)}</b> (tối đa ${fmtDiem(r.diem_toi_da)})`;
  else diem = `Đã phê duyệt (không chấm điểm)`;
  return `
    <div class="report-row">
      <div class="ip-title">${esc(r.ten_cong_viec)}</div>
      <div class="ip-code">
        ${esc(r.ma_cv)} · Cấp ${esc(CAP_LABEL[r.cap] || r.cap)} · Người làm: ${esc(r.nguoi_thuc_hien)} (${esc(r.ma_cbnv_thuc_hien)}) · SL ${r.so_luong}
        · ${r.dung_han ? `<span class="freq" style="color:var(--accent)">Đúng hạn</span>` : `<span class="freq" style="color:var(--danger)">Trễ hạn</span>`}
        ${r.so_lan_gia_han > 0 ? `<span class="freq" style="color:var(--warn)">Đã gia hạn ${r.so_lan_gia_han} lần</span>` : ''}
      </div>
      <div class="report-points">${diem}</div>
      ${noteHtml(r.ghi_chu)}
    </div>`;
}

function groupByDate(rows) {
  const groups = [];
  rows.forEach((r) => {
    const last = groups[groups.length - 1];
    const ngay = String(r.ngay).slice(0, 10);
    if (last && last.ngay === ngay) last.rows.push(r);
    else groups.push({ ngay, rows: [r] });
  });
  return groups;
}

function listHtml(rows, rowFn, emptyMsg) {
  if (rows.length === 0) return `<div class="empty-msg">${emptyMsg}</div>`;
  return groupByDate(rows).map((g) => `
    <div class="group-label">${fmtNgay(g.ngay)}</div>
    ${g.rows.map(rowFn).join('')}
  `).join('');
}

function resultHtml(d) {
  const kb = d.tong_khai_bao;
  const ks = d.tong_kiem_soat;
  return `
    <div class="ov-section-title" style="margin:4px 2px 8px">Việc tôi đã khai báo · ${fmtNgay(d.tu)} – ${fmtNgay(d.den)}</div>
    <div class="ov-tiles">
      <div class="ov-tile"><div class="ov-tile-v">${kb.so_viec_xong}</div><div class="ov-tile-l">Việc đã kết thúc</div></div>
      <div class="ov-tile"><div class="ov-tile-v">${kb.so_viec_dang_lam}</div><div class="ov-tile-l">Đang thực hiện</div></div>
      <div class="ov-tile"><div class="ov-tile-v">${fmtDiem(kb.gia_tri)}đ</div><div class="ov-tile-l">Tổng giá trị công việc</div></div>
      <div class="ov-tile"><div class="ov-tile-v" style="color:var(--accent)">${fmtDiem(kb.diem_thuong)}đ</div><div class="ov-tile-l">Điểm thưởng (Đoàn thể)</div></div>
      <div class="ov-tile"><div class="ov-tile-v">${fmtDiem(kb.diem_tien_do)}</div><div class="ov-tile-l">Tổng điểm Tiến độ</div></div>
      <div class="ov-tile"><div class="ov-tile-v">${fmtDiem(kb.diem_chat_luong)}</div><div class="ov-tile-l">Tổng điểm Chất lượng</div></div>
    </div>
    <div class="list-scroll">${listHtml(d.khai_bao, khaiBaoRowHtml, 'Không có việc nào khai báo trong khoảng ngày này.')}</div>

    ${d.kiem_soat.length === 0 ? '' : `
    <div class="ov-section-title" style="margin:18px 2px 8px">Việc tôi đã kiểm soát · ${fmtNgay(d.tu)} – ${fmtNgay(d.den)}</div>
    <div class="ov-tiles">
      <div class="ov-tile"><div class="ov-tile-v">${ks.so_viec}</div><div class="ov-tile-l">Việc được giao kiểm soát</div></div>
      <div class="ov-tile"><div class="ov-tile-v"><span style="color:var(--accent)">${ks.da_duyet}</span> / <span style="color:var(--warn)">${ks.cho_duyet}</span></div><div class="ov-tile-l">Đã duyệt / chờ duyệt</div></div>
      <div class="ov-tile"><div class="ov-tile-v">${fmtDiem(ks.diem_tien_do)}</div><div class="ov-tile-l">Điểm kiểm soát — Tiến độ</div></div>
      <div class="ov-tile"><div class="ov-tile-v">${fmtDiem(ks.diem_chat_luong)}</div><div class="ov-tile-l">Điểm kiểm soát — Chất lượng</div></div>
    </div>
    <div class="list-scroll">${listHtml(d.kiem_soat, ksRowHtml, '')}</div>`}
  `;
}
