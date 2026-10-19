import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/api_config.dart';
import 'screens/home_screen.dart';
import 'services/notificacao_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // carrega o endereço do servidor salvo no celular antes de tudo
  await ApiConfig.carregar();
  await NotificacaoService.inicializar();

  runApp(const ValityApp());

  // IMPORTANTE: sem await, e depois do runApp.
  // O agendamento faz chamada de rede. Se ficasse antes, com o servidor
  // fora do ar ou IP errado o app travava na tela de abertura, porque
  // nenhuma tela chega a ser desenhada enquanto isso não termina.
  NotificacaoService.agendarLembreteDiario();
}

class ValityApp extends StatelessWidget {
  const ValityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vality',
      debugShowCheckedModeBanner: false,

      // Deixa o app inteiro em português do Brasil: o calendário vem com
      // os meses e dias traduzidos e no formato dia/mês/ano.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
