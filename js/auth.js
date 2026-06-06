const Auth = {
  currentUser: null,

  async login(nome, senha) {
    try {
      const docRef = db.collection('usuarios').doc(nome);
      const doc = await docRef.get();
      if (doc.exists) {
        const d = doc.data();
        if (d.senha === senha) {
          this.currentUser = { nome: doc.id, perfil: d.perfil || 'gate' };
          localStorage.setItem('user', JSON.stringify(this.currentUser));
          return this.currentUser;
        }
      }

      const snap = await db.collection('usuarios').get();
      for (const d of snap.docs) {
        const data = d.data();
        const docName = data.nome || d.id;
        if (docName.toLowerCase() === nome.toLowerCase() && (data.senha || '') === senha) {
          this.currentUser = { nome: docName, perfil: data.perfil || 'gate' };
          localStorage.setItem('user', JSON.stringify(this.currentUser));
          return this.currentUser;
        }
      }
      return null;
    } catch (e) {
      console.error('Erro login:', e);
      throw new Error('Erro de conexão: ' + (e.message || e.code));
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
