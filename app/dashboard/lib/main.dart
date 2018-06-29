// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:dashboard/build_status_model.dart';
import 'package:dashboard/dashboard_app.dart';
import 'package:dashboard/dashboard_module_model.dart';
import 'package:dashboard/service/build_service.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fidl_fuchsia_testing_runner/fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

const List<List<List<String>>> _kTargetsMap = const <List<List<String>>>[
  const <List<String>>[
    const <String>[
      'topaz-arm64-debug-qemu_kvm',
      'arm64-debug',
      'topaz',
    ],
    const <String>[
      'topaz-arm64-release-qemu_kvm',
      'arm64-release',
      'topaz',
    ],
    const <String>[
      'topaz-x64-debug-qemu_kvm',
      'x64-debug',
      'topaz',
    ],
    const <String>[
      'topaz-x64-release-qemu_kvm',
      'x64-release',
      'topaz',
    ],
  ],
  const <List<String>>[
    const <String>[
      'peridot-arm64-debug-qemu_kvm',
      'arm64-debug',
      'peridot',
    ],
    const <String>[
      'peridot-arm64-release-qemu_kvm',
      'arm64-release',
      'peridot',
    ],
    const <String>[
      'peridot-x64-debug-qemu_kvm',
      'x64-debug',
      'peridot',
    ],
    const <String>[
      'peridot-x64-release-qemu_kvm',
      'x64-release',
      'peridot',
    ],
  ],
  const <List<String>>[
    const <String>[
      'garnet-arm64-debug-qemu_kvm',
      'arm64-debug',
      'garnet',
    ],
    const <String>[
      'garnet-arm64-release-qemu_kvm',
      'arm64-release',
      'garnet',
    ],
    const <String>[
      'garnet-x64-debug-qemu_kvm',
      'x64-debug',
      'garnet',
    ],
    const <String>[
      'garnet-x64-release-qemu_kvm',
      'x64-release',
      'garnet',
    ],
  ],
  const <List<String>>[
    const <String>[
      'zircon-arm64-clang-qemu_kvm',
      'arm64-clang',
      'zircon',
    ],
    const <String>[
      'zircon-arm64-gcc-qemu_kvm',
      'arm64-gcc',
      'zircon',
    ],
    const <String>[
      'zircon-x64-clang-qemu_kvm',
      'x64-clang',
      'zircon',
    ],
    const <String>[
      'zircon-x64-gcc-qemu_kvm',
      'x64-gcc',
      'zircon',
    ],
  ],
  const <List<String>>[
    const <String>[
      'web_view-x64-linux',
      'x64-linux',
      'web_view',
    ],
    const <String>[
      'web_view-arm64-linux',
      'arm64-linux',
      'web_view',
    ],
    const <String>[
      'jiri-x64-linux',
      'x64-linux',
      'jiri',
    ],
    const <String>[
      'jiri-x64-mac',
      'x64-mac',
      'jiri',
    ],
  ],
  const <List<String>>[
    const <String>[
      'zircon-roller',
      'zircon',
      'roller',
    ],
    const <String>[
      'garnet-roller',
      'garnet',
      'roller',
    ],
    const <String>[
      'peridot-roller',
      'peridot',
      'roller',
    ],
  ]
];

const String _kLastUpdate = '/system/data/build/last-update';
const String _testName = 'dashboard_boot_test';

TestRunnerProxy runnerProxy;
LauncherProxy launcherProxy;

final List<List<BuildStatusModel>> _buildStatusModels =
    <List<BuildStatusModel>>[];

