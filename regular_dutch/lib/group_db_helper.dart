// ✅ group_db_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

//참고 : db함수들이 async인 이유는  플러터앱은 기본적으로 싱글 스레드.

// async로 안하면  DB읽는 동안 화면이 없음( 코드순서상 db읽고,  그 다음에 마지막에 화면만드는 코드순서임)
// 비동기로 해서 일단 기본틀 화면 만들고  그 다음에 DB읽은 데이터를 화면에 뿌려주는 방식.
// 그래서 DB관련클래스인 여기서 다 비동기 처리하고  외부에서도 사용할 때 비동기방식으로 사용

class GroupDatabaseHelper {
  GroupDatabaseHelper._internal(); //   클래스이름.();   생성자 정의 .  즉 생성자 이름을 internal로 하는데 private(_)임
  static final GroupDatabaseHelper _instance = GroupDatabaseHelper
      ._internal(); //싱글톤 패턴처럼   static 객체 선언(생성자는 private이기때문에 객체는 하나.
  factory GroupDatabaseHelper() => _instance;

  // factory: 일반적인 생성자가 아니라 직접 객체를 생성하거나 기존 객체를 리턴할 수 있는 생성자
  // 생성자지만 새로 객체를 생성하는게 아니라 기존에 만든 객체 리턴,  외부에서는 GroupDatabaseHelper() 이렇게 사용
  //  ()=> 는   return _instance의 축약형
  //  즉 _instance 객체를 return 하는 거.

  static Database? _database;

  Future<void> resetDB() async {
    //비동기 작업함수.   반환타입은 없음..이지만 비동기함수인걸 나타내기 위해  Futrue 사용
    final dbPath =
        await getDatabasesPath(); //final :  필드가 아니어도 사용가능.   이후 값 변경 불가.
    //sqflite에서 제공하는 함수. **DB 파일이 저장될 디렉토리 경로(String)**를 가져옴. 예: /data/user/0/패키지명/databases

    final path =
        join(dbPath, 'group.db'); //path패키지에서 제공되는 join함수.   위의 DB파일 경로 +  파일이름
    await deleteDatabase(path); // 기존 DB 삭제
    _database = null;
  }

  Future<Database> get database async {
    //dart의 getter문법.  getter가 메소드 중 특별한 거기때문에 이렇게 따로 문법이 있음..    getDatabase()임.   위의 필드의 _database 리턴
    //이게 있으면 위의 private 필드인 _를  그냥 외부에서 필드로 사용가능(읽기전용변수)
    // 객체.database=a   (이건 X),    변수 =객체.database  이런식으로.
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!; //필드에서 database?로 null일수도 아닐수도 있는데  !를써서 null이 아니게 됐다는 확신을 가지고 return
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'group.db');

    return await openDatabase(
      path,
      version: 2, // 버전 2로 올림 (마이그레이션 필요시)
      onConfigure: (db) async {
        await db.execute("PRAGMA foreign_keys = ON");
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER,
            name TEXT,
            FOREIGN KEY(group_id) REFERENCES groups(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER,
            date TEXT,
            member TEXT, 
            FOREIGN KEY(group_id) REFERENCES groups(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE holidays (
            holiday_date TEXT PRIMARY KEY,
            name TEXT,
            last_updated INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS holidays (
              holiday_date TEXT PRIMARY KEY,
              name TEXT,
              last_updated INTEGER
            )
          ''');
        }
      },
    );
  }

  // 공휴일 저장 (전체 덮어쓰기)
  Future<void> saveHolidays(List<Map<String, dynamic>> holidays) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('holidays'); // 전체 삭제 후
    for (final holiday in holidays) {
      batch.insert('holidays', holiday);
    }
    await batch.commit(noResult: true);
  }

  // 공휴일 전체 조회
  Future<List<DateTime>> getAllHolidayDates() async {
    final db = await database;
    final rows = await db.query('holidays');
    return rows.map((row) => DateTime.parse(row['holiday_date'] as String)).toList();
  }

  // 공휴일 전체 조회 (이름 포함)
  Future<List<Map<String, dynamic>>> getAllHolidays() async {
    final db = await database;
    return await db.query('holidays');
  }

  // 마지막 공휴일 업데이트 시각 조회 (epoch millis)
  Future<int?> getLastHolidayUpdate() async {
    final db = await database;
    final rows = await db.query('holidays', orderBy: 'last_updated DESC', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['last_updated'] as int?;
  }

  Future<int> createGroup(String groupName, List<String> members) async {
    final db = await database;
    final groupId = await db.insert('groups', {'name': groupName});
    for (final name in members) {
      await db.insert('members', {'group_id': groupId, 'name': name});
    }
    return groupId;
  }




  Future<List<Map<String, dynamic>>> getAllGroups() async {
    final db =
        await database; // getter database임.   private 필드 직접쓰려면 _database로 사용해야함.
    final groupRows = await db.query('groups'); //이건 그냥 전체 select문
    List<Map<String, dynamic>> result = [];
    // groups는    [ group1,  group2, group3...     ]
    // group1  = {  }    이게 Map.
    // 형태는 { "id" : 1,  name :  이름 , members :  [] }  이다. String은 id,name,members.  값들은 다 다르기때문에 dynamic
    // 내가 다트에서 DB첨이라 그런진 모르겠는데  일단 모든 데이터를 로직에 맞게 한번에 return하는구나...
    // rdb처럼 별개의 entity 없이..

    for (final group in groupRows) {
      final members = await db.query(
        'members',
        where: 'group_id = ?',
        whereArgs: [group['id']],
      );
      result.add({
        'id': group['id'],
        'name': group['name'],
        'members': members.map((m) => m['name'].toString()).toList(),
      });
    }
    return result;
  }

  Future<void> updateGroup(int groupId, List<String> newMembers) async {
    final db = await database;
    await db.delete('members', where: 'group_id = ?', whereArgs: [groupId]);
    for (final name in newMembers) {
      await db.insert('members', {'group_id': groupId, 'name': name});
    }
  }

  Future<void> deleteGroup(int groupId) async {
    final db = await database;
    await db.delete('groups', where: 'id = ?', whereArgs: [groupId]);
  }

  Future<Map<String, dynamic>?> getGroup(int groupId) async {
    final db = await database;
    final group =
        await db.query('groups', where: 'id = ?', whereArgs: [groupId]);
    if (group.isEmpty) return null;
    final members =
        await db.query('members', where: 'group_id = ?', whereArgs: [groupId]);
    return {
      'id': groupId,
      'name': group.first['name'],
      'members': members.map((m) => m['name'].toString()).toList(),
    };
  }


  // 날짜별 결제자 저장
  Future<void> setPayment(int groupId, DateTime date, String member) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T').first;

    // 먼저 같은 날짜에 같은 그룹의 기록이 있으면 삭제
    await db.delete(
      'payments',
      where: 'group_id = ? AND date = ?',
      whereArgs: [groupId, dateStr],
    );
    await db.insert('payments', {
      'group_id': groupId,
      'date': dateStr,
      'member': member,
    });
  }

  // 해당 그룹의 모든 날짜별 결제자 로딩
  Future<Map<DateTime, String>> getPayments(int groupId) async {
    final db = await database;
    final rows = await db.query('payments', where: 'group_id = ?', whereArgs: [groupId]);

    Map<DateTime, String> result = {};
    for (final row in rows) {
      final date = DateTime.parse(row['date'] as String);
      final member = row['member'] as String;
      result[date] = member;
    }
    return result;
  }
}
