function renderContainerCard(c, opts = {}) {
  const badge = Utils.deadlineBadge(c.deadline);
  const deadlineCls = Utils.deadlineClass(c.deadline);
  const isEmpty = !c.pesoKg || c.pesoKg === 0;
  const posLabel = Utils.positionLabel(c.posicao);
  const hasPosition = c.posicao && c.posicao.trim() !== '';

  let statusDot = '';
  if (c.status === 'embarcado') statusDot = '<span style="color:#f59e0b;font-size:1.2rem">●</span>';
  else if (c.status === 'noShow') statusDot = '<span style="color:#dc2626;font-size:1.2rem">●</span>';
  else if (!hasPosition) statusDot = '<span style="color:#a855f7;font-size:1.2rem">●</span>';

  let headerRight = `<span class="card-type" style="background:${Utils.tipoColor(c.tipo)}20;color:${Utils.tipoColor(c.tipo)}">${c.tipo}</span>`;
  if (badge) headerRight += ` <span class="badge ${badge.cls}">${badge.text}</span>`;

  return `
    <div class="card ${deadlineCls}" onclick="showContainerDetail('${c.codigo || c.id}')">
      <div class="card-header">
        <span class="card-code">${statusDot} ${c.codigo}</span>
        <span>${headerRight}</span>
      </div>
      <div class="card-body">
        <div class="row"><span class="label">Cliente:</span> ${c.cliente || '-'} (${c.codigoCliente || '-'})</div>
        <div class="row"><span class="label">Posição:</span> ${posLabel}</div>
        ${!isEmpty ? `<div class="row"><span class="label">Peso:</span> ${Utils.weightLabel(c.pesoKg)}</div>` : '<div class="row"><span class="label">Status:</span> Vazio</div>'}
        ${c.deadline ? `<div class="row"><span class="label">Deadline:</span> ${Utils.formatDateShort(c.deadline)}</div>` : ''}
        ${c.observacao ? `<div class="row"><span class="label">Obs:</span> ${c.observacao}</div>` : ''}
        <div class="row"><span class="label">Entrada:</span> ${Utils.formatDate(c.entrada)}</div>
      </div>
    </div>`;
}

function showContainerDetail(codigo) {
  const c = Store.containers.find(x => (x.codigo || x.id) === codigo);
  if (!c) return;
  const isAdmin = Auth.isAdmin();
  const canEdit = Auth.isAdmin();

  let actions = '';
  if (canEdit) {
    actions += `<button class="btn btn-primary btn-full" onclick="editContainer('${c.codigo || c.id}')" style="margin-bottom:8px">Editar</button>`;
    actions += `<button class="btn btn-danger btn-full" onclick="deleteContainer('${c.codigo || c.id}')">Excluir</button>`;
  }

  Utils.showModal(`
    <div class="modal-header">
      <h3>${c.codigo}</h3>
      <button class="modal-close" onclick="Utils.closeModal()">&times;</button>
    </div>
    <div class="card-body">
      <div class="row" style="margin-bottom:8px"><span class="label">Tipo:</span> ${c.tipo}</div>
      <div class="row" style="margin-bottom:8px"><span class="label">Cliente:</span> ${c.cliente} (${c.codigoCliente})</div>
      <div class="row" style="margin-bottom:8px"><span class="label">Posição:</span> ${Utils.positionLabel(c.posicao)}</div>
      <div class="row" style="margin-bottom:8px"><span class="label">Peso:</span> ${Utils.weightLabel(c.pesoKg)}</div>
      <div class="row" style="margin-bottom:8px"><span class="label">Status:</span> ${Utils.statusLabel(c.status)}</div>
      ${c.deadline ? `<div class="row" style="margin-bottom:8px"><span class="label">Deadline:</span> ${Utils.formatDate(c.deadline)}</div>` : ''}
      ${c.navio ? `<div class="row" style="margin-bottom:8px"><span class="label">Navio:</span> ${c.navio}</div>` : ''}
      ${c.terminal ? `<div class="row" style="margin-bottom:8px"><span class="label">Terminal:</span> ${c.terminal}</div>` : ''}
      ${c.observacao ? `<div class="row" style="margin-bottom:8px"><span class="label">Obs:</span> ${c.observacao}</div>` : ''}
      <div class="row" style="margin-bottom:8px"><span class="label">Entrada:</span> ${Utils.formatDate(c.entrada)}</div>
      ${c.saida ? `<div class="row" style="margin-bottom:8px"><span class="label">Saída:</span> ${Utils.formatDate(c.saida)}</div>` : ''}
    </div>
    ${actions ? '<div style="margin-top:16px">' + actions + '</div>' : ''}
  `);
}

function editContainer(codigo) {
  const c = Store.containers.find(x => (x.codigo || x.id) === codigo);
  if (!c) return;
  Utils.closeModal();
  const clienteOpts = Store.clientes.map(cl =>
    `<option value="${cl.codigo}" ${cl.codigo === c.codigoCliente ? 'selected' : ''}>${cl.nome}</option>`
  ).join('');

  Utils.showModal(`
    <div class="modal-header">
      <h3>Editar ${c.codigo}</h3>
      <button class="modal-close" onclick="Utils.closeModal()">&times;</button>
    </div>
    <form onsubmit="saveEdit(event, '${c.codigo || c.id}')">
      <div class="form-group">
        <label>Cliente</label>
        <select id="edit-cliente" onchange="fillEditCliente()">${clienteOpts}</select>
      </div>
      <div class="form-group">
        <label>Nome do Cliente</label>
        <input id="edit-nome" value="${c.cliente}" readonly>
      </div>
      <div class="form-group">
        <label>Tipo</label>
        <select id="edit-tipo">
          ${['20','40','Reefer','Open Top','Flat Rack','Tank'].map(t => `<option ${t === c.tipo ? 'selected' : ''}>${t}</option>`).join('')}
        </select>
      </div>
      <div class="form-group">
        <label>Posição</label>
        <input id="edit-posicao" value="${c.posicao || ''}">
      </div>
      <div class="form-group">
        <label>Peso (kg)</label>
        <input id="edit-peso" type="number" value="${c.pesoKg || ''}">
      </div>
      <div class="form-group">
        <label>Observação</label>
        <textarea id="edit-obs" rows="2">${c.observacao || ''}</textarea>
      </div>
      <button type="submit" class="btn btn-primary btn-full">Salvar</button>
    </form>
  `);
}

function fillEditCliente() {
  const cod = document.getElementById('edit-cliente').value;
  const cl = Store.clientes.find(x => x.codigo === cod);
  if (cl) document.getElementById('edit-nome').value = cl.nome;
}

async function saveEdit(e, codigo) {
  e.preventDefault();
  const c = Store.containers.find(x => (x.codigo || x.id) === codigo);
  if (!c) return;
  const codCliente = document.getElementById('edit-cliente').value;
  const cl = Store.clientes.find(x => x.codigo === codCliente);
  c.codigoCliente = codCliente;
  c.cliente = cl ? cl.nome : c.cliente;
  c.tipo = document.getElementById('edit-tipo').value;
  c.posicao = Utils.normalizarPosicao(document.getElementById('edit-posicao').value);
  c.pesoKg = parseFloat(document.getElementById('edit-peso').value) || null;
  c.observacao = document.getElementById('edit-obs').value;
  await Store.saveContainer(c);
  Utils.closeModal();
  Utils.showToast('Container atualizado!');
}

async function deleteContainer(codigo) {
  if (!confirm('Excluir este container?')) return;
  await Store.deleteContainer(codigo);
  Utils.closeModal();
  Utils.showToast('Container excluído!');
}
