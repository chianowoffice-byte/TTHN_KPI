import { getSession } from './auth.js';
import { renderLogin, renderChangePassword } from './loginScreen.js';
import { renderToday } from './todayScreen.js';
import { renderReview } from './reviewScreen.js';
import { renderOverview } from './overviewScreen.js';
import { renderMyStats } from './myStatsScreen.js';

const app = document.getElementById('app');
let currentScreen = 'today';
let screenBeforePassword = 'today';

function route() {
  const session = getSession();
  if (!session) {
    currentScreen = 'today';
    renderLogin(app, route);
  } else if (session.must_change_password) {
    renderChangePassword(app, route); // bắt buộc, không có nút Huỷ
  } else if (currentScreen === 'password') {
    renderChangePassword(app, () => goto(screenBeforePassword), {
      mandatory: false,
      onCancel: () => goto(screenBeforePassword),
    });
  } else if (currentScreen === 'review') {
    renderReview(app, route, goto);
  } else if (currentScreen === 'overview') {
    renderOverview(app, route, goto);
  } else if (currentScreen === 'mystats') {
    renderMyStats(app, route, goto);
  } else {
    renderToday(app, route, goto);
  }
}

function goto(screen) {
  if (screen === 'password') screenBeforePassword = currentScreen;
  currentScreen = screen;
  route();
}

route();
