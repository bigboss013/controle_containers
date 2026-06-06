import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';

class FirestoreDb {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static Future<void> initDefaultData() async {
    final userSnapshot = await _db.collection('usuarios').limit(1).get();
    if (userSnapshot.docs.isNotEmpty) return;
    await _db.collection('usuarios').doc('admin').set({
      'senha': 'admin123', 'perfil': 'administrador',
    });
    await _db.collection('clientes').doc('ALFA-001').set({
      'codigo': 'ALFA-001', 'nome': 'Alfa Logística',
    });
    await _db.collection('clientes').doc('PORTO-109').set({
      'codigo': 'PORTO-109', 'nome': 'Porto Sul',
    });
  }

  static Future<List<AppUser>> carregarUsuarios() async {
    final snapshot = await _db.collection('usuarios').get();
    return snapshot.docs.map((doc) {
      final d = doc.data();
      return AppUser(
        nome: doc.id,
        senha: d['senha'] as String? ?? '',
        perfil: UserRole.values.firstWhere(
          (r) => r.name == d['perfil'], orElse: () => UserRole.gate,
        ),
      );
    }).toList();
  }

  static Future<void> salvarUsuario(AppUser user) async {
    await _db.collection('usuarios').doc(user.nome).set({
      'senha': user.senha, 'perfil': user.perfil.name,
    });
  }

  static Future<void> removerUsuario(String nome) async {
    await _db.collection('usuarios').doc(nome).delete();
  }

