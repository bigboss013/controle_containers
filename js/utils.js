const Utils = {
  formatDate(d) {
    if (!d) return '-';
    const dt = d instanceof Date ? d : new Date(d);
    if (isNaN(dt)) return '-';
    return dt.toLocaleDateString('pt-BR') + ' ' + dt.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
  },

  formatDateShort(d) {
    if (!d) return '-';
    const dt = d instanceof Date ? d : new Date(d);
    if (isNaN(dt)) return '-';
    return dt.toLocaleDateString('pt-BR');
  },

  positionLabel(p) {
    if (!p || p.trim() === '') return 'Aguardando posição';
    return p;
  },

  weightLabel(w) {
    if (w == null) return '-';
    return Number(w).toLocaleString('pt-BR') + ' kg';
  },

  parseWeight(v) {
    if (!v) return 0;
    return parseFloat(String(v).replace(/\./g, '').replace(',', '.')) || 0;
  },

  normalizarPosicao(p) {
    if (!p) return '';
    p = p.trim().toUpperCase();
    if (p.includes('-')) return p;
    const m = p.match(/^([A-Z]+)(\d+)$/);
    if (!m) return p;
    const letters = m[1], digits = m[2];
    if (digits.length === 2) return `${letters}-${digits}`;
    if (digits.length === 3) return `${letters}${digits[0]}-${digits.substring(1)}`;
    return p;
  },

  parsePosition(p) {
    if (!p) return { block: '', row: '' };
    const m = p.match(/^([A-Z]+\d*)-?(\d+)$/i);
    if (!m) return { block: p, row: '' };
    return { block: m[1], row: m[2] };
  },

  roleLabel(r) {
    const map = { administrador: 'Administrador', conferente: 'Conferente', gate: 'Gate' };
    return map[r] || r;
  },

  statusLabel(s) {
    const map = { armazenado: 'Armazenado', reserva: 'Reserva', embarcado: 'Embarcado', noShow: 'No-show', saiu: 'Saiu' };
    return map[s] || s || 'Armazenado';
  },

  tipoColor(t) {
    const map = { '20': '#0ea5e9', '40': '#8b5cf6', 'Reefer': '#14b8a6', 'Open Top': '#f97316', 'Flat Rack': '#ec4899', 'Tank': '#6366f1' };
    return map[t] || '#0ea5e9';
  },

  deadlineClass(d) {
    if (!d) return '';
    const diff = Math.ceil((d - new Date()) / (1000 * 60 * 60 * 24));
    if (diff <= 0) return 'deadline-red';
    if (diff <= 1) return 'deadline-red';
    if (diff <= 3) return 'deadline-amber';
    return 'deadline-green';
  },

  deadlineBadge(d) {
    if (!d) return null;
    const diff = Math.ceil((d - new Date()) / (1000 * 60 * 60 * 24));
    if (diff <= 0) return { text: 'URGENTE', cls: 'badge-danger' };
    if (diff <= 1) return { text: 'URGENTE', cls: 'badge-danger' };
    if (diff <= 3) return { text: 'Atenção', cls: 'badge-warning' };
    return null;
  },

  showToast(msg) {
    const t = document.createElement('div');
    t.className = 'toast';
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(() => t.remove(), 3000);
  },

  showModal(html) {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay';
    overlay.onclick = e => { if (e.target === overlay) overlay.remove(); };
    overlay.innerHTML = `<div class="modal">${html}</div>`;
    document.body.appendChild(overlay);
    return overlay;
  },

  closeModal() {
    document.querySelectorAll('.modal-overlay').forEach(o => o.remove());
  },

  iconForMovement(tipo) {
    const map = { Entrada: '📥', Saida: '📤', Embarque: '🚢', 'No-show': '⚠️', Movimentacao: '🔄', Reserva: '📋', Cancelamento: '❌' };
    return map[tipo] || '📄';
  }
};
