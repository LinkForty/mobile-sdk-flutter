import 'package:flutter/material.dart';
import 'package:linkforty_flutter/linkforty_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkForty Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LinkFortyDemo(),
    );
  }
}

class LinkFortyDemo extends StatefulWidget {
  const LinkFortyDemo({Key? key}) : super(key: key);

  @override
  State<LinkFortyDemo> createState() => _LinkFortyDemoState();
}

class _LinkFortyDemoState extends State<LinkFortyDemo> {
  // App State (Equivalent to SwiftUI AppState)
  String? _installId;
  bool _isAttributed = false;
  DeepLinkData? _deepLinkData;
  int _eventCount = 0;
  int _queuedEvents = 0;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _createdLinkURL;
  String? _createdLinkShortCode;

  @override
  void initState() {
    super.initState();
    _initializeSDK();
  }

  Future<void> _initializeSDK() async {
    try {
      // Configure SDK
      final config = LinkFortyConfig(
        baseURL: Uri.parse('https://api.linkforty.com'),
        apiKey: 'your-api-key-here',
        debug: true,
      );

      // Register callbacks before initialization
      LinkForty.instanceOrNull?.onDeferredDeepLink((data) {
        if (!mounted) return;
        setState(() {
          _deepLinkData = data;
        });
        debugPrint('📱 Deferred deep link received: $data');
      });

      LinkForty.instanceOrNull?.onDeepLink((uri, data) {
        if (!mounted) return;
        setState(() {
          _deepLinkData = data;
        });
        debugPrint('🔗 Deep link opened: $uri');
        debugPrint('   Data: $data');
      });

      // Initialize SDK
      final response = await LinkForty.initialize(config: config);

      if (!mounted) return;
      setState(() {
        _installId = response.installId;
        _isAttributed = response.attributed;
        _isInitialized = true;
        _queuedEvents = LinkForty.instance.queuedEventCount;
      });

      debugPrint('✅ SDK initialized successfully');
      debugPrint('   Install ID: ${response.installId}');
      debugPrint('   Attributed: ${response.attributed}');

      if (response.attributed) {
        debugPrint('   Confidence: ${response.confidenceScore}%');
        debugPrint('   Matched factors: ${response.matchedFactors}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      debugPrint('❌ SDK initialization failed: $e');
    }
  }

  Future<void> _trackEvent(String name) async {
    try {
      await LinkForty.instance.trackEvent(
        name,
        {
          'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
          'source': 'example_app',
        },
      );

      if (!mounted) return;
      setState(() {
        _eventCount++;
        _queuedEvents = LinkForty.instance.queuedEventCount;
      });

      debugPrint('✅ Event tracked: $name');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      debugPrint('❌ Event tracking failed: $e');
    }
  }

  Future<void> _trackRevenue(double amount, String currency) async {
    try {
      await LinkForty.instance.trackRevenue(
        amount: amount,
        currency: currency,
        properties: {
          'product': 'example_product',
          'quantity': 1,
        },
      );

      if (!mounted) return;
      setState(() {
        _eventCount++;
        _queuedEvents = LinkForty.instance.queuedEventCount;
      });

      debugPrint('✅ Revenue tracked: $amount $currency');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      debugPrint('❌ Revenue tracking failed: $e');
    }
  }

  Future<void> _createLink() async {
    try {
      final options = CreateLinkOptions(
        deepLinkParameters: {'route': 'EXAMPLE', 'id': '123'},
        title: 'Example Link',
        templateId: 'tpl_123',
      );

      final result = await LinkForty.instance.createLink(options);

      if (!mounted) return;
      setState(() {
        _createdLinkURL = result.url;
        _createdLinkShortCode = result.shortCode;
      });

      debugPrint('Link created: ${result.url}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      debugPrint('Link creation failed: $e');
    }
  }

  Future<void> _flushEvents() async {
    await LinkForty.instance.flushEvents();
    if (!mounted) return;
    setState(() {
      _queuedEvents = LinkForty.instance.queuedEventCount;
    });
    debugPrint('✅ Events flushed');
  }

  Future<void> _clearData() async {
    await LinkForty.instance.clearData();
    if (!mounted) return;
    setState(() {
      _installId = null;
      _isAttributed = false;
      _deepLinkData = null;
      _eventCount = 0;
      _queuedEvents = 0;
      _createdLinkURL = null;
      _createdLinkShortCode = null;
    });
    debugPrint('Data cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LinkForty Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Section
            _StatusSection(
              isInitialized: _isInitialized,
              eventCount: _eventCount,
              queuedEvents: _queuedEvents,
            ),
            const SizedBox(height: 20),

            // Attribution Section
            _AttributionSection(
              installId: _installId,
              isAttributed: _isAttributed,
            ),
            const SizedBox(height: 20),

            // Events Section
            _EventsSection(
              onTrackEvent: _trackEvent,
              onTrackRevenue: _trackRevenue,
              onFlushEvents: _flushEvents,
            ),
            const SizedBox(height: 20),

            // Link Creation Section
            _LinkCreationSection(
              onCreateLink: _createLink,
              createdLinkURL: _createdLinkURL,
              createdLinkShortCode: _createdLinkShortCode,
            ),
            const SizedBox(height: 20),

            // Deep Link Section
            _DeepLinkSection(deepLinkData: _deepLinkData),
            const SizedBox(height: 20),

            // Data Management Section
            _DataManagementSection(onClearData: _clearData),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionContainer({
    Key? key,
    required this.title,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  final bool isInitialized;
  final int eventCount;
  final int queuedEvents;

  const _StatusSection({
    Key? key,
    required this.isInitialized,
    required this.eventCount,
    required this.queuedEvents,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'SDK Status',
      child: Column(
        children: [
          _RowItem(
            label: 'Initialized:',
            value: Icon(
              isInitialized ? Icons.check_circle : Icons.cancel,
              color: isInitialized ? Colors.green : Colors.red,
            ),
          ),
          _RowItem(
            label: 'Events Tracked:',
            value: Text('$eventCount',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          _RowItem(
            label: 'Queued Events:',
            value: Text('$queuedEvents',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AttributionSection extends StatelessWidget {
  final String? installId;
  final bool isAttributed;

  const _AttributionSection({
    Key? key,
    this.installId,
    required this.isAttributed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Attribution',
      child: Column(
        children: [
          if (installId != null)
            _RowItem(
              label: 'Install ID:',
              value: Expanded(
                child: Text(
                  installId!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
          _RowItem(
            label: 'Attributed:',
            value: Icon(
              isAttributed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isAttributed ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsSection extends StatelessWidget {
  final Function(String) onTrackEvent;
  final Function(double, String) onTrackRevenue;
  final VoidCallback onFlushEvents;

  const _EventsSection({
    Key? key,
    required this.onTrackEvent,
    required this.onTrackRevenue,
    required this.onFlushEvents,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Track Events',
      child: Column(
        children: [
          _FullWidthButton(
            onPressed: () => onTrackEvent('button_clicked'),
            icon: Icons.touch_app,
            label: 'Track Button Click',
            color: Colors.blue,
          ),
          const SizedBox(height: 10),
          _FullWidthButton(
            onPressed: () => onTrackEvent('page_viewed'),
            icon: Icons.visibility,
            label: 'Track Page View',
            color: Colors.blue,
          ),
          const SizedBox(height: 10),
          _FullWidthButton(
            onPressed: () => onTrackRevenue(29.99, 'USD'),
            icon: Icons.monetization_on,
            label: 'Track Revenue (\$29.99)',
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          _FullWidthButton(
            onPressed: onFlushEvents,
            icon: Icons.refresh,
            label: 'Flush Event Queue',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _LinkCreationSection extends StatelessWidget {
  final VoidCallback onCreateLink;
  final String? createdLinkURL;
  final String? createdLinkShortCode;

  const _LinkCreationSection({
    Key? key,
    required this.onCreateLink,
    this.createdLinkURL,
    this.createdLinkShortCode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Link Creation',
      child: Column(
        children: [
          _FullWidthButton(
            onPressed: onCreateLink,
            icon: Icons.add_link,
            label: 'Create Short Link',
            color: Colors.purple,
          ),
          if (createdLinkURL != null) ...[
            const SizedBox(height: 10),
            Text('URL: $createdLinkURL', style: const TextStyle(fontSize: 12)),
            if (createdLinkShortCode != null)
              Text('Short Code: $createdLinkShortCode',
                  style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _DeepLinkSection extends StatelessWidget {
  final DeepLinkData? deepLinkData;

  const _DeepLinkSection({
    Key? key,
    this.deepLinkData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Deep Link Data',
      child: deepLinkData == null
          ? const Text('No deep link data',
              style: TextStyle(color: Colors.grey, fontSize: 12))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TextItem(label: 'Short Code', value: deepLinkData!.shortCode),
                if (deepLinkData!.iosURL != null)
                  _TextItem(label: 'iOS URL', value: deepLinkData!.iosURL),
                if (deepLinkData!.deepLinkPath != null)
                  _TextItem(
                      label: 'Deep Link Path',
                      value: deepLinkData!.deepLinkPath),
                if (deepLinkData!.appScheme != null)
                  _TextItem(
                      label: 'App Scheme', value: deepLinkData!.appScheme),
                if (deepLinkData!.linkId != null)
                  _TextItem(
                      label: 'Link ID',
                      value: deepLinkData!.linkId,
                      color: Colors.grey),
                if (deepLinkData!.utmParameters != null) ...[
                  if (deepLinkData!.utmParameters!.source != null)
                    _TextItem(
                        label: 'UTM Source',
                        value: deepLinkData!.utmParameters!.source),
                  if (deepLinkData!.utmParameters!.campaign != null)
                    _TextItem(
                        label: 'UTM Campaign',
                        value: deepLinkData!.utmParameters!.campaign),
                ],
                if (deepLinkData!.customParameters != null &&
                    deepLinkData!.customParameters!.isNotEmpty)
                  _TextItem(
                      label: 'Custom Params',
                      value: '${deepLinkData!.customParameters!.length}'),
              ],
            ),
    );
  }
}

class _DataManagementSection extends StatelessWidget {
  final VoidCallback onClearData;

  const _DataManagementSection({
    Key? key,
    required this.onClearData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Data Management',
      child: _FullWidthButton(
        onPressed: onClearData,
        icon: Icons.delete,
        label: 'Clear All Data',
        color: Colors.red,
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final Widget value;

  const _RowItem({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          value,
        ],
      ),
    );
  }
}

class _TextItem extends StatelessWidget {
  final String label;
  final String? value;
  final Color? color;

  const _TextItem({
    Key? key,
    required this.label,
    this.value,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        '$label: ${value ?? ""}',
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }
}

class _FullWidthButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _FullWidthButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
