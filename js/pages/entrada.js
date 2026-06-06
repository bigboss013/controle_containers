function renderEntrada() {
  const el = document.getElementById('page-entrada');
  const clienteOpts = Store.clientes.map(c => `<option value="${c.codigo}">${c.nome}</option>`).join('');

  el.innerHTML = `
    <div class="page-title">Entrada de Container</div>
    <form onsubmit="salvarEntrada(event)">
      <div class="form-group">
        <label>Código do Container</label>
        <input id="ent-codigo" placeholder="Ex: MSCU1234567" required style="text-transform:uppercase">
      </div>
      <div class="form-group">
        <label>Cliente</label>
        <div style="display:flex;gap:8px">
          <select id="ent-cliente" onchange="fillEntradaCliente()" style="flex:1">
            <option value="">Selecionar...</option>
            ${clienteOpts}
          </select>
          <button type="button" class="btn btn-outline btn-sm" onclick="showNewClientDialog()">+ Novo</button>
        </div>
      </div>
      <div class="form-group">
        <label>Nome do Cliente</label>
        <input id="ent-nome" readonly>
      </div>
      <div class="form-group">
        <label>Status</label>
        <div style="display:flex;gap:8px">
          <button type="button" class="btn btn-sm btn-primary" id="ent-cheio" onclick="toggleEntCheio(true)">Cheio</button>
          <button type="button" class="btn btn-sm btn-outline" id="ent-vazio" onclick="toggleEntCheio(false)">Vazio</button>
        </div>
      </div>
      <div class="form-group" id="ent-peso-group">
        <label>Peso (kg)</label>
        <input id="ent-peso" type="number" placeholder="Ex: 24800">
      </div>
      <div class="form-group">
        <label>Tipo</label>
        <select id="ent-tipo">
          ${['20','40','Reefer','Open Top','Flat Rack','Tank'].map(t => `<option>${t}</option>`).join('')}
        </select>
      </div>
      <div class="form-group">
        <label>Posição ${Auth.canSetPosition() ? '' : '(somente admin/conferente)'}</label>
        <input id="ent-posicao" placeholder="Ex: A-14" ${Auth.canSetPosition() ? '' : 'disabled'}>
      </div>
      <div class="form-group">
        <label>Deadline</label>
        <input id="ent-deadline" type="date" ${Auth.canSetPosition() ? '' : 'disabled'}>
      </div>
      <div class="form-group">
        <label>Observação</label>
        <textarea id="ent-obs" rows="2"></textarea>
      </div>
      <button type="submit" class="btn btn-primary btn-full">Salvar Entrada</button>
    </form>`;

  toggleEntCheio(true);
}

let entCheio = true;
function toggleEntCheio(v) {
  entCheio = v;
  document.getElementById('ent-cheio').className = v ? 'btn btn-sm btn-primary' : 'btn btn-sm btn-outline';
  document.getElementById('ent-vazio').className = v ? 'btn btn-sm btn-outline' : 'btn btn-sm btn-primary';
  document.getElementById('ent-peso-group').style.display = v ? '' : 'none';
}

function fillEntradaCliente() {
  const cod = document.getElementById('ent-cliente').value;
  const cl = Store.clientes.find(c => c.codigo === cod);
  document.getElementById('ent-nome').value = cl ? cl.nome : '';
}

async function salvarEntrada(e) {
  e.preventDefault();
  const codigo = document.getElementById('ent-codigo').value.trim().toUpperCase();
  if (!codigo) { Utils.showToast('Informe o código'); return; }

  const exists = Store.containers.find(c => c.codigo === codigo);
  if (exists) { Utils.showToast('Container já cadastrado!'); return; }

  const codCliente = document.getElementById('ent-cliente').value;
  const cl = Store.clientes.find(c => c.codigo === codCliente);

  const deadlineVal = document.getElementById('ent-deadline').value;

  const c = {
    codigo,
    codigoCliente: codCliente,
    cliente: cl ? cl.nome : '',
    tipo: document.getElementById('ent-tipo').value,
    posicao: Auth.canSetPosition() ? Utils.normalizarPosicao(document.getElementById('ent-posicao').value) : '',
    pesoKg: entCheio ? parseFloat(document.getElementById('ent-peso').value) || null : null,
    observacao: document.getElementById('ent-obs').value,
    entrada: new Date().toISOString(),
    deadline: deadlineVal ? new Date(deadlineVal + 'T23:59:59').toISOString() : null,
    status: 'armazenado',
    noShowCount: 0,
  };

  await Store.saveContainer(c);
  await Store.addMovement({
    tipo: 'Entrada',
    codigo: c.codigo,
    descricao: `${c.cliente} em ${Utils.positionLabel(c.posicao)}`,
    data: new Date().toISOString(),
    usuario: Auth.currentUser?.nome || '',
  });

  Utils.showToast('Container registrado!');
  e.target.reset();
  document.getElementById('ent-nome').value = '';
  toggleEntCheio(true);
  Router.navigate('dashboard');
}

function showNewClientDialog() {
  Utils.showModal(`
    <div class="modal-header">
      <h3>Novo Cliente</h3>
      <button class="modal-close" onclick="Utils.closeModal()">&times;</button>
    </div>
    <form onsubmit="saveNewClient(event)">
      <div class="form-group">
        <label>Código</label>
        <input id="new-client-cod" required placeholder="Ex: ALFA-001" style="text-transform:uppercase">
      </div>
      <div class="form-group">
        <label>Nome</label>
        <input id="new-client-name" required>
      </div>
      <button type="submit" class="btn btn-primary btn-full">Cadastrar</button>
    </form>
  `);
}

async function saveNewClient(e) {
  e.preventDefault();
  const cod = document.getElementById('new-client-cod').value.trim().toUpperCase();
  const name = document.getElementById('new-client-name').value.trim();
  await Store.saveCliente({ codigo: cod, nome: name });
  document.getElementById('ent-cliente').innerHTML =
    `<option value="">Selecionar...</option>` +
    Store.clientes.map(c => `<option value="${c.codigo}">${c.nome}</option>`).join('');
  document.getElementById('ent-cliente').value = cod;
  fillEntradaCliente();
  Utils.closeModal();
  Utils.showToast('Cliente cadastrado!');
}
