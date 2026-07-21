import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_chat_controller.dart';
import '../application/ai_portal_context_builder.dart';
import '../domain/ai_chat_models.dart';
import 'ai_context_consent_sheet.dart';
import 'ai_provider_settings_screen.dart';
import 'ai_provider_switcher_sheet.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _shareContextConsented = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_shareContextConsented) {
      final snapshot = const AiPortalContextBuilder().buildSnapshot(ref);
      ref.read(aiChatControllerProvider.notifier).sendMessage(text, contextSnapshot: snapshot);
    } else {
      ref.read(aiChatControllerProvider.notifier).sendMessage(text);
    }
    _textController.clear();
    FocusScope.of(context).unfocus(); // Close keyboard after sending
  }

  void _showConsentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return AiContextConsentSheet(
          onConsentChanged: (consented) {
            setState(() {
              _shareContextConsented = consented;
            });
          },
        );
      },
    );
  }

  void _showProviderSwitcher() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const AiProviderSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatControllerProvider);
    final notifier = ref.read(aiChatControllerProvider.notifier);

    // Auto scroll khi có tin nhắn mới hoặc đang stream
    ref.listen(aiChatControllerProvider, (prev, next) {
      if (prev?.activeConversation?.messages.length != next.activeConversation?.messages.length ||
          (next.isGenerating && _scrollController.hasClients)) {
        _scrollToBottom();
      }
    });

    final hasProvider = state.activeProvider != null;
    final conversation = state.activeConversation;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showHistorySheet(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  conversation?.title ?? 'Trợ lý AI',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: PortalSpacing.xxs),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        actions: [
          if (hasProvider)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.35, // reduced from 0.4
                ),
                child: ActionChip(
                  label: Text(
                    '${state.activeProvider!.name} · ${state.activeProvider!.modelId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10), // reduced size
                  ),
                  onPressed: _showProviderSwitcher,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Hội thoại mới',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: notifier.startNewConversation,
          ),
          IconButton(
            tooltip: 'Cấu hình AI',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiProviderSettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !hasProvider
                  ? _buildNoProviderState(context)
                  : conversation == null || conversation.messages.isEmpty
                      ? _buildEmptyState(context)
                      : _buildChatList(context, conversation, state),
            ),
            if (hasProvider) _buildComposer(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildNoProviderState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PortalSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.assistant_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: PortalSpacing.lg),
            Text(
              'Cấu hình Trợ lý AI',
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PortalSpacing.xs),
            Text(
              'Trợ lý AI hỗ trợ bạn giải quyết các thắc mắc về lịch học, học phí và điểm số chạy ngay trên máy hoặc kết nối qua API.',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PortalSpacing.xl),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiProviderSettingsScreen()),
              ),
              icon: const Icon(Icons.settings),
              label: const Text('Cấu hình ngay'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final suggestions = [
      'Lịch học tuần này của tôi?',
      'Tôi còn nợ học phí không?',
      'Tóm tắt điểm số học kỳ mới nhất',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PortalSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assistant_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: PortalSpacing.md),
            Text(
              'Tôi có thể giúp gì cho bạn?',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: PortalSpacing.lg),
            for (final suggestion in suggestions) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: PortalSpacing.xs),
                child: ActionChip(
                  label: Text(suggestion),
                  onPressed: () {
                    _textController.text = suggestion;
                    _sendMessage();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context, AiConversation conversation, AiChatState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        if (state.errorMessage != null)
          Container(
            color: colorScheme.errorContainer,
            width: double.infinity,
            padding: const EdgeInsets.all(PortalSpacing.sm),
            child: Text(
              state.errorMessage!,
              style: TextStyle(color: colorScheme.onErrorContainer),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(PortalSpacing.md),
            itemCount: conversation.messages.length,
            itemBuilder: (context, index) {
              final msg = conversation.messages[index];
              final isUser = msg.role == AiMessageRole.user;

              return Padding(
                padding: const EdgeInsets.only(bottom: PortalSpacing.md),
                child: Row(
                  mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isUser) ...[
                      const CircleAvatar(
                        radius: 16,
                        child: Icon(Icons.assistant, size: 16),
                      ),
                      const SizedBox(width: PortalSpacing.xs),
                    ],
                    Flexible(
                      child: isUser
                          ? PortalSurface(
                              padding: const EdgeInsets.symmetric(
                                horizontal: PortalSpacing.md,
                                vertical: PortalSpacing.sm,
                              ),
                              child: Text(
                                msg.content,
                                style: textTheme.bodyLarge,
                              ),
                            )
                          : Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.8,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: PortalSpacing.xs),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SelectionArea(
                                    child: MarkdownBody(
                                      data: msg.content,
                                      shrinkWrap: true,
                                    ),
                                  ),
                                  if (msg.status == AiMessageStatus.streaming)
                                    const Padding(
                                      padding: EdgeInsets.only(top: PortalSpacing.xxs),
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComposer(BuildContext context, AiChatState state) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + PortalSpacing.sm,
        left: PortalSpacing.md,
        right: PortalSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  value: _shareContextConsented,
                  title: const Text(
                    'Chia sẻ ngữ cảnh học tập (Điểm, Lịch học, Học phí)',
                    style: TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val == true) {
                      _showConsentSheet();
                    } else {
                      setState(() {
                        _shareContextConsented = false;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: PortalSpacing.md,
                      vertical: PortalSpacing.sm,
                    ),
                  ),
                  maxLines: 5,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  onSubmitted: (val) {
                    _sendMessage();
                  },
                ),
              ),
              const SizedBox(width: PortalSpacing.xs),
              IconButton(
                onPressed: state.isGenerating
                    ? ref.read(aiChatControllerProvider.notifier).stopGeneration
                    : _sendMessage,
                icon: Icon(
                  state.isGenerating ? Icons.stop_circle : Icons.send,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(aiChatControllerProvider);
            final notifier = ref.read(aiChatControllerProvider.notifier);

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('Lịch sử hội thoại'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.conversations.length,
                      itemBuilder: (context, index) {
                        final conv = state.conversations[index];
                        final isActive = conv.id == state.activeConversation?.id;

                        return ListTile(
                          title: Text(
                            conv.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          leading: Icon(
                            Icons.chat_bubble_outline,
                            color: isActive ? Theme.of(context).colorScheme.primary : null,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              notifier.deleteConversation(conv.id);
                              if (state.conversations.length <= 1) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          onTap: () {
                            notifier.switchConversation(conv.id);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
