# Controle Containers

Aplicativo Flutter para controlar entrada, saida, movimentacao e armazenamento de conteineres.

## Primeiro passo

Abra a pasta `controle_containers` no VS Code ou Android Studio.

Para Android, use:

```bash
flutter pub get
flutter run
```

Para iOS, sera necessario usar um Mac com Xcode instalado.

## O que esta pronto

- Tela de patio com conteineres armazenados.
- Tela inicial com login por usuario e senha.
- Redefinicao de senha pela tela inicial.
- Cadastro de usuarios salvo no aparelho.
- Cadastro de novos usuarios visivel somente para Administrador.
- Perfil Gate registra entrada sem posicao do conteiner.
- Perfil Gate informa peso, codigo do cliente, observacao de avarias e foto.
- Leitura OCR por camera para preencher o codigo do cliente.
- Perfil Conferente define e remaneja a posicao do conteiner.
- Registro de entrada.
- Registro de saida.
- Alteracao de posicao no patio.
- Historico de movimentacoes.

Nesta etapa os usuarios ficam gravados no aparelho. Os conteineres ainda ficam em memoria enquanto o app esta aberto. A proxima etapa pode gravar tambem os conteineres em banco local ou back-end com API.
