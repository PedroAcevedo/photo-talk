import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:provider/provider.dart';

/// PhotoTalk bottom navigation.
///
/// Four large, labeled tabs designed for low cognitive load:
///   0  Memories  - Today's Memories feed
///   1  Companion - AI Companion (chat mode)
///   2  Snippets  - Family Story Snippets
///   3  Caregiver - Caregiver Recap
class BottomMenubar extends StatelessWidget {
  const BottomMenubar({Key? key}) : super(key: key);

  static const _tabs = <_PhotoTab>[
    _PhotoTab(label: 'Memories', icon: Icons.photo_library_outlined),
    _PhotoTab(label: 'Companion', icon: Icons.chat_bubble_outline),
    _PhotoTab(label: 'Snippets', icon: Icons.format_quote_rounded),
    _PhotoTab(label: 'Caregiver', icon: Icons.favorite_border_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
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
            children: List.generate(_tabs.length, (i) {
              final selected = state.pageIndex == i;
              return Expanded(
                child: InkWell(
                  onTap: () => state.setPageIndex = i,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _tabs[i].icon,
                        size: 26,
                        color: selected
                            ? PhotoTalkPalette.primary
                            : PhotoTalkPalette.textSecondary,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tabs[i].label,
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
            }),
          ),
        ),
      ),
    );
  }
}

class _PhotoTab {
  final String label;
  final IconData icon;
  const _PhotoTab({required this.label, required this.icon});
}
