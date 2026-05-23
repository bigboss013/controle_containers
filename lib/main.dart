import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ControleContainersApp());
}

class ControleContainersApp extends StatelessWidget {
  const ControleContainersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Controle de Conteiners',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F8),
      ),
      home: const AppShell(),
    );
  }
}

enum UserRole { administrador, conferente, gate }

enum ContainerStatus { armazenado, reserva, embarcado, noShow, saiu }

class AppUser {
  const AppUser({
    required this.nome,
    required this.senha,
    required this.perfil,
  });

  final String nome;
  final String senha;
  final UserRole perfil;

  Map<String, Object?> toJson() {
    return {
      'nome': nome,
      'senha': senha,
      'perfil': perfil.name,
    };
  }

  factory AppUser.fromJson(Map<String, Object?> json) {
    return AppUser(
      nome: json['nome'] as String? ?? '',
      senha: json['senha'] as String? ?? '',
      perfil: roleFromName(json['perfil'] as String?),
    );
  }
}

class Cliente {
  Cliente({required this.codigo, required this.nome});

  String codigo;
  String nome;

  Map<String, Object?> toJson() => {'codigo': codigo, 'nome': nome};

  factory Cliente.fromJson(Map<String, Object?> json) => Cliente(
        codigo: json['codigo'] as String? ?? '',
        nome: json['nome'] as String? ?? '',
      );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _usersStorageKey = 'usuarios_cadastrados';

  AppUser? _usuario;
  final List<AppUser> _usuarios = [];
  bool _carregandoUsuarios = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsers = prefs.getString(_usersStorageKey);
    final loadedUsers = <AppUser>[];

    if (savedUsers != null && savedUsers.isNotEmpty) {
      final decoded = jsonDecode(savedUsers) as List<dynamic>;
      loadedUsers.addAll(
        decoded.map(
          (item) => AppUser.fromJson(Map<String, Object?>.from(item as Map)),
        ),
      );
    }

