import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CheckRewardPage extends StatefulWidget {
  final int drawId; // งวดที่ต้องการตรวจ
  final String apiEndpoint; // URL ของ Backend
  final int userId; // รหัสผู้ใช้

  const CheckRewardPage({
    super.key,
    required this.drawId,
    required this.apiEndpoint,
    required this.userId,
  });

  @override
  State<CheckRewardPage> createState() => _CheckRewardPageState();
}

class _CheckRewardPageState extends State<CheckRewardPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> myTickets = [];
  String drawStatus = "active"; // สถานะงวด: active/closed

  @override
  void initState() {
    super.initState();
    fetchRewards();
  }

  Future<void> claimReward(int purchaseId) async {
    try {
      final response = await http.post(
        Uri.parse("${widget.apiEndpoint}/tickets/claim"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "purchaseId": purchaseId,
          "userId": widget.userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ขึ้นรางวัลแล้ว: ${data['amount']} บาท")),
        );

        // รีโหลดข้อมูลใหม่
        fetchRewards();
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ผิดพลาด: ${err['error']}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> fetchRewards() async {
    try {
      final response = await http.get(Uri.parse(
          "${widget.apiEndpoint}/tickets/reward/${widget.drawId}/${widget.userId}"));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        setState(() {
          drawStatus = data['drawStatus'];
          myTickets = (data['rewards'] as List)
              .map((e) => {
                    'purchase_id': e['purchase_id'],
                    'ticket_number': e['ticket_number'],
                    'status': e['status'],
                    'prize': e['prize'],
                    'prize_type': e['prize_type'],
                    'already_claimed': e['already_claimed'] ?? false,
                    'claimed':
                        e['status'] == 'win' && (e['already_claimed'] ?? false),
                  })
              .toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        print("Failed to fetch rewards: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Error fetchRewards: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ตรวจรางวัล"),
        backgroundColor: Colors.orange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : myTickets.isEmpty
              ? const Center(
                  child: Text(
                    "คุณยังไม่มีเลขในงวดนี้",
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: myTickets.length,
                  itemBuilder: (context, index) {
                    final item = myTickets[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text("เลข: ${item['ticket_number']}"),
                        subtitle: Text(
                          item['status'] == "pending"
                              ? "รอประกาศรางวัล"
                              : item['status'] == "win"
                                  ? "ถูกรางวัล (${item['prize_type']}) ${(item['prize'] ?? 0)} บาท"
                                  : "ไม่ถูกรางวัล",
                          style: TextStyle(
                            color: item['status'] == "win"
                                ? Colors.green
                                : item['status'] == "lose"
                                    ? Colors.red
                                    : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: item['status'] == "win"
                            ? item['claimed']
                                ? const Text(
                                    "ขึ้นรางวัลแล้ว",
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold),
                                  )
                                : ElevatedButton(
                                    onPressed: () =>
                                        claimReward(item['purchase_id'] as int),
                                    child: const Text("ขึ้นรางวัล"),
                                  )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
