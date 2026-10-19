# Vality — guia de instalação

## Onde cada arquivo vai

### Backend (`back_end/`)
```
back_end/
├── main.py
├── database.py
├── models.py
├── schemas.py
├── config.py
├── requirements.txt
├── iniciar_vality.bat      ← rodar na mão (mostra erro)
├── vality_servico.bat      ← usado pelo Agendador de Tarefas
└── services/
    ├── __init__.py
    ├── fonte_venda.py
    ├── alertas.py
    ├── notificacao.py
    └── agendador.py
```

**Atenção:** sem pasta dentro de pasta. Os arquivos ficam direto em
`C:\Users\Nordeste\Documents\back_end`, não em `back_end\back_end`.

### App (`vality_app/lib/`)
```
lib/
├── main.dart
├── config/
│   └── api_config.dart
├── models/
│   ├── produto.dart
│   └── lote.dart
├── services/
│   ├── api_service.dart
│   └── notificacao_service.dart
└── screens/
    ├── home_screen.dart
    ├── produtos_vencendo_screen.dart
    ├── produtos_screen.dart
    ├── nova_entrada_screen.dart
    ├── detalhe_produto_screen.dart
    ├── dashboard_screen.dart
    ├── scanner_screen.dart
    └── configuracao_screen.dart
```

O `AndroidManifest.xml` vai em `android/app/src/main/`
e o `build.gradle.kts` em `android/app/`.

---

## Instalar o backend (PC do mercado)

```
cd /d "C:\Users\Nordeste\Documents\back_end"
python -m pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Se `python` não for reconhecido, use o caminho completo:
`C:\Users\Nordeste\AppData\Local\Programs\Python\Python315\python.exe`

Deu certo quando aparecer `Uvicorn running on http://0.0.0.0:8000`.
Confira em `http://localhost:8000/docs`.

### Descobrir o IP da máquina
```
ipconfig
```
Anote o **Endereço IPv4** (ex.: 192.168.0.15). É o que vai no app.

---

## Gerar o APK

```
cd C:\Users\kmota\Documents\vality_system\vality_app
flutter pub get
flutter build apk --release
```

Sai em `build\app\outputs\flutter-apk\app-release.apk`.

**O app não usa mais o `workmanager`.** Se ele ainda estiver no
`pubspec.yaml`, remova:
```
flutter pub remove workmanager
flutter clean
flutter pub get
```

---

## Configurar o app

1. Abrir o app → ⚙️ Configurações
2. Endereço do servidor: `http://192.168.0.15:8000` (o IP do passo acima)
3. **Testar conexão** → tem que dar verde
4. Voltar e tocar no **sininho** pra ligar as notificações

Nos celulares Samsung, deixar o app como **Irrestrito** na bateria:
Configurações → Bateria → Limites de uso em segundo plano.

---

## Rodar sozinho junto com o Windows

Agendador de Tarefas → **Criar Tarefa** (não a básica).

- **Geral:** marcar "Executar estando o usuário conectado ou não"
  e "Executar com privilégios mais altos"
- **Disparadores:** Ao iniciar o computador, atrasar 30 segundos
- **Ações:** programa `C:\Users\Nordeste\Documents\back_end\vality_servico.bat`
  e, no campo **Iniciar em**, `C:\Users\Nordeste\Documents\back_end`
- **Condições:** desmarcar "somente se estiver ligado na fonte"
- **Configurações:** reiniciar a cada 1 minuto, até 3 tentativas

O campo **Iniciar em** é o mais importante. Sem ele o SQLite cria um
`estoque.db` vazio em outro lugar e parece que os produtos sumiram.

---

## Backup

O banco inteiro é o arquivo `estoque.db` na pasta do backend.
Copiar esse arquivo é o backup completo. Vale fazer isso antes de
qualquer atualização de código.

Pra achar bancos duplicados no PC:
```
dir /s C:\Users\Nordeste\estoque.db
```
O que tiver data mais recente é o que está em uso.
