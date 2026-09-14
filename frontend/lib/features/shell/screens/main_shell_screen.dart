import 'package:flutter/material.dart';

import '../../home/screens/home_screen.dart';
import '../../mypage/screens/my_page_screen.dart';
import '../constants.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/quick_menu_button.dart';
import '../widgets/quick_menu_panel.dart';

/// 하단 바를 소유하는 껍데기 화면. 탭이 바뀌면 본문만 갈아끼운다.
///
/// 화면마다 각자 하단 바를 달면 탭 선택 상태가 화면 수만큼 흩어지고,
/// 화면을 하나 추가할 때마다 바를 다는 걸 잊을 수 있다. 그래서 바는 여기
/// 한 곳에만 둔다.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  static const _homeTab = 0;

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  /// 하단 바의 인덱스와 순서가 같아야 한다. 마이페이지의 뒤로가기는 홈 탭으로
  /// 돌아오는 일이라 그 콜백을 여기서 넘긴다.
  List<Widget> get _tabs => [
    const HomeScreen(),
    MyPageScreen(onBackPressed: () => _selectTab(_homeTab)),
  ];

  Future<void> _openQuickMenu() async {
    final selected = await showQuickMenu(context);
    if (selected == null || !mounted) return;

    final routeName = selected.routeName;
    if (routeName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ShellStrings.notReady(selected.label))),
      );
      return;
    }
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedIndex,
        onTabSelected: _selectTab,
        onQuickMenuPressed: _openQuickMenu,
      ),
      // 원형 버튼은 바 위로 솟아 본문에 겹친다. 바 위젯에 넣으면 솟은 만큼을
      // 바 높이에 더해야 하고, 그 띠가 흰 배경으로 채워져 바가 두 겹으로 보인다.
      floatingActionButton: QuickMenuButton(onPressed: _openQuickMenu),
      floatingActionButtonLocation: quickMenuButtonLocation,
    );
  }
}
