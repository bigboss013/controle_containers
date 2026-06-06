function renderIA() {
  const el = document.getElementById('page-ia');
  const patio = Store.containers.filter(c => c.status !== 'saiu' && c.posicao && c.posicao.trim());
  const score = calcularScorePatio(patio);
  const sugestoes = gerarSugestoes(patio);

  let scoreCls = 'good';
  if (score < 60) scoreCls = 'ok';
  if (score < 40) scoreCls = 'bad';

  el.innerHTML = `
    <div class="page-title">🤖 Ana - Assistente IA</div>
    <div class="ia-score ${scoreCls}">
      ${score}
      <small>Saúde do Pátio</small>
    </div>
    <div style="text-align:center;margin-bottom:16px;font-size:.85rem;color:var(--text-secondary)">
      ${score >= 80 ? 'Excelente' : score >= 60 ? 'Bom' : score >= 40 ? 'Atenção' : 'Crítico'}
    </div>
    <div class="section-title">💡 Sugestões (${sugestoes.length})</div>
    <div id="ia-suggestions"></div>
    <button class="btn btn-primary btn-full" onclick="renderIA()" style="margin-top:16px">🔄 Reanalisar</button>`;

  const list = document.getElementById('ia-suggestions');
  if (sugestoes.length === 0) {
    list.innerHTML = '<div class="empty-state"><div class="icon">✅</div>Pátio otimizado!</div>';
    return;
  }
  list.innerHTML = sugestoes.map((s, i) => `
    <div class="suggestion-card">
      <div class="title">${s.tipo === 'reposicionamento' ? '🔄' : '📍'} ${s.titulo}</div>
      <div class="desc">${s.descricao}</div>
      ${s.posicaoOrigem && s.posicaoDestino ? `
        <div class="route">
          <span>${s.posicaoOrigem}</span>
          <span class="arrow">→</span>
          <span>${s.posicaoDestino}</span>
        </div>` : ''}
      <button class="btn btn-primary btn-sm" style="margin-top:8px" onclick="applySuggestion(${i})">Aplicar</button>
    </div>`).join('');
}

function calcularPrioridade(c) {
  let p = 0;
  if (c.deadline) {
    const diff = (c.deadline - new Date()) / (1000 * 60 * 60 * 24);
    if (diff <= 0) p += 100;
    else if (diff <= 1) p += 80;
    else if (diff <= 3) p += 50;
    else p += 20;
  }
  if (c.agendamento) p += 40;
  if (c.status === 'embarcado') p += 30;
  if (c.status === 'noShow') p += 60;
  const days = (new Date() - c.entrada) / (1000 * 60 * 60 * 24);
  if (days > 14) p += 20;
  else if (days > 7) p += 10;
  return p;
}

function analisarConflitos(patio) {
  const conflitos = [];
  const byPosition = {};
  patio.forEach(c => {
    const key = c.posicao;
    if (!byPosition[key]) byPosition[key] = [];
    byPosition[key].push(c);
  });
  Object.entries(byPosition).forEach(([pos, containers]) => {
    if (containers.length > 1) {
      const sorted = containers.sort((a, b) => calcularPrioridade(b) - calcularPrioridade(a));
      for (let i = 1; i < sorted.length; i++) {
        if (calcularPrioridade(sorted[0]) > calcularPrioridade(sorted[i]) + 20) {
          conflitos.push({
            container: sorted[i],
            posicao: pos,
            bloqueando: [sorted[0]],
            severidade: calcularPrioridade(sorted[0]) - calcularPrioridade(sorted[i]),
          });
        }
      }
    }
  });
  return conflitos;
}

function gerarSugestoes(patio) {
  const sugestoes = [];
  const conflitos = analisarConflitos(patio);

  conflitos.forEach(c => {
    const novaPos = findEmptyPosition(patio);
    if (novaPos) {
      sugestoes.push({
        tipo: 'reposicionamento',
        titulo: `Reposicionar ${c.container.codigo}`,
        descricao: `${c.container.codigo} (${c.container.cliente}) está bloqueado por ${c.bloqueando.map(b => b.codigo).join(', ')} em ${c.posicao}`,
        container: c.container,
        posicaoOrigem: c.posicao,
        posicaoDestino: novaPos,
        prioridade: c.severidade,
      });
    }
  });

  const unpositioned = Store.containers.filter(c => (!c.posicao || !c.posicao.trim()) && c.status !== 'saiu');
  unpositioned.sort((a, b) => calcularPrioridade(b) - calcularPrioridade(a));
  unpositioned.forEach(c => {
    const pos = findEmptyPosition(patio);
    if (pos) {
      sugestoes.push({
        tipo: 'posicao',
        titulo: `Posicionar ${c.codigo}`,
        descricao: `${c.codigo} (${c.cliente}) aguardando posição. Prioridade: ${calcularPrioridade(c)}`,
        container: c,
        posicaoDestino: pos,
        prioridade: calcularPrioridade(c),
      });
    }
  });

  return sugestoes.sort((a, b) => b.prioridade - a.prioridade);
}

function findEmptyPosition(patio) {
  const occupied = new Set(patio.map(c => c.posicao));
  const blocks = ['A', 'B', 'C', 'D'];
  for (const block of blocks) {
    for (let row = 1; row <= 30; row++) {
      const pos = `${block}-${row}`;
      if (!occupied.has(pos)) return pos;
    }
  }
  return null;
}

function calcularScorePatio(patio) {
  if (patio.length === 0) return 100;
  const conflitos = analisarConflitos(patio);
  const penalidade = conflitos.reduce((sum, c) => sum + c.severidade * 10, 0);
  return Math.max(0, Math.min(100, 100 - penalidade));
}

function applySuggestion(i) {
  const patio = Store.containers.filter(c => c.status !== 'saiu' && c.posicao && c.posicao.trim());
  const sugestoes = gerarSugestoes(patio);
  const s = sugestoes[i];
  if (!s || !s.container) return;

  const c = Store.containers.find(x => x.codigo === s.container.codigo);
  if (!c) return;
  c.posicao = s.posicaoDestino;
  Store.saveContainer(c);
  Store.addMovement({
    tipo: 'Movimentacao',
    codigo: c.codigo,
    descricao: `Reposicionado de ${s.posicaoOrigem || 'N/A'} para ${s.posicaoDestino}`,
    data: new Date().toISOString(),
    usuario: Auth.currentUser?.nome || '',
  });
  Utils.showToast('Sugestão aplicada!');
  renderIA();
}
