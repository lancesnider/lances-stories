import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class MagicAlley extends StatefulWidget {
  const MagicAlley({super.key});

  @override
  State<MagicAlley> createState() => _MagicAlleyState();
}

class _MagicAlleyState extends State<MagicAlley> {
  late File file;
  late RiveWidgetController controller;
  bool isInitialized = false;

  late ViewModelInstance viewModelInstance;

  @override
  void initState() {
    super.initState();
    initRive();
  }

  void initRive() async {
    file = (await File.asset(
      "assets/rive/magic_alley_12.riv",
      riveFactory: Factory.rive,
    ))!;
    controller = RiveWidgetController(file);
    _initViewModel();
    setState(() => isInitialized = true);
  }

  void _initViewModel() {
    viewModelInstance = controller.dataBind(DataBind.auto());
    debugPrint(viewModelInstance.properties.toString());
  }

  @override
  void dispose() {
    file.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return RiveWidget(
      controller: controller,
      fit: Fit.layout,
      layoutScaleFactor: .421,
    );
  }
}
