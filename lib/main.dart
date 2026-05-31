import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'models.dart';
import 'security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive storage adapters for your specific device architecture
  await Hive.initFlutter();

  // Register the encryption adapter we generated in Step 3
  Hive.registerAdapter(TransactionModelAdapter());

  runApp(const MoneyManagerApp());
}

class MoneyManagerApp extends StatelessWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vault Money',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFFEF4444),
          tertiary: Color(0xFF8B5CF6),
        ),
      ),
      home: const UnlockScreen(), // Changed from DashboardScreen()
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txBox = Hive.box<TransactionModel>('encrypted_transactions');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        'Secure Vault',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.shield, color: Color(0xFF10B981)),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Live Mathematical Value Card
              ValueListenableBuilder(
                valueListenable: txBox.listenable(),
                builder: (context, Box<TransactionModel> box, _) {
                  double totalIncome = 0;
                  double totalExpense = 0;
                  double totalInvestment = 0;

                  for (var tx in box.values) {
                    if (tx.type == 'Income') totalIncome += tx.amount;
                    if (tx.type == 'Expense') totalExpense += tx.amount;
                    if (tx.type == 'Investment') totalInvestment += tx.amount;
                  }

                  double totalBalance =
                      totalIncome - totalExpense - totalInvestment;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL ENCRYPTED BALANCE',
                          style: TextStyle(
                            color: Colors.grey,
                            letterSpacing: 1.2,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalBalance.toStringAsFixed(2)}', // Rupee Currency Change!
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            BalanceStat(
                              title: 'Income',
                              amount: '₹${totalIncome.toStringAsFixed(0)}',
                              color: const Color(0xFF10B981),
                            ),
                            const Spacer(),
                            BalanceStat(
                              title: 'Expense',
                              amount: '₹${totalExpense.toStringAsFixed(0)}',
                              color: const Color(0xFFEF4444),
                            ),
                            const Spacer(),
                            BalanceStat(
                              title: 'Invested',
                              amount: '₹${totalInvestment.toStringAsFixed(0)}',
                              color: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 35),

              const Text(
                'Recent Safe Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              // Live Dynamic Transaction Stream
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: txBox.listenable(),
                  builder: (context, Box<TransactionModel> box, _) {
                    if (box.isEmpty) {
                      return const Center(
                        child: Text(
                          'No encrypted records yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    // Sort transactions to show the newest entries first
                    final transactions = box.values.toList()
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];

                        IconData selectedIcon = Icons.monetization_on;
                        if (tx.type == 'Income') selectedIcon = Icons.work;
                        if (tx.type == 'Expense') selectedIcon = Icons.bolt;
                        if (tx.type == 'Investment')
                          selectedIcon = Icons.trending_up;
                        if (tx.type == 'Loan') selectedIcon = Icons.handshake;

                        return TransactionTile(
                          title: tx.title,
                          category: tx.category,
                          amount:
                              '${tx.type == "Income" ? "+" : "-"}₹${tx.amount.toStringAsFixed(2)}',
                          isIncome: tx.type == 'Income',
                          isInvestment: tx.type == 'Investment',
                          icon: selectedIcon,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AddTransactionSheet(),
          );
        },
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
    );
  }
}

class BalanceStat extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;

  const BalanceStat({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class TransactionTile extends StatelessWidget {
  final String title;
  final String category;
  final String amount;
  final bool isIncome;
  final bool isInvestment;
  final IconData icon;

  const TransactionTile({
    super.key,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    this.isInvestment = false,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color amountColor = isIncome
        ? const Color(0xFF10B981)
        : (isInvestment ? const Color(0xFF8B5CF6) : const Color(0xFFEF4444));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: amountColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: amountColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  category,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  String selectedType = 'Expense';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    Color activeColor = const Color(0xFFEF4444); // Expense
    if (selectedType == 'Income') activeColor = const Color(0xFF10B981);
    if (selectedType == 'Investment') activeColor = const Color(0xFF8B5CF6);
    if (selectedType == 'Loan')
      activeColor = const Color(0xFFF59E0B); // Amber for loans

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Secure Entry',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: ['Income', 'Expense', 'Investment', 'Loan'].map((type) {
                bool isSelected = selectedType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedType = type),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? activeColor : Colors.grey[800]!,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? activeColor : Colors.grey,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 25),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: activeColor,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.grey[800]),
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                ),
                border: InputBorder.none,
              ),
            ),
            const Divider(color: Color(0xFF1F2937)),
            const SizedBox(height: 15),

            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: selectedType == 'Loan'
                    ? 'Lender / Borrower Name'
                    : 'Item / Source Name',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF161E2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _categoryController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: selectedType == 'Loan'
                    ? 'Loan Purpose / Terms'
                    : 'Category (e.g., Bills, Food)',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF161E2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  // 1. Validate that the input amount is a proper number
                  final double? enteredAmount = double.tryParse(
                    _amountController.text,
                  );
                  if (enteredAmount == null || _titleController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid title and amount.'),
                      ),
                    );
                    return;
                  }

                  // 2. Access the already opened encrypted box
                  final txBox = Hive.box<TransactionModel>(
                    'encrypted_transactions',
                  );

                  // 3. Create a clean unique data package
                  final newTransaction = TransactionModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: _titleController.text,
                    amount: enteredAmount,
                    type: selectedType,
                    category: _categoryController.text.isEmpty
                        ? 'General'
                        : _categoryController.text,
                    timestamp: DateTime.now(),
                  );

                  // 4. Inject it into the encrypted engine
                  await txBox.put(newTransaction.id, newTransaction);

                  // 5. Dismiss the input panel safely
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      'Encrypt & Save Entry',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _attemptUnlock() async {
    if (_passwordController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Stretch the user's password into a 256-bit AES cryptographic key
      final encryptionKey = SecurityService.deriveKey(_passwordController.text);

      // 2. Attempt to open the local encrypted database file using the key
      final encryptedBox = await Hive.openBox<TransactionModel>(
        'encrypted_transactions',
        encryptionCipher: HiveAesCipher(encryptionKey),
      );

      // 3. If successful, pass the decrypted database reference to your Dashboard layout
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      // If the encryption key is wrong, Hive will throw an exception automatically
      setState(() {
        _errorMessage = "Decryption Failed. Invalid Key Master File.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_person_outlined,
                size: 80,
                color: Color(0xFF10B981),
              ),
              const SizedBox(height: 16),
              const Text(
                'VAULT INTERCEPT',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter Master Password to Decrypt Vault Storage',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: '••••••••••••',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF161E2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.key, color: Colors.grey),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _attemptUnlock,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'DECRYPT STORAGE',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
