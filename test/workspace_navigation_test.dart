import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/workspace_navigation.dart';
import 'package:in4up/widgets/workspace_navigation/workspace_action_button.dart';
import 'package:in4up/widgets/workspace_navigation/workspace_mode_bar.dart';
import 'package:in4up/widgets/workspace_navigation/workspace_source_picker.dart';

enum _Choice { first, second, third }

const _items = <WorkspaceNavigationItem<_Choice>>[
  WorkspaceNavigationItem(
    value: _Choice.first,
    label: 'First',
    icon: Icons.looks_one,
  ),
  WorkspaceNavigationItem(
    value: _Choice.second,
    label: 'Second',
    icon: Icons.looks_two,
  ),
  WorkspaceNavigationItem(
    value: _Choice.third,
    label: 'Third',
    icon: Icons.looks_3,
  ),
];

Widget _host(Widget child, {double width = 800}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: width, child: child)),
    ),
  );
}

void main() {
  group('WorkspaceModeBar', () {
    testWidgets('renders two to three items and marks selected chip', (tester) async {
      await tester.pumpWidget(
        _host(
          WorkspaceModeBar<_Choice>(
            items: _items,
            selectedValue: _Choice.second,
            onChanged: (_) {},
            presentation: WorkspaceNavigationPresentation.chips,
          ),
        ),
      );

      expect(find.byType(ChoiceChip), findsNWidgets(3));
      final selected = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Second'));
      expect(selected.selected, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('calls onChanged with the tapped typed value', (tester) async {
      _Choice? changed;
      await tester.pumpWidget(
        _host(
          WorkspaceModeBar<_Choice>(
            items: _items.take(2).toList(),
            selectedValue: _Choice.first,
            onChanged: (value) => changed = value,
            presentation: WorkspaceNavigationPresentation.chips,
          ),
        ),
      );

      await tester.tap(find.text('Second'));
      expect(changed, _Choice.second);
    });

    testWidgets('does not invoke callback when disabled', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        _host(
          WorkspaceModeBar<_Choice>(
            items: _items.take(2).toList(),
            selectedValue: _Choice.first,
            onChanged: (_) => callCount++,
            enabled: false,
            presentation: WorkspaceNavigationPresentation.chips,
          ),
        ),
      );

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      expect(chips.every((chip) => chip.onSelected == null), isTrue);
      await tester.tap(find.text('Second'));
      expect(callCount, 0);
    });

    testWidgets('uses a menu at narrow width and selects from it', (tester) async {
      _Choice? changed;
      await tester.pumpWidget(
        _host(
          WorkspaceModeBar<_Choice>(
            items: _items,
            selectedValue: _Choice.first,
            onChanged: (value) => changed = value,
          ),
          width: 300,
        ),
      );

      expect(find.byKey(const Key('workspace-mode-menu')), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      await tester.tap(find.byKey(const Key('workspace-mode-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workspace-mode-selected-check')), findsOneWidget);
      await tester.tap(find.text('Third').last);
      await tester.pumpAndSettle();
      expect(changed, _Choice.third);
    });
  });

  group('WorkspaceSourcePicker', () {
    testWidgets('supports an explicitly selected menu source', (tester) async {
      await tester.pumpWidget(
        _host(
          WorkspaceSourcePicker<_Choice>(
            items: _items.take(2).toList(),
            selectedValue: _Choice.second,
            onChanged: (_) {},
            presentation: WorkspaceNavigationPresentation.menu,
          ),
        ),
      );

      expect(find.byKey(const Key('workspace-source-picker')), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.byType(PopupMenuButton<_Choice>), findsOneWidget);
    });
  });

  group('WorkspaceActionButton', () {
    testWidgets('exposes enabled and disabled actions', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          Row(
            children: [
              WorkspaceActionButton(
                label: 'Add',
                icon: Icons.add,
                onPressed: () => calls++,
              ),
              const WorkspaceActionButton(
                label: 'Disabled',
                icon: Icons.block,
                onPressed: null,
                compact: true,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Add'));
      expect(calls, 1);
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
    });
  });
}
