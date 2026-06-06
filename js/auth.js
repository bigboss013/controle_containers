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
        return null;
      }
      return null;
    } catch (e) {
      console.warn('SDK failed, trying REST:', e.message);
      return this._loginRest(nome, senha);
    }
  },

  async _loginRest(nome, senha) {
    try {
      const url = `https://firestore.googleapis.com/v1/projects/santos-transportes/databases/(default)/documents/usuarios/${nome}?key=AIzaSyCje8V9yQcgJ6LJL1AhyViKq8ArtjARsRA`;
      const resp = await fetch(url);
      if (!resp.ok) return null;
      const doc = await resp.json();
      const fields = doc.fields || {};
      if (fields.senha?.stringValue === senha) {
        this.currentUser = { nome: doc.name.split('/').pop(), perfil: fields.perfil?.stringValue || 'gate' };
        localStorage.setItem('user', JSON.stringify(this.currentUser));
        return this.currentUser;
      }
      return null;
    } catch (e) {
      throw new Error('Servidor ocupado. Aguarde 1-2 minutos.');
    }
  },

  async resetPassword(nome, novaSenha) {
    try {
      await db.collection('usuarios').doc(nome).update({ senha: novaSenha });
      return true;
    } catch (e) { return false; }
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
