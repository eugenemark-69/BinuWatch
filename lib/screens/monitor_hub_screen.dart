import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'bird_screen.dart';
import '../pairing_service.dart';

class MonitorHubScreen extends StatefulWidget {
  const MonitorHubScreen({super.key});

  @override
  State<MonitorHubScreen> createState() => _MonitorHubScreenState();
}

class _MonitorHubScreenState extends State<MonitorHubScreen> {
  final _codeController = TextEditingController();

  bool _loading = true; // reading what was saved on this phone
  bool _busy = false; // talking to Firebase
  bool _enteringCode = false; // receiver is typing the code
  SavedPairing? _saved;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final s = await PairingService.instance.loadSaved();
    if (!mounted) return;
    setState(() {
      _saved = s;
      _loading = false;
    });
  }

  String _msg(Object e) {
    if (e is PairingException) return e.message;
    debugPrint('Pairing error: $e');
    return 'Something went wrong. Check your internet and try again.';
  }

  Future<void> _chooseMonitor() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PairingService.instance.createPairing();
      await _loadSaved();
    } catch (e) {
      _error = _msg(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PairingService.instance.joinPairing(_codeController.text);
      _enteringCode = false;
      _codeController.clear();
      await _loadSaved();
    } catch (e) {
      _error = _msg(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _unpair() async {
    setState(() => _busy = true);
    await PairingService.instance.unpair();
    if (!mounted) return;
    setState(() {
      _saved = null;
      _enteringCode = false;
      _error = null;
      _busy = false;
    });
  }

  // Used when the pairing no longer exists on the server.
  Future<void> _startOver() async {
    await PairingService.instance.clearLocal();
    if (!mounted) return;
    setState(() {
      _saved = null;
      _enteringCode = false;
      _error = null;
    });
  }

  void _openCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Monitoring')),
          body: const BirdScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_saved == null) {
      return _enteringCode ? _buildCodeEntry() : _buildChooser();
    }

    final saved = _saved!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: PairingService.instance.watch(saved.code),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Pairing watch error: ${snap.error}');
          return _centered([
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text('Could not reach the pairing server.\nCheck your internet.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _startOver, child: const Text('Start over')),
          ]);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final doc = snap.data!;
        if (!doc.exists) {
          return _centered([
            const Icon(Icons.link_off, size: 48),
            const SizedBox(height: 12),
            const Text('This pairing was ended.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _startOver, child: const Text('Start over')),
          ]);
        }
        final paired = doc.data()?['paired'] == true;
        return saved.role == PairRole.monitor
            ? _buildMonitorView(saved.code, paired)
            : _buildReceiverView(paired);
      },
    );
  }

  // ---------- Screens ----------

  Widget _buildChooser() {
    return _centered([
      const Text('What will this phone do?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _busy ? null : _chooseMonitor,
          icon: const Icon(Icons.videocam),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Monitor', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
      const SizedBox(height: 4),
      const Text('Leave this phone watching the rice.',
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => setState(() {
            _enteringCode = true;
            _error = null;
          }),
          icon: const Icon(Icons.notifications_active),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Receive notifications', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
      const SizedBox(height: 4),
      const Text('Get alerts on this phone when a bird is seen.',
          textAlign: TextAlign.center),
      if (_busy) ...[
        const SizedBox(height: 24),
        const CircularProgressIndicator(),
      ],
      if (_error != null) _errorText(),
    ]);
  }

  Widget _buildCodeEntry() {
    return _centered([
      const Icon(Icons.notifications_active, size: 48),
      const SizedBox(height: 12),
      const Text('Enter the 6-digit code shown on the monitor phone.',
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 32, letterSpacing: 8),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          counterText: '',
          hintText: '000000',
        ),
        onSubmitted: (_) => _busy ? null : _join(),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _busy ? null : _join,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Pair', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
          _enteringCode = false;
          _error = null;
        }),
        child: const Text('Cancel'),
      ),
      if (_busy) const CircularProgressIndicator(),
      if (_error != null) _errorText(),
    ]);
  }

  Widget _buildMonitorView(String code, bool paired) {
    if (!paired) {
      return _centered([
        const Text('Pairing code',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(code,
            style: const TextStyle(
                fontSize: 52, fontWeight: FontWeight.bold, letterSpacing: 8)),
        const SizedBox(height: 16),
        const Text(
          'On the other phone, tap "Receive notifications" and type this code.\n'
              'The code expires in 10 minutes if unused.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(),
        const SizedBox(height: 8),
        const Text('Waiting for the other phone...'),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _unpair, child: const Text('Cancel')),
      ]);
    }
    return _centered([
      Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
      const SizedBox(height: 12),
      const Text('Paired!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('The other phone will receive your bird alerts.',
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _openCamera,
          icon: const Icon(Icons.videocam),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Open camera monitor', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
      TextButton(onPressed: _unpair, child: const Text('Unpair')),
    ]);
  }

  Widget _buildReceiverView(bool paired) {
    return _centered([
      Icon(
        paired ? Icons.notifications_active : Icons.hourglass_empty,
        size: 64,
        color: paired ? Colors.green.shade600 : null,
      ),
      const SizedBox(height: 12),
      Text(paired ? 'Paired with the monitor phone' : 'Waiting...',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text(
        'You will get an alert here when a bird or chicken is detected.\n'
            '(Alerts are added in the next step.)',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      TextButton(onPressed: _unpair, child: const Text('Unpair')),
    ]);
  }

  // ---------- Helpers ----------

  Widget _errorText() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Text(_error!,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.red.shade700)),
  );

  Widget _centered(List<Widget> children) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    ),
  );
}