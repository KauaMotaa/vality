import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'produtos_vencendo_screen.dart';
import 'produtos_screen.dart';

/// Casca do app com a navegação principal.
///
/// Três abas: o que precisa de atenção (Vencendo), o catálogo com
/// cadastro e entrada (Produtos) e os números (Painel). Assim a barra
/// de cima fica limpa e cada tela cuida de uma coisa só.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _aba = 0;

  // chaves pra conseguir mandar cada aba recarregar quando necessário
  final _chaveVencendo = GlobalKey<ProdutosVencendoScreenState>();
  final _chaveProdutos = GlobalKey<ProdutosScreenState>();

  late final List<Widget> _telas = [
    ProdutosVencendoScreen(key: _chaveVencendo),
    ProdutosScreen(key: _chaveProdutos),
    const DashboardScreen(),
  ];

  void _trocarAba(int i) {
    setState(() => _aba = i);
    // ao voltar pra uma aba, atualiza os dados
    if (i == 0) _chaveVencendo.currentState?.recarregar();
    if (i == 1) _chaveProdutos.currentState?.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _aba, children: _telas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: _trocarAba,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber_rounded),
            label: 'Vencendo',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Produtos',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Painel',
          ),
        ],
      ),
    );
  }
}
