import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../components/AddDownloadLocationScreen/app_directory_location_form.dart';
import '../components/AddDownloadLocationScreen/custom_download_location_form.dart';
import '../models/finamp_models.dart';
import '../services/finamp_settings_helper.dart';

class AddDownloadLocationScreen extends StatefulWidget {
  const AddDownloadLocationScreen({Key? key}) : super(key: key);

  static const routeName = "/settings/downloadlocations/add";

  @override
  State<AddDownloadLocationScreen> createState() =>
      _AddDownloadLocationScreenState();
}

class _AddDownloadLocationScreenState extends State<AddDownloadLocationScreen>
    with SingleTickerProviderStateMixin {
  final customLocationFormKey = GlobalKey<FormState>();
  final appDirectoryFormKey = GlobalKey<FormState>();
  late final List<_DownloadLocationTabKind> _tabKinds = [
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
      _DownloadLocationTabKind.appDirectory,
    _DownloadLocationTabKind.custom,
    if (Platform.isAndroid) _DownloadLocationTabKind.appDirectory,
  ];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: _tabKinds.length);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabKinds
        .map((tabKind) => Tab(
              text: switch (tabKind) {
                _DownloadLocationTabKind.custom =>
                  AppLocalizations.of(context)!.customLocation.toUpperCase(),
                _DownloadLocationTabKind.appDirectory =>
                  AppLocalizations.of(context)!.appDirectory.toUpperCase(),
              },
            ))
        .toList();
    return Provider<NewDownloadLocation>(
      create: (_) => NewDownloadLocation(
        name: null,
        baseDirectory: DownloadLocationType.none,
      ),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.addDownloadLocation),
            bottom: TabBar(
              controller: _tabController,
              tabs: tabs,
            ),
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.check),
            onPressed: () async {
              bool isValidated = false;
              final currentTab = _tabKinds[_tabController.index];

              if (currentTab == _DownloadLocationTabKind.custom) {
                if (customLocationFormKey.currentState?.validate() ?? false) {
                  customLocationFormKey.currentState!.save();
                  context.read<NewDownloadLocation>().baseDirectory =
                      DownloadLocationType.custom;
                  isValidated = true;
                }
              } else {
                if (appDirectoryFormKey.currentState?.validate() ?? false) {
                  appDirectoryFormKey.currentState!.save();
                  context.read<NewDownloadLocation>().baseDirectory =
                      Platform.isAndroid
                          ? DownloadLocationType.external
                          : DownloadLocationType.internalSupport;
                  isValidated = true;
                }
              }

              // We set a variable called isValidated so that we don't have to copy this logic into each validate()
              if (isValidated) {
                final navigator = Navigator.of(context);
                final newDownloadLocation = context.read<NewDownloadLocation>();

                // We don't use DownloadLocation when initially getting the
                // values because DownloadLocation doesn't have nullable values.
                // At this point, the NewDownloadLocation shouldn't have any
                // null values.
                final downloadLocation = await DownloadLocation.create(
                  name: newDownloadLocation.name!,
                  relativePath: newDownloadLocation.path,
                  baseDirectory: newDownloadLocation.baseDirectory,
                );

                if (!mounted) return;
                FinampSettingsHelper.addDownloadLocation(downloadLocation);
                navigator.pop();
              }
            },
          ),
          body: TabBarView(
            controller: _tabController,
            children: _tabKinds
                .map((tabKind) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: switch (tabKind) {
                          _DownloadLocationTabKind.custom =>
                            CustomDownloadLocationForm(
                              formKey: customLocationFormKey,
                            ),
                          _DownloadLocationTabKind.appDirectory =>
                            AppDirectoryLocationForm(
                              formKey: appDirectoryFormKey,
                            ),
                        },
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

enum _DownloadLocationTabKind { custom, appDirectory }
