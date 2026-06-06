function renderDeadline() {
  const el = document.getElementById('page-deadline');
  const withDeadline = Store.containers
    .filter(c => c.deadline && c.status !== 'saiu')
    .sort((a, b) => a.deadline - b.deadline);

  el.innerHTML = `
    <div class="page-title">Deadlines</div>
    <div class="tabs">
      <button class="tab active" onclick="this.parentElement.querySelectorAll('.tab').forEach(t=>t.classList.remove('active'));this.classList.add('active')">Todos</button>
    </div>
    <div id="deadline-list"></div>`;

  const list = document.getElementById('deadline-list');
  if (withDeadline.length === 0) {
    list.innerHTML = '<div class="empty-state"><div class="icon">📅</div>Nenhum container com deadline</div>';
    return;
  }
  list.innerHTML = withDeadline.map(c => {
    const diff = Math.ceil((c.deadline - new Date()) / (1000 * 60 * 60 * 24));
    let urgency = '';
    if (diff <= 0) urgency = '<span class="badge badge-danger">URGENTE - Prazo expirado!</span>';
    else if (diff <= 1) urgency = '<span class="badge badge-danger">URGENTE - Expira hoje!</span>';
    else if (diff <= 3) urgency = `<span class="badge badge-warning">Atenção - ${diff} dias</span>`;
    else urgency = `<span class="badge badge-success">${diff} dias</span>`;

    return `
      <div class="card ${Utils.deadlineClass(c.deadline)}" onclick="showContainerDetail('${c.codigo}')">
        <div class="card-header">
          <span class="card-code">${c.codigo}</span>
          ${urgency}
        </div>
        <div class="card-body">
          <div class="row"><span class="label">Cliente:</span> ${c.cliente}</div>
          <div class="row"><span class="label">Posição:</span> ${Utils.positionLabel(c.posicao)}</div>
          <div class="row"><span class="label">Deadline:</span> ${Utils.formatDate(c.deadline)}</div>
          ${c.navio ? `<div class="row"><span class="label">Navio:</span> ${c.navio}</div>` : ''}
          ${c.terminal ? `<div class="row"><span class="label">Terminal:</span> ${c.terminal}</div>` : ''}
        </div>
      </div>`;
  }).join('');
}
