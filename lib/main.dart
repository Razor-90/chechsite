import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Проверка сайтов',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SiteStatusChecker(),
    );
  }
}

class SiteStatusChecker extends StatefulWidget {
  @override
  _SiteStatusCheckerState createState() => _SiteStatusCheckerState();
}

class _SiteStatusCheckerState extends State<SiteStatusChecker> {
  List<String> sites = [
    'https://alina.kz',
    'https://alinapaint.kz',
    'https://decorex.kz/',
    'https://domsad.kz/',
    'https://nashi-sss.kz/',
    'https://promo.alinex.kz',
    'https://promo.nashi-sss.kz/',
    'https://promo.alinapaint.kz',
    'https://new.domsad.kz',
    'https://g-ex.kz/',
    'https://pharmkaz.kz/',
    'https://journal.nncf.kz/',
    'https://dentistrykazakhstan.kz/'
  ];

  Map<String, String> siteStatus = {};
  Map<String, String> siteSslStatus = {};
  Map<String, String> siteTitles = {};
  Map<String, String?> siteScreenshots = {};
  Map<String, List<ChartData>> siteHistory = {};
  Map<String, int?> siteResponseTimes = {};
  Map<String, Map<String, String>?> siteHeaders = {};
  Map<String, int?> siteContentLengths = {};
  Map<String, String?> siteLastModified = {};
  Map<String, bool?> siteKeywordsFound = {};
  bool isLoading = true;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    checkSites();
    timer = Timer.periodic(Duration(minutes: 30), (Timer t) => checkSites());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> checkSites() async {
    setState(() {
      isLoading = true;
    });

    List<Future<void>> futures = sites.map((site) => checkSite(site)).toList();

    await Future.wait(futures);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> checkSite(String site) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(Uri.parse(site));
      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds;
      siteResponseTimes[site] = responseTime;

      if (response.statusCode == 200) {
        siteStatus[site] = 'Работает';
        siteSslStatus[site] = Uri.parse(site).scheme == 'https'
            ? 'SSL присутствует'
            : 'SSL отсутствует';

        final document = html_parser.parse(response.body);
        final titleElement = document.head?.getElementsByTagName('title').first;
        siteTitles[site] = titleElement?.text ?? 'Без заголовка';

        siteHeaders[site] = response.headers;
        siteContentLengths[site] = response.contentLength;
        siteLastModified[site] = response.headers['last-modified'];
        siteKeywordsFound[site] =
            document.body?.text.contains('important keyword') ?? false;
      } else {
        siteStatus[site] = 'Не работает';
        siteSslStatus[site] = 'Не определено';
        siteTitles[site] = 'Не определено';
      }
    } catch (e) {
      siteStatus[site] = 'Ошибка';
      siteSslStatus[site] = 'Не определено';
      siteTitles[site] = 'Ошибка';
      siteResponseTimes[site] = null;
      siteHeaders[site] = null;
      siteContentLengths[site] = null;
      siteLastModified[site] = null;
      siteKeywordsFound[site] = null;
    }

    try {
      final screenshotUrl = await getScreenshotUrl(site);
      siteScreenshots[site] = screenshotUrl;
    } catch (e) {
      siteScreenshots[site] = null;
    }

    updateSiteHistory(site);

    setState(() {});
  }

  Future<String?> getScreenshotUrl(String site) async {
    final apiKey =
        '91ed89c8f28029d6053abba252ddace7'; // Замените на ваш ключ API
    final screenshotUrl = 'https://api.screenshotlayer.com/api/capture';
    final url = '$screenshotUrl?access_key=$apiKey&url=$site&fullpage=1';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return url; // Возвращаем URL скриншота
      }
    } catch (e) {
      print('Ошибка при получении скриншота: $e');
    }

    return null;
  }

  void updateSiteHistory(String site) {
    String timestamp = DateTime.now().toString();
    String status = siteStatus[site] ?? 'Не проверено';
    if (siteHistory[site] == null) {
      siteHistory[site] = [];
    }
    siteHistory[site]!
        .add(ChartData(DateTime.now(), status == 'Работает' ? 1 : 0));
  }

  void addSite(String site) {
    setState(() {
      sites.add(site);
      checkSite(site);
    });
  }

  void removeSite(String site) {
    setState(() {
      sites.remove(site);
      siteStatus.remove(site);
      siteSslStatus.remove(site);
      siteTitles.remove(site);
      siteHistory.remove(site);
      siteScreenshots.remove(site);
      siteResponseTimes.remove(site);
      siteHeaders.remove(site);
      siteContentLengths.remove(site);
      siteLastModified.remove(site);
      siteKeywordsFound.remove(site);
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController siteController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text('Проверка сайтов'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: checkSites,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: siteController,
                    decoration: InputDecoration(
                      labelText: 'Добавить сайт',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    if (siteController.text.isNotEmpty) {
                      addSite(siteController.text);
                      siteController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.separated(
                    separatorBuilder: (context, index) => Divider(),
                    itemCount: sites.length,
                    itemBuilder: (context, index) {
                      String site = sites[index];
                      String status = siteStatus[site] ?? 'Проверяется...';
                      String sslStatus = siteSslStatus[site] ?? 'Не проверено';
                      String title = siteTitles[site] ?? 'Не определено';
                      String? screenshotUrl = siteScreenshots[site];
                      int? responseTime = siteResponseTimes[site];
                      Map<String, String>? headers = siteHeaders[site];
                      int? contentLength = siteContentLengths[site];
                      String? lastModified = siteLastModified[site];
                      bool? keywordsFound = siteKeywordsFound[site];

                      return Card(
                        margin: EdgeInsets.all(8.0),
                        elevation: 4,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                AssetImage('assets/default_icon.png'),
                            child: Icon(Icons.language),
                            radius: 20,
                          ),
                          title: Text(title,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '$status\n$sslStatus\nResponse Time: ${responseTime ?? 'N/A'} ms\nContent Length: ${contentLength ?? 'N/A'} bytes\nLast Modified: ${lastModified ?? 'N/A'}\nKeywords Found: ${keywordsFound != null && keywordsFound ? 'Yes' : 'No'}',
                          ),
                          children: [
                            if (siteHistory[site] != null &&
                                siteHistory[site]!.isNotEmpty)
                              SizedBox(
                                height: 200,
                                child: SfCartesianChart(
                                  primaryXAxis: DateTimeAxis(
                                    title: AxisTitle(text: 'Дата и время'),
                                    dateFormat: DateFormat('dd/MM/yyyy HH:mm'),
                                  ),
                                  primaryYAxis: NumericAxis(
                                    title: AxisTitle(text: 'Статус'),
                                    minimum: 0,
                                    maximum: 1,
                                    interval: 1,
                                    labelFormat: '{value}',
                                  ),
                                  series: <ChartSeries>[
                                    LineSeries<ChartData, DateTime>(
                                      dataSource: siteHistory[site]!,
                                      xValueMapper: (ChartData data, _) =>
                                          data.time,
                                      yValueMapper: (ChartData data, _) =>
                                          data.status,
                                      color: Colors.blue,
                                      width: 2,
                                      markerSettings:
                                          MarkerSettings(isVisible: true),
                                    ),
                                  ],
                                  tooltipBehavior:
                                      TooltipBehavior(enable: true),
                                ),
                              ),
                            if (screenshotUrl != null)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CachedNetworkImage(
                                  imageUrl: screenshotUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      CircularProgressIndicator(),
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.error),
                                ),
                              ),
                          ],
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              removeSite(site);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ChartData {
  final DateTime time;
  final int status;

  ChartData(this.time, this.status);
}
