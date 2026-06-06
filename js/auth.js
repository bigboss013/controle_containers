const Auth = {
  currentUser: null,

  async login(nome, senha) {
    try {
      const user = await FirestoreRest.getDoc('usuarios', nome);
      if (user && user.senha === senha) {
        this.currentUser = { nome: user.id, perfil: user.perfil || 'gate' };
        localStorage.setItem('user', JSON.stringify(this.currentUser));
        return this.currentUser;
      }
      return null;
    } catch (e) {
      console.error('Erro login:', e);
      throw new Error('Erro de conexão: ' + e.message);
    }
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
