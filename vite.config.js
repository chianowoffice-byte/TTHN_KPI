import { defineConfig } from 'vite';

// TODO: đổi 'base' thành '/<ten-repo>/' đúng tên repo GitHub thật khi có (giống
// cách "Quan ly ban hang" dùng base: '/Quanlybanhang/') — để GitHub Pages phục vụ
// đúng đường dẫn con thay vì domain gốc. Để '/' tạm trong lúc dev local.
export default defineConfig({
  base: '/',
});