  static Future<List<ContainerItem>> carregarContainers() async {
    final snapshot = await _db.collection('containers').get();
    return snapshot.docs.map((doc) {
      final d = doc.data();
      return ContainerItem(
        codigo: doc.id,
        codigoCliente: d['codigoCliente'] as String? ?? '',
        cliente: d['cliente'] as String? ?? '',
        tipo: d['tipo'] as String? ?? '20',
        posicao: d['posicao'] as String? ?? '',
        entrada: DateTime.tryParse(d['entrada'] as String? ?? '') ?? DateTime.now(),
        saida: d['saida'] != null ? DateTime.tryParse(d['saida'] as String) : null,
        status: ContainerStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => ContainerStatus.armazenado,
        ),
        pesoKg: (d['pesoKg'] as num?)?.toDouble(),
        observacao: d['observacao'] as String? ?? '',
        fotoAvariaPath: d['fotoAvariaPath'] as String?,
        deadline: d['deadline'] != null ? DateTime.tryParse(d['deadline'] as String) : null,
        terminal: d['terminal'] as String?,
        navio: d['navio'] as String?,
        agendamento: d['agendamento'] != null ? DateTime.tryParse(d['agendamento'] as String) : null,
        noShowCount: d['noShowCount'] as int? ?? 0,
      );
    }).toList();
  }

  static Future<void> salvarContainer(ContainerItem c) async {
    await _db.collection('containers').doc(c.codigo).set({
      'codigoCliente': c.codigoCliente, 'cliente': c.cliente,
      'tipo': c.tipo, 'posicao': c.posicao,
      'entrada': c.entrada.toIso8601String(),
      'saida': c.saida?.toIso8601String(),
      'status': c.status.name, 'pesoKg': c.pesoKg,
      'observacao': c.observacao, 'fotoAvariaPath': c.fotoAvariaPath,
      'deadline': c.deadline?.toIso8601String(),
      'terminal': c.terminal, 'navio': c.navio,
      'agendamento': c.agendamento?.toIso8601String(),
      'noShowCount': c.noShowCount,
    });
  }

  static Future<void> removerContainer(String codigo) async {
    await _db.collection('containers').doc(codigo).delete();
  }

  static Future<List<MovementItem>> carregarMovimentos() async {
    final snapshot = await _db.collection('movimentos')
        .orderBy('data', descending: true).get();
    return snapshot.docs.map((doc) {
      final d = doc.data();
      return MovementItem(
        tipo: d['tipo'] as String? ?? '',
        codigo: d['codigo'] as String? ?? '',
        descricao: d['descricao'] as String? ?? '',
        data: DateTime.tryParse(d['data'] as String? ?? '') ?? DateTime.now(),
        usuario: d['usuario'] as String? ?? '',
      );
    }).toList();
  }

  static Future<void> registrarMovimento(MovementItem m) async {
    await _db.collection('movimentos').add({
      'tipo': m.tipo, 'codigo': m.codigo,
      'descricao': m.descricao,
      'data': m.data.toIso8601String(),
      'usuario': m.usuario,
    });
  }

  static Future<List<Cliente>> carregarClientes() async {
    final snapshot = await _db.collection('clientes').get();
    return snapshot.docs.map((doc) {
      final d = doc.data();
      return Cliente(codigo: doc.id, nome: d['nome'] as String? ?? '');
    }).toList();
  }

  static Future<void> salvarCliente(Cliente c) async {
    await _db.collection('clientes').doc(c.codigo).set({'nome': c.nome});
  }

  static Future<void> removerCliente(String codigo) async {
    await _db.collection('clientes').doc(codigo).delete();
  }

  static Future<void> limparTudo() async {
    final containers = await _db.collection('containers').get();
    for (final doc in containers.docs) {
      await doc.reference.delete();
    }
    final movimentos = await _db.collection('movimentos').get();
    for (final doc in movimentos.docs) {
      await doc.reference.delete();
    }
  }

  static Future<void> limparHistorico() async {
    final movimentos = await _db.collection('movimentos').get();
    for (final doc in movimentos.docs) {
      await doc.reference.delete();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirestoreDb.initDefaultData();
  runApp(const ControleContainersApp());
}

class ControleContainersApp extends StatelessWidget {
  const ControleContainersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Controle de Contêineres',
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
  AppUser? _usuario;
  final List<AppUser> _usuarios = [];
  bool _carregandoUsuarios = true;
  String? _usuarioSalvoNome;
  String? _usuarioSalvoSenha;
  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
    _carregarDadosLogin();
  }

  Future<void> _carregarDadosLogin() async {
    final prefs = await SharedPreferences.getInstance();
    _usuarioSalvoNome = prefs.getString('usuario_salvo_nome');
    _usuarioSalvoSenha = prefs.getString('usuario_salvo_senha');
  }

  Future<void> _carregarUsuarios() async {
    final loaded = await FirestoreDb.carregarUsuarios();
    if (loaded.isEmpty) {
      await FirestoreDb.initDefaultData();
      loaded.addAll(await FirestoreDb.carregarUsuarios());
    }
    if (!mounted) return;
    setState(() {
      _usuarios
        ..clear()
        ..addAll(loaded);
      _carregandoUsuarios = false;
    });
  }

  Future<void> _salvarUsuarios(List<AppUser> usuarios) async {
    for (final u in usuarios) {
      await FirestoreDb.salvarUsuario(u);
    }
  }

  Future<void> _cadastrarUsuario(AppUser novoUsuario) async {
    setState(() => _usuarios.add(novoUsuario));
    await _salvarUsuarios(_usuarios);
  }

  Future<void> _excluirUsuario(String nome) async {
    await FirestoreDb.removerUsuario(nome);
    setState(() => _usuarios.removeWhere((u) => u.nome == nome));
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
      return Scaffold(
        body: Center(
          child: Image.asset(
            'assets/images/icone_santos.jpg',
            fit: BoxFit.contain,
            width: 300,
          ),
        ),
      );
    }

    if (usuario == null) {
      return LoginPage(
        usuarios: _usuarios,
        usuarioSalvoNome: _usuarioSalvoNome,
        usuarioSalvoSenha: _usuarioSalvoSenha,
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
      onExcluirUsuario: _excluirUsuario,
      onSair: () => setState(() => _usuario = null),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.usuarios,
    this.usuarioSalvoNome,
    this.usuarioSalvoSenha,
    required this.onEntrar,
    required this.onRedefinirSenha,
  });

  final List<AppUser> usuarios;
  final String? usuarioSalvoNome;
  final String? usuarioSalvoSenha;
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
  final _localAuth = LocalAuthentication();
  bool _redefinindoSenha = false;
  bool _ocultarSenha = true;
  bool _salvarUsuario = false;

  @override
  void initState() {
    super.initState();
    if (widget.usuarioSalvoNome != null) {
      _nomeController.text = widget.usuarioSalvoNome!;
      if (widget.usuarioSalvoSenha != null) {
        _senhaController.text = widget.usuarioSalvoSenha!;
      }
      _salvarUsuario = true;
      _entrarBiometrico();
    }
  }

  Future<void> _entrarBiometrico() async {
    final autenticado = await _localAuth.authenticate(
      localizedReason: 'Use a senha de desbloqueio ou biometria do aparelho',
    );
    if (!autenticado) return;
    final usuario = _buscarUsuario(
      widget.usuarioSalvoNome!,
      widget.usuarioSalvoSenha ?? '',
    );
    if (usuario != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('usar_biometria');
      widget.onEntrar(usuario);
    }
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
        const SnackBar(content: Text('Usuário ou senha inválidos.')),
      );
      return;
    }

    _salvarCredenciais();
    widget.onEntrar(usuario);
  }

  Future<void> _salvarCredenciais() async {
    final prefs = await SharedPreferences.getInstance();
    if (_salvarUsuario) {
      await prefs.setString('usuario_salvo_nome', _nomeController.text.trim());
      await prefs.setString('usuario_salvo_senha', _senhaController.text);
    } else {
      await prefs.remove('usuario_salvo_nome');
      await prefs.remove('usuario_salvo_senha');
    }
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
        const SnackBar(content: Text('Usuário não encontrado.')),
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
                  constraints: const BoxConstraints(maxWidth: 267),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xBBFFFFFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE1E5E8)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
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
                            const SizedBox(height: 13),
                            TextFormField(
                              controller: _nomeController,
                              decoration: const InputDecoration(
                                labelText: 'Usuário',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                return obrigatorio(
                                  value,
                                  'Informe o usuário.',
                                );
                              },
                            ),
                            const SizedBox(height: 8),
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
                            if (!_redefinindoSenha) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: _salvarUsuario,
                                          onChanged: (v) => setState(() {
                                            _salvarUsuario = v ?? false;
                                            if (!_salvarUsuario) {
                                              _nomeController.clear();
                                              _senhaController.clear();
                                              _salvarCredenciais();
                                            }
                                          }),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          _salvarUsuario = !_salvarUsuario;
                                          if (!_salvarUsuario) {
                                            _nomeController.clear();
                                            _senhaController.clear();
                                            _salvarCredenciais();
                                          }
                                        }),
                                        child: const Text('Salvar usuário',
                                            style: TextStyle(fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: _alternarModo,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Redefinir senha',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                            if (_redefinindoSenha) ...[
                              const SizedBox(height: 8),
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
                                    return 'As senhas não conferem.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 13),
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
                            const SizedBox(height: 5),
                            if (_redefinindoSenha)
                              TextButton(
                                onPressed: _alternarModo,
                                child: const Text('Voltar para login'),
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
    required this.onExcluir,
    required this.onLimparDados,
  });

  final List<AppUser> usuarios;
  final Future<void> Function(AppUser usuario) onCadastrar;
  final Future<void> Function(String nome) onExcluir;
  final VoidCallback onLimparDados;

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
      const SnackBar(content: Text('Usuário cadastrado com sucesso.')),
    );
  }

  bool _nomeJaCadastrado(String nome) {
    return widget.usuarios.any(
      (usuario) => usuario.nome.toLowerCase() == nome.toLowerCase(),
    );
  }

  Future<void> _confirmarExclusao(AppUser usuario) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text('Deseja excluir o usuário "${usuario.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    await widget.onExcluir(usuario.nome);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Usuário "${usuario.nome}" excluído.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Cadastrar novo usuário',
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
                  labelText: 'Usuário',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final mensagem = obrigatorio(value, 'Informe o usuário.');
                  if (mensagem != null) {
                    return mensagem;
                  }
                  if (_nomeJaCadastrado(value!.trim())) {
                    return 'Este usuário já foi cadastrado.';
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
                    return 'As senhas não conferem.';
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
                  label: const Text('Cadastrar usuário'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Usuários cadastrados',
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
            onTap: () => _confirmarExclusao(usuario),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Limpar dados'),
                content: const Text(
                    'Deseja excluir TODOS os containers e movimentos? Esta ação não pode ser desfeita.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Limpar tudo'),
                  ),
                ],
              ),
            );
            if (confirm == true && context.mounted) {
              widget.onLimparDados();
            }
          },
          icon: const Icon(Icons.delete_sweep, size: 18),
          label: const Text('Limpar dados'),
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
    required this.onExcluirUsuario,
    required this.onSair,
  });

  final List<AppUser> usuarios;
  final AppUser usuario;
  final Future<void> Function(AppUser usuario) onCadastrarUsuario;
  final Future<void> Function(String nome) onExcluirUsuario;
  final VoidCallback onSair;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final List<ContainerItem> _containers = [];
  final List<MovementItem> _movimentos = [];
  final List<Cliente> _clientes = [];
  int _abaAtual = 0;
  int _dashboardResetKey = 0;
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
    _verificarAtualizacao();
  }

  Future<void> _verificarAtualizacao() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final versaoAtual = info.version;
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('https://api.github.com/repos/bigboss013/controle_containers/releases/latest'),
      );
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'controle_containers');
      final response = await request.close();
      if (response.statusCode != 200) return;
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final tag = data['tag_name'] as String?;
      if (tag == null) return;
      final versaoRemota = tag.replaceAll(RegExp(r'[vV]'), '').split('+')[0];
      if (!_versaoMaior(versaoRemota, versaoAtual)) return;
      String? urlDownload;
      final assets = data['assets'] as List<dynamic>?;
      if (assets != null) {
        for (final asset in assets) {
          final name = asset['name'] as String?;
          if (name != null && name.endsWith('.apk')) {
            urlDownload = asset['browser_download_url'] as String?;
            break;
          }
        }
      }
      if (urlDownload == null || !mounted) return;
      final doBaixar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Atualização disponível'),
          content: Text('Versão $versaoRemota disponível. Deseja instalar agora?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Depois'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.system_update, size: 18),
              label: const Text('Instalar'),
            ),
          ],
        ),
      );
      if (doBaixar != true || !mounted) return;
      await _baixarEInstalar(urlDownload, versaoRemota);
    } catch (_) {}
  }

  Future<void> _baixarEInstalar(String url, String versao) async {
    if (!mounted) return;
    final downloadController = ValueNotifier<double>(0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Baixando atualização...'),
            const SizedBox(height: 16),
            ValueListenableBuilder<double>(
              valueListenable: downloadController,
              builder: (_, pct, __) => Column(
                children: [
                  LinearProgressIndicator(value: pct / 100),
                  const SizedBox(height: 8),
                  Text('${pct.toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    try {
      final tempDir = Directory.systemTemp;
      final filePath = '${tempDir.path}/atualizacao_$versao.apk';
      final file = File(filePath);
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      final totalBytes = response.contentLength;
      int receivedBytes = 0;
      final sink = file.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          downloadController.value = (receivedBytes / totalBytes) * 100;
        }
      }
      await sink.flush();
      await sink.close();
      if (mounted) Navigator.of(context).pop();
      final result = await OpenFile.open(filePath,
          type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir instalador: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao baixar atualização: $e')),
        );
      }
    }
  }

  bool _versaoMaior(String a, String b) {
    final partsA = a.split('.');
    final partsB = b.split('.');
    final maxLen = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < maxLen; i++) {
      final va = i < partsA.length ? int.tryParse(partsA[i]) ?? 0 : 0;
      final vb = i < partsB.length ? int.tryParse(partsB[i]) ?? 0 : 0;
      if (va > vb) return true;
      if (va < vb) return false;
    }
    return false;
  }

  Future<void> _carregarClientes() async {
    _clientes.clear();
    _clientes.addAll(await FirestoreDb.carregarClientes());
    if (_clientes.isEmpty) {
      _clientes.addAll([
        Cliente(codigo: 'ALFA-001', nome: 'Alfa Logística'),
        Cliente(codigo: 'PORTO-109', nome: 'Porto Sul'),
      ]);
    }
  }

  Future<void> _salvarClientes() async {
    for (final c in _clientes) {
      await FirestoreDb.salvarCliente(c);
    }
  }

  Future<void> _carregarDados() async {
    _containers.clear();
    _containers.addAll(await FirestoreDb.carregarContainers());
    _movimentos.clear();
    _movimentos.addAll(await FirestoreDb.carregarMovimentos());

    if (_containers.isEmpty) {
      final usuarioNome = widget.usuario.nome;
      _containers.addAll([
        ContainerItem(
          codigo: 'MSCU1234567',
          codigoCliente: 'ALFA-001',
          cliente: 'Alfa Logística',
          tipo: '40 HC',
          posicao: 'A-14',
          pesoKg: 24800,
          entrada: DateTime.now().subtract(const Duration(days: 4)),
        ),
        ContainerItem(
          codigo: 'TCLU7654321',
          codigoCliente: 'PORTO-109',
          cliente: 'Porto Sul',
          tipo: '20',
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
      await _salvarDados();
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _salvarDados() async {
    for (final c in _containers) {
      await FirestoreDb.salvarContainer(c);
    }
    for (final m in _movimentos) {
      await FirestoreDb.registrarMovimento(m);
    }
  }

  Future<void> _limparDados() async {
    await FirestoreDb.limparTudo();
    setState(() {
      _containers.clear();
      _movimentos.clear();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados excluídos com sucesso.')),
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

  void _cancelarEmbarque(ContainerItem item) {
    final usuarioNome = widget.usuario.nome;
    setState(() {
      item.terminal = null;
      item.navio = null;
      item.agendamento = null;
      item.status = ContainerStatus.armazenado;
      _movimentos.insert(
        0,
        MovementItem(
          tipo: 'Cancelamento Embarque',
          codigo: item.codigo,
          descricao:
              '${item.cliente} - Embarque cancelado em ${positionLabel(item.posicao)}',
          data: DateTime.now(),
          usuario: usuarioNome,
        ),
      );
    });
    _salvarDados();
  }

  void _abrirDialogEditarPosicao(BuildContext context, ContainerItem item) {
    final posController = TextEditingController(text: item.posicao);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar posição - ${item.codigo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoLine(icon: Icons.business_outlined, texto: item.cliente),
            const SizedBox(height: 12),
            TextField(
              controller: posController,
              decoration: const InputDecoration(
                labelText: 'Nova posição no pátio',
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
              final novaPos = normalizarPosicao(posController.text);
              if (novaPos.isEmpty) return;
              item.posicao = novaPos;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Posição alterada para $novaPos.')),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
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

  void _excluirContainer(ContainerItem item) async {
    await FirestoreDb.removerContainer(item.codigo);
    setState(() {
      _containers.removeWhere((c) => c.codigo == item.codigo);
      _movimentos.removeWhere((m) => m.codigo == item.codigo);
    });
    _salvarDados();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Contêiner ${item.codigo} excluído.')),
    );
  }

  void _excluirMovimento(MovementItem movimento) async {
    setState(() {
      _movimentos.remove(movimento);
    });
    _salvarDados();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Movimento excluído.')),
    );
  }

  void _limparHistorico() async {
    await FirestoreDb.limparHistorico();
    setState(() {
      _movimentos.clear();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Histórico limpo com sucesso.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.usuario.perfil == UserRole.administrador;
    final paginas = [
      DashboardPage(
        key: ValueKey(_dashboardResetKey),
        containers: _containers,
        armazenados: _armazenados,
        patio: _patio,
        total: _containers.length,
        movimentos: _movimentos,
        podeMover: isAdmin,
        podeEditar: isAdmin,
        perfil: widget.usuario.perfil,
        onSaida: _registrarSaida,
        onMover: _alterarPosicao,
        onEmbarque: _registrarEmbarque,
        onNoShow: _registrarNoShow,
        onReintegrar: _reintegrarNoShow,
        onReserva: _registrarReserva,
        onCancelarEmbarque: (c) {
          _cancelarEmbarque(c);
          _abrirDialogEditarPosicao(context, c);
        },
        onAtualizar: () {
          setState(() {});
          _salvarDados();
        },
        onExcluir: _excluirContainer,
      ),
      EntradaPage(
        perfil: widget.usuario.perfil,
        clientes: _clientes,
        onSalvar: _registrarEntrada,
        onCadastrarCliente: (Cliente c) {
          setState(() => _clientes.add(c));
          _salvarClientes();
        },
        onImportarExcel: (List<ContainerItem> items) async {
          for (final item in items) {
            _registrarEntrada(item);
          }
        },
      ),
      DeadlinePage(
        containers: _containers,
        onAtualizar: () {
          setState(() {});
          _salvarDados();
        },
        perfil: widget.usuario.perfil,
      ),
      HistoricoPage(
        movimentos: _movimentos,
        containers: _containers,
        onRegistrarNoShow: _registrarNoShow,
        onReintegrar: _reintegrarNoShow,
        onExcluirMovimento: isAdmin ? _excluirMovimento : null,
        onLimparHistorico: isAdmin ? _limparHistorico : null,
      ),
      if (isAdmin)
        UsuariosPage(
          usuarios: widget.usuarios,
          onCadastrar: widget.onCadastrarUsuario,
          onExcluir: widget.onExcluirUsuario,
          onLimparDados: _limparDados,
        ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sair'),
            content: const Text('Tem certeza que deseja sair do app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Não'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sim'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          exit(0);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Santos Transportes',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
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
        onDestinationSelected: (index) => setState(() {
          if (index == 0 && _abaAtual == 0) _dashboardResetKey++;
          _abaAtual = index;
        }),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Entrada',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning, color: _deadlineAlertColor, size: 24),
            selectedIcon: Icon(Icons.warning, color: _deadlineAlertColor),
            label: 'Deadline',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Histórico',
          ),
          if (isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(Icons.manage_accounts),
              label: 'Usuários',
            ),
        ],
      ),
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
    required this.podeEditar,
    required this.perfil,
    required this.onSaida,
    required this.onMover,
    required this.onEmbarque,
    required this.onNoShow,
    required this.onReintegrar,
    required this.onReserva,
    required this.onCancelarEmbarque,
    required this.onAtualizar,
    required this.onExcluir,
  });

  final List<ContainerItem> containers;
  final List<ContainerItem> armazenados;
  final List<ContainerItem> patio;
  final int total;
  final List<MovementItem> movimentos;
  final bool podeMover;
  final bool podeEditar;
  final UserRole perfil;
  final ValueChanged<ContainerItem> onSaida;
  final void Function(ContainerItem item, String novaPosicao) onMover;
  final void Function(ContainerItem item, String terminal, String navio, DateTime agendamento) onEmbarque;
  final ValueChanged<ContainerItem> onNoShow;
  final ValueChanged<ContainerItem> onReintegrar;
  final ValueChanged<ContainerItem> onReserva;
  final ValueChanged<ContainerItem> onCancelarEmbarque;
  final VoidCallback onAtualizar;
  final ValueChanged<ContainerItem> onExcluir;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _searchController = TextEditingController();
  final _patioSearchController = TextEditingController();
  String _searchQuery = '';
  String _patioSearchQuery = '';
  String? _selectedSection;
  final Set<String> _embarqueFiltros = {};

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

  @override
  Widget build(BuildContext context) {
    final isConferente = widget.perfil == UserRole.conferente;

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
              hintText: 'Buscar contêiner por código, cliente ou posição...',
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
          AspectRatio(
            aspectRatio: 1,
            child: InkWell(
              onTap: () => _abrirMapaPatio(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE1E5E8)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map, color: Color(0xFF1565C0), size: 40),
                    const SizedBox(height: 8),
                    Text('Mapa do Patio',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
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
            Expanded(
              child: Text(
                'Todos os containers no patio',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => _abrirMapaPatio(context),
              icon: const Icon(Icons.map, size: 22),
              tooltip: 'Visualizar patio 3D',
              visualDensity: VisualDensity.compact,
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedSection = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Inicio'),
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
              onCancelarEmbarque: null,
              onEditar: item.status == ContainerStatus.embarcado && widget.podeEditar
                  ? () => _abrirDetalhesContainer(context, item)
                  : null,
              onExcluir: widget.podeEditar ? () => widget.onExcluir(item) : null,
              onAbrirMapa: () => _abrirDialogMapa(context, item),
            ),
          ),
      ],
    );
  }

  void _abrirDetalhesContainer(BuildContext context, ContainerItem container) {
    if (widget.perfil == UserRole.gate) return;
    final codCliCtrl = TextEditingController(text: container.codigoCliente);
    final cliCtrl = TextEditingController(text: container.cliente);
    final posCtrl = TextEditingController(text: container.posicao);
    final obsCtrl = TextEditingController(text: container.observacao);
    final terminalCtrl = TextEditingController(text: container.terminal ?? '');
    final navioCtrl = TextEditingController(text: container.navio ?? '');
    String tipo = container.tipo;
    DateTime? deadline = container.deadline;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(container.codigo,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  const SizedBox(width: 4),
                  Chip(label: Text(tipo, style: const TextStyle(fontSize: 12))),
                  if (container.posicao.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 28, height: 28,
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
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codCliCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Código do cliente', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cliCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cliente', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: posCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Posição', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo', border: OutlineInputBorder(),
                        isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      items: const [
                        DropdownMenuItem(value: '20', child: Text('20')),
                        DropdownMenuItem(value: '40', child: Text('40')),
                        DropdownMenuItem(value: 'Reefer', child: Text('Reefer')),
                        DropdownMenuItem(value: 'Open Top', child: Text('Open Top')),
                        DropdownMenuItem(value: 'Flat Rack', child: Text('Flat Rack')),
                        DropdownMenuItem(value: 'Tank', child: Text('Tank')),
                      ],
                      onChanged: (v) => setDialogState(() => tipo = v ?? tipo),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: terminalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Terminal destino', border: OutlineInputBorder(),
                        isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: navioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Navio', border: OutlineInputBorder(),
                        isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
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
                              color: deadline != null ? Colors.red : null, size: 18,
                            ),
                            label: Text(
                              deadline != null ? formatDate(deadline!) : 'Definir Deadline',
                            ),
                          ),
                        ),
                        if (deadline != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            tooltip: 'Remover deadline',
                            onPressed: () => setDialogState(() => deadline = null),
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: obsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observação', border: OutlineInputBorder(),
                        isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                      minLines: 2, maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      container.codigoCliente = codCliCtrl.text.trim().toUpperCase();
                      container.cliente = cliCtrl.text.trim();
                      container.posicao = normalizarPosicao(posCtrl.text);
                      container.tipo = tipo;
                        container.terminal = terminalCtrl.text.trim().isEmpty
                            ? null : terminalCtrl.text.trim();
                        container.navio = navioCtrl.text.trim().isEmpty
                            ? null : navioCtrl.text.trim();
                        container.observacao = obsCtrl.text.trim();
                        container.deadline = deadline;
                        Navigator.pop(ctx);
                        widget.onAtualizar();
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _abrirDialogMapa(BuildContext context, ContainerItem container) {
    final pos = container.posicao.replaceAll('.', '-');
    final block = pos.split('-').isNotEmpty
        ? pos.split('-')[0]
        : '';
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
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
            ),
            Flexible(
              child: YardMap3D(
                containers: widget.containers
                    .where((c) =>
                        c.posicao.isNotEmpty &&
                        c.status != ContainerStatus.saiu &&
                        c.posicao.replaceAll('.', '-').split('-').isNotEmpty &&
                        c.posicao.replaceAll('.', '-').split('-')[0] == block)
                    .toList(),
                highlightCodigo: container.codigo,
                onContainerTap: (c) {
                  Navigator.pop(ctx);
                  _abrirDetalhesContainer(context, c);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirMapaPatio(BuildContext context) {
    final yard = widget.containers
        .where((c) =>
            c.status != ContainerStatus.saiu && c.posicao.isNotEmpty)
        .toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Mapa 3D - Patio',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: YardMap3D(
                containers: yard,
                onContainerTap: (c) {
                  Navigator.pop(ctx);
                  _abrirDetalhesContainer(context, c);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbarqueSection() {
    final items = _embarqueItems;
    var filtered = items.toList();
    if (_embarqueFiltros.isNotEmpty) {
      filtered = items.where((c) {
        for (final f in _embarqueFiltros) {
          switch (f) {
            case 'Data':
              if (c.agendamento == null) return false;
            case 'Hora':
              if (c.agendamento == null) return false;
            case 'Terminal':
              if (c.terminal == null || c.terminal!.isEmpty) return false;
            case 'Navio':
              if (c.navio == null || c.navio!.isEmpty) return false;
          }
        }
        return true;
      }).toList();
    }
    filtered.sort((a, b) => (a.agendamento ?? DateTime(9999))
        .compareTo(b.agendamento ?? DateTime(9999)));
    final grupos = <String, List<ContainerItem>>{};
    for (final c in filtered) {
      final chave = c.agendamento != null
          ? '${c.agendamento!.year}-${c.agendamento!.month.toString().padLeft(2, '0')}-${c.agendamento!.day.toString().padLeft(2, '0')}'
          : 'Sem data';
      grupos.putIfAbsent(chave, () => []);
      grupos[chave]!.add(c);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Embarques',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Filtros',
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                setState(() {
                  if (_embarqueFiltros.contains(value)) {
                    _embarqueFiltros.remove(value);
                  } else {
                    _embarqueFiltros.add(value);
                  }
                });
              },
              itemBuilder: (_) => [
                for (final op in ['Data', 'Hora', 'Terminal', 'Navio'])
                  CheckedPopupMenuItem<String>(
                    value: op,
                    checked: _embarqueFiltros.contains(op),
                    child: Text(op),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const EmptyState(texto: 'Nenhum embarque agendado.')
        else
          ...grupos.entries.map((entry) {
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
                      Text(entry.key,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Color(0xFF0F766E))),
                      const SizedBox(height: 8),
                      ...entry.value.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: ContainerCard(
                              item: c,
                              podeMover: false,
                              podeEmbarcar: false,
                              podeReservar: false,
                              noShowActions: false,
                              mostrarCancelarEmbarque: true,
                              onSaida: () => widget.onSaida(c),
                              onMover: (_) {},
                              onEmbarque: null,
                              onCancelarEmbarque: () => widget.onCancelarEmbarque(c),
                              onAbrirMapa: () => _abrirDialogMapa(context, c),
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
            Expanded(
              child: Text(
                'No-show pendentes',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedSection = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Inicio'),
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
            Expanded(
              child: Text(
                'Reserva',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedSection = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Inicio'),
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
              onAbrirMapa: () => _abrirDialogMapa(context, item),
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
                      labelText: 'Horário do agendamento',
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
            SizedBox(
              width: 110,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _abrirDetalhesContainer(context, item);
                },
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Cancelar'),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                ),
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
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Confirmar embarque'),
                ),
              ),
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
    this.onAbrirMapa,
    this.onCancelarEmbarque,
    this.mostrarCancelarEmbarque = false,
    this.onEditar,
    this.onExcluir,
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
  final VoidCallback? onAbrirMapa;
  final VoidCallback? onCancelarEmbarque;
  final bool mostrarCancelarEmbarque;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;

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
                    _statusDotParaContainer(item),
                    if (_statusDotParaContainer(item) is! SizedBox)
                      const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.codigo,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (item.posicao.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Tooltip(
                                message: 'Aguardando posição',
                                child: Icon(
                                  Icons.push_pin_outlined,
                                  size: 18,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                        ],
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
                texto: 'Código cliente ${emptyLabel(item.codigoCliente)}',
              ),
              InfoLine(
                icon: Icons.scale_outlined,
                texto: 'Peso ${weightLabel(item.pesoKg)}',
              ),
              InfoLine(
                icon: Icons.place_outlined,
                texto: item.posicao.isEmpty
                    ? 'Aguardando posição'
                    : 'Posição ${positionLabel(item.posicao)}',
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

  Widget _statusDotParaContainer(ContainerItem c) {
    if (c.status == ContainerStatus.embarcado) {
      return _BlinkingDot(color: Colors.amber);
    }
    if (c.status == ContainerStatus.noShow || c.noShowCount > 0) {
      return _StaticDot(color: Colors.red);
    }
    if (c.posicao.isEmpty) {
      return _StaticDot(color: Colors.purple);
    }
    return const SizedBox(width: 14, height: 14);
  }

  void _abrirMoverDialog(BuildContext context) {
    final controller = TextEditingController(text: item.posicao);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Alterar posição'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nova posição',
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
                final novaPosicao = normalizarPosicao(controller.text);
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

  void _confirmarExclusao(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir container'),
        content: Text('Deseja excluir o container ${item.codigo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) onExcluir?.call();
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
              if (item.posicao.isNotEmpty && onAbrirMapa != null) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: 28, height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.map, size: 18),
                    tooltip: 'Mostrar no mapa 3D',
                    onPressed: () {
                      Navigator.pop(ctx);
                      onAbrirMapa!.call();
                    },
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
              InfoLine(icon: Icons.business_outlined, texto: item.cliente),
              InfoLine(
                  icon: Icons.badge_outlined,
                  texto: 'Código cliente ${emptyLabel(item.codigoCliente)}'),
              InfoLine(
                  icon: Icons.scale_outlined,
                  texto: 'Peso ${weightLabel(item.pesoKg)}'),
              InfoLine(
                  icon: Icons.place_outlined,
                  texto: item.posicao.isEmpty
                      ? 'Aguardando posição'
                      : 'Posição ${positionLabel(item.posicao)}'),
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
                    texto: 'Saída em ${formatDate(item.saida!)}'),
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
                  if (onExcluir != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmarExclusao(context);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Excluir', style: TextStyle(fontSize: 13, color: Colors.red)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ),
                  if (onExcluir != null) const SizedBox(width: 8),
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
                  if (item.status == ContainerStatus.embarcado) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: mostrarCancelarEmbarque
                          ? OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onCancelarEmbarque?.call();
                              },
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text('Cancelar Embarque',
                                  style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onEditar?.call();
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Editar',
                                  style: TextStyle(fontSize: 13)),
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
                      label: const Text('Saída', style: TextStyle(fontSize: 13)),
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
      final pos = c.posicao.replaceAll('.', '-');
      final parts = pos.split('-');
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
    this.onImportarExcel,
  });

  final UserRole perfil;
  final List<Cliente> clientes;
  final ValueChanged<ContainerItem> onSalvar;
  final ValueChanged<Cliente> onCadastrarCliente;
  final Future<void> Function(List<ContainerItem> items)? onImportarExcel;

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
  bool _isScanning = false;
  String _tipo = '20';
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
                labelText: 'Código do cliente',
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
    if (foto == null || !mounted) return;
    setState(() => _fotoAvariaPath = foto.path);
  }

  Future<void> _scanContainerCode() async {
    final foto = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (foto == null || !mounted) return;
    setState(() => _isScanning = true);
    try {
      final inputImage = InputImage.fromFilePath(foto.path);
      final recognizer = TextRecognizer();
      final recognisedText = await recognizer.processImage(inputImage);
      await recognizer.close();
      if (!mounted) return;
      final codigoRegex = RegExp(r'[A-Z]{4}\d{7}');
      for (final block in recognisedText.blocks) {
        for (final line in block.lines) {
          final match = codigoRegex.firstMatch(line.text.replaceAll(' ', ''));
          if (match != null) {
            _codigoController.text = match.group(0)!;
            if (mounted) setState(() => _isScanning = false);
            return;
          }
        }
      }
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Código do contêiner não encontrado na imagem.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ler imagem: $e')),
        );
      }
    }
  }

  void _salvar() {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    widget.onSalvar(
      ContainerItem(
        codigo: _codigoController.text.trim().toUpperCase(),
        codigoCliente: _codigoClienteController.text.trim().toUpperCase(),
        cliente: _clienteController.text.trim(),
        tipo: _tipo,
        posicao: _podeInformarPosicao
            ? normalizarPosicao(_posicaoController.text)
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
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _deadline != null
          ? TimeOfDay.fromDateTime(_deadline!)
          : const TimeOfDay(hour: 18, minute: 0),
    );
    if (!mounted || time == null) return;
    setState(() {
      _deadline = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _importarExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível ler o arquivo.')),
        );
        return;
      }
      final excel = Excel.decodeBytes(file.bytes!);
      if (excel.tables.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Planilha vazia ou inválida.')),
        );
        return;
      }
      final table = excel.tables[excel.tables.keys.first];
      if (table == null || table.rows.isEmpty) return;
      final header = table.rows.first;
      final colMap = <String, int>{};
      for (var i = 0; i < header.length; i++) {
        final val = header[i]?.value?.toString().toLowerCase().trim() ?? '';
        colMap[val] = i;
      }
      String? findCol(List<String> aliases) {
        for (final alias in aliases) {
          if (colMap.containsKey(alias)) return alias;
        }
        return null;
      }
      final colCodigo = findCol(['codigo', 'container', 'container code', 'cod container', 'cod']);
      final colCliente = findCol(['cliente', 'client', 'nome cliente', 'razao social']);
      final colCodigoCliente = findCol(['codigo cliente', 'cod cliente', 'client code', 'cod cli']);
      final colTipo = findCol(['tipo', 'type', 'tamanho', 'size']);
      final colPeso = findCol(['peso', 'weight', 'peso kg', 'kg']);
      final colPosicao = findCol(['posicao', 'posição', 'position', 'pos', 'lote']);
      final colObs = findCol(['obs', 'observacao', 'observação', 'observation', 'notes']);
      final items = <ContainerItem>[];
      for (var r = 1; r < table.rows.length; r++) {
        final row = table.rows[r];
        String cell(String? col) => col != null && colMap[col] != null && colMap[col]! < row.length
            ? (row[colMap[col]!]?.value?.toString() ?? '').trim()
            : '';
        final codigo = cell(colCodigo);
        if (codigo.isEmpty) continue;
        final pesoStr = cell(colPeso);
        final peso = pesoStr.isNotEmpty ? parseWeight(pesoStr) : null;
        final isCheio = peso != null && peso > 0;
        String tipo = cell(colTipo).toUpperCase();
        if (!['20', '40', 'REEFER', 'OPEN TOP', 'FLAT RACK', 'TANK'].contains(tipo)) {
          if (tipo.contains('20')) tipo = '20';
          else if (tipo.contains('REEFER') || tipo.contains('REFR')) tipo = 'Reefer';
          else if (tipo.contains('OPEN') || tipo.contains('TOP')) tipo = 'Open Top';
          else if (tipo.contains('FLAT') || tipo.contains('RACK')) tipo = 'Flat Rack';
          else if (tipo.contains('TANK')) tipo = 'Tank';
          else if (tipo.contains('40')) tipo = '40';
          else tipo = '20';
        }
        if (tipo == 'REEFER') tipo = 'Reefer';
        if (tipo == 'FLAT RACK') tipo = 'Flat Rack';
        if (tipo == 'OPEN TOP') tipo = 'Open Top';
        items.add(ContainerItem(
          codigo: codigo.toUpperCase(),
          codigoCliente: cell(colCodigoCliente).toUpperCase(),
          cliente: cell(colCliente),
          tipo: tipo,
          posicao: normalizarPosicao(cell(colPosicao)),
          pesoKg: isCheio ? peso : null,
          observacao: cell(colObs),
          entrada: DateTime.now(),
        ));
      }
      if (items.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum contêiner válido encontrado na planilha.')),
        );
        return;
      }
      if (widget.onImportarExcel != null) {
        await widget.onImportarExcel!(items);
      } else {
        for (final item in items) {
          widget.onSalvar(item);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length} container(es) importado(s) com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao importar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Registrar entrada',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _importarExcel,
            icon: const Icon(Icons.file_upload_outlined, size: 22),
            label: const Text('Importar planilha Excel', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Importe um arquivo .xlsx. Se o container tiver peso, será registrado como CHEIO. Se não tiver, como VAZIO.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _codigoController,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Código do contêiner',
                  hintText: 'Ex: MSCU1234567',
                  prefixIcon: const Icon(Icons.tag),
                  suffixIcon: _isScanning
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.camera_alt_outlined),
                          tooltip: 'Escanear código',
                          onPressed: _scanContainerCode,
                        ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => obrigatorio(value, 'Informe o código.'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _codigoClienteController,
                readOnly: true,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                labelText: 'Código do cliente',
                  hintText: 'Toque para selecionar',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                onTap: _selecionarCliente,
                validator: (value) =>
                    obrigatorio(value, 'Informe o código do cliente.'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _clienteController,
                readOnly: true,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                onTap: _selecionarCliente,
                validator: (value) => obrigatorio(value, 'Informe o cliente.'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Cheio', style: TextStyle(fontSize: 16)),
                      selected: _cheio,
                      onSelected: (_) => setState(() => _cheio = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Vazio', style: TextStyle(fontSize: 16)),
                      selected: !_cheio,
                      onSelected: (_) => setState(() => _cheio = false),
                    ),
                  ),
                ],
              ),
              if (_cheio) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pesoController,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Peso do contêiner',
                    hintText: 'Ex: 24500',
                    suffixText: 'kg',
                    prefixIcon: Icon(Icons.scale_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                      return 'Informe um peso válido.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _tipo,
                style: const TextStyle(fontSize: 18, color: Colors.black87),
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.view_in_ar_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                items: const [
                  DropdownMenuItem(value: '20', child: Text('20', style: TextStyle(fontSize: 17))),
                  DropdownMenuItem(value: '40', child: Text('40', style: TextStyle(fontSize: 17))),
                  DropdownMenuItem(value: 'Reefer', child: Text('Reefer', style: TextStyle(fontSize: 17))),
                  DropdownMenuItem(value: 'Open Top', child: Text('Open Top', style: TextStyle(fontSize: 17))),
                  DropdownMenuItem(value: 'Flat Rack', child: Text('Flat Rack', style: TextStyle(fontSize: 17))),
                  DropdownMenuItem(value: 'Tank', child: Text('Tank', style: TextStyle(fontSize: 17))),
                ],
                onChanged: (value) => setState(() => _tipo = value ?? _tipo),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _observacaoController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  hintText: 'Descreva avarias, lacre, divergências...',
                  prefixIcon: Icon(Icons.report_problem_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _tirarFotoAvaria,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  _fotoAvariaPath == null
                      ? 'Tirar foto de avaria'
                      : 'Trocar foto de avaria',
                  style: const TextStyle(fontSize: 16),
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _posicaoController,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Posição no pátio',
                    hintText: 'Ex: A-14 ou A5-34',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) =>
                      obrigatorio(value, 'Informe a posição.'),
                ),
              ] else ...[
                const SizedBox(height: 14),
                const PermissionNotice(
                  texto:
                      'Perfil Gate registra a entrada sem posição. A posição será definida pelo Conferente.',
                ),
              ],
              if (_podeInformarPosicao) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: _selecionarDeadline,
                  icon: Icon(
                    _deadline != null ? Icons.event_busy : Icons.event_outlined,
                    color: _deadline != null ? Colors.red : null,
                  ),
                  label: Text(
                    _deadline != null
                        ? 'Deadline: ${formatDate(_deadline!)}'
                        : 'Definir Deadline (prazo de entrega)',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
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
    this.onExcluirMovimento,
    this.onLimparHistorico,
  });

  final List<MovementItem> movimentos;
  final List<ContainerItem> containers;
  final ValueChanged<ContainerItem> onRegistrarNoShow;
  final ValueChanged<ContainerItem>? onReintegrar;
  final ValueChanged<MovementItem>? onExcluirMovimento;
  final VoidCallback? onLimparHistorico;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Histórico',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (onLimparHistorico != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Limpar histórico'),
                      content: const Text('Deseja excluir todo o histórico? Esta ação não pode ser desfeita.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Limpar'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) onLimparHistorico!();
                },
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Limpar'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (movimentos.isEmpty)
          const EmptyState(texto: 'Nenhum movimento registrado.')
        else
          ...movimentos
              .where((m) {
                final c = containers.where((x) => x.codigo == m.codigo).firstOrNull;
                return c == null || c.status != ContainerStatus.armazenado;
              })
              .map(
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
                title: Row(
                  children: [
                    _buildStatusCircle(movimento, container),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${movimento.tipo} - ${movimento.codigo}'),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${movimento.descricao}\n${formatDate(movimento.data)}${movimento.usuario.isNotEmpty ? ' • ${movimento.usuario}' : ''}',
                ),
                isThreeLine: true,
                onTap: () => _abrirAcoesContainer(context, container, movimento, isSaida),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onExcluirMovimento != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Excluir movimento',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Excluir movimento'),
                              content: const Text('Deseja excluir este movimento?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Excluir'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) onExcluirMovimento!(movimento);
                        },
                      ),
                    if (isSaida && container != null)
                      const Icon(Icons.restart_alt, size: 18, color: Colors.orange),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatusCircle(MovementItem movimento, ContainerItem? container) {
    if (movimento.tipo == 'Cancelamento Embarque') {
      return const Icon(Icons.close, color: Colors.red, size: 16);
    }
    if (container != null && container.status == ContainerStatus.embarcado) {
      return _BlinkingDot(color: Colors.amber);
    }
    if (movimento.tipo == 'Embarque') {
      return _StaticDot(color: Colors.green);
    }
    if (movimento.tipo == 'No-show' || (container?.noShowCount ?? 0) > 0) {
      return _StaticDot(color: Colors.red);
    }
    return const SizedBox(width: 14, height: 14);
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
              const Text('Ações disponíveis:', style: TextStyle(fontWeight: FontWeight.w600)),
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
                labelText: 'Nova posição no pátio',
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
                      final novaPos = normalizarPosicao(posController.text);
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
  const DeadlinePage({
    super.key,
    required this.containers,
    required this.onAtualizar,
    required this.perfil,
  });

  final List<ContainerItem> containers;
  final VoidCallback onAtualizar;
  final UserRole perfil;

  bool get _podeEditar =>
      perfil == UserRole.conferente || perfil == UserRole.administrador;

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
          'Contêineres com prazo limite para entrada no terminal.',
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
                    ? 'Atenção - ${diff}d'
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
    if (!_podeEditar) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(c.codigo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              const SizedBox(width: 4),
              Chip(label: Text(c.tipo, style: const TextStyle(fontSize: 12))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoLine(icon: Icons.business_outlined, texto: c.cliente),
              InfoLine(icon: Icons.badge_outlined, texto: 'Código cliente ${emptyLabel(c.codigoCliente)}'),
              InfoLine(icon: Icons.place_outlined, texto: c.posicao.isEmpty ? 'Aguardando posição' : 'Posição ${positionLabel(c.posicao)}'),
              InfoLine(icon: Icons.scale_outlined, texto: 'Peso ${weightLabel(c.pesoKg)}'),
              if (c.terminal != null) InfoLine(icon: Icons.business, texto: 'Terminal: ${c.terminal}'),
              if (c.navio != null) InfoLine(icon: Icons.directions_boat, texto: 'Navio: ${c.navio}'),
              if (c.deadline != null) InfoLine(icon: Icons.event_busy, texto: 'Deadline: ${formatDate(c.deadline!)}'),
              if (c.observacao.isNotEmpty) InfoLine(icon: Icons.report_problem_outlined, texto: c.observacao),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
        ),
      );
      return;
    }

    final codCliCtrl = TextEditingController(text: c.codigoCliente);
    final cliCtrl = TextEditingController(text: c.cliente);
    final posCtrl = TextEditingController(text: c.posicao);
    final obsCtrl = TextEditingController(text: c.observacao);
    final terminalCtrl = TextEditingController(text: c.terminal ?? '');
    final navioCtrl = TextEditingController(text: c.navio ?? '');
    String tipo = c.tipo;
    DateTime? deadline = c.deadline;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c.codigo,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  const SizedBox(width: 4),
                  Chip(label: Text(tipo, style: const TextStyle(fontSize: 12))),
                  if (c.posicao.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 28, height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.map, size: 18),
                        tooltip: 'Mostrar no mapa 3D',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _abrirMapa(context, c);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codCliCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Código do cliente', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cliCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cliente', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: posCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Posição', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: tipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        items: const [
                          DropdownMenuItem(value: '20', child: Text('20')),
                          DropdownMenuItem(value: '40', child: Text('40')),
                          DropdownMenuItem(value: 'Reefer', child: Text('Reefer')),
                          DropdownMenuItem(value: 'Open Top', child: Text('Open Top')),
                          DropdownMenuItem(value: 'Flat Rack', child: Text('Flat Rack')),
                          DropdownMenuItem(value: 'Tank', child: Text('Tank')),
                        ],
                        onChanged: (v) => setDialogState(() => tipo = v ?? tipo),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: terminalCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Terminal destino', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: navioCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Navio', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                textStyle: const TextStyle(fontSize: 13),
                              ),
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
                                color: deadline != null ? Colors.red : null, size: 18,
                              ),
                              label: Text(
                                deadline != null ? formatDate(deadline!) : 'Definir Deadline',
                              ),
                            ),
                          ),
                          if (deadline != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              tooltip: 'Remover deadline',
                              onPressed: () => setDialogState(() => deadline = null),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: obsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Observação', border: OutlineInputBorder(),
                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                        minLines: 2, maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        c.codigoCliente = codCliCtrl.text.trim().toUpperCase();
                        c.cliente = cliCtrl.text.trim();
                        c.posicao = normalizarPosicao(posCtrl.text);
                        c.tipo = tipo;
                        c.terminal = terminalCtrl.text.trim().isEmpty
                            ? null : terminalCtrl.text.trim();
                        c.navio = navioCtrl.text.trim().isEmpty
                            ? null : navioCtrl.text.trim();
                        c.observacao = obsCtrl.text.trim();
                        c.deadline = deadline;
                        Navigator.pop(ctx);
                        onAtualizar();
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
  }
 
  void _abrirMapa(BuildContext context, ContainerItem c) {
    final pos = c.posicao.replaceAll('.', '-');
    final block = pos.split('-').isNotEmpty
        ? pos.split('-')[0]
        : '';
    final screenH = MediaQuery.of(context).size.height;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Mapa 3D - ${c.codigo}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 300,
              height: (screenH - 180) * 0.5,
              child: YardMap3D(
                containers: containers
                    .where((x) =>
                        x.posicao.isNotEmpty &&
                        x.status != ContainerStatus.saiu &&
                        x.posicao.replaceAll('.', '-').split('-').isNotEmpty &&
                        x.posicao.replaceAll('.', '-').split('-')[0] == block)
                    .toList(),
                highlightCodigo: c.codigo,
              ),
            ),
          ],
        ),
      ),
    );
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
    return 'Aguardando posição';
  }
  return posicao;
}

String emptyLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Não informado';
  }
  return value;
}

String weightLabel(double? value) {
  if (value == null) {
    return 'Não informado';
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
String normalizarPosicao(String pos) {
  String p = pos.trim().toUpperCase().replaceAll('.', '-');
  if (p.contains('-')) return p;
  final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(p);
  if (match == null) return p;
  final letters = match.group(1)!;
  final digits = match.group(2)!;
  if (digits.length == 2) return '$letters-${digits}';
  if (digits.length == 3) return '$letters${digits[0]}-${digits.substring(1)}';
  return p;
}

(String block, int? row) parsePosition(String pos) {
  final normalized = normalizarPosicao(pos);
  final parts = normalized.split('-');
  if (parts.length < 2) return (normalized, null);
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

class _StaticDot extends StatelessWidget {
  const _StaticDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({required this.color});
  final Color color;
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