    if (loadedUsers.isEmpty) {
      loadedUsers.add(
        const AppUser(
          nome: 'admin',
          senha: 'admin123',
          perfil: UserRole.administrador,
        ),
      );
      await _salvarUsuarios(loadedUsers);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _usuarios
        ..clear()
        ..addAll(loadedUsers);
      _carregandoUsuarios = false;
    });
  }

  Future<void> _salvarUsuarios(List<AppUser> usuarios) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(usuarios.map((usuario) => usuario.toJson()).toList());
    await prefs.setString(_usersStorageKey, encoded);
  }

  Future<void> _cadastrarUsuario(AppUser novoUsuario) async {
    setState(() => _usuarios.add(novoUsuario));
    await _salvarUsuarios(_usuarios);
  }

  Future<void> _redefinirSenha(String nome, String novaSenha) async {
    final index = _usuarios.indexWhere(
      (usuario) => usuario.nome.toLowerCase() == nome.toLowerCase(),
    );
    if (index == -1) {
      return;
    }

    final usuario = _usuarios[index];
    setState(() {
      _usuarios[index] = AppUser(
        nome: usuario.nome,
        senha: novaSenha,
        perfil: usuario.perfil,
      );
    });
    await _salvarUsuarios(_usuarios);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = _usuario;

    if (_carregandoUsuarios) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (usuario == null) {
      return LoginPage(
        usuarios: _usuarios,
        onEntrar: (novoUsuario) {
          setState(() => _usuario = novoUsuario);
        },
        onRedefinirSenha: _redefinirSenha,
      );
    }

    return HomePage(
      usuarios: _usuarios,
      usuario: usuario,
      onCadastrarUsuario: _cadastrarUsuario,
      onSair: () => setState(() => _usuario = null),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.usuarios,
    required this.onEntrar,
    required this.onRedefinirSenha,
  });

  final List<AppUser> usuarios;
  final ValueChanged<AppUser> onEntrar;
  final Future<void> Function(String nome, String novaSenha) onRedefinirSenha;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _redefinindoSenha = false;
  bool _ocultarSenha = true;

  @override
  void dispose() {
    _nomeController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _entrar() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final usuario = _buscarUsuario(
      _nomeController.text.trim(),
      _senhaController.text,
    );

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario ou senha invalidos.')),
      );
      return;
    }

    widget.onEntrar(usuario);
  }

  Future<void> _redefinirSenha() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final nome = _nomeController.text.trim();
    final existeUsuario = widget.usuarios.any(
      (usuario) => usuario.nome.toLowerCase() == nome.toLowerCase(),
    );

    if (!existeUsuario) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario nao encontrado.')),
      );
      return;
    }

    await widget.onRedefinirSenha(nome, _senhaController.text);
    setState(() {
      _redefinindoSenha = false;
      _senhaController.clear();
      _confirmarSenhaController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Senha redefinida. Entre novamente.')),
    );
  }

  AppUser? _buscarUsuario(String nome, String senha) {
    for (final usuario in widget.usuarios) {
      if (usuario.nome.toLowerCase() == nome.toLowerCase() &&
          usuario.senha == senha) {
        return usuario;
      }
    }
    return null;
  }

  void _alternarModo() {
    setState(() {
      _redefinindoSenha = !_redefinindoSenha;
      _senhaController.clear();
      _confirmarSenhaController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/santos_transportes_login.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const ColoredBox(color: Color(0x26000000)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xBBFFFFFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE1E5E8)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _redefinindoSenha
                                  ? 'Redefinir senha'
                                  : 'Bem Vindo',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _redefinindoSenha
                                  ? 'Informe usuario e nova senha'
                                  : 'Controle de entradas, saidas e patio',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _nomeController,
                              decoration: const InputDecoration(
                                labelText: 'Usuario',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                return obrigatorio(
                                  value,
                                  'Informe o usuario.',
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _senhaController,
                              obscureText: _ocultarSenha,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _ocultarSenha
                                      ? 'Mostrar senha'
                                      : 'Ocultar senha',
                                  onPressed: () {
                                    setState(
                                      () => _ocultarSenha = !_ocultarSenha,
                                    );
                                  },
                                  icon: Icon(
                                    _ocultarSenha
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final mensagem = obrigatorio(
                                  value,
                                  'Informe a senha.',
                                );
                                if (mensagem != null) {
                                  return mensagem;
                                }
                                if (_redefinindoSenha && value!.length < 4) {
                                  return 'Use pelo menos 4 caracteres.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) {
                                if (!_redefinindoSenha) {
                                  _entrar();
                                }
                              },
                            ),
                            if (_redefinindoSenha) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmarSenhaController,
                                obscureText: _ocultarSenha,
                                decoration: const InputDecoration(
                                  labelText: 'Confirmar senha',
                                  prefixIcon: Icon(Icons.lock_reset_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final mensagem = obrigatorio(
                                    value,
                                    'Confirme a senha.',
                                  );
                                  if (mensagem != null) {
                                    return mensagem;
                                  }
                                  if (value != _senhaController.text) {
                                    return 'As senhas nao conferem.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed:
                                  _redefinindoSenha ? _redefinirSenha : _entrar,
                              icon: Icon(
                                _redefinindoSenha
                                    ? Icons.lock_reset_outlined
                                    : Icons.login,
                              ),
                              label: Text(
                                _redefinindoSenha
                                    ? 'Salvar nova senha'
                                    : 'Entrar',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _alternarModo,
                              child: Text(
                                _redefinindoSenha
                                    ? 'Voltar para login'
                                    : 'Redefinir senha',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({
    super.key,
    required this.usuarios,
    required this.onCadastrar,
  });

  final List<AppUser> usuarios;
  final Future<void> Function(AppUser usuario) onCadastrar;

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  UserRole _perfil = UserRole.conferente;
  bool _ocultarSenha = true;

  @override
  void dispose() {
    _nomeController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await widget.onCadastrar(
      AppUser(
        nome: _nomeController.text.trim(),
        senha: _senhaController.text,
        perfil: _perfil,
      ),
    );

    _nomeController.clear();
    _senhaController.clear();
    _confirmarSenhaController.clear();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuario cadastrado com sucesso.')),
    );
  }

  bool _nomeJaCadastrado(String nome) {
    return widget.usuarios.any(
      (usuario) => usuario.nome.toLowerCase() == nome.toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Cadastrar novo usuario',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final mensagem = obrigatorio(value, 'Informe o usuario.');
                  if (mensagem != null) {
                    return mensagem;
                  }
                  if (_nomeJaCadastrado(value!.trim())) {
                    return 'Este usuario ja foi cadastrado.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _senhaController,
                obscureText: _ocultarSenha,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip:
                        _ocultarSenha ? 'Mostrar senha' : 'Ocultar senha',
                    onPressed: () {
                      setState(() => _ocultarSenha = !_ocultarSenha);
                    },
                    icon: Icon(
                      _ocultarSenha
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final mensagem = obrigatorio(value, 'Informe a senha.');
                  if (mensagem != null) {
                    return mensagem;
                  }
                  if (value!.length < 4) {
                    return 'Use pelo menos 4 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmarSenhaController,
                obscureText: _ocultarSenha,
                decoration: const InputDecoration(
                  labelText: 'Confirmar senha',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final mensagem = obrigatorio(value, 'Confirme a senha.');
                  if (mensagem != null) {
                    return mensagem;
                  }
                  if (value != _senhaController.text) {
                    return 'As senhas nao conferem.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                value: _perfil,
                decoration: const InputDecoration(
                  labelText: 'Perfil',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: UserRole.administrador,
                    child: Text('Administrador'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.conferente,
                    child: Text('Conferente'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.gate,
                    child: Text('Gate'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _perfil = value ?? _perfil);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _cadastrar,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Cadastrar usuario'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Usuarios cadastrados',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...widget.usuarios.map(
          (usuario) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(usuario.nome),
            subtitle: Text(roleLabel(usuario.perfil)),
          ),
        ),
      ],
    );
  }
}

class ContainerItem {
  ContainerItem({
    required this.codigo,
    required this.codigoCliente,
    required this.cliente,
    required this.tipo,
    required this.posicao,
    required this.entrada,
    this.pesoKg,
    this.observacao = '',
    this.fotoAvariaPath,
    this.saida,
    this.status = ContainerStatus.armazenado,
    this.noShowCount = 0,
    this.navio,
    this.agendamento,
    this.terminal,
    this.deadline,
  });

  final String codigo;
  String codigoCliente;
  String cliente;
  String tipo;
  String posicao;
  DateTime entrada;
  double? pesoKg;
  String observacao;
  String? fotoAvariaPath;
  DateTime? saida;
  ContainerStatus status;
  int noShowCount;
  String? navio;
  DateTime? agendamento;
  String? terminal;
  DateTime? deadline;

  Map<String, Object?> toJson() {
    return {
      'codigo': codigo,
      'codigoCliente': codigoCliente,
      'cliente': cliente,
      'tipo': tipo,
      'posicao': posicao,
      'entrada': entrada.toIso8601String(),
      'pesoKg': pesoKg,
      'observacao': observacao,
      'fotoAvariaPath': fotoAvariaPath,
      'saida': saida?.toIso8601String(),
      'status': status.name,
      'noShowCount': noShowCount,
      'navio': navio,
      'agendamento': agendamento?.toIso8601String(),
      'terminal': terminal,
      'deadline': deadline?.toIso8601String(),
    };
  }

  factory ContainerItem.fromJson(Map<String, Object?> json) {
    return ContainerItem(
      codigo: json['codigo'] as String? ?? '',
      codigoCliente: json['codigoCliente'] as String? ?? '',
      cliente: json['cliente'] as String? ?? '',
      tipo: json['tipo'] as String? ?? '',
      posicao: json['posicao'] as String? ?? '',
      entrada: DateTime.tryParse(json['entrada'] as String? ?? '') ??
          DateTime.now(),
      pesoKg: (json['pesoKg'] as num?)?.toDouble(),
      observacao: json['observacao'] as String? ?? '',
      fotoAvariaPath: json['fotoAvariaPath'] as String?,
      saida: json['saida'] != null
          ? DateTime.tryParse(json['saida'] as String)
          : null,
      status: containerStatusFromName(json['status'] as String?),
      noShowCount: json['noShowCount'] as int? ?? 0,
      navio: json['navio'] as String?,
      agendamento: json['agendamento'] != null
          ? DateTime.tryParse(json['agendamento'] as String)
          : null,
      terminal: json['terminal'] as String?,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
    );
  }
}

class MovementItem {
  MovementItem({
    required this.tipo,
    required this.codigo,
    required this.descricao,
    required this.data,
    this.usuario = '',
  });

  final String tipo;
  final String codigo;
  final String descricao;
  final DateTime data;
  final String usuario;

  Map<String, Object?> toJson() {
    return {
      'tipo': tipo,
      'codigo': codigo,
      'descricao': descricao,
      'data': data.toIso8601String(),
      'usuario': usuario,
    };
  }

  factory MovementItem.fromJson(Map<String, Object?> json) {
    return MovementItem(
      tipo: json['tipo'] as String? ?? '',
      codigo: json['codigo'] as String? ?? '',
      descricao: json['descricao'] as String? ?? '',
      data: DateTime.tryParse(json['data'] as String? ?? '') ?? DateTime.now(),
      usuario: json['usuario'] as String? ?? '',
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.usuarios,
    required this.usuario,
    required this.onCadastrarUsuario,
    required this.onSair,
  });

  final List<AppUser> usuarios;
  final AppUser usuario;
  final Future<void> Function(AppUser usuario) onCadastrarUsuario;
  final VoidCallback onSair;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _containersStorageKey = 'containers';
  static const _movementsStorageKey = 'movements';
  static const _clientesStorageKey = 'clientes';

  final List<ContainerItem> _containers = [];
  final List<MovementItem> _movimentos = [];
  final List<Cliente> _clientes = [];
  int _abaAtual = 0;
  bool _deadlineBlink = true;

  Color get _deadlineAlertColor {
    final now = DateTime.now();
    for (final c in _containers) {
      if (c.deadline == null || c.status == ContainerStatus.saiu) continue;
      final diff = c.deadline!.difference(now).inDays;
      if (diff <= 1) return Colors.red;
      if (diff <= 3) return Colors.amber;
    }
    return Colors.grey;
  }

  List<ContainerItem> get _armazenados => _containers
      .where((item) => item.status == ContainerStatus.armazenado)
      .toList();

  List<ContainerItem> get _patio => _containers
      .where((item) => item.status != ContainerStatus.saiu)
      .toList();

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _carregarClientes();
    _iniciarDeadlineBlink();
  }

  void _iniciarDeadlineBlink() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _deadlineBlink = !_deadlineBlink);
      _iniciarDeadlineBlink();
    });
  }

  Future<void> _carregarClientes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_clientesStorageKey);
    if (saved != null && saved.isNotEmpty) {
      final decoded = jsonDecode(saved) as List<dynamic>;
      for (final item in decoded) {
        _clientes.add(
          Cliente.fromJson(Map<String, Object?>.from(item as Map)),
        );
      }
    }
    if (_clientes.isEmpty) {
      _clientes.addAll([
        Cliente(codigo: 'ALFA-001', nome: 'Alfa Logistica'),
        Cliente(codigo: 'PORTO-109', nome: 'Porto Sul'),
      ]);
    }
  }

  Future<void> _salvarClientes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clientesStorageKey,
      jsonEncode(_clientes.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final savedContainers = prefs.getString(_containersStorageKey);
    final savedMovements = prefs.getString(_movementsStorageKey);

    if (savedContainers != null && savedContainers.isNotEmpty) {
      final decoded = jsonDecode(savedContainers) as List<dynamic>;
      for (final item in decoded) {
        _containers.add(
          ContainerItem.fromJson(Map<String, Object?>.from(item as Map)),
        );
      }
    }

    if (savedMovements != null && savedMovements.isNotEmpty) {
      final decoded = jsonDecode(savedMovements) as List<dynamic>;
      for (final item in decoded) {
        _movimentos.add(
          MovementItem.fromJson(Map<String, Object?>.from(item as Map)),
        );
      }
    }

    if (_containers.isEmpty) {
      final usuarioNome = widget.usuario.nome;
      _containers.addAll([
        ContainerItem(
          codigo: 'MSCU1234567',
          codigoCliente: 'ALFA-001',
          cliente: 'Alfa Logistica',
          tipo: '40 HC',
          posicao: 'A-14',
          pesoKg: 24800,
          entrada: DateTime.now().subtract(const Duration(days: 4)),
        ),
        ContainerItem(
          codigo: 'TCLU7654321',
          codigoCliente: 'PORTO-109',
          cliente: 'Porto Sul',
          tipo: '20 DRY',
          posicao: 'B-21',
          pesoKg: 16250,
          entrada: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]);
      for (final item in _containers) {
        _movimentos.insert(
          0,
          MovementItem(
            tipo: 'Entrada',
            codigo: item.codigo,
            descricao: '${item.cliente} em ${positionLabel(item.posicao)}',
            data: item.entrada,
            usuario: usuarioNome,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _salvarDados() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _containersStorageKey,
      jsonEncode(_containers.map((c) => c.toJson()).toList()),
    );
    await prefs.setString(
      _movementsStorageKey,
      jsonEncode(_movimentos.map((m) => m.toJson()).toList()),
    );
  }

  void _registrarEntrada(ContainerItem item) {
    final usuarioNome = widget.usuario.nome;
    setState(() {
      _containers.add(item);
      _movimentos.insert(
        0,
        MovementItem(
          tipo: 'Entrada',
          codigo: item.codigo,
          descricao: '${item.cliente} em ${positionLabel(item.posicao)}',
          data: item.entrada,
          usuario: usuarioNome,
        ),
      );
      _abaAtual = 0;
    });
    _salvarDados();
  }

  void _registrarSaida(ContainerItem item) {
    final usuarioNome = widget.usuario.nome;
    setState(() {
      item.status = ContainerStatus.saiu;
      item.saida = DateTime.now();
      item.posicao = '';
      _movimentos.insert(
        0,
        MovementItem(
          tipo: 'Saida',
          codigo: item.codigo,
          descricao:
              '${item.cliente} saiu do terminal',
          data: item.saida!,
          usuario: usuarioNome,
        ),
      );
    });
    _salvarDados();
  }

  void _alterarPosicao(ContainerItem item, String novaPosicao) {
    final antiga = item.posicao;
    final usuarioNome = widget.usuario.nome;
    setState(() {
      item.posicao = novaPosicao;
      _movimentos.insert(
        0,
        MovementItem(
          tipo: 'Movimentacao',
          codigo: item.codigo,
          descricao: '${positionLabel(antiga)} para $novaPosicao',
          data: DateTime.now(),
          usuario: usuarioNome,
        ),
      );
    });
    _salvarDados();
  }

  void _registrarEmbarque(ContainerItem item, String terminal, String navio, DateTime agendamento) {
    final usuarioNome = widget.usuario.nome;
    setState(() {
      item.terminal = terminal;
      item.navio = navio;
      item.agendamento = agendamento;
      item.status = ContainerStatus.embarcado;
      final pos = item.posicao;
      _movimentos.insert(
        0,
        MovementItem(
          tipo: 'Embarque',
          codigo: item.codigo,
          descricao:
              '${item.cliente} - Terminal $terminal - Navio $navio - ${formatDate(agendamento)} - ${positionLabel(pos)}',
          data: DateTime.now(),
          usuario: usuarioNome,
        ),
      );
    });
    _salvarDados();
  }

  void _registrarReserva(ContainerItem item) {
    final usuarioNome = widget.usuario.nome;
    setState(() {
      item.status = ContainerStatus.reserva;
      _movimentos.insert(
        0,
        MovementItem(
          tipo: 'Reserva',
          codigo: item.codigo,
          descricao: '${item.cliente} reservado em ${positionLabel(item.posicao)}',
          data: DateTime.now(),
          usuario: usuarioNome,
        ),
      );
    });
    _salvarDados();
  }

  void _registrarNoShow(ContainerItem item) {
    final usuarioNome = widget.usuario.nome;
    setState(() {
      item.noShowCount++;
      item.status = ContainerStatus.noShow;
      _movimentos.insert(
        0,
        MovementItem(
          tipo: 'No-show',
          codigo: item.codigo,
          descricao:
              '${item.cliente} retornou ao patio (No-show #${item.noShowCount})',
          data: DateTime.now(),
          usuario: usuarioNome,
        ),
      );
    });
    _salvarDados();
  }

  void _reintegrarNoShow(ContainerItem item) {
    final usuarioNome = widget.usuario.nome;
    setState(() {
      item.status = ContainerStatus.armazenado;
      _movimentos.insert(
        0,
        MovementItem(
          tipo: 'Entrada',
          codigo: item.codigo,
          descricao:
              '${item.cliente} reintegrado ao patio (No-show)',
          data: DateTime.now(),
          usuario: usuarioNome,
        ),
      );
    });
    _salvarDados();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.usuario.perfil == UserRole.administrador;
    final paginas = [
      DashboardPage(
        containers: _containers,
        armazenados: _armazenados,
        patio: _patio,
        total: _containers.length,
        movimentos: _movimentos,
        podeMover: widget.usuario.perfil == UserRole.conferente ||
            widget.usuario.perfil == UserRole.administrador,
        perfil: widget.usuario.perfil,
        onSaida: _registrarSaida,
        onMover: _alterarPosicao,
        onEmbarque: _registrarEmbarque,
        onNoShow: _registrarNoShow,
        onReintegrar: _reintegrarNoShow,
        onReserva: _registrarReserva,
        onAtualizar: () {
          setState(() {});
          _salvarDados();
        },
      ),
      EntradaPage(
        perfil: widget.usuario.perfil,
        clientes: _clientes,
        onSalvar: _registrarEntrada,
        onCadastrarCliente: (Cliente c) {
          setState(() => _clientes.add(c));
          _salvarClientes();
        },
      ),
      DeadlinePage(
        containers: _containers,
        onAtualizar: () {
          setState(() {});
          _salvarDados();
        },
      ),
      HistoricoPage(
        movimentos: _movimentos,
        containers: _containers,
        onRegistrarNoShow: _registrarNoShow,
        onReintegrar: _reintegrarNoShow,
      ),
      if (isAdmin)
        UsuariosPage(
          usuarios: widget.usuarios,
          onCadastrar: widget.onCadastrarUsuario,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Santos Transportes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800)),
            ),
            Text(
              '${widget.usuario.nome} - ${roleLabel(widget.usuario.perfil)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: widget.onSair,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: paginas[_abaAtual]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _abaAtual,
        onDestinationSelected: (index) => setState(() => _abaAtual = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Patio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Entrada',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.warning,
              color: _deadlineBlink ? _deadlineAlertColor : Colors.grey.shade400,
              size: 24,
            ),
            selectedIcon: Icon(
              Icons.warning,
              color: _deadlineAlertColor,
            ),
            label: 'Deadline',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Historico',
          ),
          if (isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(Icons.manage_accounts),
              label: 'Usuarios',
            ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.containers,
    required this.armazenados,
    required this.patio,
    required this.total,
    required this.movimentos,
    required this.podeMover,
    required this.perfil,
    required this.onSaida,
    required this.onMover,
    required this.onEmbarque,
    required this.onNoShow,
    required this.onReintegrar,
    required this.onReserva,
    required this.onAtualizar,
  });

  final List<ContainerItem> containers;
  final List<ContainerItem> armazenados;
  final List<ContainerItem> patio;
  final int total;
  final List<MovementItem> movimentos;
  final bool podeMover;
  final UserRole perfil;
  final ValueChanged<ContainerItem> onSaida;
  final void Function(ContainerItem item, String novaPosicao) onMover;
  final void Function(ContainerItem item, String terminal, String navio, DateTime agendamento) onEmbarque;
  final ValueChanged<ContainerItem> onNoShow;
  final ValueChanged<ContainerItem> onReintegrar;
  final ValueChanged<ContainerItem> onReserva;
  final VoidCallback onAtualizar;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _searchController = TextEditingController();
  final _patioSearchController = TextEditingController();
  String _searchQuery = '';
  String _patioSearchQuery = '';
  String? _selectedSection;

  @override
  void dispose() {
    _searchController.dispose();
    _patioSearchController.dispose();
    super.dispose();
  }

  List<ContainerItem> get _noShowItems => widget.containers
      .where((c) => c.status == ContainerStatus.noShow)
      .toList();

  List<ContainerItem> get _reservaItems => widget.containers
      .where((c) => c.status == ContainerStatus.reserva)
      .toList();

  List<ContainerItem> get _embarqueItems => widget.containers
      .where((c) =>
          c.status == ContainerStatus.embarcado && c.terminal != null)
      .toList();

  Map<String, List<ContainerItem>> get _termaisAgrupados {
    final map = <String, List<ContainerItem>>{};
    for (final c in _embarqueItems) {
      map.putIfAbsent(c.terminal!, () => []);
      map[c.terminal]!.add(c);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final isConferente = widget.perfil == UserRole.conferente;
    final filtered = _searchQuery.isEmpty
        ? widget.patio
        : widget.patio.where((c) {
            final q = _searchQuery.toUpperCase();
            return c.codigo.toUpperCase().contains(q) ||
                c.cliente.toUpperCase().contains(q) ||
                c.posicao.toUpperCase().contains(q);
          }).toList();

    final ContainerItem? searchedItem = _searchQuery.isEmpty
        ? null
        : widget.containers.where((c) {
            final q = _searchQuery.toUpperCase();
            return c.codigo.toUpperCase().contains(q);
          }).toList().firstOrNull;

    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = (screenWidth - 44) / 2;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SummaryTile(
              width: tileWidth,
              titulo: isConferente ? 'Patio' : 'Armazenados',
              valor: widget.patio.length.toString(),
              icon: Icons.warehouse_outlined,
              selected: _selectedSection == 'patio',
              onTap: () => setState(() =>
                  _selectedSection = _selectedSection == 'patio'
                      ? null
                      : 'patio'),
            ),
            SummaryTile(
              width: tileWidth,
              titulo: isConferente ? 'Embarque' : 'Movimentos',
              valor: isConferente
                  ? _embarqueItems.length.toString()
                  : widget.movimentos.length.toString(),
              icon: Icons.swap_horiz,
              selected: _selectedSection == 'embarque',
              onTap: isConferente
                  ? () => setState(() =>
                      _selectedSection = _selectedSection == 'embarque'
                          ? null
                          : 'embarque')
                  : null,
            ),
            if (isConferente)
              SummaryTile(
                width: tileWidth,
                titulo: 'No-show',
                valor: _noShowItems.length.toString(),
                icon: Icons.cancel_outlined,
                selected: _selectedSection == 'noshow',
                onTap: () => setState(() =>
                    _selectedSection = _selectedSection == 'noshow'
                        ? null
                        : 'noshow'),
              ),
            SummaryTile(
              width: tileWidth,
              titulo: isConferente ? 'Reserva' : 'Total cadastrado',
              valor: isConferente
                  ? _reservaItems.length.toString()
                  : widget.total.toString(),
              icon: Icons.dataset_outlined,
              selected: _selectedSection == 'reserva',
              onTap: () => setState(() =>
                  _selectedSection = _selectedSection == 'reserva'
                      ? null
                      : 'reserva'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedSection == null) ...[
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar container por codigo, cliente ou posicao...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          if (searchedItem != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22C55E)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Container ${searchedItem.codigo} localizado em ${positionLabel(searchedItem.posicao)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Conteineres no patio',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (widget.patio.isEmpty)
            const EmptyState(texto: 'Nenhum conteiner no patio.')
          else if (filtered.isEmpty)
            const EmptyState(texto: 'Nenhum resultado para esta busca.')
          else
            ...filtered.map(
              (item) => ContainerCard(
                item: item,
                podeMover: widget.podeMover,
                podeEmbarcar: isConferente && item.status != ContainerStatus.embarcado,
                podeReservar: isConferente && item.status == ContainerStatus.armazenado,
                onSaida: () => widget.onSaida(item),
                onMover: (novaPosicao) =>
                    widget.onMover(item, novaPosicao),
                onEmbarque: () =>
                    _confirmarEmbarque(context, item),
                onReserva: () => widget.onReserva(item),
              ),
            ),
          if (isConferente && _noShowItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'No-show pendentes',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._noShowItems.map(
              (item) => ContainerCard(
                item: item,
                podeMover: false,
                podeEmbarcar: false,
                podeReservar: false,
                onSaida: () {},
                onMover: (_) {},
                onEmbarque: () {},
                noShowActions: true,
                onReintegrar: () => widget.onReintegrar(item),
                onRegistrarNoShow: () => widget.onNoShow(item),
              ),
            ),
          ],
        ] else if (_selectedSection == 'patio') ...[
          _buildPatioSection(),
        ] else if (_selectedSection == 'embarque') ...[
          _buildEmbarqueSection(),
        ] else if (_selectedSection == 'noshow') ...[
          _buildNoShowSection(),
        ] else if (_selectedSection == 'reserva') ...[
          _buildReservaSection(),
        ],
      ],
    );
  }

  Widget _buildPatioSection() {
    final patioFiltered = _patioSearchQuery.isEmpty
        ? widget.patio
        : widget.patio.where((c) {
            final q = _patioSearchQuery.toUpperCase();
            return c.codigo.toUpperCase().contains(q) ||
                c.cliente.toUpperCase().contains(q) ||
                c.posicao.toUpperCase().contains(q);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Todos os containers no patio',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _selectedSection = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Voltar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _patioSearchController,
          decoration: InputDecoration(
            hintText: 'Buscar container no patio...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _patioSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _patioSearchController.clear();
                      setState(() => _patioSearchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (v) => setState(() => _patioSearchQuery = v),
        ),
        const SizedBox(height: 16),
        if (patioFiltered.isEmpty)
          const EmptyState(texto: 'Nenhum container encontrado.')
        else
          ...patioFiltered.map(
            (item) => ContainerCard(
              item: item,
              podeMover: widget.podeMover,
              podeEmbarcar: widget.perfil == UserRole.conferente && item.status != ContainerStatus.embarcado,
              podeReservar: widget.perfil == UserRole.conferente && item.status == ContainerStatus.armazenado,
              onSaida: () => widget.onSaida(item),
              onMover: (novaPosicao) => widget.onMover(item, novaPosicao),
              onEmbarque: () => _confirmarEmbarque(context, item),
              onReserva: () => widget.onReserva(item),
            ),
          ),
      ],
    );
  }

  void _abrirDetalhesContainer(BuildContext context, ContainerItem container) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(container.codigo,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Chip(label: Text(container.tipo)),
            if (container.posicao.isNotEmpty) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.map, size: 18),
                  tooltip: 'Mostrar no mapa 3D',
                  onPressed: () => _abrirDialogMapa(context, container),
                ),
              ),
            ],
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoLine(icon: Icons.business_outlined, texto: container.cliente),
              InfoLine(icon: Icons.badge_outlined,
                  texto: 'Cliente: ${emptyLabel(container.codigoCliente)}'),
              InfoLine(icon: Icons.scale_outlined,
                  texto: 'Peso: ${weightLabel(container.pesoKg)}'),
              InfoLine(icon: Icons.place_outlined,
                  texto: 'Posicao: ${positionLabel(container.posicao)}'),
              if (container.observacao.isNotEmpty)
                InfoLine(icon: Icons.report_problem_outlined,
                    texto: 'Obs: ${container.observacao}'),
              if (container.terminal != null)
                InfoLine(icon: Icons.business, texto: 'Terminal: ${container.terminal}'),
              if (container.navio != null)
                InfoLine(icon: Icons.directions_boat, texto: 'Navio: ${container.navio}'),
              if (container.agendamento != null)
                InfoLine(icon: Icons.schedule,
                    texto: 'Agendamento: ${formatDate(container.agendamento!)}'),
              InfoLine(icon: Icons.login,
                  texto: 'Entrada: ${formatDate(container.entrada)}'),
            ],
          ),
        ),
        actions: [
          if (widget.perfil == UserRole.conferente ||
              widget.perfil == UserRole.administrador)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _editarContainer(context, container);
              },
              child: const Text('Editar',
                  style: TextStyle(color: Colors.orange)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          if (container.posicao.isNotEmpty &&
              container.status != ContainerStatus.saiu)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmarSaida(context, container);
              },
              child: const Text('Saida',
                  style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmarSaida(
      BuildContext context, ContainerItem container) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar saida'),
        content: Text(
            'Registrar saida do container ${container.codigo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      widget.onSaida(container);
    }
  }

  void _editarContainer(BuildContext context, ContainerItem container) {
    final terminalCtrl = TextEditingController(text: container.terminal ?? '');
    final navioCtrl = TextEditingController(text: container.navio ?? '');
    DateTime? deadline = container.deadline;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Editar ${container.codigo}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: terminalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Terminal destino',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: navioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Navio',
                    prefixIcon: Icon(Icons.directions_boat),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: deadline ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: deadline != null
                          ? TimeOfDay.fromDateTime(deadline!)
                          : const TimeOfDay(hour: 18, minute: 0),
                    );
                    if (time == null) return;
                    setDialogState(() {
                      deadline = DateTime(
                        date.year, date.month, date.day, time.hour, time.minute,
                      );
                    });
                  },
                  icon: Icon(
                    deadline != null ? Icons.event_busy : Icons.event_outlined,
                    color: deadline != null ? Colors.red : null,
                  ),
                  label: Text(
                    deadline != null
                        ? 'Deadline: ${formatDate(deadline!)}'
                        : 'Definir Deadline',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                container.terminal = terminalCtrl.text.trim().isEmpty
                    ? null
                    : terminalCtrl.text.trim();
                container.navio = navioCtrl.text.trim().isEmpty
                    ? null
                    : navioCtrl.text.trim();
                container.deadline = deadline;
                widget.onAtualizar();
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDialogMapa(BuildContext context, ContainerItem container) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        title: Row(
          children: [
            Expanded(
              child: Text('Mapa 3D - ${container.codigo}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        content: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: YardMap3D(
            containers: widget.containers
                .where((c) =>
                    c.posicao.isNotEmpty &&
                    c.status != ContainerStatus.saiu &&
                    c.posicao.split('-').isNotEmpty &&
                    c.posicao.split('-')[0] ==
                        container.posicao.split('-')[0])
                .toList(),
            highlightCodigo: container.codigo,
            onContainerTap: (c) {
              Navigator.pop(ctx);
              _abrirDetalhesContainer(context, c);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmbarqueSection() {
    final terminais = _termaisAgrupados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Embarques por terminal',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _selectedSection = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Voltar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (terminais.isEmpty)
          const EmptyState(texto: 'Nenhum embarque agendado.')
        else
          ...terminais.entries.map((entry) {
            final containers = entry.value;
            containers.sort((a, b) =>
                (a.agendamento ?? DateTime.now())
                    .compareTo(b.agendamento ?? DateTime.now()));
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFE1E5E8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.business,
                              color: Color(0xFF0F766E)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(entry.key,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${containers.length} container${containers.length > 1 ? 'es' : ''}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...containers.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: InkWell(
                              onTap: () =>
                                  _abrirDetalhesContainer(context, c),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2, horizontal: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Text(c.codigo,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w600))),
                                    Text(
                                      'Navio: ${c.navio ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      c.agendamento != null
                                          ? formatDate(c.agendamento!)
                                          : '',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildNoShowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'No-show pendentes',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _selectedSection = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Voltar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_noShowItems.isEmpty)
          const EmptyState(texto: 'Nenhum no-show pendente.')
        else
          ..._noShowItems.map(
            (item) => ContainerCard(
              item: item,
              podeMover: false,
              podeEmbarcar: false,
              podeReservar: false,
              onSaida: () {},
              onMover: (_) {},
              onEmbarque: () {},
              noShowActions: true,
              onReintegrar: () => widget.onReintegrar(item),
              onRegistrarNoShow: () => widget.onNoShow(item),
            ),
          ),
      ],
    );
  }

  Widget _buildReservaSection() {
    final items = _reservaItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Reserva',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _selectedSection = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Voltar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const EmptyState(texto: 'Nenhum container reservado.')
        else
          ...items.map(
            (item) => ContainerCard(
              item: item,
              podeMover: widget.podeMover,
              podeEmbarcar: true,
              podeReservar: false,
              onSaida: () => widget.onSaida(item),
              onMover: (novaPosicao) => widget.onMover(item, novaPosicao),
              onEmbarque: () => _confirmarEmbarque(context, item),
              onReserva: null,
            ),
          ),
      ],
    );
  }

  void _confirmarEmbarque(BuildContext context, ContainerItem item) {
    final terminalCtrl = TextEditingController();
    final navioCtrl = TextEditingController();
    DateTime dataAgendamento = DateTime.now().add(const Duration(days: 1));
    TimeOfDay horaAgendamento = const TimeOfDay(hour: 8, minute: 0);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Agendar embarque'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Container: ${item.codigo}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (item.status == ContainerStatus.reserva)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Reservado',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: terminalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Terminal de embarque',
                    hintText: 'Ex: Terminal XXX',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: navioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome do navio',
                    hintText: 'Ex: MSC ALESSIA',
                    prefixIcon: Icon(Icons.directions_boat),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: dataAgendamento,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => dataAgendamento = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data do agendamento',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                        '${dataAgendamento.day.toString().padLeft(2, '0')}/'
                        '${dataAgendamento.month.toString().padLeft(2, '0')}/'
                        '${dataAgendamento.year}'),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: horaAgendamento,
                    );
                    if (time != null) {
                      setDialogState(() => horaAgendamento = time);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Horario do agendamento',
                      prefixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(horaAgendamento.format(context)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final navio = navioCtrl.text.trim();
                if (navio.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe o nome do navio.')),
                  );
                  return;
                }
                final agendamento = DateTime(
                  dataAgendamento.year,
                  dataAgendamento.month,
                  dataAgendamento.day,
                  horaAgendamento.hour,
                  horaAgendamento.minute,
                );
                widget.onEmbarque(item, terminalCtrl.text.trim(), navio, agendamento);
                Navigator.pop(ctx);
              },
              child: const Text('Confirmar embarque'),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icon,
    this.onTap,
    this.selected = false,
    this.width,
  });

  final String titulo;
  final String valor;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width ?? 168,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colorScheme.primary : const Color(0xFFE1E5E8),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.secondary),
                const SizedBox(height: 12),
                Text(valor,
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(titulo,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContainerCard extends StatelessWidget {
  const ContainerCard({
    super.key,
    required this.item,
    required this.podeMover,
    required this.onSaida,
    required this.onMover,
    this.podeEmbarcar = false,
    this.onEmbarque,
    this.podeReservar = false,
    this.onReserva,
    this.noShowActions = false,
    this.onReintegrar,
    this.onRegistrarNoShow,
  });

  final ContainerItem item;
  final bool podeMover;
  final VoidCallback onSaida;
  final ValueChanged<String> onMover;
  final bool podeEmbarcar;
  final VoidCallback? onEmbarque;
  final bool podeReservar;
  final VoidCallback? onReserva;
  final bool noShowActions;
  final VoidCallback? onReintegrar;
  final VoidCallback? onRegistrarNoShow;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: noShowActions
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE1E5E8),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (noShowActions) return;
          _abrirDetalhesDialog(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.codigo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      noShowActions
                          ? 'No-show #${item.noShowCount}'
                          : item.tipo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InfoLine(icon: Icons.business_outlined, texto: item.cliente),
              InfoLine(
                icon: Icons.badge_outlined,
                texto: 'Codigo cliente ${emptyLabel(item.codigoCliente)}',
              ),
              InfoLine(
                icon: Icons.scale_outlined,
                texto: 'Peso ${weightLabel(item.pesoKg)}',
              ),
              InfoLine(
                icon: Icons.place_outlined,
                texto: 'Posicao ${positionLabel(item.posicao)}',
              ),
              if (item.observacao.trim().isNotEmpty)
                InfoLine(
                  icon: Icons.report_problem_outlined,
                  texto: 'Obs: ${item.observacao}',
                ),
              if (item.fotoAvariaPath != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(item.fotoAvariaPath!),
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              InfoLine(
                icon: Icons.login,
                texto: 'Entrada em ${formatDate(item.entrada)}',
              ),
              if (noShowActions) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReintegrar,
                        icon: const Icon(Icons.restore),
                        label: const Text('Reintegrar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onRegistrarNoShow,
                        icon: const Icon(Icons.report_problem),
                        label: const Text('No-show'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _abrirMoverDialog(BuildContext context) {
    final controller = TextEditingController(text: item.posicao);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Alterar posicao'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nova posicao',
              hintText: 'Ex: A-14 ou A5-34',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final novaPosicao = controller.text.trim().toUpperCase();
                if (novaPosicao.isNotEmpty) {
                  onMover(novaPosicao);
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _abrirDetalhesDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(item.codigo,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Chip(label: Text(item.tipo)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoLine(icon: Icons.business_outlined, texto: item.cliente),
              InfoLine(
                  icon: Icons.badge_outlined,
                  texto: 'Codigo cliente ${emptyLabel(item.codigoCliente)}'),
              InfoLine(
                  icon: Icons.scale_outlined,
                  texto: 'Peso ${weightLabel(item.pesoKg)}'),
              InfoLine(
                  icon: Icons.place_outlined,
                  texto: 'Posicao ${positionLabel(item.posicao)}'),
              if (item.observacao.trim().isNotEmpty)
                InfoLine(
                    icon: Icons.report_problem_outlined,
                    texto: 'Obs: ${item.observacao}'),
              if (item.navio != null)
                InfoLine(
                    icon: Icons.directions_boat,
                    texto: 'Navio: ${item.navio}'),
              if (item.terminal != null)
                InfoLine(
                    icon: Icons.business, texto: 'Terminal: ${item.terminal}'),
              if (item.agendamento != null)
                InfoLine(
                    icon: Icons.schedule,
                    texto: 'Agendamento: ${formatDate(item.agendamento!)}'),
              if (item.status == ContainerStatus.reserva)
                InfoLine(
                    icon: Icons.bookmark,
                    texto: 'Status: Reservado'),
              InfoLine(
                  icon: Icons.login,
                  texto: 'Entrada em ${formatDate(item.entrada)}'),
              if (item.saida != null)
                InfoLine(
                    icon: Icons.logout,
                    texto: 'Saida em ${formatDate(item.saida!)}'),
              if (item.noShowCount > 0)
                InfoLine(
                    icon: Icons.cancel_outlined,
                    texto: 'No-shows: ${item.noShowCount}'),
              if (item.fotoAvariaPath != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(item.fotoAvariaPath!),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (podeMover)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _abrirMoverDialog(context);
                        },
                        icon: const Icon(Icons.open_with, size: 18),
                        label: const Text('Mover', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  if (podeEmbarcar) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onEmbarque?.call();
                        },
                        icon: const Icon(Icons.flight_takeoff, size: 18),
                        label: const Text('Embarque', style: TextStyle(fontSize: 13)),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (podeReservar)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onReserva?.call();
                        },
                        icon:
                            const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: const Text('Reservar', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  if (podeReservar) const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onSaida();
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Saida', style: TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class YardMap3D extends StatelessWidget {
  const YardMap3D({
    super.key,
    required this.containers,
    this.highlightCodigo,
    this.onContainerTap,
  });

  final List<ContainerItem> containers;
  final String? highlightCodigo;
  final void Function(ContainerItem container)? onContainerTap;

  @override
  Widget build(BuildContext context) {
    final yard = containers
        .where((c) =>
            c.status != ContainerStatus.saiu &&
            c.posicao.isNotEmpty)
        .toList();

    if (yard.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build layout: block -> row -> stack height map
    // Each entry: (stack, height) -> container
    final layout = <String, Map<int?, Map<int, Map<int, ContainerItem>>>>{};
    for (final c in yard) {
      final (block, row) = parsePosition(c.posicao);
      final parts = c.posicao.split('-');
      final sh = parts.length >= 2 ? parts[1] : '';
      final stack = sh.isNotEmpty ? int.tryParse(sh[0]) ?? 1 : 1;
      final height = sh.length >= 2 ? int.tryParse(sh[1]) ?? 1 : 1;
      layout.putIfAbsent(block, () => {});
      layout[block]!.putIfAbsent(row, () => {});
      layout[block]![row]!.putIfAbsent(stack, () => {});
      layout[block]![row]![stack]![height] = c;
    }

    final sortedBlocks = layout.keys.toList()..sort();
    final colorScheme = Theme.of(context).colorScheme;
    final screenW = MediaQuery.of(context).size.width;
    final cellW = screenW < 400 ? 60.0 : screenW < 600 ? 70.0 : 80.0;
    final cellH = cellW * 0.5;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedBlocks.map((block) {
                final rows = layout[block]!;
                final sortedRows = rows.keys.toList()
                  ..sort((a, b) {
                    if (a == null && b == null) return 0;
                    if (a == null) return -1;
                    if (b == null) return 1;
                    return a.compareTo(b);
                  });

                // Find max stack and height across all rows in this block
                int maxStack = 0;
                int maxHeight = 0;
                for (final row in sortedRows) {
                  for (final s in rows[row]!.keys) {
                    if (s > maxStack) maxStack = s;
                    for (final h in rows[row]![s]!.keys) {
                      if (h > maxHeight) maxHeight = h;
                    }
                  }
                }
                maxStack = maxStack.clamp(1, 9);
                maxHeight = maxHeight.clamp(1, 9);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Block header
                      Text('Quadra $block',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 6),
                      ...sortedRows.map((row) {
                        final stacks = rows[row]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (row != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text('$row',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black54)),
                                ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Height axis
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: List.generate(
                                        maxHeight,
                                        (i) => SizedBox(
                                          width: 20,
                                          height: cellH,
                                          child: Center(
                                            child: Text('${maxHeight - i}',
                                                style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Stacks from back (left) to front (right)
                                    ...List.generate(maxStack, (si) {
                                      final stackNum = si + 1;
                                      final containersInStack =
                                          stacks[stackNum] ?? {};
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 2),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: List.generate(
                                            maxHeight,
                                            (hi) {
                                              final heightNum = maxHeight - hi;
                                              final c = containersInStack[
                                                  heightNum];
                                              final isEmpty = c == null;
                                              final isHighlighted =
                                                  c?.codigo == highlightCodigo;

                                              return GestureDetector(
                                                onTap: c != null
                                                    ? () => onContainerTap
                                                        ?.call(c)
                                                    : null,
                                                child: Container(
                                                  width: cellW,
                                                  height: cellH,
                                                  margin:
                                                      const EdgeInsets.only(
                                                          bottom: 1),
                                                  decoration: BoxDecoration(
                                                    color: isEmpty
                                                        ? Colors.grey.shade50
                                                        : isHighlighted
                                                            ? const Color(
                                                                0xFF22C55E)
                                                            : Color.lerp(
                                                                colorScheme
                                                                    .primaryContainer,
                                                                colorScheme
                                                                    .primary,
                                                                (heightNum -
                                                                        1) /
                                                                    maxHeight
                                                                        .toDouble(),
                                                              )!,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                    border: Border.all(
                                                      color: isEmpty
                                                          ? Colors.grey.shade200
                                                          : isHighlighted
                                                              ? const Color(
                                                                  0xFF16A34A)
                                                              : colorScheme
                                                                  .primary
                                                                  .withValues(
                                                                      alpha:
                                                                          0.3),
                                                      width:
                                                          isHighlighted ? 2 : 1,
                                                    ),
                                                    boxShadow: isEmpty
                                                        ? null
                                                        : [
                                                            BoxShadow(
                                                              color: Colors.black
                                                                  .withValues(
                                                                      alpha:
                                                                          0.06),
                                                              offset:
                                                                  const Offset(
                                                                      0, 1),
                                                              blurRadius: 2,
                                                            ),
                                                          ],
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '$stackNum$heightNum',
                                                      style: TextStyle(
                                                        fontSize: isEmpty
                                                            ? 9
                                                            : 12,
                                                        fontWeight: isEmpty
                                                            ? null
                                                            : FontWeight
                                                                .w800,
                                                        color: isEmpty
                                                            ? Colors
                                                                .grey.shade300
                                                            : isHighlighted
                                                                ? Colors
                                                                    .white
                                                                : Colors
                                                                    .black87,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              // Stack labels
                              Row(
                                children: [
                                  const SizedBox(width: 20),
                                  ...List.generate(maxStack, (i) {
                                    final sn = i + 1;
                                    return SizedBox(
                                      width: cellW + 2,
                                      child: Text('P$sn',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey)),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class EntradaPage extends StatefulWidget {
  const EntradaPage({
    super.key,
    required this.perfil,
    required this.clientes,
    required this.onSalvar,
    required this.onCadastrarCliente,
  });

  final UserRole perfil;
  final List<Cliente> clientes;
  final ValueChanged<ContainerItem> onSalvar;
  final ValueChanged<Cliente> onCadastrarCliente;

  @override
  State<EntradaPage> createState() => _EntradaPageState();
}

class _EntradaPageState extends State<EntradaPage> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _codigoClienteController = TextEditingController();
  final _clienteController = TextEditingController();
  final _pesoController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _posicaoController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _fotoAvariaPath;
  bool _cheio = true;
  String _tipo = '20 DRY';
  DateTime? _deadline;

  bool get _podeInformarPosicao =>
      widget.perfil == UserRole.conferente ||
      widget.perfil == UserRole.administrador;

  @override
  void dispose() {
    _codigoController.dispose();
    _codigoClienteController.dispose();
    _clienteController.dispose();
    _pesoController.dispose();
    _observacaoController.dispose();
    _posicaoController.dispose();
    super.dispose();
  }

  void _selecionarCliente() {
    final searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final q = searchCtrl.text.toUpperCase();
            final clientes = q.isEmpty
                ? widget.clientes
                : widget.clientes.where((c) =>
                    c.codigo.toUpperCase().contains(q) ||
                    c.nome.toUpperCase().contains(q)).toList();

            return AlertDialog(
              title: const Text('Selecionar cliente'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Buscar cliente...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    if (clientes.isEmpty)
                      const Text('Nenhum cliente encontrado.')
                    else
                      SizedBox(
                        height: 200,
                        child: ListView(
                          children: clientes.map((c) => ListTile(
                            dense: true,
                            title: Text(c.nome),
                            subtitle: Text(c.codigo),
                            onTap: () {
                              _codigoClienteController.text = c.codigo;
                              _clienteController.text = c.nome;
                              Navigator.pop(ctx);
                            },
                          )).toList(),
                        ),
                      ),
                    const Divider(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cadastrarCliente();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Cadastrar novo cliente'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _cadastrarCliente() {
    final codCtrl = TextEditingController();
    final nomeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cadastrar cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codCtrl,
              decoration: const InputDecoration(
                labelText: 'Codigo do cliente',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do cliente',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (codCtrl.text.trim().isEmpty ||
                  nomeCtrl.text.trim().isEmpty) return;
              widget.onCadastrarCliente(Cliente(
                codigo: codCtrl.text.trim().toUpperCase(),
                nome: nomeCtrl.text.trim(),
              ));
              _codigoClienteController.text =
                  codCtrl.text.trim().toUpperCase();
              _clienteController.text = nomeCtrl.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _tirarFotoAvaria() async {
    final foto = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (foto == null) {
      return;
    }

    setState(() => _fotoAvariaPath = foto.path);
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    widget.onSalvar(
      ContainerItem(
        codigo: _codigoController.text.trim().toUpperCase(),
        codigoCliente: _codigoClienteController.text.trim().toUpperCase(),
        cliente: _clienteController.text.trim(),
        tipo: _tipo,
        posicao: _podeInformarPosicao
            ? _posicaoController.text.trim().toUpperCase()
            : '',
        pesoKg: _cheio ? parseWeight(_pesoController.text) : null,
        observacao: _observacaoController.text.trim(),
        fotoAvariaPath: _fotoAvariaPath,
        entrada: DateTime.now(),
        deadline: _deadline,
      ),
    );

    _codigoController.clear();
    _deadline = null;
    _codigoClienteController.clear();
    _clienteController.clear();
    _pesoController.clear();
    _observacaoController.clear();
    _posicaoController.clear();
    setState(() => _fotoAvariaPath = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada registrada com sucesso.')),
    );
  }

  Future<void> _selecionarDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _deadline != null
            ? TimeOfDay.fromDateTime(_deadline!)
            : const TimeOfDay(hour: 18, minute: 0),
      );
      if (time != null) {
        setState(() {
          _deadline = DateTime(
            date.year, date.month, date.day, time.hour, time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Registrar entrada',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _codigoController,
                decoration: const InputDecoration(
                  labelText: 'Codigo do conteiner',
                  hintText: 'Ex: MSCU1234567',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => obrigatorio(value, 'Informe o codigo.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codigoClienteController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Codigo do cliente',
                  hintText: 'Toque para selecionar',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  border: const OutlineInputBorder(),
                ),
                onTap: _selecionarCliente,
                validator: (value) =>
                    obrigatorio(value, 'Informe o codigo do cliente.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clienteController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(),
                ),
                onTap: _selecionarCliente,
                validator: (value) => obrigatorio(value, 'Informe o cliente.'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Cheio'),
                      selected: _cheio,
                      onSelected: (_) => setState(() => _cheio = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Vazio'),
                      selected: !_cheio,
                      onSelected: (_) => setState(() => _cheio = false),
                    ),
                  ),
                ],
              ),
              if (_cheio) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pesoController,
                  decoration: const InputDecoration(
                    labelText: 'Peso do conteiner',
                    hintText: 'Ex: 24500',
                    suffixText: 'kg',
                    prefixIcon: Icon(Icons.scale_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final mensagem = obrigatorio(value, 'Informe o peso.');
                    if (mensagem != null) {
                      return mensagem;
                    }
                    if (parseWeight(value!) == null) {
                      return 'Informe um peso valido.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.view_in_ar_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '20 DRY', child: Text('20 DRY')),
                  DropdownMenuItem(value: '40 DRY', child: Text('40 DRY')),
                  DropdownMenuItem(value: '40 HC', child: Text('40 HC')),
                  DropdownMenuItem(value: 'Reefer', child: Text('Reefer')),
                ],
                onChanged: (value) => setState(() => _tipo = value ?? _tipo),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _observacaoController,
                decoration: const InputDecoration(
                  labelText: 'Observacao',
                  hintText: 'Descreva avarias, lacre, divergencias...',
                  prefixIcon: Icon(Icons.report_problem_outlined),
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _tirarFotoAvaria,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  _fotoAvariaPath == null
                      ? 'Tirar foto de avaria'
                      : 'Trocar foto de avaria',
                ),
              ),
              if (_fotoAvariaPath != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_fotoAvariaPath!),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              if (_podeInformarPosicao) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _posicaoController,
                  decoration: const InputDecoration(
                    labelText: 'Posicao no patio',
                    hintText: 'Ex: A-14 ou A5-34',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) =>
                      obrigatorio(value, 'Informe a posicao.'),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const PermissionNotice(
                  texto:
                      'Perfil Gate registra a entrada sem posicao. A posicao sera definida pelo Conferente.',
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _selecionarDeadline,
                icon: Icon(
                  _deadline != null ? Icons.event_busy : Icons.event_outlined,
                  color: _deadline != null ? Colors.red : null,
                ),
                label: Text(
                  _deadline != null
                      ? 'Deadline: ${formatDate(_deadline!)}'
                      : 'Definir Deadline (prazo de entrega)',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _salvar,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar entrada'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HistoricoPage extends StatelessWidget {
  const HistoricoPage({
    super.key,
    required this.movimentos,
    required this.containers,
    required this.onRegistrarNoShow,
    this.onReintegrar,
  });

  final List<MovementItem> movimentos;
  final List<ContainerItem> containers;
  final ValueChanged<ContainerItem> onRegistrarNoShow;
  final ValueChanged<ContainerItem>? onReintegrar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Historico',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (movimentos.isEmpty)
          const EmptyState(texto: 'Nenhum movimento registrado.')
        else
          ...movimentos.map(
            (movimento) {
              final container = containers.where((c) => c.codigo == movimento.codigo).firstOrNull;
              final isSaida = movimento.tipo == 'Saida';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  child: Icon(iconForMovement(movimento.tipo), size: 20),
                ),
                title: Text('${movimento.tipo} - ${movimento.codigo}'),
                subtitle: Text(
                  '${movimento.descricao}\n${formatDate(movimento.data)}${movimento.usuario.isNotEmpty ? ' • ${movimento.usuario}' : ''}',
                ),
                isThreeLine: true,
                onTap: () => _abrirAcoesContainer(context, container, movimento, isSaida),
                trailing: isSaida && container != null
                    ? const Icon(Icons.restart_alt, size: 18, color: Colors.orange)
                    : null,
              );
            },
          ),
      ],
    );
  }

  void _abrirAcoesContainer(BuildContext context, ContainerItem? container, MovementItem movimento, bool isSaida) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${movimento.codigo} - ${movimento.tipo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(movimento.descricao, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(formatDate(movimento.data), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (container != null && isSaida) ...[
              const SizedBox(height: 12),
              const Text('Acoes disponiveis:', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          if (isSaida && container != null) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRegistrarNoShow(container);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Container ${container.codigo} registrado como No-show.')),
                );
              },
              child: const Text('Registrar No-show'),
            ),
            if (onReintegrar != null)
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _abrirRetornoPatio(context, container);
                },
                child: const Text('Retorno ao patio'),
              ),
          ],
        ],
      ),
    );
  }

  void _abrirRetornoPatio(BuildContext context, ContainerItem container) {
    final posController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retorno ao patio - ${container.codigo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoLine(icon: Icons.business_outlined, texto: container.cliente),
            const SizedBox(height: 12),
            TextField(
              controller: posController,
              decoration: const InputDecoration(
                labelText: 'Nova posicao no patio',
                hintText: 'Ex: A-14 ou A5-34',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final novaPos = posController.text.trim().toUpperCase();
              if (novaPos.isEmpty) return;
              container.posicao = novaPos;
              onReintegrar!(container);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Container ${container.codigo} retornou ao patio em $novaPos.')),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E8)),
      ),
      child: Text(texto),
    );
  }
}

class PermissionNotice extends StatelessWidget {
  const PermissionNotice({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFACC15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class DeadlinePage extends StatelessWidget {
  const DeadlinePage(
      {super.key, required this.containers, required this.onAtualizar});

  final List<ContainerItem> containers;
  final VoidCallback onAtualizar;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final deadlines = containers
        .where((c) =>
            c.deadline != null &&
            c.status != ContainerStatus.saiu)
        .toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Deadline - Prazo de entrega',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Containeres com prazo limite para entrada no terminal.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        if (deadlines.isEmpty)
          const EmptyState(texto: 'Nenhum container com deadline definido.')
        else
          ...deadlines.map((c) {
            final diff = c.deadline!.difference(now).inDays;
            final color = diff <= 1
                ? Colors.red
                : diff <= 3
                    ? Colors.amber.shade700
                    : Colors.green;
            final label = diff <= 1
                ? 'URGENTE - ${diff}d'
                : diff <= 3
                    ? 'Atencao - ${diff}d'
                    : '${diff}d restantes';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: Icon(Icons.warning, color: color, size: 28),
                title: Text(c.codigo,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${c.cliente} • Deadline: ${formatDate(c.deadline!)}\n$label'),
                isThreeLine: true,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    diff <= 1 ? '⚠' : diff <= 3 ? '⚡' : '✓',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                onTap: () => _mostrarContainer(context, c),
              ),
            );
          }),
      ],
    );
  }

  void _mostrarContainer(BuildContext context, ContainerItem c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.codigo,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoLine(icon: Icons.person, texto: 'Cliente: ${c.cliente}'),
              InfoLine(icon: Icons.location_on, texto: 'Posicao: ${emptyLabel(c.posicao)}'),
              InfoLine(icon: Icons.info, texto: 'Status: ${statusLabel(c.status)}'),
              InfoLine(icon: Icons.access_time, texto: 'Deadline: ${formatDate(c.deadline!)}'),
              if (c.observacao.isNotEmpty)
                InfoLine(icon: Icons.notes, texto: 'Obs: ${c.observacao}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _editarDeadline(context, c);
            },
            child:
                const Text('Editar Deadline', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _editarDeadline(BuildContext context, ContainerItem c) async {
    final data = await showDatePicker(
      context: context,
      initialDate: c.deadline!,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (data == null) return;

    final hora = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(c.deadline!),
    );
    if (hora == null) return;

    c.deadline = DateTime(
      data.year,
      data.month,
      data.day,
      hora.hour,
      hora.minute,
    );
    onAtualizar();
  }
}

String? obrigatorio(String? value, String mensagem) {
  if (value == null || value.trim().isEmpty) {
    return mensagem;
  }
  return null;
}

String positionLabel(String posicao) {
  if (posicao.trim().isEmpty) {
    return 'Aguardando posicao';
  }
  return posicao;
}

String emptyLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Nao informado';
  }
  return value;
}

String weightLabel(double? value) {
  if (value == null) {
    return 'Nao informado';
  }
  final formatted = value % 1 == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$formatted kg';
}

double? parseWeight(String value) {
  final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String roleLabel(UserRole role) {
  return switch (role) {
    UserRole.administrador => 'Administrador',
    UserRole.conferente => 'Conferente',
    UserRole.gate => 'Gate',
  };
}

UserRole roleFromName(String? name) {
  return switch (name) {
    'administrador' => UserRole.administrador,
    'gate' => UserRole.gate,
    _ => UserRole.conferente,
  };
}

String statusLabel(ContainerStatus status) {
  return switch (status) {
    ContainerStatus.armazenado => 'Armazenado',
    ContainerStatus.reserva => 'Reserva',
    ContainerStatus.embarcado => 'Embarcado',
    ContainerStatus.noShow => 'No-show',
    ContainerStatus.saiu => 'Saiu',
  };
}

ContainerStatus containerStatusFromName(String? name) {
  return switch (name) {
    'reserva' => ContainerStatus.reserva,
    'embarcado' => ContainerStatus.embarcado,
    'noShow' => ContainerStatus.noShow,
    'saiu' => ContainerStatus.saiu,
    _ => ContainerStatus.armazenado,
  };
}

/// Parse position format: A-14 (block A, stack 1, height 4)
/// or A5-34 (block A, row 5, stack 3, height 4)
/// Returns (block, row) where row is null if not specified.
(String block, int? row) parsePosition(String pos) {
  final parts = pos.split('-');
  if (parts.length < 2) return (pos, null);
  final blockMatch = RegExp(r'^([A-Z]+)(\d+)?$').firstMatch(parts[0]);
  final block = blockMatch?.group(1) ?? parts[0];
  final row = int.tryParse(blockMatch?.group(2) ?? '');
  return (block, row);
}

IconData iconForMovement(String tipo) {
  return switch (tipo) {
    'Entrada' => Icons.login,
    'Saida' => Icons.logout,
    'Embarque' => Icons.flight_takeoff,
    'No-show' => Icons.cancel_outlined,
    _ => Icons.open_with,
  };
}

String formatDate(DateTime value) {
  final dia = value.day.toString().padLeft(2, '0');
  final mes = value.month.toString().padLeft(2, '0');
  final hora = value.hour.toString().padLeft(2, '0');
  final minuto = value.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${value.year} $hora:$minuto';
}
