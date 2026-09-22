import 'package:flutter/material.dart';

import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import '../state/ticket_api_scope.dart';

/// 빠른 메뉴에서 입장 가능한 티켓을 찾는다. 한 장이면 곧바로 QR 을 연다.
class QuickEntryQrScreen extends StatefulWidget {
  const QuickEntryQrScreen({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  State<QuickEntryQrScreen> createState() => _QuickEntryQrScreenState();
}

class _QuickEntryQrScreenState extends State<QuickEntryQrScreen> {
  late Future<List<MyTicket>> _tickets;

  @override
  void initState() {
    super.initState();
    _tickets = _load();
  }

  Future<List<MyTicket>> _load() async {
    final tickets = await TicketApiScope.of(context).fetchMyTickets();
    final now = (widget.clock ?? DateTime.now)();
    final available = tickets.where((ticket) => ticket.canEnter(now)).toList();
    if (available.length == 1 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(available.single);
      });
    }
    return available;
  }

  void _open(MyTicket ticket) {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.entryQr,
      arguments: ticket,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(TicketStrings.qrScreenTitle)),
    body: AsyncBoundary<List<MyTicket>>(
      future: _tickets,
      onRetry: () => setState(() => _tickets = _load()),
      builder: (context, tickets) {
        if (tickets.isEmpty) {
          return const Center(child: Text(TicketStrings.qrNoTickets));
        }
        if (tickets.length == 1) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(TicketMetrics.horizontalPadding),
          children: [
            const Text(TicketStrings.qrSelectTicket),
            const SizedBox(height: 16),
            for (final ticket in tickets)
              ListTile(
                title: Text(ticket.title),
                subtitle: Text('${ticket.venueName} · ${ticket.seatLabel}'),
                trailing: const Icon(Icons.qr_code_2),
                onTap: () => _open(ticket),
              ),
          ],
        );
      },
    ),
  );
}
