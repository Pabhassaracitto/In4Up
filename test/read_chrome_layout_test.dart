// READ-UI-120 — model cấu hình chrome tab Đọc (thuần Dart, không cần Flutter).
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/read_chrome_layout.dart';

void main() {
  group('ReadChromeLayout.defaults', () {
    test('tối giản: công cụ gộp ở đáy, không ẩn nút phát', () {
      const layout = ReadChromeLayout.defaults;
      expect(layout.toolsState, ReadChromeGroupState.collapsed);
      expect(layout.displayState, ReadChromeGroupState.collapsed);
      expect(layout.toolsPlacement, ReadToolsPlacement.bottom);
      expect(layout.useBottomDock, isTrue);
      expect(layout.dockAlwaysVisible, isTrue);
      expect(layout.toolsExpanded, isFalse);
      expect(layout.toolsHidden, isFalse);
      expect(layout.playbackScope, ReadPlaybackScope.wholeDocument);
      expect(layout.readsWholeDocument, isTrue);
    });

    test('mặc định vẫn tự dịch nền nhưng KHÔNG chặn phát', () {
      // autoTranslateOnBilingual chỉ quyết định có gọi translateAll nền hay
      // không; startReadPlayback không await nó (pin ở contract test).
      expect(ReadChromeLayout.defaults.autoTranslateOnBilingual, isTrue);
    });
  });

  test('missing scope defaults to the whole document; explicit line is retained', () {
    expect(ReadChromeLayout.fromJson({}).readsWholeDocument, isTrue);
    expect(ReadChromeLayout.fromJson({'playbackScope': 'currentLine'}).readsWholeDocument, isFalse);
  });

  group('copyWith', () {
    test('đổi từng trường, giữ các trường còn lại', () {
      const base = ReadChromeLayout.defaults;
      final next = base.copyWith(
        toolsState: ReadChromeGroupState.expanded,
        playbackScope: ReadPlaybackScope.wholeDocument,
      );
      expect(next.toolsState, ReadChromeGroupState.expanded);
      expect(next.readsWholeDocument, isTrue);
      expect(next.toolsPlacement, ReadToolsPlacement.bottom);
      expect(next.rememberExpanded, isTrue);
      expect(next.autoTranslateOnBilingual, isTrue);
    });
  });

  group('collapsedTools', () {
    test('ghi nhớ panel khi rememberExpanded = true', () {
      const base = ReadChromeLayout.defaults;
      final opened = base.collapsedTools(
        panel: ReadDockPanel.tools,
        open: true,
      );
      expect(opened.toolsExpanded, isTrue);
      expect(opened.lastPanel, ReadDockPanel.tools);

      final closed = opened.collapsedTools(panel: opened.lastPanel);
      expect(closed.toolsExpanded, isFalse);
      expect(closed.lastPanel, ReadDockPanel.tools);
    });

    test('không ghi nhớ ⇒ về panel audio + gộp', () {
      const base = ReadChromeLayout(rememberExpanded: false);
      final opened = base.collapsedTools(
        panel: ReadDockPanel.display,
        open: true,
      );
      expect(opened.toolsExpanded, isTrue);
      expect(opened.lastPanel, ReadDockPanel.audio);
    });
  });

  group('encode / decode', () {
    test('round-trip giữ nguyên mọi trường', () {
      const layout = ReadChromeLayout(
        toolsState: ReadChromeGroupState.hidden,
        displayState: ReadChromeGroupState.expanded,
        toolsPlacement: ReadToolsPlacement.top,
        rememberExpanded: false,
        autoTranslateOnBilingual: false,
        playbackScope: ReadPlaybackScope.wholeDocument,
        lastPanel: ReadDockPanel.display,
      );
      expect(ReadChromeLayout.decode(layout.encode()), layout);
      expect(layout.dockAlwaysVisible, isFalse);
    });

    test('dữ liệu cũ / hỏng / null ⇒ về defaults, không crash', () {
      expect(ReadChromeLayout.decode(null), ReadChromeLayout.defaults);
      expect(ReadChromeLayout.decode(''), ReadChromeLayout.defaults);
      expect(ReadChromeLayout.decode('{not json'),
          ReadChromeLayout.defaults);
      expect(ReadChromeLayout.decode('[]'), ReadChromeLayout.defaults);
      expect(
        ReadChromeLayout.decode('{"toolsState":"khong_biet","toolsPlacement":42}'),
        ReadChromeLayout.defaults,
      );
    });

    test('thiếu key ⇒ điền giá trị mặc định cho key đó', () {
      final decoded =
          ReadChromeLayout.decode('{"toolsState":"expanded"}');
      expect(decoded.toolsState, ReadChromeGroupState.expanded);
      expect(decoded.toolsPlacement, ReadToolsPlacement.bottom);
      expect(decoded.autoTranslateOnBilingual, isTrue);
    });
  });

  group('3 nhóm × 3 trạng thái + allowHide', () {
    test('mỗi nhóm có key riêng read_chrome_group_<id>_v1', () {
      for (final group in ReadChromeGroupId.values) {
        expect(group.storageKey,
            'read_chrome_group_${group.name}_v1');
      }
    });

    test('Nguồn KHÔNG cho ẩn; 2 nhóm kia cho ẩn', () {
      expect(ReadChromeGroupId.source.allowHide, isFalse);
      expect(ReadChromeGroupId.tools.allowHide, isTrue);
      expect(ReadChromeGroupId.display.allowHide, isTrue);

      const base = ReadChromeLayout.defaults;
      final guarded = ReadChromeGroupId.source.withState(
        base,
        ReadChromeGroupState.hidden,
      );
      expect(guarded.sourceState, ReadChromeGroupState.collapsed);
      expect(ReadChromeGroupId.display.withState(
        base,
        ReadChromeGroupState.hidden,
      ).displayHidden, isTrue);
    });

    test('stateOf / withState round-trip cho cả 3 nhóm', () {
      const base = ReadChromeLayout.defaults;
      for (final group in ReadChromeGroupId.values) {
        final next = group.withState(
          base,
          ReadChromeGroupState.expanded,
        );
        expect(group.stateOf(next), ReadChromeGroupState.expanded);
        expect(group.stateOf(base), ReadChromeGroupState.collapsed);
      }
    });

    test('JSON cũ ghi hidden cho Nguồn ⇒ tự ép về collapsed', () {
      final decoded = ReadChromeLayout.decode(
        '{"sourceState":"hidden","toolsState":"expanded"}',
      );
      expect(decoded.sourceState, ReadChromeGroupState.collapsed);
      expect(decoded.toolsExpanded, isTrue);
    });

    test('nhãn nhóm là chuỗi nguồn (đi qua uiText)', () {
      expect(ReadChromeGroupId.source.label, 'Nguồn');
      expect(ReadChromeGroupId.tools.label, 'Công cụ đọc');
      expect(ReadChromeGroupId.display.label, 'Thông tin & Hiển thị');
    });
  });

  group('equality', () {
    test('hai instance cùng giá trị bằng nhau', () {
      expect(const ReadChromeLayout(), ReadChromeLayout.defaults);
      expect(
        const ReadChromeLayout(toolsState: ReadChromeGroupState.hidden),
        isNot(ReadChromeLayout.defaults),
      );
    });
  });
}
