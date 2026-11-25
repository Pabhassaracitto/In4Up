// lib/features/mascot/mascot_controller.dart
//
// MASCOT-003 — Bộ não phiên chat của linh vật Sara (PLAN-050 §5/§8,
// ADR-0036 D1/D4).
//
// NGUYÊN TẮC "MỘT BỘ NÃO": controller KHÔNG nhân bản engine chat — mọi tin
// nhắn đi qua `AiServiceFacade` (giữ epoch/stop/queue/persist/history như AI
// Chat màn hình cũ). Sara chỉ thêm: persona + ngữ cảnh tab (oneShotContext —
// PSRC-264: chỉ đính một lần) + bóc hành động từ câu trả lời rồi thực thi qua
// `ShellActionHub` (tab/mode/tool; playback chưa nối ở P1).
//
// Đăng ký ở `lib/main.dart` NGAY SAU provider `AiServiceFacade` (cần facade
// sẵn — đọc bằng context.read trong create).

import 'package:flutter/foundation.dart';

import 'package:in4up_ai/in4up_ai.dart';

import '../../services/storage_service.dart';
import 'mascot_context_builder.dart';
import 'mascot_intent_registry.dart';
import 'mascot_prompts.dart';
import 'mascot_reply_parser.dart';
import 'shell_action_hub.dart';

/// Controller phiên chat Sara — ChangeNotifier cho sheet lắng nghe.
class MascotController extends ChangeNotifier {
  MascotController({required AiServiceFacade facade}) : _facade = facade;

  final AiServiceFacade _facade;

  AiServiceFacade get facade => _facade;

  MascotContextData? _sessionContext;

  MascotContextData? get sessionContext => _sessionContext;

  /// Kết quả parse LƯỢT TRẢ LỜI GẦN NHẤT (null khi chưa hỏi gì).
  MascotParsedReply? get lastParsedReply => _lastParsedReply;
  MascotParsedReply? _lastParsedReply;

  /// Hành động vừa được thực thi sau lượt trả lời gần nhất (null nếu không có
  /// hoặc model yêu cầu id không hợp lệ — UI hiện "không chạy được").
  MascotActionDef? get lastExecutedAction => _lastExecutedAction;
  MascotActionDef? _lastExecutedAction;

  String? _lastExecutionError;
  String? get lastExecutionError => _lastExecutionError;

  /// Bắt đầu/mở lại phiên với ngữ cảnh tab hiện tại — main_shell gọi trước
  /// khi mở sheet (thu thập từ provider THẬT, không hardcode).
  void beginSession(MascotContextData data) {
    _sessionContext = data;
    notifyListeners();
  }

  /// Gửi câu hỏi người dùng. Sau khi facade xử lý xong (streaming kết thúc),
  /// parse lượt trả lời cuối và tự thực thi hành động nếu hợp lệ.
  Future<void> send(String message) async {
    final text = message.trim();
    if (text.isEmpty) return;

    _lastExecutedAction = null;
    _lastExecutionError = null;
    notifyListeners();

    final context = _sessionContext;
    final oneShot = context == null
        ? null
        : buildMascotOneShotContext(
            context,
            systemPrompt: buildMascotDefaultSystemPrompt(),
          );

    // await = đợi LƯỢT NÀY xử lý xong (facade `sendMessage` hoàn tất cùng
    // `item.done.future` — hàng đợi tuần tự, không cần listener dò streaming).
    await _facade.sendMessage(text, oneShotContext: oneShot);

    // Bóc hành động từ lượt trả lời TRỰC THUỘC lượt này: tin assistant cuối
    // trong lịch sử facade (lỗi thì bỏ qua — không thực thi trên câu lỗi).
    ChatMessage? lastAssistant;
    for (final message in _facade.chatMessages) {
      if (message.role == ChatRole.assistant) lastAssistant = message;
    }
    if (lastAssistant == null || lastAssistant.isError) {
      _lastParsedReply = null;
      notifyListeners();
      return;
    }

    final parsed = parseMascotReply(lastAssistant.text);
    _lastParsedReply = parsed;

    final actionId = parsed.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      final def = MascotIntentRegistry.byId(actionId);
      if (def == null) {
        _lastExecutionError = actionId;
      } else if (def.group == MascotActionGroup.playback) {
        // P1 chưa nối executor playback — không thực thi, không báo lỗi giả.
        _lastExecutionError = null;
      } else {
        final result = await ShellActionHub.instance.execute(def);
        if (result.executed) {
          _lastExecutedAction = def;
          if (def.group == MascotActionGroup.tool) {
            await StorageService().recordQuickActionUsage(def.id);
          }
        } else {
          _lastExecutionError = result.reason ?? def.id;
        }
      }
    }
    notifyListeners();
  }

  /// Dừng lượt đang streaming (nút Dừng trong sheet — facade guard sẵn).
  void stop() {
    _facade.stopGenerating();
    notifyListeners();
  }

  /// Xoá hội thoại (cùng epoch của facade — màn AI Chat cũng thấy xoá, đúng
  /// hợp đồng "một bộ não").
  Future<void> clear() async {
    await _facade.clearChat();
    _lastParsedReply = null;
    _lastExecutedAction = null;
    _lastExecutionError = null;
    notifyListeners();
  }
}
