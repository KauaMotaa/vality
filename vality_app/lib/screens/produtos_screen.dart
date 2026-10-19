import 'package:flutter/material.dart';

import '../models/lote.dart';
import '../models/produto.dart';
import '../services/api_service.dart';
import 'detalhe_produto_screen.dart';
import 'nova_entrada_screen.dart';
import 'scanner_screen.dart';

/// Aba Produtos: o catálogo completo (não só o que está vencendo), com
/// busca, leitura de código de barras e o botão de registrar entrada.
/// Juntar "ver" e "cadastrar" num lugar só deixa a navegação mais simples.
class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => ProdutosScreenState();
}

class ProdutosScreenState extends State<ProdutosScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _buscaCtrl = TextEditingController();

  bool _carregando = true;
  String? _erro;
  List<Produto> _produtos = [];
  Map<int, List<Lote>> _lotesPorProduto = {};
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
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
      final lotes = await _api.listarLotes();

      final mapa = <int, List<Lote>>{};
      for (final lote in lotes) {
        mapa.putIfAbsent(lote.produtoId, () => []).add(lote);
      }
      for (final lista in mapa.values) {
        lista.sort((a, b) => a.dataValidade.compareTo(b.dataValidade));
      }

      setState(() {
        _produtos = produtos;
        _lotesPorProduto = mapa;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _novaEntrada() async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NovaEntradaScreen()),
    );
    if (salvou == true) _carregar();
  }

  /// Bipa e abre direto o produto. Se não existir, oferece cadastrar.
  Future<void> _biparProduto() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    Produto? achado;
    for (final p in _produtos) {
      if (p.codigoBarras == codigo) {
        achado = p;
        break;
      }
    }

    if (achado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produto não cadastrado (código $codigo).'),
          action: SnackBarAction(label: 'Cadastrar', onPressed: _novaEntrada),
        ),
      );
      return;
    }

    await _abrirDetalhe(achado);
  }

  Future<void> _abrirDetalhe(Produto produto) async {
    final mudou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetalheProdutoScreen(produto: produto)),
    );
    if (mudou == true) _carregar();
  }

  List<Produto> get _filtrados {
    if (_busca.trim().isEmpty) return _produtos;
    final termo = _busca.toLowerCase().trim();
    return _produtos.where((p) {
      return p.nome.toLowerCase().contains(termo) ||
          (p.categoria ?? '').toLowerCase().contains(termo) ||
          (p.codigoBarras ?? '').toLowerCase().contains(termo);
    }).toList();
  }

  int _totalEmEstoque(int produtoId) {
    final lotes = _lotesPorProduto[produtoId] ?? [];
    return lotes.fold(0, (s, l) => s + l.quantidadeAtual);
  }

  /// Validade mais próxima entre os lotes com estoque.
  Lote? _loteMaisUrgente(int produtoId) {
    final lotes = (_lotesPorProduto[produtoId] ?? [])
        .where((l) => l.quantidadeAtual > 0)
        .toList();
    if (lotes.isEmpty) return null;
    lotes.sort((a, b) => a.dataValidade.compareTo(b.dataValidade));
    return lotes.first;
  }

  String _dataBr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _buscaCtrl,
              onChanged: (v) => setState(() => _busca = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nome, categoria ou código',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_busca.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscaCtrl.clear();
                          setState(() => _busca = '');
                        },
                        tooltip: 'Limpar',
                      ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _biparProduto,
                      tooltip: 'Bipar código de barras',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _construirCorpo()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novaEntrada,
        icon: const Icon(Icons.add),
        label: const Text('Nova entrada'),
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
              const Text('Não consegui falar com o servidor.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _carregar,
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }

    if (_produtos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum produto cadastrado ainda.\n'
            'Toque em "Nova entrada" para começar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final lista = _filtrados;
    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nenhum produto encontrado para "$_busca".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final produto = lista[index];
          final total = _totalEmEstoque(produto.id);
          final urgente = _loteMaisUrgente(produto.id);

          Color? corValidade;
          String subtitulo;
          if (urgente == null) {
            subtitulo = 'Sem estoque';
          } else {
            subtitulo = 'Vence ${_dataBr(urgente.dataValidade)}';
            if (urgente.vencido) {
              corValidade = Colors.red.shade700;
            } else if (urgente.diasParaVencer <= 14) {
              corValidade = Colors.orange.shade800;
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _abrirDetalhe(produto),
              title: Text(
                produto.nome,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                subtitulo,
                style: TextStyle(fontSize: 13, color: corValidade),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    produto.unidadeMedida,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
