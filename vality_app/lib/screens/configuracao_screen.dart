import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Permite trocar o endereço do servidor sem gerar um APK novo.
/// Tem um "Testar conexão" pra confirmar antes de salvar — assim dá pra
/// descobrir na hora se o IP está errado ou se o backend não está ligado.
class ConfiguracaoScreen extends StatefulWidget {
  const ConfiguracaoScreen({super.key});

  @override
  State<ConfiguracaoScreen> createState() => _ConfiguracaoScreenState();
}

class _ConfiguracaoScreenState extends State<ConfiguracaoScreen> {
  late final TextEditingController _urlCtrl;
  bool _testando = false;
  String? _resultado;
  bool _sucesso = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testar() async {
    setState(() {
      _testando = true;
      _resultado = null;
    });

    final url = ApiConfig.normalizar(_urlCtrl.text);
    try {
      final resposta = await http
          .get(Uri.parse('$url${ApiConfig.produtos}'))
          .timeout(const Duration(seconds: 8));

      if (resposta.statusCode == 200) {
        final List<dynamic> dados = jsonDecode(utf8.decode(resposta.bodyBytes));
        setState(() {
          _sucesso = true;
          _resultado = 'Conectou! ${dados.length} produto(s) cadastrado(s).';
        });
      } else {
        setState(() {
          _sucesso = false;
          _resultado = 'O servidor respondeu ${resposta.statusCode}.';
        });
      }
    } catch (e) {
      setState(() {
        _sucesso = false;
        _resultado = 'Não conectou. Confira se o backend está ligado e se o '
            'celular está no mesmo Wi-Fi do PC.';
      });
    } finally {
      if (mounted) setState(() => _testando = false);
    }
  }

  Future<void> _salvar() async {
    await ApiConfig.salvar(_urlCtrl.text);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Endereço do servidor',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'É o IP do computador onde o sistema está rodando. '
              'Para descobrir, rode "ipconfig" nesse PC e veja o '
              'Endereço IPv4.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Servidor',
                border: OutlineInputBorder(),
                hintText: '192.168.0.15:8000',
                helperText: 'Se faltar http:// ou a porta, o app completa.',
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testando ? null : _testar,
                    icon: _testando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(_testando ? 'Testando...' : 'Testar conexão'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _salvar,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar'),
                  ),
                ),
              ],
            ),

            if (_resultado != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _sucesso ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _sucesso ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sucesso ? Icons.check_circle : Icons.error_outline,
                      color: _sucesso ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_resultado!)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
