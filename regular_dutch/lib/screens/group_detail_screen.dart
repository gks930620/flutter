import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../group_db_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

//해야될게 있으면 해야지  딴 생각하지말고.  졸려 뒤지겄소.

// 그룹 상세 화면 위젯
class GroupDetailScreen extends StatefulWidget {
  final int groupId; // 선택된 그룹의 ID
  const GroupDetailScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  String _groupName = ''; // 그룹 이름
  List<String> _members = []; // 그룹 멤버 리스트
  Map<DateTime, String> paymentRecords = {}; // 날짜별 결제자 기록
  //처음에 DB에서 select,  이후 Map 직접 put + DB insert만.   DBselect는 맨 처음에만 하는거

  Set<DateTime> _holidays = {}; // 공휴일 집합
  DateTime _focusedDay = DateTime
      .now(); // 현재 포커스된 날짜   Caledndars는 이 focusedDay를 가지고 해당 월의 달력을 만듬.
  DateTime? _selectedDay; // 선택된 날짜 (nullable)

  @override
  void initState() {
    super.initState();

    //작업이 오래걸리는 일들은 여기서 해야 build하고 나서 작업이 일어남.
    WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadGroup(); // 그룹 정보 불러오기
    _loadPayments();
    _loadHolidays(_focusedDay.year, _focusedDay.month); // 공휴일 불러오기
    });
  }

  // 날짜를 yyyy-MM-dd 형태로 정규화 (시간 제거)
  DateTime normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  // DateTime normalizeDate(DateTime date){   이렇게 간단히 한줄로 할수있는 메소드는 위의 람다식처럼 표현..   어쨋든 메소드임
  //   return DateTime(date.year, date.month, date.day);
  // }




  // 그룹 정보 불러오기
  Future<void> _loadGroup() async {
    final data =
    await GroupDatabaseHelper().getGroup(widget.groupId); //기본 제공 widget 객체
    if (data != null) {
      setState(() {
        _groupName = data['name'] ?? '이름 없음';
        _members = List<String>.from(data['members']);
      });
    }
  }

  Future<void> _loadPayments() async {
    final payments = await GroupDatabaseHelper().getPayments(widget.groupId);
    setState(() => paymentRecords = payments);
  }

  //db에 있는걸로 뭘 할까? ....
  //

  // 공휴일 로딩 (API 호출)
  Future<void> _loadHolidays(int year, int month) async {
    try {
      final result = await fetchKoreanHolidays(year, month);
      setState(() {
        _holidays = result.map((d) => normalizeDate(d)).toSet();
      });
    } catch (e) {
      print('공휴일 불러오기 실패: $e');
    }
  }

  // 공공데이터포털 API를 이용한 공휴일 데이터 fetch
  Future<List<DateTime>> fetchKoreanHolidays(int year, int month) async {
    String apiKey = dotenv.env['PUBLIC_API_KEY'] ?? '';

    final url =
        'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo'
        '?serviceKey=$apiKey'
        '&solYear=$year'
        '&solMonth=${month.toString().padLeft(2, '0')}'
        '&_type=json';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final items = body['response']['body']['items'];

      if (items == null) return [];
      final List holidays =
      items['item'] is List ? items['item'] : [items['item']];
      return holidays.map<DateTime>((item) {
        final dateStr = item['locdate'].toString();
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      }).toList();
    } else {
      throw Exception('공휴일 데이터를 불러오지 못했습니다.');
    }
  }


  // 날짜 클릭 시 실행되는 콜백
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    //TableCalendar 위젯이 정해놓은 콜백 함수 타입.

    final normalized = normalizeDate(selectedDay); //yyyy-MM-dd 문자열
    // 멤버 선택 다이얼로그 표시

    final TextEditingController _customNameController = TextEditingController();
    final selectedMember = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => SimpleDialog(
            title: Text("${normalized.year}-${normalized.month}-${normalized.day} 계산자 선택"),
            children: [
              ..._members.map((member) => SimpleDialogOption(   //...은 map().toList()랑 비슷.
                child: Text(member),
                onPressed: () => Navigator.pop(context, member),
              )),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _customNameController,
                  maxLength: 15, // 최대 15자 제한
                  decoration: InputDecoration(
                    labelText: '직접 입력',
                    border: OutlineInputBorder(),   // payments테이블의 member컬럼에 저장이 되긴하지만
                    // members테이블에는 없는 데이터라  크게 문제없음.
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final input = _customNameController.text.trim();
                  if (input.isNotEmpty) {
                    Navigator.pop(context, input);
                  }
                },
                child: Text('입력한 이름으로 선택'),
              ),
            ],
          ),
        );
      },
    );

    //여기까지 했으면 멤버선택됐고 날짜도 선택됐으니까 마지막에 다시 setState를 하면 현재 날짜가 뜨는게 맞는데...

    // 선택된 멤버 기록
    if (selectedMember != null) {
      setState(() {
        _selectedDay = normalized;
        //  _focusedDay = normalized;   이건 필요없지 여기서  focusedDay가 바뀌는건  월을 바꿧을때 함수에서 처리중
        paymentRecords[normalized] = selectedMember;
      });


      await GroupDatabaseHelper().setPayment(widget.groupId, normalized, selectedMember);
    }
  }


  Widget _buildDowCell(BuildContext context, DateTime day) {
    final text = ['일', '월', '화', '수', '목', '금', '토'][day.weekday % 7];
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: day.weekday == DateTime.sunday ? Colors.red : Colors.grey[600],
        ),
      ),
    );
  }
  Text makeText(DateTime curDay , bool isHoliday , bool isToday) {
    // 오늘 -> 보라색 굵게.
    //공휴일 -> 빨간색표시,
    if( isToday){
      return Text(
          '${curDay.day}',
          style: TextStyle(
              color: Colors.purple,
            fontWeight: FontWeight.bold
          )
      );
    }

    if(isHoliday){
      return Text(
        '${curDay.day}',
        style: TextStyle(
            color: Colors.red
        )
      );
    }

    //그냥 평범한 날
    return Text(
        '${curDay.day}'
    );

  }

  Widget _basicMakeCalendarBuilder(BuildContext context, DateTime curDay,
      DateTime focusedDay) {
    final normalized = normalizeDate(curDay);
    final isHoliday = _holidays.contains(normalized);
    final member = paymentRecords[normalized]; //키 : 날짜,  value : 그 날짜의 계산자 멤버
    final isToday= isSameDay(DateTime.now(), curDay);
    Text dayText = makeText(curDay , isHoliday, isToday);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dayText,
        if (member != null) // 현재 날짜에 멤버가 있다면 멤버표시
          Text(
            member,
            style: TextStyle(fontSize: 10, color: Colors.purple),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(10, (i) => 2020 + i); // 2020~2029
    final months = List.generate(12, (i) => i + 1); // 1~12월
      Map<String, int> paymentCountByMember = {};
    for (final member in _members) {
      paymentCountByMember[member] = 0;
    }
    paymentRecords.forEach((_, member) {
      if (paymentCountByMember.containsKey(member)) {
        paymentCountByMember[member] = paymentCountByMember[member]! + 1;  // !는 null이 아니니까 그냥써.    null일 가능성이 있으면 null체크 (?? 등)
      }
    });  // 결제 개수가 크지않으니까 크게 상관없는데.. 나중에는 이 과정한번 + 필드에 map(멤버별 횟수)에다가  +1 -1 등등해야겠구만.

    final minCount=paymentCountByMember.values.reduce((a, b) => a < b ? a : b);
    final nextPayer = _members.firstWhere(
          (m) => paymentCountByMember[m] == minCount,
      orElse: () => '',
    );


    //detail 화면 들어가기전에 잠깐 에러나고 가네... 이거 확인하자.. minCount 다음결제자 하면서 생김 

    return Scaffold(
      appBar: AppBar(
        title: Text('📋 $_groupName'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text( '👥 멤버 목록 (${_members.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: _members.map((m) {

                final count = paymentCountByMember[m] ?? 0;  //null이면 0
                final isNext = m == nextPayer;

                return Chip(
                    label: Text('$m ($count)'),
                   backgroundColor: isNext ? Colors.orange.shade200 : null,
                  shape: StadiumBorder(
                    side: isNext
                        ? BorderSide(color: Colors.deepOrange, width: 2)
                        : BorderSide.none,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            // 연도, 월 드롭다운 선택 UI
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<int>(
                  value: _focusedDay.year,
                  items: years
                      .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y년')))
                      .toList(),
                  onChanged: (year) {
                    if (year != null) {
                      final newDate = DateTime(year, _focusedDay.month);
                      setState(() {
                        _focusedDay = newDate;
                        _loadHolidays(newDate.year, newDate.month);
                      });
                    }
                  },
                ),
                SizedBox(width: 16),
                DropdownButton<int>(
                  value: _focusedDay.month,
                  items: months
                      .map(
                          (m) => DropdownMenuItem(value: m, child: Text('$m월')))
                      .toList(),
                  onChanged: (month) {
                    if (month != null) {
                      final newDate = DateTime(_focusedDay.year, month);
                      setState(() {
                        _focusedDay = newDate;
                        _loadHolidays(newDate.year, newDate.month);
                      });
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 12),

            // 달력 위젯
            Expanded(
              child: TableCalendar(
                rowHeight: 80,
                daysOfWeekHeight: 36,
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                //이 focusedDay(6월)를 기준으로 밑의 함수들의 파라미터 curDay(6월1일~ 6월30일)가 변경됨.
                selectedDayPredicate: (curDay) =>
                    isSameDay(normalizeDate(curDay), _selectedDay),
                //true flase에 따라 caleder위젯이 알아서 다르게 표시. 역할: 어떤 날짜가 "선택된 날짜"인지 판단하는 기준.

                onDaySelected: _onDaySelected,
                headerVisible: false,
                calendarFormat: CalendarFormat.month,
                onPageChanged: (newFocusedDay) {  //페이지가 바뀌었을때... 기본적으로 15일이 newFocusedDay가 됨
                  setState(() {
                    _focusedDay = newFocusedDay;
                  });
                },
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(),
                  selectedDecoration: BoxDecoration(),

                  //기본 스타일지정하는데 selectedBuilder,todayBuilder보단 낮음
                  // 난 _paymentRecords 변수를 이용해서 만들어야되기때문에 builder 를 하기때문에 여기서는 큰 의미 없음.
                  todayTextStyle: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.purple),
                  //현재날짜는 이렇게
                  selectedTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black), //선택된 날짜표기
                ),

                calendarBuilders: CalendarBuilders(
                  dowBuilder: (context, curDay) =>
                      _buildDowCell(context, curDay),   //이렇게 파라미터를 전부 쓸 때는 람다말고 _buildDowCell  딱 이것만 써도 됨.
                  todayBuilder: (buildContext, curDay, foucsedDay) =>
                      _basicMakeCalendarBuilder(
                          buildContext, curDay, foucsedDay),

                  // selectedDayPredicate: (day) => isSameDay(normalizeDate(day), _selectedDay)에서 true일 때( 선택된날짜일 떄)
                  // 선택된날짜를 만드는 buidler
                  selectedBuilder: (buildContext, curDay, foucsedDay) =>
                      _basicMakeCalendarBuilder(
                          buildContext, curDay, foucsedDay),
                  defaultBuilder: (buildContext, curDay, foucsedDay) =>
                      _basicMakeCalendarBuilder(
                          buildContext, curDay, foucsedDay),

                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
