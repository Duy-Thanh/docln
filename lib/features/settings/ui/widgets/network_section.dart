import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:docln/features/settings/logic/network_settings_provider.dart';
import 'package:docln/core/services/settings_services.dart';
import 'package:docln/core/widgets/custom_toast.dart';
import 'package:docln/core/services/dns_service.dart';

class NetworkSection extends StatefulWidget {
  final Function() onSettingsChanged;

  const NetworkSection({super.key, required this.onSettingsChanged});

  @override
  State<NetworkSection> createState() => _NetworkSectionState();
}

class _NetworkSectionState extends State<NetworkSection> {
  // TexControllers must be disposed, or we should listen to provider changes
  // Ideally, we move text editing state to local state and sync with provider on change/blur
  // For simplicity matching existing logic, we'll keep controllers here and sync.

  late TextEditingController _proxyAddressCtrl;
  late TextEditingController _proxyPortCtrl;
  late TextEditingController _proxyUserCtrl;
  late TextEditingController _proxyPassCtrl;
  late TextEditingController _customDnsCtrl;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<NetworkSettingsProvider>(
      context,
      listen: false,
    );
    _proxyAddressCtrl = TextEditingController(text: provider.proxyAddress);
    _proxyPortCtrl = TextEditingController(text: provider.proxyPort);
    _proxyUserCtrl = TextEditingController(text: provider.proxyUsername);
    _proxyPassCtrl = TextEditingController(text: provider.proxyPassword);
    _customDnsCtrl = TextEditingController(text: provider.customDns);
  }

  @override
  void dispose() {
    _proxyAddressCtrl.dispose();
    _proxyPortCtrl.dispose();
    _proxyUserCtrl.dispose();
    _proxyPassCtrl.dispose();
    _customDnsCtrl.dispose();
    super.dispose();
  }

  // Sync controllers if provider updates from outside (e.g. presets)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<NetworkSettingsProvider>(context);
    if (_proxyAddressCtrl.text != provider.proxyAddress) {
      // Only update if not focused? Or blindly update?
      // For presets, we must update.
      if (provider.proxyType != 'Custom') {
        _proxyAddressCtrl.text = provider.proxyAddress;
      }
    }
    if (_proxyPortCtrl.text != provider.proxyPort) {
      if (provider.proxyType != 'Custom') {
        _proxyPortCtrl.text = provider.proxyPort;
      }
    }
  }

  void _notifyChange() {
    widget.onSettingsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_buildProxySection(context), _buildDnsSection(context)],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(children: children),
    );
  }

  // --- Proxy Section ---

  Widget _buildProxySection(BuildContext context) {
    final provider = context.watch<NetworkSettingsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Proxy Settings'),
        _buildSectionCard(
          children: [
            _buildModernSwitchTile(
              context,
              'Enable Proxy',
              'Use proxy for accessing blocked content',
              Icons.security_rounded,
              provider.isProxyEnabled,
              (value) {
                provider.setProxyEnabled(value);
                _notifyChange();
              },
            ),
            if (provider.isProxyEnabled) ...[
              _buildProxyTypeTile(context, provider),
              _buildProxyConfigurationTile(context, provider),
              _buildProxyInfoBanner(context),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildProxyTypeTile(
    BuildContext context,
    NetworkSettingsProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.dns_rounded, color: colorScheme.primary),
      ),
      title: const Text(
        'Proxy Type',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(provider.proxyType),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showProxyTypeBottomSheet(context, provider),
    );
  }

  Widget _buildProxyConfigurationTile(
    BuildContext context,
    NetworkSettingsProvider provider,
  ) {
    bool isCustom = provider.proxyType == 'Custom';
    final colorScheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.settings_rounded, color: colorScheme.primary),
      ),
      title: const Text(
        'Proxy Configuration',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text('${provider.proxyAddress}:${provider.proxyPort}'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              TextField(
                controller: _proxyAddressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter proxy address (e.g., 1.1.1.1)',
                  border: OutlineInputBorder(),
                ),
                enabled: isCustom,
                onChanged: (val) {
                  provider.setProxyAddress(val);
                  _notifyChange();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proxyPortCtrl,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: 'Enter proxy port (e.g., 80)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: isCustom,
                onChanged: (val) {
                  provider.setProxyPort(val);
                  _notifyChange();
                },
              ),
              const SizedBox(height: 12),
              if (isCustom) ...[
                TextField(
                  controller: _proxyUserCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username (Optional)',
                    hintText: 'Enter username if required',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    provider.setProxyUsername(val);
                    _notifyChange();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proxyPassCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password (Optional)',
                    hintText: 'Enter password if required',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: (val) {
                    provider.setProxyPassword(val);
                    _notifyChange();
                  },
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _testProxyConnection(context, provider),
                icon: const Icon(Icons.network_check),
                label: const Text('Test Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _testProxyConnection(
    BuildContext context,
    NetworkSettingsProvider provider,
  ) async {
    // Validate
    if (provider.proxyAddress.isEmpty || provider.proxyPort.isEmpty) {
      CustomToast.show(context, 'Proxy address and port are required');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final statusCode = await provider.testProxyConnection();

    if (context.mounted) {
      Navigator.pop(context); // Pop Loading
      if (statusCode >= 200 && statusCode < 300) {
        CustomToast.show(context, 'Proxy connection successful! ✅');
      } else if (statusCode == 0) {
        CustomToast.show(context, 'Connection failed with error.');
      } else {
        CustomToast.show(context, 'Connection failed: Status $statusCode');
      }
    }
  }

  void _showProxyTypeBottomSheet(
    BuildContext context,
    NetworkSettingsProvider provider,
  ) {
    final presets = SettingsService.proxyPresets.keys.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Proxy Type',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  return ListTile(
                    leading: Radio<String>(
                      value: preset,
                      groupValue: provider.proxyType,
                      onChanged: (value) {
                        Navigator.pop(context);
                        provider.setProxyType(value!);
                        _notifyChange();
                        // Controllers will update via didChangeDependencies logic or manually
                        if (value != 'Custom') {
                          _proxyAddressCtrl.text = provider.proxyAddress;
                          _proxyPortCtrl.text = provider.proxyPort;
                        }
                      },
                    ),
                    title: Text(preset),
                    subtitle: _getProxyDescription(preset),
                    onTap: () {
                      Navigator.pop(context);
                      provider.setProxyType(preset);
                      _notifyChange();
                      if (preset != 'Custom') {
                        _proxyAddressCtrl.text = provider.proxyAddress;
                        _proxyPortCtrl.text = provider.proxyPort;
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getProxyDescription(String type) {
    switch (type) {
      case 'None':
        return const Text('No proxy (direct connection)');
      case 'Open Proxy 1':
        return const Text('Public HTTP proxy - 91.92.209.35:3128');
      case 'Open Proxy 2':
        return const Text('Public HTTP proxy - 45.173.6.5:999');
      case 'Open Proxy 3':
        return const Text('Public HTTP proxy - 103.151.40.25:80');
      case 'HTTP SOCKS5':
        return const Text('SOCKS5 proxy - 216.137.184.253:80');
      case 'Custom':
        return const Text('Configure your own proxy settings');
      default:
        return const Text('');
    }
  }

  Widget _buildProxyInfoBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'About Proxies',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Public proxies may be unreliable or slow. They can help bypass '
            'network restrictions but may not always work.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // --- DNS Section ---

  Widget _buildDnsSection(BuildContext context) {
    final provider = context.watch<NetworkSettingsProvider>();
    return Column(
      children: [
        _buildSectionHeader(context, 'DNS Settings'),
        _buildSectionCard(
          children: [
            _buildModernSwitchTile(
              context,
              'Enable Custom DNS',
              'Override system DNS settings',
              Icons.dns_rounded,
              provider.isDnsEnabled,
              (value) {
                provider.setDnsEnabled(value);
                _notifyChange();
              },
            ),
            if (provider.isDnsEnabled) ...[
              _buildDnsProviderTile(context, provider),
              _buildDnsConfigurationTile(context, provider),
              _buildDnsInfoBanner(context),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDnsProviderTile(
    BuildContext context,
    NetworkSettingsProvider provider,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.public, color: Colors.green),
      ),
      title: const Text(
        'DNS Provider',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(provider.dnsProvider),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showDnsProviderBottomSheet(context, provider),
    );
  }

  Widget _buildDnsConfigurationTile(
    BuildContext context,
    NetworkSettingsProvider provider,
  ) {
    if (provider.dnsProvider != 'Custom') {
      // Display read-only info
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.settings_rounded,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
        title: const Text(
          'DNS Configuration',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          SettingsService.dnsProviders[provider.dnsProvider] ?? 'Unknown',
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _showDnsInstructions(context),
          icon: const Icon(Icons.help_outline, size: 18),
          label: const Text('How to Configure'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            foregroundColor: Theme.of(context).colorScheme.onTertiary,
          ),
        ),
      );
    }

    // Custom DNS Input
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.settings_rounded,
          color: Theme.of(context).colorScheme.tertiary,
        ),
      ),
      title: const Text(
        'DNS Configuration',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        provider.customDns.isEmpty ? 'No custom DNS set' : provider.customDns,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              TextField(
                controller: _customDnsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom DNS',
                  hintText: 'Enter DNS server (e.g., 1.1.1.1)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  provider.setCustomDns(val);
                  _notifyChange();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDnsProviderBottomSheet(
    BuildContext context,
    NetworkSettingsProvider provider,
  ) {
    final providers = SettingsService.dnsProviders.keys.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select DNS Provider',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: providers.length,
                itemBuilder: (context, index) {
                  final pName = providers[index];
                  return ListTile(
                    leading: Radio<String>(
                      value: pName,
                      groupValue: provider.dnsProvider,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        Navigator.pop(context);
                        provider.setDnsProvider(value!);
                        _notifyChange();
                      },
                    ),
                    title: Text(pName),
                    // subtitle: _getDnsDescription(pName), // Skip for brevity
                    onTap: () {
                      Navigator.pop(context);
                      provider.setDnsProvider(pName);
                      _notifyChange();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDnsInstructions(BuildContext context) {
    final dnsService = DnsService();
    final instructions = dnsService.getDnsSetupInstructions();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('DNS Instructions'),
          ],
        ),
        content: SingleChildScrollView(child: Text(instructions)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDnsInfoBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text(
                'About DNS',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'DNS changes affect your entire device. Configure DNS in Android settings, then enable here for optimization.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // --- Common Helpers ---

  Widget _buildModernSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
      ),
    );
  }
}
