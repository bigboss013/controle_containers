const Auth = {
  currentUser: null,

  async login(nome, senha) {
    try {
      const snap = await db.collection('usuarios').get();
      for (const doc of snap.docs) {
        const d = doc.data();
        const docName = d.nome || doc.id;
        const docSenha = d.senha || '';
        if (docName && docName.toLowerCase() === nome.toLowerCase() && docSenha === senha) {
          this.currentUser = { nome: docName, perfil: d.perfil || 'gate' };
          localStorage.setItem('user', JSON.stringify(this.currentUser));
          return this.currentUser;
        }
      }
      return null;
    } catch (e) {
      console.error('Erro login Firestore:', e.code, e.message);
      if (e.code === 'permission-denied') {
        throw new Error('Sem permissão para acessar dados. Verifique as regras do Firestore.');
      }
      throw new Error('Erro de conexão: ' + e.message);
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
