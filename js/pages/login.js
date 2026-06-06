function renderLogin() {
  const saved = JSON.parse(localStorage.getItem('user') || 'null');
  const el = document.getElementById('page-login');
  el.innerHTML = `
    <div class="login-page">
      <div class="login-card">
        <h1>🚢 Santos Transportes</h1>
        <p class="subtitle">Controle de Containers</p>
        <form id="login-form" onsubmit="doLogin(event)">
          <div class="form-group">
            <label>Usuário</label>
            <input id="login-user" value="${saved?.nome || ''}" required autocomplete="username">
          </div>
          <div class="form-group">
            <label>Senha</label>
            <input id="login-pass" type="password" required autocomplete="current-password">
          </div>
          <button type="submit" class="btn btn-primary btn-full">Entrar</button>
        </form>
        <div style="text-align:center;margin-top:12px">
          <a href="#" onclick="showResetPassword()" style="color:var(--primary);font-size:.85rem">Esqueceu a senha?</a>
        </div>
        <div id="login-error" style="color:var(--danger);text-align:center;margin-top:8px;font-size:.85rem"></div>
      </div>
    </div>`;
  el.classList.remove('hidden');
}

async function doLogin(e) {
  e.preventDefault();
  const user = document.getElementById('login-user').value.trim();
  const pass = document.getElementById('login-pass').value;
  const errEl = document.getElementById('login-error');
  const btn = e.target.querySelector('button[type="submit"]');
  errEl.textContent = '';
  btn.disabled = true;
  btn.textContent = 'Entrando...';

  try {
    const u = await Auth.login(user, pass);
    if (u) {
      document.getElementById('page-login').classList.add('hidden');
      document.getElementById('app-shell').classList.remove('hidden');
      Store.init();
      setupNav();
      Router.init();
    } else {
      errEl.textContent = 'Usuário ou senha inválidos.';
    }
  } catch (err) {
    errEl.innerHTML = 'Erro: ' + err.message + '<br><small>Se for a primeira vez, aguarde 2 min e tente novamente.</small>';
    console.error('Login error:', err);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Entrar';
  }
}

function showResetPassword() {
  Utils.showModal(`
    <div class="modal-header">
      <h3>Redefinir Senha</h3>
      <button class="modal-close" onclick="Utils.closeModal()">&times;</button>
    </div>
    <form onsubmit="doResetPassword(event)">
      <div class="form-group">
        <label>Usuário</label>
        <input id="reset-user" required>
      </div>
      <div class="form-group">
        <label>Nova Senha</label>
        <input id="reset-pass" type="password" minlength="4" required>
      </div>
      <div class="form-group">
        <label>Confirmar Senha</label>
        <input id="reset-pass2" type="password" minlength="4" required>
      </div>
      <button type="submit" class="btn btn-primary btn-full">Redefinir</button>
    </form>
  `);
}

async function doResetPassword(e) {
  e.preventDefault();
  const user = document.getElementById('reset-user').value.trim();
  const pass = document.getElementById('reset-pass').value;
  const pass2 = document.getElementById('reset-pass2').value;
  if (pass !== pass2) { Utils.showToast('As senhas não conferem'); return; }
  const ok = await Auth.resetPassword(user, pass);
  Utils.closeModal();
  Utils.showToast(ok ? 'Senha redefinida!' : 'Usuário não encontrado');
}
