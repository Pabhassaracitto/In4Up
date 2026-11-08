import 'package:flutter/widgets.dart';

/// Mount each child on first visit, then retain its state while this stack lives.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({super.key, required this.index, required this.children});

  final int index;
  final List<WidgetBuilder> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = {};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_visited.contains(i))
            Builder(builder: widget.children[i])
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
