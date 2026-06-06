function renderUsuarios() {
  if (!Auth.isAdmin()) {
    document.getElementById('page-usuarios').innerHTML = '<div class="empty-state"><div class="icon">🔒</div>Acesso restrito a administradores</div>';
    return;
  }

  const el = document.getElementById('page-usuarios');
  el.innerHTML = `
    <div class="page-title">Gerenciar Usuários</div>
    <form onsubmit="saveUser(event)" style="margin-bottom:24px">
      <div class="form-group">
        <label>Nome</label>
        <input id="user-nome" required style="text-transform:lowercase">
      </div>
      <div class="form-group">
        <label>Senha</label>
        <input id="user-senha" type="password" minlength="4" required>
      </div>
      <div class="form-group">
        <label>Perfil</label>
        <select id="user-perfil">
          <option value="gate">Gate</option>
          <option value="conferente">Conferente</option>
          <option value="administrador">Administrador</option>
        </select>
      </div>
      <button type="submit" class="btn btn-primary btn-full">Cadastrar</button>
    </form>
    <div class="section-title">Usuários Cadastrados</div>
    <div id="users-list"></div>
    <div style="margin-top:24px">
      <button class="btn btn-danger btn-full" onclick="clearAllData()">🗑️ Limpar Todos os Dados</button>
    </div>`;

  renderUsersList();
}

function renderUsersList() {
  const list = document.getElementById('users-list');
  if (!list) return;
  if (Store.usuarios.length === 0) {
    list.innerHTML = '<div class="empty-state">Nenhum usuário cadastrado</div>';
    return;
  }
  list.innerHTML = Store.usuarios.map(u => `
    <div class="card" style="border-left-color: ${u.perfil === 'administrador' ? 'var(--danger)' : u.perfil === 'conferente' ? 'var(--warning)' : 'var(--primary)'}">
      <div class="card-header">
        <span class="card-code">${u.nome}</span>
        <span class="badge ${u.perfil === 'administrador' ? 'badge-danger' : u.perfil === 'conferente' ? 'badge-warning' : 'badge-success'}">${Utils.roleLabel(u.perfil)}</span>
      </div>
      <button class="btn btn-outline btn-sm" onclick="deleteUser('${u.nome}')" style="margin-top:8px">Excluir</button>
    </div>`).join('');
}

async function saveUser(e) {
  e.preventDefault();
  const nome = document.getElementById('user-nome').value.trim().toLowerCase();
  const senha = document.getElementById('user-senha').value;
  const perfil = document.getElementById('user-perfil').value;
  await Store.saveUser({ nome, senha, perfil });
  document.getElementById('user-nome').value = '';
  document.getElementById('user-senha').value = '';
  Utils.showToast('Usuário cadastrado!');
}

async function deleteUser(nome) {
  if (!confirm(`Excluir usuário ${nome}?`)) return;
  await Store.deleteUser(nome);
  Utils.showToast('Usuário excluído!');
}

async function clearAllData() {
  if (!confirm('ATENÇÃO: Isso apagará TODOS os containers e movimentos. Continuar?')) return;
  if (!confirm('Tem ABSOLUTA certeza? Esta ação não pode ser desfeita!')) return;
  await Store.clearAll();
  Utils.showToast('Todos os dados foram apagados!');
}
