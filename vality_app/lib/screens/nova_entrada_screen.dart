import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../services/api_service.dart';
import 'scanner_screen.dart';

/// Registra entrada de mercadoria: escolhe um produto existente ou
/// cadastra um novo, e cria o lote com a data de validade.
class NovaEntradaScreen extends StatefulWidget {
  const NovaEntradaScreen({super.key});

  @override
  State<NovaEntradaScreen> createState() => _NovaEntradaScreenState();
}

class _NovaEntradaScreenState extends State<NovaEntradaScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  bool _carregandoProdutos = true;
  bool _salvando = false;
  String? _erro;

  List<Produto> _produtos = [];

  bool _produtoNovo = true;
  Produto? _produtoSelecionado;

  final _nomeCtrl = TextEditingController();
  final _codigoBarrasCtrl = TextEditingController();
  final _quantidadeCtrl = TextEditingController();
  final _fornecedorCtrl = TextEditingController();
  final _precoCustoCtrl = TextEditingController();
  DateTime? _dataValidade;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _codigoBarrasCtrl.dispose();
    _quantidadeCtrl.dispose();
    _fornecedorCtrl.dispose();
    _precoCustoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    try {
      final produtos = await _api.listarProdutos();
      setState(() {
        _produtos = produtos;
        _produtoNovo = produtos.isEmpty;
        _carregandoProdutos = false;
      });
    } catch (e) {
      setState(() {
        _erro = e.toString();
        _carregandoProdutos = false;
      });
    }
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: hoje.add(const Duration(days: 14)),
      firstDate: hoje.subtract(const Duration(days: 365)),
      lastDate: hoje.add(const Duration(days: 365 * 5)),
      helpText: 'Data de validade',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      fieldLabelText: 'Digite a data',
      fieldHintText: 'dd/mm/aaaa',
    );
    if (escolhida != null) {
      setState(() => _dataValidade = escolhida);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataValidade == null) {
      _mostrarMsg('Escolha a data de validade.');
      return;
    }

    setState(() => _salvando = true);
    String nomeSalvo = '';
    try {
      int produtoId;

      if (_produtoNovo) {
        final novo = await _api.criarProduto(
          nome: _nomeCtrl.text.trim(),
          codigoBarras: _codigoBarrasCtrl.text.trim().isEmpty
              ? null
              : _codigoBarrasCtrl.text.trim(),
        );
        produtoId = novo.id;
        nomeSalvo = novo.nome;
      } else {
        produtoId = _produtoSelecionado!.id;
        nomeSalvo = _produtoSelecionado!.nome;
      }

      final quantidade = int.parse(_quantidadeCtrl.text.trim());

      await _api.criarLote(
        produtoId: produtoId,
        quantidade: quantidade,
        dataValidade: _dataValidade!,
        fornecedor: _fornecedorCtrl.text.trim().isEmpty
            ? null
            : _fornecedorCtrl.text.trim(),
        precoCusto: _precoCustoCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_precoCustoCtrl.text.trim().replaceAll(',', '.')),
      );

      if (!mounted) return;
      await _mostrarSucesso(nomeSalvo, quantidade);
    } catch (e) {
      _mostrarMsg('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Confirmação visual clara de que deu certo — sem isso fica aquela
  /// dúvida de "será que salvou?", principalmente quando o produto não
  /// aparece na lista de vencendo por estar longe do vencimento.
  Future<void> _mostrarSucesso(String nomeProduto, int quantidade) async {
    final data = _dataValidade!;
    final dataBr = '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';

    final maisUm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
        title: const Text('Cadastrado com sucesso!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nomeProduto,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('$quantidade unidade(s)'),
            Text('Validade: $dataBr'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cadastrar outro'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (maisUm == true) {
      // limpa só os campos do lote, mantendo o fluxo rápido
      _nomeCtrl.clear();
      _codigoBarrasCtrl.clear();
      _quantidadeCtrl.clear();
      _precoCustoCtrl.clear();
      setState(() {
        _dataValidade = null;
        _produtoSelecionado = null;
      });
      _carregarProdutos();
    } else {
      Navigator.pop(context, true);
    }
  }

  void _mostrarMsg(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    Produto? existente;
    for (final p in _produtos) {
      if (p.codigoBarras == codigo) {
        existente = p;
        break;
      }
    }

    if (existente != null) {
      setState(() {
        _produtoNovo = false;
        _produtoSelecionado = existente;
      });
      _mostrarMsg('Produto reconhecido: ${existente.nome}');
    } else {
      setState(() {
        _produtoNovo = true;
        _codigoBarrasCtrl.text = codigo;
      });
      _mostrarMsg('Código lido: $codigo');
    }
  }

  String get _dataFormatada {
    if (_dataValidade == null) return 'Toque pra escolher';
    final d = _dataValidade!;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova entrada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _escanear,
            tooltip: 'Escanear código de barras',
          ),
        ],
      ),
      body: _carregandoProdutos
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(child: Text('Erro: $_erro'))
              : _construirFormulario(),
    );
  }

  Widget _construirFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_produtos.isNotEmpty)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Produto existente')),
                  ButtonSegment(value: true, label: Text('Produto novo')),
                ],
                selected: {_produtoNovo},
                onSelectionChanged: (s) => setState(() => _produtoNovo = s.first),
              ),
            const SizedBox(height: 16),

            if (_produtoNovo) ..._camposProdutoNovo() else _dropdownProdutos(),

            const Divider(height: 32),
            Text('Dados do lote', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            TextFormField(
              controller: _quantidadeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe a quantidade';
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) return 'Quantidade inválida';
                return null;
              },
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: _escolherData,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Validade *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                  helperText: 'Formato dia/mês/ano',
                ),
                child: Text(_dataFormatada),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _fornecedorCtrl,
              decoration: const InputDecoration(
                labelText: 'Fornecedor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _precoCustoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preço de custo (R\$)',
                border: OutlineInputBorder(),
                hintText: 'Ex: 4,50',
                helperText: 'Alimenta o painel financeiro',
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_salvando ? 'Salvando...' : 'Registrar entrada'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _camposProdutoNovo() {
    return [
      TextFormField(
        controller: _nomeCtrl,
        decoration: const InputDecoration(
          labelText: 'Nome do produto *',
          border: OutlineInputBorder(),
        ),
        validator: (v) {
          if (_produtoNovo && (v == null || v.trim().isEmpty)) {
            return 'Informe o nome do produto';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _codigoBarrasCtrl,
        decoration: const InputDecoration(
          labelText: 'Código de barras',
          border: OutlineInputBorder(),
          hintText: 'Toque no ícone acima pra ler pela câmera',
        ),
      ),
    ];
  }

  Widget _dropdownProdutos() {
    return DropdownButtonFormField<Produto>(
      initialValue: _produtoSelecionado,
      decoration: const InputDecoration(
        labelText: 'Produto *',
        border: OutlineInputBorder(),
      ),
      items: _produtos
          .map((p) => DropdownMenuItem(value: p, child: Text(p.nome)))
          .toList(),
      onChanged: (p) => setState(() => _produtoSelecionado = p),
      validator: (v) {
        if (!_produtoNovo && v == null) return 'Escolha um produto';
        return null;
      },
    );
  }
}
