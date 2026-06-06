const RETRY_DELAYS = [1, 4, 16, 64, 120, 300];

const Store = {
  containers: [],
  movimentos: [],
  clientes: [],
  usuarios: [],
  _listeners: {},
  _polling: null,
  _ready: null,
  _retries: {},

  init() {
    this._loadCache();
    this._ready = this._fetchAll();
    return this._ready;
  },

  get ready() { return this._ready || Promise.resolve(); },

  destroy() {
    if (this._polling) clearInterval(this._polling);
    this._listeners = {};
    this._ready = null;
  },

  _loadCache() {
    for (const col of ['containers','movimentos','clientes','usuarios']) {
      const c = localStorage.getItem('cache_' + col);
      if (c) {
        try { this[col] = this._parseDates(JSON.parse(c), col); }
        catch {}
      }
    }
  },

  _saveCache(col, data) {
    localStorage.setItem('cache_' + col, JSON.stringify(data));
  },

  _parseDates(data, col) {
    if (col === 'containers') {
      return data.map(c => ({
        ...c,
        entrada: c.entrada ? new Date(c.entrada) : new Date(),
        saida: c.saida ? new Date(c.saida) : null,
        deadline: c.deadline ? new Date(c.deadline) : null,
        agendamento: c.agendamento ? new Date(c.agendamento) : null,
      }));
    }
    if (col === 'movimentos') {
      return data.map(m => ({ ...m, data: m.data ? new Date(m.data) : new Date() }));
    }
    return data;
  },

  async _fetchAll() {
    await Promise.all([
      this._fetch('containers'),
      this._fetch('movimentos'),
      this._fetch('clientes'),
      this._fetch('usuarios'),
    ]);
  },

  async _fetch(collection) {
    const col = collection;
    for (let attempt = 0; attempt < RETRY_DELAYS.length; attempt++) {
      try {
        const data = await FirestoreRest.getCollection(col);
        this._saveCache(col, data);
        this[col] = this._parseDates(data, col);
        if (col === 'movimentos') {
          this[col].sort((a, b) => (b.data || 0) - (a.data || 0));
        }
        this._notify(col);
        this._retries[col] = 0;
        return;
      } catch (err) {
        const is429 = err.message.includes('429') || err.message.includes('Servidor ocupado');
        if (!is429 || attempt >= RETRY_DELAYS.length - 1) {
          console.warn(`${col} falhou: ${err.message}`);
          this._retries[col] = (this._retries[col] || 0) + 1;
          this._notify(col);
          return;
        }
        await new Promise(r => setTimeout(r, RETRY_DELAYS[attempt] * 1000));
      }
    }
  },

  async _fetchOne(collection, id) {
    try {
      return await FirestoreRest.getDoc(collection, id);
    } catch {
      const c = localStorage.getItem('cache_' + collection);
      if (c) {
        const data = JSON.parse(c);
        return data.find(d => d.id === id || d.codigo === id) || null;
      }
      return null;
    }
  },

  async saveContainer(c) {
    const id = c.codigo || c.id;
    const data = { ...c, id: undefined };
    for (const k of ['entrada','saida','deadline','agendamento']) {
      if (data[k] instanceof Date) data[k] = data[k].toISOString();
    }
    await FirestoreRest.setDoc('containers', id, data);
    await this._fetch('containers');
  },

  async deleteContainer(codigo) {
    await FirestoreRest.deleteDoc('containers', codigo);
    await this._fetch('containers');
  },

  async addMovement(m) {
    const data = { ...m };
    if (data.data instanceof Date) data.data = data.data.toISOString();
    await FirestoreRest.addDoc('movimentos', data);
    await this._fetch('movimentos');
  },

  async deleteMovement(id) {
    await FirestoreRest.deleteDoc('movimentos', id);
    await this._fetch('movimentos');
  },

  async clearHistory() {
    const list = await FirestoreRest.getCollection('movimentos');
    for (const m of list) {
      await FirestoreRest.deleteDoc('movimentos', m.id);
    }
    await this._fetch('movimentos');
  },

  async saveCliente(c) {
    await FirestoreRest.setDoc('clientes', c.codigo, { nome: c.nome, codigo: c.codigo });
    await this._fetch('clientes');
  },

  async deleteCliente(codigo) {
    await FirestoreRest.deleteDoc('clientes', codigo);
    await this._fetch('clientes');
  },

  async saveUser(u) {
    await FirestoreRest.setDoc('usuarios', u.nome, { nome: u.nome, senha: u.senha, perfil: u.perfil });
    await this._fetch('usuarios');
  },

  async deleteUser(nome) {
    await FirestoreRest.deleteDoc('usuarios', nome);
    await this._fetch('usuarios');
  },

  async retry() {
    this._retries = {};
    this._ready = this._fetchAll();
    await this._ready;
  },

  _notify(type) {
    (this._listeners[type] || []).forEach(fn => fn());
  },

  on(type, fn) {
    if (!this._listeners[type]) this._listeners[type] = [];
    this._listeners[type].push(fn);
  },
};
