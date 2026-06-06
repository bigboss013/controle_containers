const Store = {
  containers: [],
  movimentos: [],
  clientes: [],
  usuarios: [],
  listeners: [],

  init() {
    this._listenContainers();
    this._listenMovimentos();
    this._listenClientes();
    if (Auth.isAdmin()) this._listenUsuarios();
  },

  destroy() {
    this.listeners.forEach(u => u());
    this.listeners = [];
  },

  _listenContainers() {
    const unsub = db.collection('containers').onSnapshot(snap => {
      this.containers = snap.docs.map(d => ({
        id: d.id, ...d.data(),
        entrada: d.data().entrada?.toDate?.() || new Date(d.data().entrada),
        saida: d.data().saida?.toDate?.() || (d.data().saida ? new Date(d.data().saida) : null),
        deadline: d.data().deadline?.toDate?.() || (d.data().deadline ? new Date(d.data().deadline) : null),
        agendamento: d.data().agendamento?.toDate?.() || (d.data().agendamento ? new Date(d.data().agendamento) : null),
      }));
      this._notify('containers');
    });
    this.listeners.push(unsub);
  },

  _listenMovimentos() {
    const unsub = db.collection('movimentos').orderBy('data', 'desc').onSnapshot(snap => {
      this.movimentos = snap.docs.map(d => ({
        id: d.id, ...d.data(),
        data: d.data().data?.toDate?.() || new Date(d.data().data),
      }));
      this._notify('movimentos');
    });
    this.listeners.push(unsub);
  },

  _listenClientes() {
    const unsub = db.collection('clientes').onSnapshot(snap => {
      this.clientes = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      this._notify('clientes');
    });
    this.listeners.push(unsub);
  },

  _listenUsuarios() {
    const unsub = db.collection('usuarios').onSnapshot(snap => {
      this.usuarios = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      this._notify('usuarios');
    });
    this.listeners.push(unsub);
  },

  _listeners: {},
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
  },

  async deleteContainer(codigo) {
    await db.collection('containers').doc(codigo).delete();
  },

  async addMovement(m) {
    const data = { ...m };
    data.data = data.data?.toISOString?.() || data.data;
    await db.collection('movimentos').add(data);
  },

  async deleteMovement(id) {
    await db.collection('movimentos').doc(id).delete();
  },

  async clearHistory() {
    const snap = await db.collection('movimentos').get();
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
  },

  async saveCliente(c) {
    await db.collection('clientes').doc(c.codigo).set({ nome: c.nome, codigo: c.codigo });
  },

  async deleteCliente(codigo) {
    await db.collection('clientes').doc(codigo).delete();
  },

  async saveUser(u) {
    await db.collection('usuarios').doc(u.nome).set({ nome: u.nome, senha: u.senha, perfil: u.perfil });
  },

  async deleteUser(nome) {
    await db.collection('usuarios').doc(nome).delete();
  },

  async clearAll() {
    const cols = ['containers', 'movimentos'];
    for (const col of cols) {
      const snap = await db.collection(col).get();
      const batch = db.batch();
      snap.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
  }
};
