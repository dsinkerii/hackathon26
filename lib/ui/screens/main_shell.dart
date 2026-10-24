import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../widgets/adaptive_phone_frame.dart';
import '../widgets/app_drawer.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/custom_search_app_bar.dart';
import 'activity_logs_screen.dart';
import 'chat_list_screen.dart';
import 'porch_screen.dart';

class MainShell extends StatefulWidget {
  final AppState state;

  const MainShell({super.key, required this.state});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.state.selectedTabIndex);
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.selectedTabIndex != _pageController.page?.round()) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          widget.state.selectedTabIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    final unreadChats = state.chats.fold<int>(0, (sum, c) => sum + c.unreadCount);
    final unreadLogs = state.unprocessedIncidentsCount;

    return AdaptivePhoneFrame(
      child: Scaffold(
        drawer: AppDrawer(
          state: state,
          onSelectTab: (index) {
            state.selectTab(index);
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
              );
            }
          },
        ),
        drawerEdgeDragWidth: 45,
        appBar: CustomSearchAppBar(
          state: state,
          searchController: _searchController,
          onSearchChanged: (query) {
            state.setSearchQuery(query);
          },
        ),
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            state.selectTab(index);
          },
          children: [
            PorchScreen(state: state),
            ChatListScreen(state: state),
            ActivityLogsScreen(state: state),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          selectedIndex: state.selectedTabIndex,
          onItemSelected: (index) {
            state.selectTab(index);
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          unreadChats: unreadChats,
          unreadLogs: unreadLogs,
        ),
      ),
    );
  }
}
