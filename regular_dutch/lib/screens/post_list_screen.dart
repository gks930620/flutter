import 'package:flutter/material.dart';
import '../group_db_helper.dart';
import 'group_create_screen.dart';
import 'group_detail_screen.dart';

class PostListScreen extends StatefulWidget {
  @override
  _PostListScreenState createState() => _PostListScreenState();
  //StatefulWidget을 만들 때 반드시 override 해야 하는 메서드 .  이 함수는 State 객체를 생성해서 연결해주는 역할
  // 여기서는 postListScreenState를 연결.
  // 보통  private으로 함.  다른데서 쓰지말고  오로지 이 PostListScreent에서만 쓰이는 State라는 의미.
}

//대부분 플러터에서는 하나의 화면 만들 때 widget  +  state로 만듦.

class _PostListScreenState extends State<PostListScreen> {
  List<Map<String, dynamic>> groupList = [];

  @override //처음 시작.
  void initState() {
    super.initState();
    _loadGroups();
  }

  void _loadGroups() async {
    final groups = await GroupDatabaseHelper().getAllGroups();
    setState(() => groupList = groups);    //위젯임. state가 아니라 위젯의 화면을 다시 그리는 거.
  }
  //setState : 호출 시 화면 다시그림.   밑의 @override build : 화면 그릴때마다 이렇게 그려!!
  //  즉  setState 호출하면 build 실행.  이건 내부적으로 변하지 않는 사실
  // groupList =  await GroupDatabaseHelper().getAllGroups();
  // setState( ()=>{} )  해도 되는데  이러면 화면을 '왜' 다시 그리는지 코드상 알 수없고 그냥 다시그림
  //   setState(() => groupList = groups);   이건 groupList의 데이터가 변경됐기때문에 화면다시그린다는 의미가 포함됨






   //여기서부터  chatgpt랑 다시 문답해보장.
  void _goToGroupCreateScreen() async {
    final result = await Navigator.push(   //현재 화면스택  위에 하나의 스택을 더 쌓는거.   눈으로 봤을 때는 새로운 화면이 새로 생기는 느낌.
      context,    //BuilderContext context :   위젯트리상에서 현재 위젯 위치를 저장하는 객체..
      // 간단하게 현재 화면(위젯)에서 하위 위젯(여기서는 createScreen)을 하고 나서 다시  현재 화면으로 와서 작업하게 할 수 있게 하려고..
      MaterialPageRoute(builder: (context) => GroupCreateScreen()),  //MaterialPageRoute는 화면 전환(페이지 이동)을 정의하는 Flutter의 라우트 객체야.
      //Material은  이드 방식의 페이지 스타일,   Cuperion는 IOS 스타일
    );
    if (result == true) _loadGroups(); // 새로고침   글 등록하고 다시 오면   새로고침.
  }

  void _goToDetail(Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(groupId: group['id']),  //GroupDetailScreen의 생성자 전달
      ),
    );
  }


  void _deleteGroup(int groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('삭제 확인'),
        content: Text('정말 이 그룹을 삭제하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('삭제')),
        ],
      ),
    );

    if (confirm == true) {
      await GroupDatabaseHelper().deleteGroup(groupId); // 여기가 핵심
      _loadGroups(); // 삭제 후 목록 갱신
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('그룹 목록'),
        actions: [IconButton(icon: Icon(Icons.add), onPressed: _goToGroupCreateScreen)],
      ),
      body: groupList.isEmpty
          ? Center(child: Text('아직 등록된 그룹이 없어요.'))
          : ListView.builder(
        itemCount: groupList.length,
        itemBuilder: (context, index) {
          final group = groupList[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(group['name'] ?? '그룹 ${index + 1}'),
              subtitle: Text(group['members'].join(', ')),
              onTap: () => _goToDetail(group),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteGroup(group['id']),
              ),
            ),
          );
        },
      ),
    );
  }
}
