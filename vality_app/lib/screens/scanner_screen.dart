import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Tela da câmera pra ler código de barras. Quando detecta um código,
/// fecha e devolve a string lida pra tela anterior via Navigator.pop.
///
/// O [errorBuilder] existe de propósito: sem ele, o mobile_scanner mostra
/// só um "!" e a gente fica sem saber se o problema é permissão, câmera
/// ocupada por outro app ou falha de inicialização.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    // código de barras de produto é 1D; manter só esses formatos deixa a
    // leitura mais rápida e evita ler QR de propaganda por engano
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.itf,
    ],
  );

  // trava pra não disparar o pop várias vezes (a câmera detecta em rajada)
  bool _jaDetectou = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Quando o app vai pro fundo, o Android solta a câmera. Sem reiniciar
  /// na volta, a tela fica preta.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _aoDetectar(BarcodeCapture captura) {
    if (_jaDetectou) return;
    if (captura.barcodes.isEmpty) return;

    final codigo = captura.barcodes.first.rawValue;
    if (codigo == null || codigo.isEmpty) return;

    _jaDetectou = true;
    Navigator.pop(context, codigo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear código'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Lanterna',
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _aoDetectar,
            errorBuilder: (context, erro) => _MensagemDeErro(erro: erro),
          ),
          // moldura visual pra ajudar o usuário a mirar
          IgnorePointer(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 48,
            child: Text(
              'Aponte pro código de barras',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                backgroundColor: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mostra o motivo real da falha em vez do "!" padrão do pacote.
class _MensagemDeErro extends StatelessWidget {
  const _MensagemDeErro({required this.erro});

  final MobileScannerException erro;

  String get _texto {
    switch (erro.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Sem permissão de câmera.\n\n'
            'Vá em Configurações → Aplicativos → Vality → '
            'Permissões → Câmera e autorize.';
      case MobileScannerErrorCode.unsupported:
        return 'Este aparelho não suporta a leitura de código.';
      case MobileScannerErrorCode.controllerUninitialized:
        return 'A câmera não chegou a iniciar. Feche o app por completo '
            'e abra de novo.';
      default:
        return 'Não consegui abrir a câmera.\n\n'
            'Detalhe técnico: ${erro.errorCode}\n'
            '${erro.errorDetails?.message ?? ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white70, size: 56),
              const SizedBox(height: 20),
              Text(
                _texto,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
