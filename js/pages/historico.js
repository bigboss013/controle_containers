function renderHistorico() {
  const el = document.getElementById('page-historico');
  const movimentos = Store.movimentos.filter(m => {
    const container = Store.containers.find(c => c.codigo === m.codigo);
    return !container || container.status !== 'armazenado';
  });

  el.innerHTML = `
    <div class="page-title">Histórico</div>
    ${Auth.isAdmin() ? `<div style="margin-bottom:16px">
      <button class="btn btn-danger btn-sm" onclick="clearHistory()">🗑️ Limpar Histórico</button>
    </div>` : ''}
    <div id="history-list"></div>`;

  const list = document.getElementById('history-list');
  if (movimentos.length === 0) {
    list.innerHTML = '<div class="empty-state"><div class="icon">📋</div>Nenhum movimento registrado</div>';
    return;
  }
  list.innerHTML = movimentos.map(m => `
    <div class="card" style="border-left-color: var(--text-secondary)">
      <div class="card-header">
        <span class="card-code" style="font-size:.9rem">${Utils.iconForMovement(m.tipo)} ${m.tipo}</span>
        <span style="font-size:.75rem;color:var(--text-secondary)">${Utils.formatDate(m.data)}</span>
      </div>
      <div class="card-body">
        <div class="row"><span class="label">Container:</span> ${m.codigo}</div>
        <div class="row">${m.descricao}</div>
        <div class="row"><span class="label">Usuário:</span> ${m.usuario || '-'}</div>
      </div>
      ${Auth.isAdmin() ? `<button class="btn btn-outline btn-sm" onclick="deleteMovement('${m.id}')" style="margin-top:8px">Excluir</button>` : ''}
    </div>`).join('');
}

async function deleteMovement(id) {
  if (!confirm('Excluir este movimento?')) return;
  await Store.deleteMovement(id);
  Utils.showToast('Movimento excluído!');
}

async function clearHistory() {
  if (!confirm('Limpar todo o histórico? Esta ação não pode ser desfeita.')) return;
  await Store.clearHistory();
  Utils.showToast('Histórico limpo!');
}
