import 'package:flutter/material.dart';
import '../group_db_helper.dart';

class GroupCreateScreen extends StatefulWidget {
  @override
  _GroupCreateScreenState createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  List<TextEditingController> _memberControllers = [];
  List<FocusNode> _memberFocusNodes = []; // 포커스 노드 리스트 추가
  final TextEditingController _groupNameController = TextEditingController();

  void _addMemberField() {
    setState(() {
      _memberControllers.add(TextEditingController());
      final focusNode = FocusNode();
      _memberFocusNodes.add(focusNode);
    });

    // setState 이후 포커스 요청
    Future.delayed(Duration(milliseconds: 100), () {
      _memberFocusNodes.last.requestFocus();
    });
  }

  void _submitGroup() async {
    final groupName = _groupNameController.text.trim();
    final members = _memberControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('그룹 이름을 입력해주세요.')));
      return;
    }
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('멤버를 1명 이상 입력해주세요.')));
      return;
    }
    if (members.toSet().length != members.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('동일한 이름의 멤버는 입력할 수 없습니다.')));
      return;
    }

    await GroupDatabaseHelper().createGroup(groupName, members);
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _memberControllers.forEach((c) => c.dispose());
    _memberFocusNodes.forEach((f) => f.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('그룹 등록')),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    labelText: '📝 그룹 이름',
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    border: OutlineInputBorder(),
                    fillColor: Colors.purple.shade50,
                    filled: true,
                  ),
                ),
                SizedBox(height: 48),
                ..._memberControllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: controller,
                      focusNode: _memberFocusNodes[index],
                      decoration: InputDecoration(
                        labelText: '멤버 이름',
                        border: UnderlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  );
                }),
                SizedBox(height: 16),
                ElevatedButton(onPressed: _addMemberField, child: Text('멤버 추가')),
                SizedBox(height: 48),
                ElevatedButton(onPressed: _submitGroup, child: Text('그룹 등록')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}