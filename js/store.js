const Store = {
  containers: [],
  movimentos: [],
  clientes: [],
  usuarios: [],
  _listeners: {},
  _polling: null,

  async init() {
    await Promise.all([
      this.refreshContainers(),
      this.refreshMovimentos(),
      this.refreshClientes(),
    ]);
    if (Auth.isAdmin()) await this.refreshUsuarios();
    this._polling = setInterval(() => this.refreshAll(), 30000);
  },

  destroy() {
    if (this._polling) clearInterval(this._polling);
    this._listeners = {};
  },

  async refreshAll() {
    await Promise.all([
      this.refreshContainers(),
      this.refreshMovimentos(),
      this.refreshClientes(),
    ]);
    if (Auth.isAdmin()) await this.refreshUsuarios();
  },

  async refreshContainers() {
    try {
      this.containers = await FirestoreRest.getCollection('containers');
      this.containers = this.containers.map(c => ({
        ...c,
        entrada: c.entrada instanceof Date ? c.entrada : new Date(c.entrada),
        saida: c.saida ? (c.saida instanceof Date ? c.saida : new Date(c.saida)) : null,
        deadline: c.deadline ? (c.deadline instanceof Date ? c.deadline : new Date(c.deadline)) : null,
        agendamento: c.agendamento ? (c.agendamento instanceof Date ? c.agendamento : new Date(c.agendamento)) : null,
      }));
      this._notify('containers');
    } catch (e) { console.error('Erro containers:', e); }
  },

  async refreshMovimentos() {
    try {
      this.movimentos = await FirestoreRest.getCollection('movimentos');
      this.movimentos = this.movimentos.map(m => ({
        ...m,
        data: m.data instanceof Date ? m.data : new Date(m.data),
      }));
      this.movimentos.sort((a, b) => (b.data || 0) - (a.data || 0));
      this._notify('movimentos');
    } catch (e) { console.error('Erro movimentos:', e); }
  },

  async refreshClientes() {
    try {
      this.clientes = await FirestoreRest.getCollection('clientes');
      this._notify('clientes');
    } catch (e) { console.error('Erro clientes:', e); }
  },

  async refreshUsuarios() {
    try {
      this.usuarios = await FirestoreRest.getCollection('usuarios');
      this._notify('usuarios');
    } catch (e) { console.error('Erro usuarios:', e); }
  },

  _notify(type) {
    (this._listeners[type] || []).forEach(fn => fn());
  },
  on(type, fn) {
    if (!this._listeners[type]) this._listeners[type] = [];
    this._listeners[type].push(fn);
  },

  async saveContainer(c) {
    const data = { ...c };
    delete data.id;
    data.entrada = data.entrada?.toISOString?.() || data.entrada;
    data.saida = data.saida?.toISOString?.() || null;
    data.deadline = data.deadline?.toISOString?.() || null;
    data.agendamento = data.agendamento?.toISOString?.() || null;
    await FirestoreRest.setDoc('containers', c.codigo || c.id, data);
    await this.refreshContainers();
  },

  async deleteContainer(codigo) {
    await FirestoreRest.deleteDoc('containers', codigo);
    await this.refreshContainers();
  },

  async addMovement(m) {
    const data = { ...m };
    data.data = data.data?.toISOString?.() || data.data;
    await FirestoreRest.addDoc('movimentos', data);
    await this.refreshMovimentos();
  },

  async deleteMovement(id) {
    await FirestoreRest.deleteDoc('movimentos', id);
    await this.refreshMovimentos();
  },

  async clearHistory() {
    const movs = await FirestoreRest.getCollection('movimentos');
    for (const m of movs) {
      await FirestoreRest.deleteDoc('movimentos', m.id);
    }
    await this.refreshMovimentos();
  },

  async saveCliente(c) {
    await FirestoreRest.setDoc('clientes', c.codigo, { nome: c.nome, codigo: c.codigo });
    await this.refreshClientes();
  },

  async deleteCliente(codigo) {
    await FirestoreRest.deleteDoc('clientes', codigo);
    await this.refreshClientes();
  },

  async saveUser(u) {
    await FirestoreRest.setDoc('usuarios', u.nome, { nome: u.nome, senha: u.senha, perfil: u.perfil });
    await this.refreshUsuarios();
  },

  async deleteUser(nome) {
    await FirestoreRest.deleteDoc('usuarios', nome);
    await this.refreshUsuarios();
  },

  async clearAll() {
    const containers = await FirestoreRest.getCollection('containers');
    for (const c of containers) await FirestoreRest.deleteDoc('containers', c.id);
    const movs = await FirestoreRest.getCollection('movimentos');
    for (const m of movs) await FirestoreRest.deleteDoc('movimentos', m.id);
    await this.refreshContainers();
    await this.refreshMovimentos();
  },
};
