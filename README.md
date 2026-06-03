# My Finance App

Aplicativo de gerenciamento de finanças pessoais (Mobile + Web) com Clean Architecture, Flutter e Firebase.

## Estrutura de Pastas

```
lib/
├── core/
│   ├── error/          # Failures e Exceptions
│   ├── usecases/       # Contrato base UseCase
│   └── utils/          # Formatadores, firebase_options
├── features/
│   ├── auth/
│   │   ├── data/       # Models, DataSources, RepositoryImpl
│   │   ├── domain/     # Entities, Repositories (abstract), UseCases
│   │   └── presentation/ # Providers (Riverpod), Screens, Widgets
│   └── transactions/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── models/             # Barrel exports
```

## Setup Firebase

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com)
2. Habilite **Authentication** (Email/Password) e **Cloud Firestore**
3. Instale o CLI: `dart pub global activate flutterfire_cli`
4. Execute: `flutterfire configure`
5. O arquivo `lib/core/utils/firebase_options.dart` será gerado automaticamente

## Instalação

```bash
flutter pub get
flutter run
```

## Dependências principais

| Pacote | Uso |
|---|---|
| `firebase_core` | Inicialização Firebase |
| `firebase_auth` | Autenticação |
| `cloud_firestore` | Banco de dados |
| `flutter_riverpod` | Gerenciamento de estado |
| `intl` | Formatação de moeda e datas |
| `dartz` | Either (tratamento funcional de erros) |
| `equatable` | Comparação de objetos |
