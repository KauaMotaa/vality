/// Espelha o schema ProdutoRead do backend FastAPI.
class Produto {
  final int id;
  final String nome;
  final String? codigoBarras;
  final String? categoria;
  final String unidadeMedida;
  final int estoqueMinimo;
  final bool ativo;

  Produto({
    required this.id,
    required this.nome,
    this.codigoBarras,
    this.categoria,
    required this.unidadeMedida,
    required this.estoqueMinimo,
    required this.ativo,
  });

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      id: json['id'] as int,
      nome: json['nome'] as String,
      codigoBarras: json['codigo_barras'] as String?,
      categoria: json['categoria'] as String?,
      unidadeMedida: json['unidade_medida'] as String? ?? 'un',
      estoqueMinimo: json['estoque_minimo'] as int? ?? 0,
      ativo: json['ativo'] as bool? ?? true,
    );
  }
}
