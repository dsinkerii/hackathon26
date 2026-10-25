import 'dart:ui' as ui;
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
    // Only animate when selectedTabIndex genuinely changed from external source (like drawer)
    if (widget.state.selectedTabIndex != oldWidget.state.selectedTabIndex) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != widget.state.selectedTabIndex) {
        _pageController.animateToPage(
          widget.state.selectedTabIndex,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _onTabSelected(int index) {
    if (widget.state.selectedTabIndex == index) return;
    widget.state.selectTab(index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
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
          onSelectTab: _onTabSelected,
        ),
        drawerEdgeDragWidth: 45,
        appBar: CustomSearchAppBar(
          state: state,
          searchController: _searchController,
          onSearchChanged: (query) {
            state.setSearchQuery(query);
          },
        ),
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                if (widget.state.selectedTabIndex != index) {
                  widget.state.selectTab(index);
                }
              },
              children: [
                PorchScreen(state: state),
                ChatListScreen(state: state),
                ActivityLogsScreen(state: state),
              ],
            ),

            // Lightweight non-blocking blur overlay on swipe
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, _) {
                    if (!_pageController.hasClients ||
                        !_pageController.position.haveDimensions) {
                      return const SizedBox.shrink();
                    }
                    final page = _pageController.page ??
                        state.selectedTabIndex.toDouble();
                    final diff = (page - page.round()).abs(); // 0.0 to 0.5
                    if (diff <= 0.02) {
                      return const SizedBox.shrink();
                    }

                    final sigma = (diff * 2.0) * 4.0;
                    return BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: Container(
                        color: Colors.black.withValues(alpha: diff * 0.06),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          selectedIndex: state.selectedTabIndex,
          onItemSelected: _onTabSelected,
          unreadChats: unreadChats,
          unreadLogs: unreadLogs,
        ),
      ),
    );
  }
}
