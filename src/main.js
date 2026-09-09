import { getSession } from './auth.js';
import { renderLogin, renderChangePassword } from './loginScreen.js';
import { renderToday } from './todayScreen.js';

const app = document.getElementById('app');

function route() {
  const session = getSession();
  if (!session) {
    renderLogin(app, route);
  } else if (session.must_change_password) {
    renderChangePassword(app, route);
  } else {
    renderToday(app, route);
  }
}

route();
