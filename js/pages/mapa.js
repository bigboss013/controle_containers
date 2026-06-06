function renderMapa() {
  const el = document.getElementById('page-mapa');
  const patio = Store.containers.filter(c => c.posicao && c.posicao.trim() && c.status !== 'saiu');
  const blocks = {};
  patio.forEach(c => {
    const parsed = Utils.parsePosition(c.posicao);
    const block = parsed.block || 'A';
    if (!blocks[block]) blocks[block] = [];
    blocks[block].push({ ...c, _row: parseInt(parsed.row) || 0 });
  });

  const blockNames = Object.keys(blocks).sort();
  const maxRow = Math.max(30, ...Object.values(blocks).map(arr => Math.max(...arr.map(c => c._row))));

  el.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
      <div class="page-title" style="margin:0">Mapa do Pátio</div>
      <button class="btn btn-outline btn-sm" onclick="Router.navigate('dashboard')">Voltar</button>
    </div>
    <div class="yard-map" id="yard-container"></div>
    <div style="display:flex;gap:12px;flex-wrap:wrap;margin-top:12px;font-size:.75rem">
      <span><span style="display:inline-block;width:12px;height:12px;background:#334155;border-radius:2px;vertical-align:middle"></span> Vazio</span>
      <span><span style="display:inline-block;width:12px;height:12px;background:var(--primary);border-radius:2px;vertical-align:middle"></span> Armazenado</span>
      <span><span style="display:inline-block;width:12px;height:12px;background:var(--warning);border-radius:2px;vertical-align:middle"></span> Reserva</span>
      <span><span style="display:inline-block;width:12px;height:12px;background:var(--success);border-radius:2px;vertical-align:middle"></span> Embarcado</span>
      <span><span style="display:inline-block;width:12px;height:12px;background:var(--danger);border-radius:2px;vertical-align:middle"></span> No-show</span>
    </div>`;

  const container = document.getElementById('yard-container');
  let html = '';

  if (blockNames.length === 0) {
    html = '<div style="color:#94a3b8;text-align:center;padding:40px">Nenhum container no pátio</div>';
  } else {
    blockNames.forEach(block => {
      const maxCols = 6;
      html += `<div class="yard-block">
        <div class="yard-block-label">Quadra ${block}</div>
        <div class="yard-grid" style="grid-template-columns:repeat(${maxCols}, 1fr)">`;

      for (let row = 1; row <= maxRow; row++) {
        const cell = blocks[block]?.find(c => c._row === row);
        if (cell) {
          let cls = 'stored';
          if (cell.status === 'reserva') cls = 'reserva';
          else if (cell.status === 'embarcado') cls = 'embarcado';
          else if (cell.status === 'noShow') cls = 'noshow';
          const label = cell.codigo?.slice(-4) || '';
          html += `<div class="yard-cell ${cls}" onclick="showContainerDetail('${cell.codigo}')" title="${cell.codigo} - ${cell.cliente}">${label}</div>`;
        } else {
          html += `<div class="yard-cell empty" onclick="addAtPosition('${block}-${row}')" title="${block}-${row}">-</div>`;
        }
      }
      html += '</div></div>';
    });
  }
  container.innerHTML = html;
}

function addAtPosition(pos) {
  if (!Auth.canSetPosition()) { Utils.showToast('Sem permissão para definir posição'); return; }
  Utils.showModal(`
    <div class="modal-header">
      <h3>Adicionar em ${pos}</h3>
      <button class="modal-close" onclick="Utils.closeModal()">&times;</button>
    </div>
    <p style="color:var(--text-secondary);margin-bottom:16px;font-size:.9rem">Selecione um container para posicionar:</p>
    <div id="position-container-list"></div>
  `);

  const unpositioned = Store.containers.filter(c => (!c.posicao || !c.posicao.trim()) && c.status !== 'saiu');
  const list = document.getElementById('position-container-list');
  if (unpositioned.length === 0) {
    list.innerHTML = '<div class="empty-state">Nenhum container aguardando posição</div>';
    return;
  }
  list.innerHTML = unpositioned.map(c => `
    <div class="card" style="cursor:pointer" onclick="moveToPosition('${c.codigo}','${pos}')">
      <div class="card-header">
        <span class="card-code">${c.codigo}</span>
        <span class="card-type">${c.tipo}</span>
      </div>
      <div class="card-body">${c.cliente}</div>
    </div>`).join('');
}

async function moveToPosition(codigo, pos) {
  const c = Store.containers.find(x => x.codigo === codigo);
  if (!c) return;
  c.posicao = pos;
  await Store.saveContainer(c);
  await Store.addMovement({
    tipo: 'Movimentacao',
    codigo: c.codigo,
    descricao: `Posicionado em ${pos}`,
    data: new Date().toISOString(),
    usuario: Auth.currentUser?.nome || '',
  });
  Utils.closeModal();
  Utils.showToast('Container posicionado!');
  renderMapa();
}
