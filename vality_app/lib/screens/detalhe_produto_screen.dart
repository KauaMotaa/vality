import 'package:flutter/material.dart';

import '../models/lote.dart';
import '../models/produto.dart';
import '../services/api_service.dart';
import 'nova_entrada_screen.dart';

/// Mostra tudo de um produto: lotes em estoque, validades, preço de custo
/// e valor parado. É a tela que abre quando você bipa um código.
///
/// Também é onde se limpa a bagunça: dá pra apagar lote antigo já baixado
/// e, no menu, apagar o produto inteiro (pra aqueles que foram só teste).
class DetalheProdutoScreen extends StatefulWidget {
  final Produto produto;

  const DetalheProdutoScreen({super.key, required this.produto});

  @override
  State<DetalheProdutoScreen> createState() => _DetalheProdutoScreenState();
}

class _DetalheProdutoScreenState extends State<DetalheProdutoScreen> {
  final ApiService _api = ApiService();

  bool _carregando = true;
  String? _erro;
  List<Lote> _comEstoque = [];
  List<Lote> _zerados = [];
  bool _mudouAlgo = false;

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
      List<Lote> meus;
      try {
        // endpoint que traz todos os lotes do produto, inclusive zerados
        meus = await _api.lotesDoProduto(widget.produto.id);
      } catch (_) {
        // se o backend ainda não tiver essa rota, cai pra lista geral
        final todos = await _api.listarLotes();
        meus = todos.where((l) => l.produtoId == widget.produto.id).toList();
      }

      final comEstoque = meus.where((l) => l.quantidadeAtual > 0).toList();
      final zerados = meus.where((l) => l.quantidadeAtual <= 0).toList();

      // FEFO: o que vence primeiro aparece primeiro
      comEstoque.sort((a, b) => a.dataValidade.compareTo(b.dataValidade));
      zerados.sort((a, b) => b.dataValidade.compareTo(a.dataValidade));

