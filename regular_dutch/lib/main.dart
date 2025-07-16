// ✅ main.dart
import 'package:flutter/material.dart';
import 'group_db_helper.dart';
import 'screens/post_list_screen.dart'; // 목록화면 import
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //fluter main 초반에 엔진초기화.    밑의  GroupDatabaseHelper().resetDB()에서
  // getDatabasesPath() 같은 Flutter의 플랫폼 채널과 연동되는 기능은, Flutter 엔진이 초기화되기 전에는 호출하면 안 됨.
  //await GroupDatabaseHelper().resetDB(); // 개발 중 DB 초기화.  배포때는 없어야함

  await dotenv.load(); // ⬅️ 반드시 async로
  await refreshHolidaysIfNeeded(); // 공휴일 최신화
  runApp(MyApp());
}

/// 공휴일 DB 최신화: 1주일 이상 지났으면 전체 연도(2020~2030) API 호출 후 DB 저장
Future<void> refreshHolidaysIfNeeded() async {
  final db = GroupDatabaseHelper();
  final lastUpdate = await db.getLastHolidayUpdate();
  final now = DateTime.now().millisecondsSinceEpoch;
  const oneWeekMillis = 7 * 24 * 60 * 60 * 1000;
  if (lastUpdate == null || now - lastUpdate > oneWeekMillis) {
    Map<String, Map<String, dynamic>> holidayMap = {};
    final apiKey = dotenv.env['PUBLIC_API_KEY'] ?? '';
    final currentYear = DateTime.now().year;
    final startYear = currentYear - 5;
    final endYear = currentYear + 1;
    for (int year = startYear; year <= endYear; year++) {
      final url =
          'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo'
          '?serviceKey=$apiKey'
          '&solYear=$year'
          '&numOfRows=100'
          '&_type=json';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final items = body['response']['body']['items'];
        if (items == null) continue;
        final List holidays = items['item'] is List ? items['item'] : [items['item']];
        for (final item in holidays) {
          if (item is! Map || !item.containsKey('locdate')) continue;
          final dateStr = item['locdate'].toString();
          if (dateStr.length != 8) continue;
          final name = item['dateName']?.toString() ?? '';
          final key = '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}';
          holidayMap[key] = {
            'holiday_date': key,
            'name': name,
            'last_updated': now,
          };
        }
      }
    }
    final allHolidays = holidayMap.values.toList();
    if (allHolidays.isNotEmpty) {
      await db.saveHolidays(allHolidays);
      print('공휴일 DB 최신화 완료 (${allHolidays.length}건)');
    } else {
      print('공휴일 DB 최신화 실패: 데이터 없음');
    }
  } else {
    print('공휴일 DB 최신화 불필요 (1주일 이내)');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '그룹 멤버 등록 앱',
      theme: ThemeData(primarySwatch: Colors.purple),
      home: PostListScreen(), // 첫 진입화면
    );
  }
}