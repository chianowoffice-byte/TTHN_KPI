import { getSession } from './auth.js';
import { renderLogin, renderChangePassword } from './loginScreen.js';
import { renderToday } from './todayScreen.js';
import { renderReview } from './reviewScreen.js';

const app = document.getElementById('app');
let currentScreen = 'today';

function route() {
  const session = getSession();
  if (!session) {
    currentScreen = 'today';
    renderLogin(app, route);
  } else if (session.must_change_password) {
    renderChangePassword(app, route);
  } else if (currentScreen === 'review') {
    renderReview(app, route, goto);
  } else {
    renderToday(app, route, goto);
  }
}

function goto(screen) {
  currentScreen = screen;
  route();
}

route();
