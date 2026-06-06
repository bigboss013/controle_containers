const Auth = {
  currentUser: null,

  async login(nome, senha) {
    try {
      const doc = await FirestoreRest.getDoc('usuarios', nome);
      if (doc && doc.senha === senha) {
        this.currentUser = { nome: doc.id || nome, perfil: doc.perfil || 'gate' };
        localStorage.setItem('user', JSON.stringify(this.currentUser));
        return this.currentUser;
      }
      return null;
    } catch (e) {
      console.warn('Login REST error:', e.message);
      return null;
    }
  },

  async resetPassword(nome, novaSenha) {
    try {
      await FirestoreRest.setDoc('usuarios', nome, { senha: novaSenha });
      return true;
    } catch { return false; }
  },

  logout() {
    this.currentUser = null;
    localStorage.removeItem('user');
  },

  getSavedUser() {
    const s = localStorage.getItem('user');
    if (s) {
      try {
        this.currentUser = JSON.parse(s);
        return this.currentUser;
      } catch {}
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
