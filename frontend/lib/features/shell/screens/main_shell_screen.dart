import 'package:flutter/material.dart';

import '../../home/screens/home_screen.dart';
import '../../mypage/screens/my_page_screen.dart';
import '../quick_menu_launcher.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/quick_menu_button.dart';

/// 하단 바를 소유하는 껍데기 화면. 탭이 바뀌면 본문만 갈아끼운다.
///
/// 바 **위젯**은 여기 말고 내 티켓 화면도 단다(시안에 하단 바가 그려져 있다).
/// 다만 탭 상태를 들고 있는 것은 이 화면 하나다 — 저쪽은 어느 탭도 고르지 않은
/// 상태로 그리고, 탭을 누르면 [initialTab] 을 지정해 이 셸로 돌아온다.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key, this.initialTab = 0});

  /// 처음 열 탭. 빠른 메뉴에서 연 화면이 하단 바로 돌아올 때 어느 탭으로
  /// 갈지 지정한다.
  final int initialTab;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _selectedIndex = widget.initialTab;

  static const _homeTab = 0;

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  /// 하단 바의 인덱스와 순서가 같아야 한다. 마이페이지의 뒤로가기는 홈 탭으로
  /// 돌아오는 일이라 그 콜백을 여기서 넘긴다.
  List<Widget> get _tabs => [
    const HomeScreen(),
    MyPageScreen(onBackPressed: () => _selectTab(_homeTab)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedIndex,
        onTabSelected: _selectTab,
        onQuickMenuPressed: () => openQuickMenu(context),
      ),
      // 원형 버튼은 바 위로 솟아 본문에 겹친다. 바 위젯에 넣으면 솟은 만큼을
      // 바 높이에 더해야 하고, 그 띠가 흰 배경으로 채워져 바가 두 겹으로 보인다.
      floatingActionButton: QuickMenuButton(
        onPressed: () => openQuickMenu(context),
      ),
      floatingActionButtonLocation: quickMenuButtonLocation,
    );
  }
}
