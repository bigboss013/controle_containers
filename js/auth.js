const Auth = {
  currentUser: null,

  async login(nome, senha) {
    const cacheKey = 'usuarios_cache';
    let users = [];

    try {
      users = await FirestoreRest.getCollection('usuarios');
      localStorage.setItem(cacheKey, JSON.stringify(users));
    } catch (e) {
      console.warn('Firestore offline, using cache:', e.message);
      const cached = localStorage.getItem(cacheKey);
      if (cached) users = JSON.parse(cached);
      else throw new Error('Sem conexão e sem dados em cache.');
    }

    const user = users.find(u => u.id === nome || (u.nome && u.nome.toLowerCase() === nome.toLowerCase()));
    if (user && user.senha === senha) {
      this.currentUser = { nome: user.id, perfil: user.perfil || 'gate' };
      localStorage.setItem('user', JSON.stringify(this.currentUser));
      return this.currentUser;
    }
    return null;
  },

  async resetPassword(nome, novaSenha) {
    try {
      await FirestoreRest.setDoc('usuarios', nome, { senha: novaSenha });
      return true;
    } catch (e) {
      return false;
    }
  },

  logout() {
    this.currentUser = null;
    localStorage.removeItem('user');
  },

  getSavedUser() {
    const s = localStorage.getItem('user');
    if (s) {
      this.currentUser = JSON.parse(s);
      return this.currentUser;
    }
    return null;
  },

  isAdmin() {
    return this.currentUser && this.currentUser.perfil === 'administrador';
  },

  isConferente() {
    return this.currentUser && this.currentUser.perfil === 'conferente';
  },

  canSetPosition() {
    return this.isAdmin() || this.isConferente();
  }
};
