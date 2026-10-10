import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/features/ai_advisor/presentation/providers/ai_advisor_service.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';

class AiAdvisorPage extends ConsumerStatefulWidget {
  const AiAdvisorPage({super.key});

  @override
  ConsumerState<AiAdvisorPage> createState() => _AiAdvisorPageState();
}

class _AiAdvisorPageState extends ConsumerState<AiAdvisorPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <AiChatMessage>[
    const AiChatMessage(
      role: AiChatRole.assistant,
      text:
          'Halo, aku AI Advisor. Tanya apa aja soal cashflow, budget, tabungan, atau cara ngatur pengeluaran kamu.',
    ),
  ];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: _messages.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return dashboard.when(
                  data: (data) => _FinanceContextCard(
                    income: data.totalIncome,
                    expense: data.totalExpense,
                    savings: data.totalSavings,
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Gagal memuat data keuangan',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return _MessageBubble(message: _messages[index - 1]);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Tanya AI soal keuangan kamu...',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _send,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(AiChatMessage(role: AiChatRole.user, text: text));
      _controller.clear();
      _loading = true;
    });
    _scrollToBottom();

    final history = _messages.length > 1
        ? _messages.sublist(1, _messages.length - 1)
        : <AiChatMessage>[];
    final reply = await AiAdvisorService().ask(message: text, history: history);

    if (!mounted) return;
    setState(() {
      _messages.add(AiChatMessage(role: AiChatRole.assistant, text: reply));
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _FinanceContextCard extends StatelessWidget {
  final double income;
  final double expense;
  final double savings;

  const _FinanceContextCard({
    required this.income,
    required this.expense,
    required this.savings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'AI Advisor Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pemasukan ${CurrencyFormatter.format(income)} | Pengeluaran ${CurrencyFormatter.format(expense)} | Tabungan ${CurrencyFormatter.format(savings)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primaryColor
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}