void main() {
  setupLogger();

  DateTime buildTimestamp;
  File lastUpdateFile = new File(_kLastUpdate);
  if (lastUpdateFile.existsSync()) {
    String lastUpdate = lastUpdateFile.readAsStringSync();
    log.info('Build timestamp: ${lastUpdate.trim()}');
    try {
      buildTimestamp = DateTime.parse(lastUpdate.trim());
    } on FormatException {
      log.warning('Could not parse build timestamp! ${lastUpdate.trim()}');
    }
  }

  final BuildService buildService = new BuildService();

  for (List<List<String>> buildConfigs in _kTargetsMap) {
    List<BuildStatusModel> categoryModels = <BuildStatusModel>[];
    for (List<String> config in buildConfigs) {
      BuildStatusModel buildStatusModel = new BuildStatusModel(
        type: config[2],
        name: config[1],
        url: config[0],
        buildService: buildService,
      )..start();
      categoryModels.add(buildStatusModel);
    }
    _buildStatusModels.add(categoryModels);
  }

  StartupContext startupContext = new StartupContext.fromStartupInfo();

  DashboardModuleModel dashboardModuleModel = new DashboardModuleModel(
    startupContext: startupContext,
    buildStatusModels: _buildStatusModels,
  );

  ModuleWidget<DashboardModuleModel> moduleWidget =
      new ModuleWidget<DashboardModuleModel>(
    startupContext: startupContext,
    moduleModel: dashboardModuleModel,
    child: new DashboardApp(
      buildService: buildService,
      buildStatusModels: _buildStatusModels,
      buildTimestamp: buildTimestamp,
      onRefresh: onRefresh,
      onLaunchUrl: dashboardModuleModel.launchWebView,
    ),
  );

  runApp(moduleWidget);

  moduleWidget.advertise();
  dashboardModuleModel.loadDeviceMap();

  _reportTestResultsIfInTestHarness(startupContext.environmentServices);
}

void onRefresh() {
  _buildStatusModels
      .expand((List<BuildStatusModel> models) => models)
      // ignore: avoid_function_literals_in_foreach_calls
      .forEach((BuildStatusModel model) => model.refresh());
}

void _reportTestResultsIfInTestHarness(
    ServiceProviderProxy environmentServices) {
  runnerProxy = new TestRunnerProxy();
  try {
    connectToService(environmentServices, runnerProxy.ctrl);
    runnerProxy.identify(_testName, () {});
    try {
      launcherProxy = new LauncherProxy();
      connectToService(environmentServices, launcherProxy.ctrl);

      runTestIterations();
    } on Exception catch (e) {
      log.warning('Not able to launch. Not enabling test mode: $e');
      runnerProxy.teardown(() {
        runnerProxy.ctrl.close();
      });
    }
  } on Exception catch (e) {
    log.warning('Not in automated test. Using normal mode: $e');
  }
}

const int kMaxAttempts = 3;
const int kDelayBeforeCaptureSeconds = 7;

int _iterationAttempt = 0;

void runTestIterations() {
  Stopwatch stopWatch = new Stopwatch()..start();
  new Timer(const Duration(seconds: kDelayBeforeCaptureSeconds), () {
    LaunchInfo launchInfo =
        new LaunchInfo(url: 'screencap', arguments: ['-histogram']);
    final ComponentControllerProxy controller = new ComponentControllerProxy();
    launcherProxy.createComponent(launchInfo, controller.ctrl.request());
    controller.wait((int r) {
      if (r == 0) {
        log.info('elapsed: ${stopWatch.elapsedMilliseconds}');
        TestResult testResult = new TestResult(
          name: _testName,
          elapsed: stopWatch.elapsedMilliseconds,
          failed: false,
          message: 'success',
        );
        launcherProxy.ctrl.close();
        runnerProxy
          ..reportResult(testResult)
          ..teardown(() {
            runnerProxy.ctrl.close();
          });
        return;
      } else {
        _iterationAttempt++;
        if (_iterationAttempt >= kMaxAttempts) {
          log.info('elapsed: ${stopWatch.elapsedMilliseconds}');
          TestResult testResult = new TestResult(
              name: _testName,
              elapsed: stopWatch.elapsedMilliseconds,
              failed: true,
              message: 'failed: See log for more info');
          launcherProxy.ctrl.close();
          runnerProxy
            ..reportResult(testResult)
            ..teardown(() {
              runnerProxy.ctrl.close();
            });
          return;
        }

        // Try refreshing the screen captures and comparing again
        onRefresh();
        runTestIterations();
      }
    });
  });
}
