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
        try { this[col] = this._parseDates(JSON.parse(c), col); } catch {}
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
    for (let attempt = 0; attempt < RETRY_DELAYS.length; attempt++) {
      try {
        const snap = await db.collection(collection).get();
        const data = snap.docs.map(d => ({ id: d.id, ...d.data() }));
        this._saveCache(collection, data);
        this[collection] = this._parseDates(data, collection);
        if (collection === 'movimentos') {
          this[collection].sort((a, b) => (b.data || 0) - (a.data || 0));
        }
        this._notify(collection);
        this._retries[collection] = 0;
        return;
      } catch (sdkErr) {
        console.warn(`${collection} SDK: ${sdkErr.code} ${sdkErr.message}`);
        try {
          const data = await FirestoreRest.getCollection(collection);
          this._saveCache(collection, data);
          this[collection] = this._parseDates(data, collection);
          if (collection === 'movimentos') {
            this[collection].sort((a, b) => (b.data || 0) - (a.data || 0));
          }
          this._notify(collection);
          this._retries[collection] = 0;
          return;
        } catch (restErr) {
          const is429 = restErr.message.includes('429') || restErr.message.includes('Servidor ocupado');
          if (!is429 || attempt >= RETRY_DELAYS.length - 1) {
            console.warn(`${collection}: SDK+falha + REST falhou`);
            this._retries[collection] = (this._retries[collection] || 0) + 1;
            this._notify(collection);
            return;
          }
          await new Promise(r => setTimeout(r, RETRY_DELAYS[attempt] * 1000));
        }
      }
    }
  },

  async saveContainer(c) {
    const id = c.codigo || c.id;
    for (const k of ['entrada','saida','deadline','agendamento']) {
      if (c[k] instanceof Date) c[k] = c[k].toISOString();
    }
    try {
      await db.collection('containers').doc(id).set(c);
    } catch {
      await FirestoreRest.setDoc('containers', id, c);
    }
    await this._fetch('containers');
  },

  async deleteContainer(codigo) {
    try {
      await db.collection('containers').doc(codigo).delete();
    } catch {
      await FirestoreRest.deleteDoc('containers', codigo);
    }
    await this._fetch('containers');
  },

  async addMovement(m) {
    if (m.data instanceof Date) m.data = m.data.toISOString();
    try {
      await db.collection('movimentos').add(m);
    } catch {
      await FirestoreRest.addDoc('movimentos', m);
    }
    await this._fetch('movimentos');
  },

  async deleteMovement(id) {
    try {
      await db.collection('movimentos').doc(id).delete();
    } catch {
      await FirestoreRest.deleteDoc('movimentos', id);
    }
    await this._fetch('movimentos');
  },

  async clearHistory() {
    try {
      const snap = await db.collection('movimentos').get();
      const batch = db.batch();
      snap.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
    } catch {
      const list = await FirestoreRest.getCollection('movimentos');
      for (const m of list) {
        await FirestoreRest.deleteDoc('movimentos', m.id);
      }
    }
    await this._fetch('movimentos');
  },

  async saveCliente(c) {
    try {
      await db.collection('clientes').doc(c.codigo).set({ nome: c.nome, codigo: c.codigo });
    } catch {
      await FirestoreRest.setDoc('clientes', c.codigo, { nome: c.nome, codigo: c.codigo });
    }
    await this._fetch('clientes');
  },

  async deleteCliente(codigo) {
    try {
      await db.collection('clientes').doc(codigo).delete();
    } catch {
      await FirestoreRest.deleteDoc('clientes', codigo);
    }
    await this._fetch('clientes');
  },

  async saveUser(u) {
    try {
      await db.collection('usuarios').doc(u.nome).set({ nome: u.nome, senha: u.senha, perfil: u.perfil });
    } catch {
      await FirestoreRest.setDoc('usuarios', u.nome, { nome: u.nome, senha: u.senha, perfil: u.perfil });
    }
    await this._fetch('usuarios');
  },

  async deleteUser(nome) {
    try {
      await db.collection('usuarios').doc(nome).delete();
    } catch {
      await FirestoreRest.deleteDoc('usuarios', nome);
    }
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
