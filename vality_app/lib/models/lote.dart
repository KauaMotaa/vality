/// Espelha o schema LoteRead do backend, com uns helpers de validade
/// que a interface usa pra colorir e ordenar.
class Lote {
  final int id;
  final int produtoId;
  final int quantidadeAtual;
  final DateTime dataValidade;
  final DateTime? dataEntrada;
  final String? fornecedor;
  final double? precoCusto;

  Lote({
    required this.id,
    required this.produtoId,
    required this.quantidadeAtual,
    required this.dataValidade,
    this.dataEntrada,
    this.fornecedor,
    this.precoCusto,
  });

  factory Lote.fromJson(Map<String, dynamic> json) {
    return Lote(
      id: json['id'] as int,
      produtoId: json['produto_id'] as int,
      quantidadeAtual: json['quantidade_atual'] as int? ?? 0,
      dataValidade: DateTime.parse(json['data_validade'] as String),
      dataEntrada: json['data_entrada'] != null
          ? DateTime.parse(json['data_entrada'] as String)
          : null,
      fornecedor: json['fornecedor'] as String?,
      // preco_custo pode vir como número ou string dependendo da serialização.
      precoCusto: _parseDecimal(json['preco_custo']),
    );
  }

  static double? _parseDecimal(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }

  /// Dias que faltam pra vencer. Negativo = já venceu.
  int get diasParaVencer {
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final validadeSemHora =
        DateTime(dataValidade.year, dataValidade.month, dataValidade.day);
    return validadeSemHora.difference(hojeSemHora).inDays;
  }

  bool get vencido => diasParaVencer < 0;
}