      setState(() {
        _comEstoque = comEstoque;
        _zerados = zerados;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _darBaixa(Lote lote, String tipo) async {
    final ehPerda = tipo == 'saida_perda';
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ehPerda ? 'Registrar perda' : 'Registrar venda'),
        content: Text(
          'Dar baixa de ${lote.quantidadeAtual} unidade(s) de '
          '"${widget.produto.nome}" como ${ehPerda ? "PERDA" : "VENDIDO"}?',
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

    await _executar(
      () => _api.registrarSaida(
        loteId: lote.id,
        quantidade: lote.quantidadeAtual,
        tipo: tipo,
      ),
      ehPerda ? 'Perda registrada.' : 'Venda registrada.',
    );
  }

  Future<void> _excluirLote(Lote lote) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lote'),
        content: Text(
          'Apagar de vez o lote com validade '
          '${_dataBr(lote.dataValidade)}?\n\n'
          'Isso remove o lote do histórico — o painel financeiro deixa '
          'de contar o que aconteceu com ele.',
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

    await _executar(() => _api.excluirLote(lote.id), 'Lote excluído.');
  }

  /// Exclui o produto inteiro. Se ainda tiver estoque, o backend recusa e
  /// a gente mostra o aviso antes de insistir.
  Future<void> _excluirProduto() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir produto'),
        content: Text(
          'Apagar "${widget.produto.nome}" e todos os lotes dele?\n\n'
          'Use pra produto que você não vende mais ou que foi só teste. '
          'Essa ação não tem volta.',
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
      final aindaTem = await _api.excluirProduto(widget.produto.id);

      if (aindaTem == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto excluído.')),
        );
        Navigator.pop(context, true);
        return;
      }

      // backend recusou: ainda tem estoque
      if (!mounted) return;
      final insistir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 40),
          title: const Text('Ainda tem estoque!'),
          content: Text(
            '"${widget.produto.nome}" ainda tem $aindaTem unidade(s) '
            'registradas.\n\nSe você já vendeu ou perdeu esse produto, o '
            'certo é dar baixa primeiro — assim o painel fica correto.\n\n'
            'Quer apagar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar assim mesmo'),
            ),
          ],
        ),
      );
      if (insistir != true) return;

      await _api.excluirProduto(widget.produto.id, forcar: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto excluído.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  Future<void> _novaEntradaDesteProduto() async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NovaEntradaScreen()),
    );
    if (salvou == true) {
      _mudouAlgo = true;
      _carregar();
    }
  }

  Future<void> _executar(Future<void> Function() acao, String msgOk) async {
    try {
      await acao();
      _mudouAlgo = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msgOk)),
      );
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  String _moeda(double v) {
    final s = v.toStringAsFixed(2).split('.');
    final inteiro = s[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    return 'R\$ $inteiro,${s[1]}';
  }

  String _dataBr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _textoValidade(Lote lote) {
    final d = lote.diasParaVencer;
    if (d < 0) return 'Venceu há ${-d} dia(s)';
    if (d == 0) return 'Vence hoje';
    if (d == 1) return 'Vence amanhã';
    return 'Vence em $d dias';
  }

  Color _cor(Lote lote) {
    if (lote.vencido) return Colors.red;
    if (lote.diasParaVencer <= 3) return Colors.deepOrange;
    if (lote.diasParaVencer <= 14) return Colors.orange;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    final totalUnidades = _comEstoque.fold(0, (s, l) => s + l.quantidadeAtual);
    final valorTotal = _comEstoque
        .where((l) => l.precoCusto != null)
        .fold(0.0, (s, l) => s + l.quantidadeAtual * l.precoCusto!);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _mudouAlgo);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.nome, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregar,
              tooltip: 'Atualizar',
            ),
            PopupMenuButton<String>(
              onSelected: (op) {
                if (op == 'excluir_produto') _excluirProduto();
                if (op == 'nova_entrada') _novaEntradaDesteProduto();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'nova_entrada',
                  child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('Nova entrada'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'excluir_produto',
                  child: ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red),
                    title: Text('Excluir produto',
                        style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Não consegui carregar.'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _carregar,
                          child: const Text('Tentar de novo'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _cartaoResumo(p, totalUnidades, valorTotal),
                      const SizedBox(height: 16),
                      Text(
                        'Lotes em estoque',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_comEstoque.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'Sem estoque no momento.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ..._comEstoque.map(_cartaoLote),
                      if (_zerados.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _historicoZerados(),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _cartaoResumo(Produto p, int totalUnidades, double valorTotal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.nome,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (p.categoria != null) ...[
              const SizedBox(height: 4),
              Text(p.categoria!, style: const TextStyle(color: Colors.grey)),
            ],
            if (p.codigoBarras != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.qr_code, size: 18),
                  const SizedBox(width: 6),
                  Text(p.codigoBarras!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$totalUnidades',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'em estoque (${p.unidadeMedida})',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      _moeda(valorTotal),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const Text(
                      'valor em custo',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoLote(Lote lote) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, size: 20, color: _cor(lote)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _dataBr(lote.dataValidade),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _cor(lote),
                    ),
                  ),
                ),
                Text(
                  _textoValidade(lote),
                  style: TextStyle(fontSize: 12, color: _cor(lote)),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (op) {
                    if (op == 'excluir') _excluirLote(lote);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir lote'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Quantidade: ${lote.quantidadeAtual}'),
            if (lote.precoCusto != null)
              Text(
                'Custo: ${_moeda(lote.precoCusto!)} cada  •  '
                'Total: ${_moeda(lote.quantidadeAtual * lote.precoCusto!)}',
                style: const TextStyle(fontSize: 13),
              ),
            if (lote.fornecedor != null)
              Text(
                'Fornecedor: ${lote.fornecedor}',
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _darBaixa(lote, 'saida_perda'),
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
                    onPressed: () => _darBaixa(lote, 'saida_venda'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Vendi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Lotes já baixados, recolhidos num expansível pra não poluir a tela.
  /// É daqui que se apaga o histórico antigo quando quiser limpar.
  Widget _historicoZerados() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.history),
        title: Text('Lotes já baixados (${_zerados.length})'),
        subtitle: const Text(
          'Toque pra ver e limpar',
          style: TextStyle(fontSize: 12),
        ),
        children: _zerados
            .map(
              (lote) => ListTile(
                dense: true,
                title: Text(
                  'Validade ${_dataBr(lote.dataValidade)}',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: lote.fornecedor != null
                    ? Text(lote.fornecedor!, style: const TextStyle(fontSize: 11))
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _excluirLote(lote),
                  tooltip: 'Excluir este lote',
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
