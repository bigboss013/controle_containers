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
      console.warn('Firestore login failed, trying REST:', e.message);
      return this._loginRest(nome, senha);
    }
  },

  async _loginRest(nome, senha) {
    const url = `https://firestore.googleapis.com/v1/projects/santos-transportes/databases/(default)/documents/usuarios/${nome}`;
    try {
      const resp = await fetch(url);
      if (!resp.ok) return null;
      const doc = await resp.json();
      const fields = doc.fields || {};
      const dbSenha = fields.senha?.stringValue || '';
      const dbPerfil = fields.perfil?.stringValue || 'gate';
      if (dbSenha === senha) {
        this.currentUser = { nome: doc.name.split('/').pop(), perfil: dbPerfil };
        localStorage.setItem('user', JSON.stringify(this.currentUser));
        return this.currentUser;
      }
      return null;
    } catch (e) {
      console.error('REST login also failed:', e);
      throw new Error('Não foi possível conectar ao servidor.');
    }
  },

  async resetPassword(nome, novaSenha) {
    const doc = await db.collection('usuarios').doc(nome).get();
    if (doc.exists) {
      await db.collection('usuarios').doc(nome).update({ senha: novaSenha });
      return true;
    }
    const snap = await db.collection('usuarios').where('nome', '==', nome).get();
    if (!snap.empty) {
      await snap.docs[0].ref.update({ senha: novaSenha });
      return true;
    }
    return false;
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
