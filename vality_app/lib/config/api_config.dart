import 'package:shared_preferences/shared_preferences.dart';

/// Endereço do backend, agora configurável pelo próprio app.
///
/// Antes esse valor era fixo no código, então toda vez que o IP do PC
/// mudava era preciso gerar um APK novo. Agora ele fica salvo no celular
/// e pode ser trocado na tela de Configurações.
class ApiConfig {
  static const String _chave = 'base_url';

  /// Usado só na primeira abertura, antes de o usuário configurar.
  static const String padrao = 'http://192.168.10.100:8000';

  static String _baseUrl = padrao;

  /// Endereço em uso. Leia sempre por aqui.
  static String get baseUrl => _baseUrl;

  /// Chame uma vez no início do app (antes do runApp).
  static Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_chave) ?? padrao;
  }

  /// Salva o novo endereço no celular e passa a usá-lo na hora.
  static Future<void> salvar(String url) async {
    final limpo = normalizar(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, limpo);
    _baseUrl = limpo;
  }

  /// Conserta os erros comuns de digitação: falta de http:// e de porta.
  /// Foi exatamente isso que deu o erro "No host specified in URI".
  static String normalizar(String entrada) {
    var url = entrada.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    // se não tem porta depois do host, assume 8000
    final semEsquema = url.replaceFirst(RegExp(r'^https?://'), '');
    if (!semEsquema.contains(':')) {
      url = '$url:8000';
    }
    return url;
  }

  // Endpoints
  static const String produtos = '/produtos';
  static const String lotes = '/lotes';
  static const String alertasVencendo = '/alertas/vencendo';
}
