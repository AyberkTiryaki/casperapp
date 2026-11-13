import 'package:flutter/widgets.dart';

/// Bir diyalog içinde kullanılan [TextEditingController]'ı diyalog route'u tamamen
/// kaldırıldığında (kapanış animasyonu bittikten sonra) siler.
///
/// `showDialog` döndükten hemen sonra `dispose()` çağırmak hatalıdır: kapanış
/// animasyonu birkaç kare boyunca alanı yeniden çizer ve "TextEditingController was
/// used after being disposed" hatası verir. Diyalog sonucu, `Navigator.pop` ile
/// metnin kendisi döndürülerek alınır.
class TextControllerScope extends StatefulWidget {
  const TextControllerScope({
    super.key,
    this.initialText = '',
    required this.builder,
  });

  final String initialText;
  final Widget Function(BuildContext context, TextEditingController controller)
  builder;

  @override
  State<TextControllerScope> createState() => _TextControllerScopeState();
}

class _TextControllerScopeState extends State<TextControllerScope> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
