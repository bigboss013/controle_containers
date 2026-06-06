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

  async _fetch(collection) {
    try {
      const snap = await db.collection(collection).get();
      const data = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      localStorage.setItem('cache_' + collection, JSON.stringify(data));
      return data;
    } catch (e) {
      console.warn(`${collection} SDK failed, trying REST`);
      try {
        const data = await FirestoreRest.getCollection(collection);
        localStorage.setItem('cache_' + collection, JSON.stringify(data));
        return data;
      } catch (e2) {
        console.warn(`${collection} REST also failed (${e2.message}), using cache`);
        const c = localStorage.getItem('cache_' + collection);
        return c ? JSON.parse(c) : [];
      }
    }
  },

  async refreshContainers() {
    this.containers = await this._fetch('containers');
    this.containers = this.containers.map(c => ({
      ...c,
      entrada: c.entrada?.toDate?.() || (c.entrada ? new Date(c.entrada) : new Date()),
      saida: c.saida?.toDate?.() || (c.saida ? new Date(c.saida) : null),
      deadline: c.deadline?.toDate?.() || (c.deadline ? new Date(c.deadline) : null),
      agendamento: c.agendamento?.toDate?.() || (c.agendamento ? new Date(c.agendamento) : null),
    }));
    this._notify('containers');
  },

  async refreshMovimentos() {
    this.movimentos = await this._fetch('movimentos');
    this.movimentos = this.movimentos.map(m => ({
      ...m,
      data: m.data?.toDate?.() || (m.data ? new Date(m.data) : new Date()),
    }));
    this.movimentos.sort((a, b) => (b.data || 0) - (a.data || 0));
    this._notify('movimentos');
  },

  async refreshClientes() {
    this.clientes = await this._fetch('clientes');
    this._notify('clientes');
  },

  async refreshUsuarios() {
    this.usuarios = await this._fetch('usuarios');
    this._notify('usuarios');
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
    await db.collection('containers').doc(c.codigo || c.id).set(data);
    await this.refreshContainers();
  },

  async deleteContainer(codigo) {
    await db.collection('containers').doc(codigo).delete();
    await this.refreshContainers();
  },

  async addMovement(m) {
    const data = { ...m };
    data.data = data.data?.toISOString?.() || data.data;
    await db.collection('movimentos').add(data);
    await this.refreshMovimentos();
  },

  async deleteMovement(id) {
    await db.collection('movimentos').doc(id).delete();
    await this.refreshMovimentos();
  },

  async clearHistory() {
    const snap = await db.collection('movimentos').get();
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    await this.refreshMovimentos();
  },

  async saveCliente(c) {
    await db.collection('clientes').doc(c.codigo).set({ nome: c.nome, codigo: c.codigo });
    await this.refreshClientes();
  },

  async deleteCliente(codigo) {
    await db.collection('clientes').doc(codigo).delete();
    await this.refreshClientes();
  },

  async saveUser(u) {
    await db.collection('usuarios').doc(u.nome).set({ nome: u.nome, senha: u.senha, perfil: u.perfil });
    await this.refreshUsuarios();
  },

  async deleteUser(nome) {
    await db.collection('usuarios').doc(nome).delete();
    await this.refreshUsuarios();
  },

  async clearAll() {
    const cols = ['containers', 'movimentos'];
    for (const col of cols) {
      const snap = await db.collection(col).get();
      const batch = db.batch();
      snap.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
    await this.refreshContainers();
    await this.refreshMovimentos();
  },
};
