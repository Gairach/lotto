import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CheckRewardHistoryPage extends StatefulWidget {
  final int userId;
  final String apiEndpoint;

  const CheckRewardHistoryPage({
    super.key,
    required this.userId,
    required this.apiEndpoint,
  });

  @override
  State<CheckRewardHistoryPage> createState() => _CheckRewardHistoryPageState();
}

class _CheckRewardHistoryPageState extends State<CheckRewardHistoryPage> {
  List<Map<String, dynamic>> history = [];
  bool isLoading = true;
  bool showOnlyWon = false;

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    try {
      final response = await http.get(
        Uri.parse("${widget.apiEndpoint}/tickets/history/${widget.userId}"),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final List<dynamic> data = json['history'] ?? [];

        setState(() {
          history = data.map((e) {
            return {
              'ticket_number':
                  e['ticket_number'] ?? e['number'] ?? 'ไม่พบเลขหวย',
              'price': e['price'] ?? 0,
              'reward_amount': e['reward_amount'] ?? 0,
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('โหลดประวัติไม่สำเร็จ (${response.statusCode})')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // กรองตาม toggle และ parse reward_amount เป็น int
    final List<Map<String, dynamic>> filteredHistory = showOnlyWon
        ? history.where((item) {
            final rewardAmount =
                int.tryParse(item['reward_amount']?.toString() ?? '0') ?? 0;
            return rewardAmount > 0;
          }).toList()
        : history;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Image.network(
          'https://raw.githubusercontent.com/FarmHouse2263/lotto/refs/heads/main/image%202.png',
          height: 30,
          width: 80,
          fit: BoxFit.cover,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text("แสดง: "),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("ทั้งหมด"),
                  selected: !showOnlyWon,
                  onSelected: (selected) =>
                      setState(() => showOnlyWon = !selected),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("ถูกรางวัล"),
                  selected: showOnlyWon,
                  onSelected: (selected) =>
                      setState(() => showOnlyWon = selected),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final item = filteredHistory[index];
                      final rewardAmount = int.tryParse(
                              item['reward_amount']?.toString() ?? '0') ??
                          0;
                      final won = rewardAmount > 0;
                      final ticketNumber = item['ticket_number'];

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: won ? Colors.green[50] : Colors.grey[200],
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(
                            won ? Icons.celebration : Icons.history,
                            color: won ? Colors.green : Colors.grey,
                            size: 36,
                          ),
                          title: Text(
                            "เลขหวย: $ticketNumber",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text("ราคา: ${item['price']}"),
                              const SizedBox(height: 2),
                              Text(
                                won
                                    ? "ถูกรางวัล: $rewardAmount"
                                    : "ยังไม่ถูกรางวัล",
                                style: TextStyle(
                                  color: won
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                                  fontWeight:
                                      won ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
