let dashboardFilter = 'todos';

function renderDashboard() {
  const el = document.getElementById('page-dashboard');
  const patio = Store.containers.filter(c => c.status !== 'saiu');
  const embarque = Store.containers.filter(c => c.status === 'embarcado');
  const noshow = Store.containers.filter(c => c.status === 'noShow');
  const reserva = Store.containers.filter(c => c.status === 'reserva');
  const comPosicao = patio.filter(c => c.posicao && c.posicao.trim());

  el.innerHTML = `
    <div class="page-title">Dashboard</div>
    <div class="search-bar">
      <input id="search-input" placeholder="Buscar container..." oninput="filterDashboard()">
    </div>
    <div class="stats-grid">
      <div class="stat-card" onclick="dashboardFilter='patio';filterDashboard()">
        <div class="stat-value">${comPosicao.length}</div>
        <div class="stat-label">Pátio</div>
      </div>
      <div class="stat-card" onclick="dashboardFilter='embarque';filterDashboard()">
        <div class="stat-value">${embarque.length}</div>
        <div class="stat-label">Embarque</div>
      </div>
      <div class="stat-card" onclick="dashboardFilter='noshow';filterDashboard()">
        <div class="stat-value">${noshow.length}</div>
        <div class="stat-label">No-show</div>
      </div>
      <div class="stat-card" onclick="dashboardFilter='reserva';filterDashboard()">
        <div class="stat-value">${reserva.length}</div>
        <div class="stat-label">Reserva</div>
      </div>
    </div>
    <div style="display:flex;gap:8px;margin-bottom:16px">
      <button class="btn btn-outline btn-sm" onclick="Router.navigate('mapa')" style="flex:1">🗺️ Mapa do Pátio</button>
    </div>
    <div class="tabs" id="dash-tabs">
      <button class="tab ${dashboardFilter === 'todos' ? 'active' : ''}" onclick="dashboardFilter='todos';filterDashboard()">Todos</button>
      <button class="tab ${dashboardFilter === 'patio' ? 'active' : ''}" onclick="dashboardFilter='patio';filterDashboard()">Pátio</button>
      <button class="tab ${dashboardFilter === 'embarque' ? 'active' : ''}" onclick="dashboardFilter='embarque';filterDashboard()">Embarque</button>
      <button class="tab ${dashboardFilter === 'noshow' ? 'active' : ''}" onclick="dashboardFilter='noshow';filterDashboard()">No-show</button>
      <button class="tab ${dashboardFilter === 'reserva' ? 'active' : ''}" onclick="dashboardFilter='reserva';filterDashboard()">Reserva</button>
    </div>
    <div id="dash-list"></div>`;
  filterDashboard();
}

function filterDashboard() {
  const q = (document.getElementById('search-input')?.value || '').toLowerCase();
  let list = Store.containers;

  if (q) {
    list = list.filter(c =>
      c.codigo?.toLowerCase().includes(q) ||
      c.cliente?.toLowerCase().includes(q) ||
      c.posicao?.toLowerCase().includes(q) ||
      c.codigoCliente?.toLowerCase().includes(q)
    );
  }

  if (dashboardFilter === 'patio') list = list.filter(c => c.status !== 'saiu' && c.status !== 'embarcado' && c.status !== 'noShow' && c.status !== 'reserva');
  else if (dashboardFilter === 'embarque') list = list.filter(c => c.status === 'embarcado');
  else if (dashboardFilter === 'noshow') list = list.filter(c => c.status === 'noShow');
  else if (dashboardFilter === 'reserva') list = list.filter(c => c.status === 'reserva');
  else list = list.filter(c => c.status !== 'saiu');

  list.sort((a, b) => {
    if (a.deadline && b.deadline) return a.deadline - b.deadline;
    if (a.deadline) return -1;
    if (b.deadline) return 1;
    return (b.entrada || 0) - (a.entrada || 0);
  });

  const container = document.getElementById('dash-list');
  if (!container) return;

  if (list.length === 0) {
    const hasCache = localStorage.getItem('cache_containers');
    if (!hasCache) {
      container.innerHTML = '<div class="empty-state"><div class="icon">📡</div>Carregando dados...<br><small>Se persistir, o servidor pode estar temporariamente indisponível.</small><br><button class="btn btn-outline btn-sm retry-btn" onclick="Store.retry();showLoading(\'Tentando novamente...\');setTimeout(()=>{hideLoading();filterDashboard()},3000)">🔄 Tentar novamente</button></div>';
    } else {
      container.innerHTML = '<div class="empty-state"><div class="icon">📦</div>Nenhum container encontrado</div>';
    }
    return;
  }
  container.innerHTML = list.map(c => renderContainerCard(c)).join('');
}
