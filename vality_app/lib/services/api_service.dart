import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/lote.dart';
import '../models/produto.dart';

/// Toda conversa com o backend passa por aqui. A UI nunca chama http
/// direto — ela chama o ApiService. Isso mantém as telas limpas e, se um
/// dia a API mudar, você conserta num lugar só.
class ApiService {
  Future<List<Produto>> listarProdutos() async {
    final resposta = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.produtos}'),
    );
    if (resposta.statusCode != 200) {
      throw Exception('Erro ao listar produtos (${resposta.statusCode})');
    }
    final List<dynamic> dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    return dados.map((e) => Produto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Lote>> lotesVencendo({int dias = 14}) async {
    final resposta = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.alertasVencendo}?dias=$dias'),
    );
    if (resposta.statusCode != 200) {
      throw Exception('Erro ao buscar alertas (${resposta.statusCode})');
    }
    final List<dynamic> dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    return dados.map((e) => Lote.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Todos os lotes (usado pelo dashboard pra calcular os totais em dinheiro).
  Future<List<Lote>> listarLotes() async {
    final resposta = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.lotes}'),
    );
    if (resposta.statusCode != 200) {
      throw Exception('Erro ao listar lotes (${resposta.statusCode})');
    }
    final List<dynamic> dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    return dados.map((e) => Lote.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Produto> criarProduto({
    required String nome,
    String? codigoBarras,
    String? categoria,
    String unidadeMedida = 'un',
    int estoqueMinimo = 0,
  }) async {
    final resposta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.produtos}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nome': nome,
        'codigo_barras': codigoBarras,
        'categoria': categoria,
        'unidade_medida': unidadeMedida,
        'estoque_minimo': estoqueMinimo,
      }),
    );
    if (resposta.statusCode != 201) {
      throw Exception('Erro ao criar produto (${resposta.statusCode})');
    }
    return Produto.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  /// Registra uma entrada de mercadoria (novo lote) pra um produto que já
  /// existe. A validade vai no formato YYYY-MM-DD, que é o que o backend espera.
  Future<void> criarLote({
    required int produtoId,
    required int quantidade,
    required DateTime dataValidade,
    String? fornecedor,
    double? precoCusto,
  }) async {
    final dataStr = '${dataValidade.year.toString().padLeft(4, '0')}-'
        '${dataValidade.month.toString().padLeft(2, '0')}-'
        '${dataValidade.day.toString().padLeft(2, '0')}';

    final resposta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.produtos}/$produtoId/lotes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'quantidade_atual': quantidade,
        'data_validade': dataStr,
        'fornecedor': fornecedor,
        'preco_custo': precoCusto?.toStringAsFixed(2),
      }),
    );
    if (resposta.statusCode != 201) {
      throw Exception('Erro ao registrar entrada (${resposta.statusCode})');
    }
  }

  /// Dá baixa no lote. tipo: 'saida_perda' (produto perdido) ou
  /// 'saida_venda' (conseguiu vender). Zerando a quantidade, o lote
  /// some sozinho da lista de alertas — sem apagar o histórico.
  Future<void> registrarSaida({
    required int loteId,
    required int quantidade,
    required String tipo,
  }) async {
    final resposta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.lotes}/$loteId/saida'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'quantidade': quantidade,
        'origem': 'manual',
        'tipo': tipo,
      }),
    );
    if (resposta.statusCode != 200) {
      throw Exception('Erro ao registrar saída (${resposta.statusCode})');
    }
  }

  /// Apaga o lote de vez — use só pra corrigir cadastro errado.
  Future<void> excluirLote(int loteId) async {
    final resposta = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.lotes}/$loteId'),
    );
    if (resposta.statusCode != 204 && resposta.statusCode != 200) {
      throw Exception('Erro ao excluir lote (${resposta.statusCode})');
    }
  }

  /// Todos os lotes de um produto, INCLUSIVE os já zerados — é o que a
  /// tela de detalhe usa pra deixar apagar lote antigo.
  Future<List<Lote>> lotesDoProduto(int produtoId) async {
    final resposta = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.produtos}/$produtoId/lotes'),
    );
    if (resposta.statusCode != 200) {
      throw Exception('Erro ao listar lotes (${resposta.statusCode})');
    }
    final List<dynamic> dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    return dados.map((e) => Lote.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Apaga o produto e todos os lotes dele.
  ///
  /// Sem `forcar`, o backend recusa com 409 se ainda houver estoque —
  /// a tela usa isso pra mostrar o aviso antes de insistir.
  /// Retorna a quantidade em estoque quando é recusado, ou null se apagou.
  Future<int?> excluirProduto(int produtoId, {bool forcar = false}) async {
    final resposta = await http.delete(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.produtos}/$produtoId'
        '${forcar ? '?forcar=true' : ''}',
      ),
    );

    if (resposta.statusCode == 204 || resposta.statusCode == 200) {
      return null; // apagou
    }

    if (resposta.statusCode == 409) {
      // o backend informa quantas unidades ainda tem
      final corpo = utf8.decode(resposta.bodyBytes);
      final numero = RegExp(r'(\d+)').firstMatch(corpo);
      return numero != null ? int.parse(numero.group(1)!) : 0;
    }

    throw Exception('Erro ao excluir produto (${resposta.statusCode})');
  }
}
