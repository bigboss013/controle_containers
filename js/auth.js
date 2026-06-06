const Auth = {
  currentUser: null,

  async login(nome, senha) {
    try {
      const doc = await db.collection('usuarios').doc(nome).get();
      if (doc.exists) {
        const d = doc.data();
        if (d.senha === senha) {
          this.currentUser = { nome: doc.id, perfil: d.perfil || 'gate' };
          localStorage.setItem('user', JSON.stringify(this.currentUser));
          return this.currentUser;
        }
      }
      return null;
    } catch (sdkErr) {
      console.warn(`login SDK: ${sdkErr.code} ${sdkErr.message}, trying REST`);
      try {
        const doc = await FirestoreRest.getDoc('usuarios', nome);
        if (doc && doc.senha === senha) {
          this.currentUser = { nome: doc.id || nome, perfil: doc.perfil || 'gate' };
          localStorage.setItem('user', JSON.stringify(this.currentUser));
          return this.currentUser;
        }
        return null;
      } catch {
        return null;
      }
    }
  },

  async resetPassword(nome, novaSenha) {
    try {
      await db.collection('usuarios').doc(nome).update({ senha: novaSenha });
      return true;
    } catch {
      try {
        await FirestoreRest.setDoc('usuarios', nome, { senha: novaSenha });
        return true;
      } catch { return false; }
    }
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
