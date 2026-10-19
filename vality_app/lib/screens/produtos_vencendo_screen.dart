import 'package:flutter/material.dart';

import '../models/lote.dart';
import '../models/produto.dart';
import '../services/api_service.dart';
import '../services/notificacao_service.dart';
import 'configuracao_screen.dart';
import 'detalhe_produto_screen.dart';
import 'scanner_screen.dart';

/// Aba Vencendo: só o que precisa de atenção nos próximos 14 dias.
/// O cadastro e o catálogo ficam na aba Produtos.
class ProdutosVencendoScreen extends StatefulWidget {
  const ProdutosVencendoScreen({super.key});

  @override
  State<ProdutosVencendoScreen> createState() => ProdutosVencendoScreenState();
}

class ProdutosVencendoScreenState extends State<ProdutosVencendoScreen> {
  final ApiService _api = ApiService();

  bool _carregando = true;
  String? _erro;
  List<Lote> _lotes = [];
  Map<int, Produto> _produtosPorId = {};

  final int _janelaDias = NotificacaoService.janelaDias;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  /// Chamado de fora (pela HomeScreen) quando a aba volta a ficar visível.
  void recarregar() => _carregar();

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final produtos = await _api.listarProdutos();
      final lotes = await _api.lotesVencendo(dias: _janelaDias);
      lotes.sort((a, b) => a.diasParaVencer.compareTo(b.diasParaVencer));

      setState(() {
        _produtosPorId = {for (final p in produtos) p.id: p};
        _lotes = lotes;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _abrirConfiguracoes() async {
    final mudou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracaoScreen()),
    );
    if (mudou == true) _carregar();
  }

  /// Bipa o produto e abre a tela dele com validades, custo e ações.
  Future<void> _biparEAbrirProduto() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    Produto? achado;
    try {
      final todos = await _api.listarProdutos();
      for (final p in todos) {
        if (p.codigoBarras == codigo) {
          achado = p;
          break;
        }
      }
    } catch (_) {
      // sem conexão: cai no aviso abaixo
    }

    if (!mounted) return;

    if (achado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produto não cadastrado (código $codigo).'),
        ),
      );
      return;
    }

    final mudou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetalheProdutoScreen(produto: achado!)),
    );
    if (mudou == true) _carregar();
  }

  Future<void> _alternarNotificacoes() async {
    final ligado = await NotificacaoService.alternar();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ligado
              ? 'Notificações ligadas — checagem diária às 13h.'
              : 'Notificações desligadas.',
        ),
        action: ligado
            ? SnackBarAction(
                label: 'Testar',
                onPressed: () =>
                    NotificacaoService.verificarEAvisar(forcar: true),
              )
            : null,
      ),
    );
  }

  Future<void> _darBaixa(Lote lote, String tipo, String nomeProduto) async {
    final ehPerda = tipo == 'saida_perda';
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ehPerda ? 'Registrar perda' : 'Registrar venda'),
        content: Text(
          ehPerda
              ? 'Dar baixa de ${lote.quantidadeAtual} unidade(s) de '
                  '"$nomeProduto" como PERDA?\n\nO valor vai entrar no '
                  'prejuízo do painel.'
              : 'Dar baixa de ${lote.quantidadeAtual} unidade(s) de '
                  '"$nomeProduto" como VENDIDO?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    try {
      await _api.registrarSaida(
        loteId: lote.id,
        quantidade: lote.quantidadeAtual,
        tipo: tipo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ehPerda ? 'Perda registrada.' : 'Venda registrada.'),
        ),
      );
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  Future<void> _excluir(Lote lote, String nomeProduto) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lote'),
        content: Text(
          'Apagar de vez o lote de "$nomeProduto"?\n\n'
          'Use isso só se o cadastro foi feito errado. Se o produto '
          'venceu ou foi vendido, registre a baixa — assim o histórico '
          'do painel continua certo.',
        ),
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
    if (confirmou != true) return;

    try {
      await _api.excluirLote(lote.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lote excluído.')),
      );
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  Color _corPorUrgencia(Lote lote) {
    if (lote.vencido) return Colors.red.shade100;
    if (lote.diasParaVencer <= 3) return Colors.orange.shade100;
    if (lote.diasParaVencer <= 7) return Colors.amber.shade50;
    return Colors.yellow.shade50;
  }

  String _textoValidade(Lote lote) {
    final d = lote.diasParaVencer;
    if (d < 0) return 'Venceu há ${-d} dia(s)';
    if (d == 0) return 'Vence hoje';
    if (d == 1) return 'Vence amanhã';
    return 'Vence em $d dias';
  }

  @override
  Widget build(BuildContext context) {
    final notifOn = NotificacaoService.ativo;
    return Scaffold(
      appBar: AppBar(
        // Título curto de propósito: com os três botões de ação ao lado,
        // "Produtos vencendo" era truncado em tela de celular.
        title: const Text('Vencendo'),
        actions: [
          IconButton(
            icon: Icon(
              notifOn ? Icons.notifications_active : Icons.notifications_off,
            ),
            onPressed: _alternarNotificacoes,
            tooltip: notifOn ? 'Desligar notificações' : 'Ligar notificações',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _abrirConfiguracoes,
            tooltip: 'Configurações',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _construirCorpo(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _biparEAbrirProduto,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Bipar produto'),
      ),
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
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Não consegui falar com o servidor.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _abrirConfiguracoes,
                    icon: const Icon(Icons.settings),
                    label: const Text('Configurar servidor'),
                  ),
                  ElevatedButton(
                    onPressed: _carregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_lotes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum produto vencendo nos próximos 14 dias. 🎉',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: _lotes.length,
        itemBuilder: (context, index) {
          final lote = _lotes[index];
          final produto = _produtosPorId[lote.produtoId];
          final nome = produto?.nome ?? 'Produto #${lote.produtoId}';

          return Card(
            color: _corPorUrgencia(lote),
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  title: Text(
                    nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_textoValidade(lote)),
                      Text('Quantidade: ${lote.quantidadeAtual}'),
                      if (lote.fornecedor != null)
                        Text('Fornecedor: ${lote.fornecedor}'),
                    ],
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${lote.dataValidade.day.toString().padLeft(2, '0')}/'
                        '${lote.dataValidade.month.toString().padLeft(2, '0')}/'
                        '${lote.dataValidade.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        onSelected: (op) {
                          if (op == 'excluir') _excluir(lote, nome);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'excluir',
                            child: Text('Excluir lote (cadastro errado)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _darBaixa(lote, 'saida_perda', nome),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Perdi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _darBaixa(lote, 'saida_venda', nome),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Vendi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
