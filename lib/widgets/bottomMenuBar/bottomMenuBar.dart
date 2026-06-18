import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:provider/provider.dart';

/// PhotoTalk bottom navigation.
///
/// Tabs are role-aware. Per spec:
///   - care_recipient   → Memories, Companion, Snippets (no Caregiver Recap;
///                         they shouldn't review themselves).
///   - family/caregiver → Memories, Companion, Snippets, Caregiver Recap.
class BottomMenubar extends StatelessWidget {
  const BottomMenubar({Key? key}) : super(key: key);

  /// Canonical tab list — index here matches the PageIndex used by
  /// HomePage. Order must stay stable so existing AppState.pageIndex
  /// values keep pointing at the right screen.
  static const _allTabs = <_PhotoTab>[
    _PhotoTab(
      label: 'Memories',
      icon: Icons.photo_library_outlined,
      pageIndex: 0,
    ),
    _PhotoTab(
      label: 'Companion',
      icon: Icons.chat_bubble_outline,
      pageIndex: 1,
    ),
    _PhotoTab(
      label: 'Snippets',
      icon: Icons.format_quote_rounded,
      pageIndex: 2,
    ),
    _PhotoTab(
      label: 'Caregiver',
      icon: Icons.favorite_border_rounded,
      pageIndex: 3,
      roles: {'family', 'caregiver'}, // hidden from care_recipient
    ),
  ];

  List<_PhotoTab> _tabsForRole(String? role) {
    return _allTabs.where((t) {
      if (t.roles == null) return true;
      if (role == null) return false;
      return t.roles!.contains(role);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final auth = Provider.of<AuthState>(context);
    final role = auth.userModel?.role;
    final tabs = _tabsForRole(role);

    // If the active page index points at a tab the current role can't see
    // (e.g. role flipped on another device), fall back to the first tab.
    final activeIndex = tabs.indexWhere((t) => t.pageIndex == state.pageIndex);
    if (activeIndex == -1 && tabs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state.setPageIndex = tabs.first.pageIndex;
      });
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: tabs.map((tab) {
              final selected = state.pageIndex == tab.pageIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => state.setPageIndex = tab.pageIndex,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size: 26,
                        color: selected
                            ? PhotoTalkPalette.primary
                            : PhotoTalkPalette.textSecondary,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? PhotoTalkPalette.primary
                              : PhotoTalkPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _PhotoTab {
  final String label;
  final IconData icon;
  final int pageIndex;

  /// When non-null, only accounts whose `UserModel.role` is in this set
  /// can see and tap the tab.
  final Set<String>? roles;

  const _PhotoTab({
    required this.label,
    required this.icon,
    required this.pageIndex,
    this.roles,
  });
}
