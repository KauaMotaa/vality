import 'package:flutter/material.dart';

import '../models/lote.dart';
import '../services/api_service.dart';
import '../services/notificacao_service.dart';

/// Painel financeiro do estoque. Cruza validade + preço de custo dos lotes
/// pra mostrar, em dinheiro: o que está em risco (vencendo), o que já
/// venceu com estoque parado (prejuízo iminente), e o total investido.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  // Mesma janela usada pela tela de alertas e pelas notificações.
  // Deixar valores diferentes aqui fazia o painel dizer "7 dias"
  // enquanto a aba Vencendo mostrava 14 — confuso pra quem usa.
  static const int _janelaDias = NotificacaoService.janelaDias;

  bool _carregando = true;
  String? _erro;

  double _valorEmRisco = 0; // vencendo nos próximos dias, ainda dá pra salvar
  double _valorVencido = 0; // já venceu mas continua no estoque = prejuízo
  double _valorEmEstoque = 0; // total investido em mercadoria
  int _qtdEmRisco = 0;
  int _qtdVencidos = 0;
  int _lotesSemCusto = 0; // não entram na conta — aviso de honestidade

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lotes = await _api.listarLotes();

      double risco = 0, vencido = 0, estoque = 0;
      int qRisco = 0, qVenc = 0, semCusto = 0;

      for (final l in lotes) {
        if (l.quantidadeAtual <= 0) continue;

        if (l.precoCusto == null) {
          semCusto++;
          continue; // sem custo cadastrado não dá pra calcular dinheiro
        }

        final valor = l.quantidadeAtual * l.precoCusto!;
        estoque += valor;

        if (l.vencido) {
          vencido += valor;
          qVenc++;
        } else if (l.diasParaVencer <= _janelaDias) {
          risco += valor;
          qRisco++;
        }
      }

      setState(() {
        _valorEmRisco = risco;
        _valorVencido = vencido;
        _valorEmEstoque = estoque;
        _qtdEmRisco = qRisco;
        _qtdVencidos = qVenc;
        _lotesSemCusto = semCusto;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  String _moeda(double v) {
    final neg = v < 0;
    final s = v.abs().toStringAsFixed(2);
    final partes = s.split('.');
    var inteiro = partes[0];
    final centavos = partes[1];
    // insere ponto de milhar
    inteiro = inteiro.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    return '${neg ? '-' : ''}R\$ $inteiro,$centavos';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel financeiro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _construirCorpo(),
    );
  }

  Widget _construirCorpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não consegui carregar o painel.'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _carregar, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cartao(
            titulo: 'Em risco (próximos $_janelaDias dias)',
            valor: _moeda(_valorEmRisco),
            legenda: '$_qtdEmRisco lote(s) vencendo — dá pra salvar',
            cor: Colors.orange,
            icone: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 12),
          _cartao(
            titulo: 'Já vencido no estoque',
            valor: _moeda(_valorVencido),
            legenda: '$_qtdVencidos lote(s) vencido(s) — prejuízo a evitar',
            cor: Colors.red,
            icone: Icons.money_off,
          ),
          const SizedBox(height: 12),
          _cartao(
            titulo: 'Total investido em estoque',
            valor: _moeda(_valorEmEstoque),
            legenda: 'Valor de custo da mercadoria em estoque',
            cor: Colors.teal,
            icone: Icons.inventory_2,
          ),
          if (_lotesSemCusto > 0) ...[
            const SizedBox(height: 16),
            Text(
              '* $_lotesSemCusto lote(s) sem preço de custo cadastrado não '
              'entram no cálculo. Cadastre o custo na entrada pra deixar os '
              'números completos.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cartao({
    required String titulo,
    required String valor,
    required String legenda,
    required Color cor,
    required IconData icone,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: cor.withValues(alpha: 0.15),
              child: Icon(icone, color: cor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    valor,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(legenda, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
