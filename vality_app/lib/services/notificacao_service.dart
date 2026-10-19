import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/lote.dart';
import 'api_service.dart';

/// Alerta de validade.
///
/// A decisão de arquitetura mais importante deste arquivo: **não há
/// execução em segundo plano.** Validade é um dado determinístico — se um
/// lote vence dia 30, já sabemos hoje que no dia 23 ele estará a 7 dias de
/// vencer. Então, em vez de acordar o app todo dia pra descobrir isso, o
/// app calcula as datas uma vez e deixa as notificações agendadas no
/// próprio Android.
///
/// Isso elimina a dependência do workmanager (e os problemas de build que
/// vinham junto), deixa de depender do Android acordar o processo, e
/// funciona mesmo com o app fechado há dias.
///
/// O preço: se alguém vender o produto depois do agendamento, o aviso
/// daquele lote ainda dispara. Como [reagendar] roda sempre que a lista é
/// carregada, na prática isso se corrige sozinho no uso diário.
class NotificacaoService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int horaAlerta = 13;
  static const int minutoAlerta = 0;

  /// Janela que a tela de alertas usa.
  static const int janelaDias = 14;

  /// Dias que faltam pra vencer em que o aviso dispara.
  /// 0 = dia do vencimento; -1 = um dia depois (se ninguém deu baixa).
  static const List<int> marcos = [14, 7, 1, 0, -1];

  /// Consultamos uma janela maior que a de alerta: um lote que vence em 25
  /// dias não aparece na tela hoje, mas o aviso de "faltam 14" dele cai
  /// daqui a 11 dias e precisa já estar agendado.
  static const int _janelaConsulta = 35;

  static const int _idTeste = 100;
  static const int _idBase = 1000;
  static const String _chaveAtivo = 'notificacoes_ativas';

  static bool _ativo = true;
  static bool get ativo => _ativo;

  static Future<void> inicializar() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    await _initPlugin();

    final prefs = await SharedPreferences.getInstance();
    _ativo = prefs.getBool(_chaveAtivo) ?? true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static Future<void> _initPlugin() async {
    const config = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(config);
  }

  static Future<bool> alternar() async {
    _ativo = !_ativo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveAtivo, _ativo);

    if (_ativo) {
      await reagendar();
    } else {
      await _plugin.cancelAll();
    }
    return _ativo;
  }

  /// Mantido com o nome antigo pra não quebrar as telas que já chamam isso.
  static Future<void> agendarLembreteDiario() => reagendar();

  /// Recalcula e reagenda todos os avisos futuros.
  ///
  /// Chame sempre que a lista de lotes puder ter mudado: ao abrir o app,
  /// depois de cadastrar entrada, depois de dar baixa.
  static Future<void> reagendar() async {
    if (!_ativo) return;

    try {
      final api = ApiService();
      final lotes = await api.lotesVencendo(dias: _janelaConsulta);
      final produtos = await api.listarProdutos();
      final nomePorId = {for (final p in produtos) p.id: p.nome};

      // só limpamos depois que os dados chegaram — se o servidor estiver
      // fora do ar, o que já estava agendado continua valendo
      await _plugin.cancelAll();
      if (lotes.isEmpty) return;

      final agora = tz.TZDateTime.now(tz.local);

      // um aviso por dia, juntando todos os lotes que caem naquela data
      final porData = <DateTime, List<Lote>>{};

      for (final lote in lotes) {
        final validade = _soData(lote.dataValidade);
        for (final m in marcos) {
          final dia = validade.subtract(Duration(days: m));
          final quando = tz.TZDateTime(
            tz.local,
            dia.year,
            dia.month,
            dia.day,
            horaAlerta,
            minutoAlerta,
          );
          if (!quando.isAfter(agora)) continue; // marco já passou
          porData.putIfAbsent(dia, () => []).add(lote);
        }
      }

      for (final entrada in porData.entries) {
        await _agendarDia(entrada.key, entrada.value, nomePorId);
      }
    } catch (_) {
      // sem rede ou servidor fora do ar: não mexe no que já está agendado
    }
  }

  /// Dispara um aviso agora, com tudo que está vencendo.
  /// Usado pelo botão "Testar" — ignora os marcos de propósito.
  static Future<void> verificarEAvisar({bool forcar = false}) async {
    try {
      final api = ApiService();
      final lotes = await api.lotesVencendo(dias: janelaDias);

      if (lotes.isEmpty) {
        await _mostrarAgora(
          'Nenhum produto vencendo',
          'Nada nos próximos $janelaDias dias. 🎉',
        );
        return;
      }

      final produtos = await api.listarProdutos();
      final nomePorId = {for (final p in produtos) p.id: p.nome};

      lotes.sort((a, b) => a.dataValidade.compareTo(b.dataValidade));

      final titulo = lotes.length == 1
          ? '1 produto precisa de atenção'
          : '${lotes.length} produtos precisam de atenção';
      final corpo = _montarCorpo(_hoje(), lotes, nomePorId);

      await _mostrarAgora(titulo, corpo);
    } catch (_) {
      // servidor fora do ar: silencia
    }
  }

  static Future<void> _mostrarAgora(String titulo, String corpo) async {
    await _plugin.show(_idTeste, titulo, corpo, _detalhes(titulo, corpo));
  }

  static Future<void> _agendarDia(
    DateTime dia,
    List<Lote> lotes,
    Map<int, String> nomePorId,
  ) async {
    lotes.sort((a, b) => a.dataValidade.compareTo(b.dataValidade));

    final titulo = lotes.length == 1
        ? '1 produto precisa de atenção'
        : '${lotes.length} produtos precisam de atenção';
    final corpo = _montarCorpo(dia, lotes, nomePorId);

    final quando = tz.TZDateTime(
      tz.local,
      dia.year,
      dia.month,
      dia.day,
      horaAlerta,
      minutoAlerta,
    );

    await _plugin.zonedSchedule(
      _idDoDia(dia),
      titulo,
      corpo,
      quando,
      _detalhes(titulo, corpo),
      // modo inexato: o Android pode atrasar alguns minutos, mas em troca
      // não precisamos da permissão SCHEDULE_EXACT_ALARM do Android 12+
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static NotificationDetails _detalhes(String titulo, String corpo) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'validade_canal',
        'Alertas de validade',
        channelDescription: 'Avisa quando há produtos perto de vencer',
        importance: Importance.high,
        priority: Priority.high,
        // deixa a notificação expandir e mostrar a lista inteira
        styleInformation: BigTextStyleInformation(corpo, contentTitle: titulo),
      ),
    );
  }

  /// Monta o texto do aviso **na perspectiva da data em que ele vai tocar**,
  /// não de hoje. Por isso recebe [dia]: um aviso agendado pra daqui a uma
  /// semana precisa dizer "vence amanhã", não "vence em 8 dias".
  static String _montarCorpo(
    DateTime dia,
    List<Lote> lotes,
    Map<int, String> nomePorId,
  ) {
    final linhas = <String>[];
    final mostrar = lotes.length > 6 ? 6 : lotes.length;

    for (var i = 0; i < mostrar; i++) {
      final lote = lotes[i];
      final nome = nomePorId[lote.produtoId] ?? 'Produto #${lote.produtoId}';
      final qtd = lote.quantidadeAtual;
      final d = _soData(lote.dataValidade).difference(dia).inDays;

      final String quando;
      if (d < 0) {
        quando = 'VENCIDO há ${-d} dia(s)';
      } else if (d == 0) {
        quando = 'vence HOJE';
      } else if (d == 1) {
        quando = 'vence AMANHÃ';
      } else {
        quando = 'vence em $d dias';
      }

      linhas.add('• $nome ($qtd un) — $quando');
    }

    if (lotes.length > mostrar) {
      linhas.add('… e mais ${lotes.length - mostrar}.');
    }

    return linhas.join('\n');
  }

  /// Id estável e único por data, pra reagendar sempre sobrescrever o
  /// aviso daquele dia em vez de duplicar.
  static int _idDoDia(DateTime dia) =>
      _idBase + dia.difference(DateTime(2020, 1, 1)).inDays;

  static DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _hoje() => _soData(DateTime.now());

  /// Quantos avisos estão na fila — útil pra conferir na tela de
  /// configurações que o agendamento realmente aconteceu.
  static Future<int> avisosAgendados() async {
    final pendentes = await _plugin.pendingNotificationRequests();
    return pendentes.length;
  }
}
