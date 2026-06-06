function setupNav() {
  const user = Auth.currentUser;
  const isAdmin = Auth.isAdmin();

  document.getElementById('user-display').textContent = `${user.nome} (${Utils.roleLabel(user.perfil)})`;

  const nav = document.getElementById('bottom-nav');
  let navHtml = `
    <button class="nav-item active" data-page="dashboard" onclick="Router.navigate('dashboard')">
      <span class="icon">📊</span>Início
    </button>
    <button class="nav-item" data-page="entrada" onclick="Router.navigate('entrada')">
      <span class="icon">📥</span>Entrada
    </button>
    <button class="nav-item" data-page="deadline" onclick="Router.navigate('deadline')">
      <span class="icon">📅</span>Deadline
    </button>
    <button class="nav-item" data-page="historico" onclick="Router.navigate('historico')">
      <span class="icon">📋</span>Histórico
    </button>`;
  if (isAdmin) {
    navHtml += `
    <button class="nav-item" data-page="usuarios" onclick="Router.navigate('usuarios')">
      <span class="icon">👥</span>Usuários
    </button>`;
  }
  nav.innerHTML = navHtml;
}

function showLoading(msg) {
  document.getElementById('loading-text').textContent = msg || 'Carregando dados...';
  document.getElementById('loading-overlay').classList.remove('hidden');
}

function hideLoading() {
  document.getElementById('loading-overlay').classList.add('hidden');
}

async function enterApp() {
  document.getElementById('page-login').classList.add('hidden');
  document.getElementById('app-shell').classList.remove('hidden');
  showLoading('Carregando dados...');
  setupNav();
  await Store.init();
  hideLoading();
  Router.navigate('dashboard', true);
}

function logout() {
  Auth.logout();
  Store.destroy();
  document.getElementById('app-shell').classList.add('hidden');
  document.getElementById('page-login').classList.remove('hidden');
  renderLogin();
}

document.addEventListener('DOMContentLoaded', () => {
  renderLogin();

  Router.register('dashboard', renderDashboard);
  Router.register('entrada', renderEntrada);
  Router.register('deadline', renderDeadline);
  Router.register('historico', renderHistorico);
  Router.register('mapa', renderMapa);
  Router.register('ia', renderIA);
  Router.register('usuarios', renderUsuarios);

  Store.on('containers', () => {
    if (Router.currentPage === 'dashboard') renderDashboard();
    if (Router.currentPage === 'deadline') renderDeadline();
    if (Router.currentPage === 'mapa') renderMapa();
    if (Router.currentPage === 'ia') renderIA();
  });
  Store.on('movimentos', () => {
    if (Router.currentPage === 'historico') renderHistorico();
  });
  Store.on('usuarios', () => {
    if (Router.currentPage === 'usuarios') renderUsuarios();
  });
});
