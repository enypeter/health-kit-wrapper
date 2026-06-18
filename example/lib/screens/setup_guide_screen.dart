import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';

/// Platform-specific setup instructions to ensure health data syncs properly.
///
/// Samsung users need to enable Health Connect writes in Samsung Health.
/// Google Fit users need to link Health Connect.
/// iOS users need to grant access in Health app settings.
class SetupGuideScreen extends StatelessWidget {
  const SetupGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            Platform.isIOS ? 'Apple Health Setup' : 'Health Connect Setup',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            Platform.isIOS
                ? 'Grant this app access to your health data in Apple Health.'
                : 'Enable health data sync from your fitness apps to Health Connect.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          if (Platform.isAndroid) ...[
            _SetupCard(
              title: 'Samsung Health Users',
              icon: Icons.watch,
              color: Colors.blue,
              steps: const [
                'Open Samsung Health app',
                'Tap menu (three dots) > Settings',
                'Tap "Health Connect"',
                'Enable "Sync data with Health Connect"',
                'Select which data types to share (steps, heart rate, sleep, etc.)',
                'Data will start syncing automatically',
              ],
              tip: 'Samsung Galaxy Watch users: Sleep and heart rate data from your watch '
                  'flows through Samsung Health → Health Connect → this app.',
            ),
            const SizedBox(height: 16),
            _SetupCard(
              title: 'Google Fit Users',
              icon: Icons.fitness_center,
              color: Colors.green,
              steps: const [
                'Install Health Connect from the Play Store (if not pre-installed)',
                'Open Google Fit app',
                'Go to Profile > Settings',
                'Tap "Manage connected apps"',
                'Enable Health Connect sync',
                'Choose data types to share',
              ],
              tip: 'On Android 14+, Health Connect is built into Settings > Health Connect. '
                  'On older versions, install it from the Play Store.',
            ),
            const SizedBox(height: 16),
            _SetupCard(
              title: 'Fitbit / Garmin / Oura Users',
              icon: Icons.device_hub,
              color: Colors.orange,
              steps: const [
                'Open your device\'s companion app (Fitbit, Garmin Connect, Oura)',
                'Go to Settings > Health Connect (or Connected Apps)',
                'Enable sync with Health Connect',
                'Select all data types you want to share',
                'Ensure background sync is enabled',
              ],
              tip: 'Data from wearables syncs through their companion app to Health Connect. '
                  'Keep the companion app installed and running for continuous sync.',
            ),
            const SizedBox(height: 16),
            _SetupCard(
              title: 'Open Health Connect',
              icon: Icons.health_and_safety,
              color: Colors.teal,
              steps: const [
                'Review all connected apps and their permissions',
                'Check which apps are writing data',
                'Manage data deletion if needed',
              ],
              action: FilledButton.icon(
                onPressed: HealthKitWrapper.openHealthApp,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Health Connect'),
              ),
            ),
          ],
          if (Platform.isIOS) ...[
            _SetupCard(
              title: 'Grant Health Access',
              icon: Icons.favorite,
              color: Colors.red,
              steps: const [
                'When prompted, tap "Allow" for each data type',
                'If you previously denied access:',
                '  Open Settings > Health > Data Access & Devices',
                '  Find this app and enable the data types',
              ],
              tip: 'iOS shows the permission prompt once. If you denied access, '
                  'you must re-enable it manually in Settings.',
            ),
            const SizedBox(height: 16),
            _SetupCard(
              title: 'Apple Watch Users',
              icon: Icons.watch,
              color: Colors.blue,
              steps: const [
                'Ensure your Apple Watch is paired and synced',
                'Heart rate, HRV (SDNN), and activity data sync automatically',
                'Sleep tracking requires watchOS sleep schedule to be configured',
                'Open the Health app to verify data is appearing',
              ],
              tip: 'Apple Watch data writes directly to HealthKit. '
                  'No extra setup needed — just grant this app read access.',
            ),
            const SizedBox(height: 16),
            _SetupCard(
              title: 'Open Health App',
              icon: Icons.health_and_safety,
              color: Colors.teal,
              steps: const [
                'Review your health data and connected sources',
                'Manage app permissions under Data Access & Devices',
              ],
              action: FilledButton.icon(
                onPressed: HealthKitWrapper.openHealthApp,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Health App'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.onTertiaryContainer),
                    const SizedBox(width: 8),
                    Text('Platform Note',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        )),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isIOS
                        ? 'HRV on iOS uses SDNN (standard deviation of NN intervals). '
                          'Android uses RMSSD. These are different statistical measures '
                          'and should not be compared directly across platforms.'
                        : 'HRV on Android uses RMSSD (root mean square of successive differences). '
                          'iOS uses SDNN. These are different statistical measures '
                          'and should not be compared directly across platforms.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> steps;
  final String? tip;
  final Widget? action;

  const _SetupCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.steps,
    this.tip,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) {
              final isSubStep = entry.value.startsWith('  ');
              return Padding(
                padding: EdgeInsets.only(
                  left: isSubStep ? 24 : 0,
                  bottom: 6,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isSubStep) ...[
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        isSubStep ? entry.value.trim() : entry.value,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSubStep
                              ? Theme.of(context).colorScheme.outline
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (tip != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tip!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline)),
                    ),
                  ],
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
